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

module data_fifo #(
    parameter LEN = 0,
    parameter WIDTH = 0
) (
    input clk,
    input rstn,
    FIFO_READ.slave read_port,
    FIFO_WRITE.slave write_port
);

    localparam CLOG2LEN = $clog2(LEN);
    localparam LAST_IDX = LEN-1;
    localparam CLOG2LEN_0 = {CLOG2LEN{1'b0}};
    localparam CLOG2LEN_1 = {{CLOG2LEN-1{1'b0}}, 1'b1};
    localparam IDX_0 = {CLOG2LEN+1{1'b0}};
    localparam IDX_1 = {{CLOG2LEN{1'b0}}, 1'b1};
    localparam POWER_2 = (LEN & (LEN-1)) == 0;

    reg [CLOG2LEN:0] read_idx;
    reg [CLOG2LEN:0] write_idx;

    assign read_port.empty = read_idx == write_idx;
    assign write_port.full = read_idx[CLOG2LEN-1:0] == write_idx[CLOG2LEN-1:0] && read_idx[CLOG2LEN] != write_idx[CLOG2LEN];

    always_ff @(posedge clk) begin
        if (read_port.read) begin
            if (POWER_2) begin
                read_idx <= read_idx + IDX_1;
            end else begin
                if (read_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) begin
                    read_idx[CLOG2LEN-1:0] <= CLOG2LEN_0;
                    read_idx[CLOG2LEN] <= !read_idx[CLOG2LEN];
                end else begin
                    read_idx[CLOG2LEN-1:0] <= read_idx[CLOG2LEN-1:0] + CLOG2LEN_1;
                end
            end
        end
        if (write_port.write) begin
            if (POWER_2) begin
                write_idx <= write_idx + IDX_1;
            end else begin
                if (write_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) begin
                    write_idx[CLOG2LEN-1:0] <= CLOG2LEN_0;
                    write_idx[CLOG2LEN] <= !write_idx[CLOG2LEN];
                end else begin
                    write_idx[CLOG2LEN-1:0] <= write_idx[CLOG2LEN-1:0] + CLOG2LEN_1;
                end
            end
        end
        if (!rstn) begin
            read_idx <= IDX_0;
            write_idx <= IDX_0;
        end
    end

    reg [WIDTH-1:0] mem[LEN];

    always_ff @(posedge clk) begin
        if (read_port.read) begin
            read_port.data <= mem[read_idx[CLOG2LEN-1:0]];
        end
        if (write_port.write) begin
            mem[write_idx[CLOG2LEN-1:0]] <= write_port.data;
        end
    end

endmodule
