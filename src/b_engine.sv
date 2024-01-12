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

module b_engine #(
    parameter AXI_DATA_WIDTH = 0,
    parameter BTT_WIDTH = 0
) (
    input clk,
    input rstn,
    input new_transaction,
    input last_transaction,
    output transaction_confirmed,
    input start,
    output set_intr,
    AXI4_B.master b_chan
);

    localparam LOW_ALIGN_BITS = $clog2(AXI_DATA_WIDTH/8);
    localparam TRANSFERS_WIDTH = BTT_WIDTH-LOW_ALIGN_BITS;

    typedef enum bit [0:0] {
        IDLE,
        B
    } State_t;

    State_t state;

    reg aw_engine_finished;
    reg [TRANSFERS_WIDTH-1:0] transactions_left;

    assign b_chan.bready = state == B;
    assign set_intr = state == B && b_chan.bvalid && transactions_left == 1 && aw_engine_finished;
    assign transaction_confirmed = state == B && b_chan.bvalid;

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                transactions_left <= {TRANSFERS_WIDTH{1'b0}};
                aw_engine_finished <= 1'b0;
                if (start) begin
                    state <= B;
                end
            end

            B: begin
                if (new_transaction && !b_chan.bvalid) begin
                    transactions_left <= transactions_left + 1;
                end else if (b_chan.bvalid && !new_transaction) begin
                    transactions_left <= transactions_left - 1;
                end
                if (new_transaction && last_transaction) begin
                    aw_engine_finished <= 1'b1;
                end
                if (b_chan.bvalid && transactions_left == 1 && aw_engine_finished) begin
                    state <= IDLE;
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
