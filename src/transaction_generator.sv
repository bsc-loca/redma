// Copyright 2023 Barcelona Supercomputing Center (BSC)
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Licensed under the Solderpad Hardware License v 2.1 (the “License”);
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at

// https://solderpad.org/licenses/SHL-2.1/

// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.

//
// Juan Miguel de Haro <juan.deharoruiz@bsc.es>

module transaction_generator #(
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_MAX_LEN = 0,
    parameter ADDR_WIDTH = 0,
    parameter BTT_WIDTH = 0
) (
    input clk,
    input rstn,
    input start,
    input advance,
    input [ADDR_WIDTH-1:0] start_addr,
    input [BTT_WIDTH-1:0] btt,
    output reg [7:0] len,
    output [ADDR_WIDTH-1:0] addr,
    output last
);

    localparam BYTES_PER_TRANSFER = AXI_DATA_WIDTH/8;
    localparam MAX_BYTES_PER_TRANSACTION = BYTES_PER_TRANSFER*(AXI_MAX_LEN+1);
    localparam HIGH_4K_ADDR_BITS = ADDR_WIDTH-12;
    localparam ADDR_4K_COMPARE_BITS = MAX_BYTES_PER_TRANSACTION < 4096 ? 1 : $clog2(MAX_BYTES_PER_TRANSACTION/4096 + 1);
    localparam TRANSFERS_WIDTH = BTT_WIDTH;

    typedef enum bit [1:0] {
        IDLE,
        COMPUTE_TRANSACTION,
        WAIT_ADVANCE
    } State_t;

    State_t state;
    reg [TRANSFERS_WIDTH-1:0] transfers_left;
    reg [ADDR_WIDTH-1:0] aligned_addr;

    wire [8:0] transfers;
    wire [HIGH_4K_ADDR_BITS-1:0] next_4k_page;
    wire [ADDR_WIDTH-1:0] last_transaction_addr;

    wire [7:0] len_sig;
    wire [7:0] len_4k_sig;

    wire [BTT_WIDTH-1:0] actual_btt;

    // SUPPORT FOR NON-POWER OF 2 DATA BUSES
    logic [BTT_WIDTH-1:0] act_btt_div, act_btt_reminder;
    logic [ADDR_WIDTH-1:0] addr_div, addr_reminder, addr_high, full_aligned_addr;

    assign addr = full_aligned_addr;
    assign len_sig = transfers_left < AXI_MAX_LEN+1 ? transfers_left[7:0]-8'd1 : AXI_MAX_LEN[7:0];

    // assign len_4k_sig = addr[12+ADDR_4K_COMPARE_BITS-1:12] != last_transaction_addr[12+ADDR_4K_COMPARE_BITS-1:12] ?
    //                         {next_4k_page, {12-LOW_ALIGN_BITS{1'b0}}} - addr[ADDR_WIDTH-1:LOW_ALIGN_BITS] - 8'd1 : AXI_MAX_LEN[7:0];
    assign len_4k_sig = '1; // BYPASSED - Not needed for GAVINA

    assign last = transfers_left <= transfers;
    assign transfers = len + 8'd1;
    assign actual_btt = btt + addr_reminder;
    assign last_transaction_addr = full_aligned_addr + AXI_MAX_LEN*BYTES_PER_TRANSFER;
    assign next_4k_page = addr[ADDR_WIDTH-1:12] + {{HIGH_4K_ADDR_BITS-1{1'b0}}, 1'b1};

    // SUPPORT FOR NON-POWER OF 2 DATA BUSES
    assign act_btt_div =        actual_btt / BYTES_PER_TRANSFER;
    assign act_btt_reminder =   actual_btt % BYTES_PER_TRANSFER;

    localparam ACTUAL_ADDR_MASK = ~(gavina_addr_pkg::MEM_ADDR_MASK | gavina_addr_pkg::AXI_CORE_ADDR_MASK);
    assign addr_div =           (start_addr & ACTUAL_ADDR_MASK) / BYTES_PER_TRANSFER;
    assign addr_reminder =      (start_addr & ACTUAL_ADDR_MASK) % BYTES_PER_TRANSFER;

    // MSBs cannot be lost!!!!
    assign addr_high = (start_addr & (~ACTUAL_ADDR_MASK));

    assign full_aligned_addr = (aligned_addr*BYTES_PER_TRANSFER) | addr_high;

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                aligned_addr <= addr_div;
                transfers_left <= act_btt_div + (act_btt_reminder>0);

                if (start) begin
                    state <= COMPUTE_TRANSACTION;
                end
            end

            COMPUTE_TRANSACTION: begin
                len <= len_sig < len_4k_sig ? len_sig : len_4k_sig;
                state <= WAIT_ADVANCE;
            end

            WAIT_ADVANCE: begin
                if (advance) begin
                    aligned_addr <= aligned_addr + transfers;
                    transfers_left <= transfers_left - transfers;
                    if (last) begin
                        state <= IDLE;
                    end else begin
                        state <= COMPUTE_TRANSACTION;
                    end
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
