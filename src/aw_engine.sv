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

module aw_engine #(
    parameter AXI_ADDR_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_MAX_AWLEN = 0,
    parameter [AXI_ADDR_WIDTH-1:0] AXI_ADDR_OFFSET = 0,
    parameter INTERNAL_ADDR_WIDTH = 0,
    parameter BTT_WIDTH = 0,
    parameter SYNC_AW_W = 0
) (
    input clk,
    input rstn,
    input [INTERNAL_ADDR_WIDTH-1:0] start_addr,
    input [BTT_WIDTH-1:0] btt,
    input start,
    input writer_fifo_empty,
    input write_zero,
    input enable,
    output new_transaction,
    output last_transaction,
    input w_sync,
    output aw_sync,
    AXI4_AW.master aw_chan
);

    typedef enum bit [1:0] {
        IDLE,
        WAIT_1,
        SEND_AW,
        W_SYNC
    } State_t;

    State_t state;

    wire [7:0] awlen;
    wire [INTERNAL_ADDR_WIDTH-1:0] awaddr;
    wire last;

    transaction_generator #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_MAX_LEN(AXI_MAX_AWLEN),
        .ADDR_WIDTH(INTERNAL_ADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) transaction_generator_I (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .advance(state == SEND_AW && aw_chan.awready),
        .start_addr(start_addr),
        .btt(btt),
        .len(awlen),
        .addr(awaddr),
        .last(last)
    );

    assign aw_chan.awvalid = state == SEND_AW;
    if (AXI_ADDR_WIDTH == INTERNAL_ADDR_WIDTH) begin
        assign aw_chan.awaddr = AXI_ADDR_OFFSET | awaddr;
    end else begin
        assign aw_chan.awaddr = AXI_ADDR_OFFSET | {{AXI_ADDR_WIDTH-INTERNAL_ADDR_WIDTH{1'b0}}, awaddr};
    end
    assign aw_chan.awlen = awlen;
    assign aw_chan.awsize = $clog2(AXI_DATA_WIDTH/8);
    assign aw_chan.awburst = 2'b01; //INCR

    assign new_transaction = state == SEND_AW && aw_chan.awready;
    assign last_transaction = last;

    assign aw_sync = (state == SEND_AW && aw_chan.awready) || state == W_SYNC;

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                if (start) begin
                   state <= WAIT_1;
                end
            end

            WAIT_1: begin
                if (enable) begin
                    if (SYNC_AW_W) begin
                        if (!writer_fifo_empty || write_zero) begin
                            state <= SEND_AW;
                        end
                    end else begin
                        state <= SEND_AW;
                    end
                end
            end

            SEND_AW: begin
                if (aw_chan.awready) begin
                    if (last) begin
                        state <= IDLE;
                    end else begin
                        if (SYNC_AW_W) begin
                            if (w_sync) begin
                                state <= WAIT_1;
                            end else begin
                                state <= W_SYNC;
                            end
                        end else begin
                            state <= WAIT_1;
                        end
                    end
                end
            end

            W_SYNC: begin
                if (w_sync) begin
                    state <= WAIT_1;
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
