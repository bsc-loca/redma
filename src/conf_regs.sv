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

module conf_regs #(
    parameter AXI_LITE_ADDR_WIDTH = 0,
    parameter INTERNAL_RADDR_WIDTH = 0,
    parameter INTERNAL_WADDR_WIDTH = 0,
    parameter BTT_WIDTH = 0
) (
    input clk,
    input rstn,
    output reg [INTERNAL_RADDR_WIDTH-1:0] read_start_addr,
    output reg [INTERNAL_WADDR_WIDTH-1:0] write_start_addr,
    output reg [BTT_WIDTH-1:0] btt,
    output reg write_zero,
    output reg reader_start,
    output reg writer_start,
    output reader_intr,
    output writer_intr,
    input set_reader_intr,
    input set_writer_intr,
    input  [AXI_LITE_ADDR_WIDTH-1:0] io_control_aw_awaddr,
    input  [2:0]                     io_control_aw_awprot,
    input                            io_control_aw_awvalid,
    output                           io_control_aw_awready,
    input  [31:0]                    io_control_w_wdata,
    input  [3:0]                     io_control_w_wstrb,
    input                            io_control_w_wvalid,
    output                           io_control_w_wready,
    output [1:0]                     io_control_b_bresp,
    output                           io_control_b_bvalid,
    input                            io_control_b_bready,
    input  [AXI_LITE_ADDR_WIDTH-1:0] io_control_ar_araddr,
    input  [2:0]                     io_control_ar_arprot,
    input                            io_control_ar_arvalid,
    output                           io_control_ar_arready,
    output [31:0]                    io_control_r_rdata,
    output [1:0]                     io_control_r_rresp,
    output                           io_control_r_rvalid,
    input                            io_control_r_rready
);

    typedef enum bit [1:0] {
        AR,
        DECODE_RADDR,
        R
    } ReadState_t;

    typedef enum bit [1:0] {
        AW,
        W,
        B
    } WriteState_t;

    ReadState_t read_state;
    WriteState_t write_state;

    reg reader_intr_en;
    reg writer_intr_en;
    reg reader_intr_reg;
    reg writer_intr_reg;
    reg [5:0] raddr;
    reg [5:0] waddr;
    reg [1:0] rresp;
    reg [31:0] rdata;
    reg [1:0] bresp;

    wire [31:0] rstart_addr_array[4];
    wire [31:0] wstart_addr_array[4];
    wire [31:0] btt_array[4];

    wire [31:0] bit_wstrb;

    assign reader_intr = reader_intr_en & reader_intr_reg;
    assign writer_intr = writer_intr_en & writer_intr_reg;

    assign bit_wstrb = {{8{io_control_w_wstrb[3]}}, {8{io_control_w_wstrb[2]}}, {8{io_control_w_wstrb[1]}}, {8{io_control_w_wstrb[0]}}};

    assign io_control_aw_awready = write_state == AW;
    assign io_control_w_wready = write_state == W;
    assign io_control_b_bvalid = write_state == B;
    assign io_control_b_bresp = bresp;
    assign io_control_ar_arready = read_state == AR;
    assign io_control_r_rvalid = read_state == R;
    assign io_control_r_rdata = rdata;
    assign io_control_r_rresp = rresp;

    for (genvar i = 0; i < INTERNAL_RADDR_WIDTH; i += 32) begin : RSTART_ADDR_ASSIGN
        if (i+32 > INTERNAL_RADDR_WIDTH) begin
            assign rstart_addr_array[i/32] = {{32-INTERNAL_RADDR_WIDTH-i{1'b0}}, read_start_addr[INTERNAL_RADDR_WIDTH-1:i]};
        end else begin
            assign rstart_addr_array[i/32] = read_start_addr[i +: 32];
        end
    end

    for (genvar i = 0; i < INTERNAL_WADDR_WIDTH; i += 32) begin : WSTART_ADDR_ASSIGN
        if (i+32 > INTERNAL_WADDR_WIDTH) begin
            assign wstart_addr_array[i/32] = {{32-INTERNAL_WADDR_WIDTH-i{1'b0}}, write_start_addr[INTERNAL_WADDR_WIDTH-1:i]};
        end else begin
            assign wstart_addr_array[i/32] = write_start_addr[i +: 32];
        end
    end

    for (genvar i = 0; i < BTT_WIDTH; i += 32) begin : BTT_ASSIGN
        if (i+32 > BTT_WIDTH) begin
            assign btt_array[i/32] = {{32-BTT_WIDTH-i{1'b0}}, btt[BTT_WIDTH-1:i]};
        end else begin
            assign btt_array[i/32] = btt[i +: 32];
        end
    end

    for (genvar i = 0; i < INTERNAL_RADDR_WIDTH; i += 32) begin : RSTART_ADDR_WRITE
        if (i+32 > INTERNAL_RADDR_WIDTH) begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h10 + (i/32)*4)) begin
                    read_start_addr[INTERNAL_RADDR_WIDTH-1:i] <= (read_start_addr[INTERNAL_RADDR_WIDTH-1:i] & ~bit_wstrb[0 +: INTERNAL_RADDR_WIDTH-i]) | (io_control_w_wdata[0 +: INTERNAL_RADDR_WIDTH-i] & bit_wstrb[0 +: INTERNAL_RADDR_WIDTH-i]);
                end
            end
        end else begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h10 + (i/32)*4)) begin
                    read_start_addr[i +: 32] <= (read_start_addr[i +: 32] & ~bit_wstrb) | (io_control_w_wdata & bit_wstrb);
                end
            end
        end
    end

    for (genvar i = 0; i < INTERNAL_WADDR_WIDTH; i += 32) begin : WSTART_ADDR_WRITE
        if (i+32 > INTERNAL_WADDR_WIDTH) begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h20 + (i/32)*4)) begin
                    write_start_addr[INTERNAL_WADDR_WIDTH-1:i] <= (write_start_addr[INTERNAL_WADDR_WIDTH-1:i] & ~bit_wstrb[0 +: INTERNAL_WADDR_WIDTH-i]) | (io_control_w_wdata[0 +: INTERNAL_WADDR_WIDTH-i] & bit_wstrb[0 +: INTERNAL_WADDR_WIDTH-i]);
                end
            end
        end else begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h20 + (i/32)*4)) begin
                    write_start_addr[i +: 32] <= (write_start_addr[i +: 32] & ~bit_wstrb) | (io_control_w_wdata & bit_wstrb);
                end
            end
        end
    end

    for (genvar i = 0; i < BTT_WIDTH; i += 32) begin : BTT_WRITE
        if (i+32 > BTT_WIDTH) begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h30 + (i/32)*4)) begin
                    btt[BTT_WIDTH-1:i] <= (btt[BTT_WIDTH-1:i] & ~bit_wstrb[0 +: BTT_WIDTH-i]) | (io_control_w_wdata[0 +: BTT_WIDTH-i] & bit_wstrb[0 +: BTT_WIDTH-i]);
                end
            end
        end else begin
            always_ff @(posedge clk) begin
                if (write_state == W && io_control_w_wvalid && waddr == (6'h30 + (i/32)*4)) begin
                    btt[i +: 32] <= (btt[i +: 32] & ~bit_wstrb) | (io_control_w_wdata & bit_wstrb);
                end
            end
        end
    end

    always_ff @(posedge clk) begin

        reader_start <= 1'b0;
        writer_start <= 1'b0;

        if (set_reader_intr) begin
            reader_intr_reg <= 1'b1;
        end
        if (set_writer_intr) begin
            writer_intr_reg <= 1'b1;
        end

        case (read_state)

            AR: begin
                raddr <= io_control_ar_araddr[5:0];
                if (io_control_ar_arvalid) begin
                    read_state <= DECODE_RADDR;
                end
            end

            DECODE_RADDR: begin
                rresp <= 2'b00;
                if (raddr == 6'h04) begin
                    rdata <= {30'd0, writer_intr_en, reader_intr_en};
                end else if (raddr == 6'hC) begin
                    rdata <= {30'd0, writer_intr_reg, reader_intr_reg};
                end else if (raddr == 6'h10) begin
                    rdata <= rstart_addr_array[0];
                end else if (INTERNAL_RADDR_WIDTH > 32 && raddr == 6'h14) begin
                    rdata <= rstart_addr_array[1];
                end else if (INTERNAL_RADDR_WIDTH > 64 && raddr == 6'h18) begin
                    rdata <= rstart_addr_array[2];
                end else if (INTERNAL_RADDR_WIDTH > 96 && raddr == 6'h1C) begin
                    rdata <= rstart_addr_array[3];
                end else if (raddr == 6'h20) begin
                    rdata <= wstart_addr_array[0];
                end else if (INTERNAL_WADDR_WIDTH > 32 && raddr == 6'h24) begin
                    rdata <= wstart_addr_array[1];
                end else if (INTERNAL_WADDR_WIDTH > 64 && raddr == 6'h28) begin
                    rdata <= wstart_addr_array[2];
                end else if (INTERNAL_WADDR_WIDTH > 96 && raddr == 6'h2C) begin
                    rdata <= wstart_addr_array[3];
                end else if (raddr == 6'h30) begin
                    rdata <= btt_array[0];
                end else if (BTT_WIDTH > 32 && raddr == 6'h34) begin
                    rdata <= btt_array[1];
                end else if (BTT_WIDTH > 64 && raddr == 6'h38) begin
                    rdata <= btt_array[2];
                end else if (BTT_WIDTH > 96 && raddr == 6'h3C) begin
                    rdata <= btt_array[3];
                end else begin
                    rresp <= 2'b10;
                end
                read_state <= R;
            end

            R: begin
                if (io_control_r_rready) begin
                    read_state <= AR;
                end
            end

        endcase

        case (write_state)

            AW: begin
                waddr <= io_control_aw_awaddr[5:0];
                if (io_control_aw_awvalid) begin
                    write_state <= W;
                end
            end

            W: begin
                bresp <= 2'b00;
                if (io_control_w_wvalid) begin
                    if (waddr == 6'h00) begin
                        reader_start <= io_control_w_wdata[0] & bit_wstrb[0];
                        writer_start <= io_control_w_wdata[1] & bit_wstrb[1];
                        write_zero <= io_control_w_wdata[8];
                    end else if (waddr == 6'h04) begin
                        reader_intr_en <= (reader_intr_en & ~bit_wstrb[0]) | (io_control_w_wdata[0] & bit_wstrb[0]);
                        writer_intr_en <= (writer_intr_en & ~bit_wstrb[1]) | (io_control_w_wdata[1] & bit_wstrb[1]);
                    end else if (waddr == 6'h0C) begin
                        if (io_control_w_wdata[0] & bit_wstrb[0]) begin
                            reader_intr_reg <= 1'b0;
                        end
                        if (io_control_w_wdata[1] & bit_wstrb[1]) begin
                            writer_intr_reg <= 1'b0;
                        end
                    end else if (waddr == 6'h10) begin
                    end else if (INTERNAL_RADDR_WIDTH > 32 && waddr == 6'h14) begin
                    end else if (INTERNAL_RADDR_WIDTH > 64 && waddr == 6'h18) begin
                    end else if (INTERNAL_RADDR_WIDTH > 96 && waddr == 6'h1C) begin
                    end else if (waddr == 6'h20) begin
                    end else if (INTERNAL_WADDR_WIDTH > 32 && waddr == 6'h24) begin
                    end else if (INTERNAL_WADDR_WIDTH > 64 && waddr == 6'h28) begin
                    end else if (INTERNAL_WADDR_WIDTH > 96 && waddr == 6'h2C) begin
                    end else if (waddr == 6'h30) begin
                    end else if (BTT_WIDTH > 32 && waddr == 6'h34) begin
                    end else if (BTT_WIDTH > 64 && waddr == 6'h38) begin
                    end else if (BTT_WIDTH > 96 && waddr == 6'h3C) begin
                    end else begin
                        bresp <= 2'b10;
                    end
                    write_state <= B;
                end
            end

            B: begin
                if (io_control_b_bready) begin
                    write_state <= AW;
                end
            end

        endcase

        if (!rstn) begin
            read_state <= AR;
            write_state <= AW;
            reader_intr_en <= 1'b0;
            writer_intr_en <= 1'b0;
            reader_intr_reg <= 1'b0;
            writer_intr_reg <= 1'b0;
        end
    end

endmodule
