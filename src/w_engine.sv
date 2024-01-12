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

module w_engine #(
    parameter AXI_ADDR_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_MAX_AWLEN = 0,
    parameter INTERNAL_ADDR_WIDTH = 0,
    parameter BTT_WIDTH = 0,
    parameter SYNC_AW_W = 0
) (
    input clk,
    input rstn,
    input [INTERNAL_ADDR_WIDTH-1:0] start_addr,
    input [BTT_WIDTH-1:0] btt,
    input start,
    input enable,
    input aw_sync,
    input write_zero,
    output w_sync,
    output new_transaction,
    AXI4_W.master w_chan,
    FIFO_READ.master data_fifo
);

    localparam LOW_ALIGN_BITS = $clog2(AXI_DATA_WIDTH/8);
    localparam TRANSFERS_WIDTH = BTT_WIDTH-LOW_ALIGN_BITS;
    localparam AXI_WSTRB_WIDTH = AXI_DATA_WIDTH/8;

    typedef enum bit [2:0] {
        IDLE,
        COMPUTE_LEN_WSTRB,
        WAIT_FIFO,
        SEND_W,
        AW_SYNC
    } State_t;

    State_t state;

    reg [TRANSFERS_WIDTH-1:0] transfers_left;
    wire [7:0] len;
    reg [7:0] cur_len;
    reg first_burst;
    reg [LOW_ALIGN_BITS-1:0] first_alignment;
    reg [LOW_ALIGN_BITS-1:0] last_alignment;
    reg [AXI_WSTRB_WIDTH-1:0] wstrb;

    wire last;

    wire [BTT_WIDTH-1:0] actual_btt;

    transaction_generator #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_MAX_LEN(AXI_MAX_AWLEN),
        .ADDR_WIDTH(INTERNAL_ADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) transaction_generator_I (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .advance(state == SEND_W && w_chan.wready && cur_len == len),
        .start_addr(start_addr),
        .btt(btt),
        .len(len),
        .addr(),
        .last(last)
    );

    function void set_first_wstrb();
        if (transfers_left == 1) begin
            for (int i = 0; i < AXI_WSTRB_WIDTH; ++i) begin
                wstrb[i] <= (first_alignment <= i[LOW_ALIGN_BITS-1:0]) && (last_alignment == 0 || i[LOW_ALIGN_BITS-1:0] < last_alignment);
            end
        end else begin
            for (int i = 0; i < AXI_WSTRB_WIDTH; ++i) begin
                wstrb[i] <= first_alignment <= i[LOW_ALIGN_BITS-1:0];
            end
            wstrb[AXI_WSTRB_WIDTH-1] <= 1'b1;
        end
    endfunction

    function void set_last_wstrb();
        for (int i = AXI_WSTRB_WIDTH-1; i > 0; --i) begin
            wstrb[i] <= last_alignment == 0 || i[LOW_ALIGN_BITS-1:0] < last_alignment;
        end
        wstrb[0] <= 1'b1;
    endfunction

    assign actual_btt = btt + {{TRANSFERS_WIDTH{1'b0}}, start_addr[LOW_ALIGN_BITS-1:0]};

    assign data_fifo.read = (state == COMPUTE_LEN_WSTRB && enable && !data_fifo.empty) || (state == SEND_W && w_chan.wready && !data_fifo.empty && cur_len != len) || (state == WAIT_FIFO && !data_fifo.empty);

    assign w_chan.wvalid = state == SEND_W;
    assign w_chan.wdata = write_zero ? {AXI_DATA_WIDTH{1'b0}} : data_fifo.data;
    assign w_chan.wstrb = wstrb;
    assign w_chan.wlast = cur_len == len;

    assign w_sync = (state == SEND_W && w_chan.wready && cur_len == len) || state == AW_SYNC;

    assign new_transaction = state == SEND_W && w_chan.wready && cur_len == len;

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                transfers_left <= actual_btt[BTT_WIDTH-1:LOW_ALIGN_BITS] + {{TRANSFERS_WIDTH-1{1'b0}}, (|actual_btt[LOW_ALIGN_BITS-1:0])};
                last_alignment <= actual_btt[LOW_ALIGN_BITS-1:0];
                first_alignment <= start_addr[LOW_ALIGN_BITS-1:0];
                first_burst <= 1'b1;

                if (start) begin
                    state <= COMPUTE_LEN_WSTRB;
                end
            end

            COMPUTE_LEN_WSTRB: begin
                if (first_burst) begin
                    set_first_wstrb();
                end
                cur_len <= 8'd0;
                if (enable && (!data_fifo.empty || write_zero)) begin
                    first_burst <= 1'b0;
                    state <= SEND_W;
                end
            end

            WAIT_FIFO: begin
                if (!data_fifo.empty) begin
                    state <= SEND_W;
                end
            end

            SEND_W: begin
                if (w_chan.wready) begin
                    cur_len <= cur_len + 8'd1;
                    transfers_left <= transfers_left - 1;
                    if (transfers_left == 2) begin
                        set_last_wstrb();
                    end else begin
                        wstrb <= {AXI_WSTRB_WIDTH{1'b1}};
                    end
                    if (transfers_left == 1) begin
                        state <= IDLE;
                    end else if (cur_len == len) begin
                        if (SYNC_AW_W) begin
                            if (aw_sync) begin
                                state <= COMPUTE_LEN_WSTRB;
                            end else begin
                                state <= AW_SYNC;
                            end
                        end else begin
                            state <= COMPUTE_LEN_WSTRB;
                        end
                    end else if (!write_zero && data_fifo.empty) begin
                        state <= WAIT_FIFO;
                    end
                end
            end

            AW_SYNC: begin
                if (aw_sync) begin
                    state <= COMPUTE_LEN_WSTRB;
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
