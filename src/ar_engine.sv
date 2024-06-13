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


module ar_engine #(
    parameter AXI_ADDR_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_MAX_ARLEN = 0,
    parameter [AXI_ADDR_WIDTH-1:0] AXI_ADDR_OFFSET = 0,
    parameter INTERNAL_ADDR_WIDTH = 0,
    parameter BTT_WIDTH = 0
) (
    input clk,
    input rstn,
    input [INTERNAL_ADDR_WIDTH-1:0] start_addr,
    input [BTT_WIDTH-1:0] btt,
    input start,
    input enable,
    output new_transaction,
    AXI4_AR.master ar_chan
);

    typedef enum bit [1:0] {
        IDLE,
        WAIT_1,
        SEND_AR
    } State_t;

    State_t state;

    wire [7:0] arlen;
    wire [INTERNAL_ADDR_WIDTH-1:0] araddr;
    wire last;

    transaction_generator #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_MAX_LEN(AXI_MAX_ARLEN),
        .ADDR_WIDTH(INTERNAL_ADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) transaction_generator_I (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .advance(state == SEND_AR && ar_chan.arready),
        .start_addr(start_addr),
        .btt(btt),
        .len(arlen),
        .addr(araddr),
        .last(last)
    );

    assign ar_chan.arvalid = state == SEND_AR;
    if (AXI_ADDR_WIDTH == INTERNAL_ADDR_WIDTH) begin
        assign ar_chan.araddr = AXI_ADDR_OFFSET | araddr;
    end else begin
        assign ar_chan.araddr = AXI_ADDR_OFFSET | {{AXI_ADDR_WIDTH-INTERNAL_ADDR_WIDTH{1'b0}}, araddr};
    end
    assign ar_chan.arlen = arlen;
    assign ar_chan.arsize = $clog2(AXI_DATA_WIDTH/8);
    assign ar_chan.arburst = 2'b01; //INCR

    assign new_transaction = state == SEND_AR && ar_chan.arready;

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                if (start) begin
                    state <= WAIT_1;
                end
            end

            WAIT_1: begin
                if (enable) begin
                    state <= SEND_AR;
                end
            end

            SEND_AR: begin
                if (ar_chan.arready) begin
                    if (last) begin
                        state <= IDLE;
                    end else begin
                        state <= WAIT_1;
                    end
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
