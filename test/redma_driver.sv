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


module redma_driver (
    input clk,
    input rst,
    input start,
    input [31:0] reader_start_addr,
    input [31:0] writer_start_addr,
    input [31:0] btt,
    output reg done,
    output [31:0] io_control_aw_awaddr,
    output [2:0]  io_control_aw_awprot,
    output        io_control_aw_awvalid,
    input         io_control_aw_awready,
    output [31:0] io_control_w_wdata,
    output [3:0]  io_control_w_wstrb,
    output        io_control_w_wvalid,
    input         io_control_w_wready,
    input  [1:0]  io_control_b_bresp,
    input         io_control_b_bvalid,
    output        io_control_b_bready
);

    localparam START_ADDR = 32'h0;
    localparam ENABLE_INTR_ADDR = 32'h4;
    localparam TOGGLE_INTR_ADDR = 32'hC;
    localparam READER_START_ADDR = 32'h10;
    localparam WRITER_START_ADDR = 32'h20;
    localparam BTT_ADDR = 32'h30;

    typedef enum {
        IDLE,
        SEND_ADDR,
        SEND_DATA,
        WAIT_WRESP
    } State_t;

    State_t state;

    reg [31:0] addr;
    reg [31:0] data;

    assign io_control_aw_awvalid = state == SEND_ADDR;
    assign io_control_aw_awaddr = addr;
    assign io_control_w_wvalid = state == SEND_DATA;
    assign io_control_w_wdata = data;
    assign io_control_w_wstrb = 4'hF;
    assign io_control_b_bready = 1;

    always @(posedge clk) begin

        done <= 0;

        case (state)

            IDLE: begin
                addr <= ENABLE_INTR_ADDR;
                data <= 2; //only enable writer interrupt
                if (start) begin
                    state <= SEND_ADDR;
                end
            end

            SEND_ADDR: begin
                if (io_control_aw_awready) begin
                    state <= SEND_DATA;
                end
            end

            SEND_DATA: begin
                if (io_control_w_wready) begin
                    state <= WAIT_WRESP;
                end
            end

            WAIT_WRESP: begin
                if (io_control_b_bvalid) begin
                    state <= SEND_ADDR;
                    case (addr)

                        ENABLE_INTR_ADDR: begin
                            addr <= TOGGLE_INTR_ADDR;
                            data <= 3; //disable reader and writer interrupts
                        end

                        TOGGLE_INTR_ADDR: begin
                            addr <= READER_START_ADDR;
                            data <= reader_start_addr;
                        end

                        READER_START_ADDR: begin
                            addr <= WRITER_START_ADDR;
                            data <= writer_start_addr;
                        end

                        WRITER_START_ADDR: begin
                            addr <= BTT_ADDR;
                            data <= btt;
                        end

                        BTT_ADDR: begin
                            addr <= START_ADDR;
                            data <= 32'dX;
                            data[0] <= 1'b1; //start reader
                            data[1] <= 1'b1; //start writer
                            data[8] <= 1'b0; //write_zero
                        end

                        START_ADDR: begin
                            done <= 1;
                            state <= IDLE;
                        end

                    endcase
                end
            end

        endcase

        if (rst) begin
            state <= IDLE;
        end
    end

endmodule
