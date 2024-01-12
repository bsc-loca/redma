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

module redma_top #(
    parameter AXI_LITE_ADDR_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_ID_WIDTH = 1,
    parameter AXI_MAX_ARLEN = 255,
    parameter AXI_MAX_AWLEN = 255,
    parameter INTERNAL_RADDR_WIDTH = 32, //width of the internal address registers, AXI addr bits beyond this width are not modified
    parameter INTERNAL_WADDR_WIDTH = 32,
    parameter BTT_WIDTH = 32, //width of the internal btt register, it limits the maximum number of bytes that can be moved in a single DMA operation
    parameter READER_FIFO_LEN = 2,
    parameter WRITER_FIFO_LEN = 2,
    parameter [AXI_ADDR_WIDTH-1:0] AXI_READER_ADDR_OFFSET = 0, //offset of the AXI addresses, must be multiple of 2^INTERNAL_ADDR_WIDTH
    parameter [AXI_ADDR_WIDTH-1:0] AXI_WRITER_ADDR_OFFSET = 0,
    parameter ELM_BITS = 8, // Number of bits of the data elements (realign granularity)
    parameter SYNC_AW_W = 0, //synchronize AW and W channels, adress is not valid until there is data availbale in the writer FIFO
    parameter MAX_OUTSTANDING_READS = 0,
    parameter MAX_OUTSTANDING_WRITES = 0
) (
    input clk,
    input rstn,
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
    input                            io_control_r_rready,
    output [AXI_ID_WIDTH-1:0]     m_axi_ar_arid,
    output [AXI_ADDR_WIDTH-1:0]   m_axi_ar_araddr,
    output [7:0]                  m_axi_ar_arlen,
    output [2:0]                  m_axi_ar_arsize,
    output [1:0]                  m_axi_ar_arburst,
    output                        m_axi_ar_arlock,
    output [3:0]                  m_axi_ar_arcache,
    output [2:0]                  m_axi_ar_arprot,
    output [3:0]                  m_axi_ar_arqos,
    output [3:0]                  m_axi_ar_region,
    output                        m_axi_ar_arvalid,
    input                         m_axi_ar_arready,
    input  [AXI_ID_WIDTH-1:0]     m_axi_r_rid,
    input  [AXI_DATA_WIDTH-1:0]   m_axi_r_rdata,
    input  [1:0]                  m_axi_r_rresp,
    input                         m_axi_r_rlast,
    input                         m_axi_r_rvalid,
    output                        m_axi_r_rready,
    output [AXI_ID_WIDTH-1:0]     m_axi_aw_awid,
    output [AXI_ADDR_WIDTH-1:0]   m_axi_aw_awaddr,
    output [7:0]                  m_axi_aw_awlen,
    output [2:0]                  m_axi_aw_awsize,
    output [1:0]                  m_axi_aw_awburst,
    output                        m_axi_aw_awlock,
    output [3:0]                  m_axi_aw_awcache,
    output [2:0]                  m_axi_aw_awprot,
    output [3:0]                  m_axi_aw_awqos,
    output [3:0]                  m_axi_aw_region,
    output                        m_axi_aw_awvalid,
    input                         m_axi_aw_awready,
    output [AXI_DATA_WIDTH-1:0]   m_axi_w_wdata,
    output [AXI_DATA_WIDTH/8-1:0] m_axi_w_wstrb,
    output                        m_axi_w_wlast,
    output                        m_axi_w_wvalid,
    input                         m_axi_w_wready,
    input  [AXI_ID_WIDTH-1:0]     m_axi_b_bid,
    input  [1:0]                  m_axi_b_bresp,
    input                         m_axi_b_bvalid,
    output                        m_axi_b_bready,
    output reader_intr,
    output writer_intr
);

    wire [INTERNAL_RADDR_WIDTH-1:0] read_start_addr;
    wire [INTERNAL_WADDR_WIDTH-1:0] write_start_addr;
    wire [BTT_WIDTH-1:0] btt;
    wire write_zero;
    wire reader_start;
    wire writer_start;
    wire set_reader_intr;
    wire set_writer_intr;

    wire ar_new_transaction;
    wire r_transaction_complete;
    wire aw_new_transaction;
    wire w_new_transaction;
    wire aw_last_transaction;
    wire b_transaction_confirmed;
    wire aw_enable;
    wire w_enable;
    wire ar_enable;

    wire aw_sync;
    wire w_sync;

    FIFO_READ #(.DATA_WIDTH(AXI_DATA_WIDTH)) reader_fifo_read();
    FIFO_WRITE #(.DATA_WIDTH(AXI_DATA_WIDTH)) reader_fifo_write();
    FIFO_READ #(.DATA_WIDTH(AXI_DATA_WIDTH)) writer_fifo_read();
    FIFO_WRITE #(.DATA_WIDTH(AXI_DATA_WIDTH)) writer_fifo_write();
    AXI4_AR #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) ar_chan();
    AXI4_R #(.DATA_WIDTH(AXI_DATA_WIDTH)) r_chan();
    AXI4_AW #(.ADDR_WIDTH(AXI_ADDR_WIDTH)) aw_chan();
    AXI4_W #(.DATA_WIDTH(AXI_DATA_WIDTH)) w_chan();
    AXI4_B b_chan();

    assign m_axi_ar_arvalid = ar_chan.arvalid;
    assign ar_chan.arready = m_axi_ar_arready;
    assign m_axi_ar_araddr = ar_chan.araddr;
    assign m_axi_ar_arlen = ar_chan.arlen;
    assign m_axi_ar_arsize = ar_chan.arsize;
    assign m_axi_ar_arburst = ar_chan.arburst;

    assign m_axi_aw_awvalid = aw_chan.awvalid;
    assign aw_chan.awready = m_axi_aw_awready;
    assign m_axi_aw_awaddr = aw_chan.awaddr;
    assign m_axi_aw_awlen = aw_chan.awlen;
    assign m_axi_aw_awsize = aw_chan.awsize;
    assign m_axi_aw_awburst = aw_chan.awburst;

    assign r_chan.rvalid = m_axi_r_rvalid;
    assign m_axi_r_rready = r_chan.rready;
    assign r_chan.rdata = m_axi_r_rdata;
    assign r_chan.rlast = m_axi_r_rlast;

    assign m_axi_w_wvalid = w_chan.wvalid;
    assign w_chan.wready = m_axi_w_wready;
    assign m_axi_w_wdata = w_chan.wdata;
    assign m_axi_w_wstrb = w_chan.wstrb;
    assign m_axi_w_wlast = w_chan.wlast;

    assign b_chan.bvalid = m_axi_b_bvalid;
    assign m_axi_b_bready = b_chan.bready;
    assign b_chan.bresp = m_axi_b_bresp;

    assign m_axi_ar_arid = {AXI_ID_WIDTH{1'b0}};
    assign m_axi_aw_awid = {AXI_ID_WIDTH{1'b0}};
    assign m_axi_ar_arlock = 1'b0;
    assign m_axi_aw_awlock = 1'b0;
    assign m_axi_ar_arcache = 4'b0010; //transaction modifiable
    assign m_axi_aw_awcache = 4'b0010;
    assign m_axi_ar_arprot = 3'b000;
    assign m_axi_aw_awprot = 3'b000;
    assign m_axi_ar_arqos = 4'd0;
    assign m_axi_aw_awqos = 4'd0;
    assign m_axi_ar_region = 4'd0;
    assign m_axi_aw_region = 4'd0;

    if (MAX_OUTSTANDING_READS != 0) begin

        localparam OUTSTANDING_READS_BITS = $clog2(MAX_OUTSTANDING_READS+1);

        reg [OUTSTANDING_READS_BITS-1:0] outstanding_ar;

        assign ar_enable = outstanding_ar != MAX_OUTSTANDING_READS;

        always_ff @(posedge clk) begin

            if (ar_new_transaction && !r_transaction_complete) begin
                outstanding_ar <= outstanding_ar + 1;
            end else if (!ar_new_transaction && r_transaction_complete) begin
                outstanding_ar <= outstanding_ar - 1;
            end

            if (!rstn) begin
                outstanding_ar <= 0;
            end
        end

    end else begin
        assign ar_enable = 1'b1;
    end

    if (MAX_OUTSTANDING_WRITES != 0) begin

        localparam OUTSTANDING_WRITES_BITS = $clog2(MAX_OUTSTANDING_WRITES+1);

        reg [OUTSTANDING_WRITES_BITS-1:0] outstanding_aw;

        assign aw_enable = outstanding_aw != MAX_OUTSTANDING_WRITES;

        if (SYNC_AW_W) begin
            assign w_enable = aw_enable;
        end else begin
            reg [OUTSTANDING_WRITES_BITS-1:0] outstanding_w;

            assign w_enable = outstanding_w != MAX_OUTSTANDING_WRITES;

            always_ff @(posedge clk) begin

                if (w_new_transaction && !b_transaction_confirmed) begin
                    outstanding_w <= outstanding_w + 1;
                end else if (!w_new_transaction && b_transaction_confirmed) begin
                    outstanding_w <= outstanding_w - 1;
                end

                if (!rstn) begin
                    outstanding_w <= 0;
                end
            end
        end

        always_ff @(posedge clk) begin

            if (aw_new_transaction && !b_transaction_confirmed) begin
                outstanding_aw <= outstanding_aw + 1;
            end else if (!aw_new_transaction && b_transaction_confirmed) begin
                outstanding_aw <= outstanding_aw - 1;
            end

            if (!rstn) begin
                outstanding_aw <= 0;
            end
        end

    end else begin
        assign aw_enable = 1'b1;
        assign w_enable = 1'b1;
    end

    conf_regs #(
        .AXI_LITE_ADDR_WIDTH(AXI_LITE_ADDR_WIDTH),
        .INTERNAL_RADDR_WIDTH(INTERNAL_RADDR_WIDTH),
        .INTERNAL_WADDR_WIDTH(INTERNAL_WADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) conf_regs_I (
        .clk(clk),
        .rstn(rstn),
        .reader_intr(reader_intr),
        .writer_intr(writer_intr),
        .set_reader_intr(set_reader_intr),
        .set_writer_intr(set_writer_intr),
        .read_start_addr(read_start_addr),
        .write_start_addr(write_start_addr),
        .btt(btt),
        .write_zero(write_zero),
        .reader_start(reader_start),
        .writer_start(writer_start),
        .io_control_aw_awaddr(io_control_aw_awaddr),
        .io_control_aw_awprot(io_control_aw_awprot),
        .io_control_aw_awvalid(io_control_aw_awvalid),
        .io_control_aw_awready(io_control_aw_awready),
        .io_control_w_wdata(io_control_w_wdata),
        .io_control_w_wstrb(io_control_w_wstrb),
        .io_control_w_wvalid(io_control_w_wvalid),
        .io_control_w_wready(io_control_w_wready),
        .io_control_b_bresp(io_control_b_bresp),
        .io_control_b_bvalid(io_control_b_bvalid),
        .io_control_b_bready(io_control_b_bready),
        .io_control_ar_araddr(io_control_ar_araddr),
        .io_control_ar_arprot(io_control_ar_arprot),
        .io_control_ar_arvalid(io_control_ar_arvalid),
        .io_control_ar_arready(io_control_ar_arready),
        .io_control_r_rdata(io_control_r_rdata),
        .io_control_r_rresp(io_control_r_rresp),
        .io_control_r_rvalid(io_control_r_rvalid),
        .io_control_r_rready(io_control_r_rready)
    );

    ar_engine #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_MAX_ARLEN(AXI_MAX_ARLEN),
        .AXI_ADDR_OFFSET(AXI_READER_ADDR_OFFSET),
        .INTERNAL_ADDR_WIDTH(INTERNAL_RADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) ar_engine_I (
        .clk(clk),
        .rstn(rstn),
        .start_addr(read_start_addr),
        .btt(btt),
        .start(reader_start),
        .enable(ar_enable),
        .new_transaction(ar_new_transaction),
        .ar_chan(ar_chan)
    );

    r_engine r_engine_I (
        .transaction_complete(r_transaction_complete),
        .r_chan(r_chan),
        .data_fifo(reader_fifo_write)
    );

    data_fifo #(
        .WIDTH(AXI_DATA_WIDTH),
        .LEN(READER_FIFO_LEN)
    ) data_fifo_reader_I (
        .clk(clk),
        .rstn(rstn),
        .read_port(reader_fifo_read),
        .write_port(reader_fifo_write)
    );

    realigner #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .BTT_WIDTH(BTT_WIDTH),
        .ELM_BITS(ELM_BITS)
    ) realigner_I (
        .i_clk(clk),
        .i_rstn(rstn),
        .i_reader_start(reader_start),
        .i_writer_start(!write_zero && writer_start),
        .i_read_start_addr(read_start_addr),
        .i_write_start_addr(write_start_addr),
        .i_btt(btt),
        .i_disable_realign(1'b0),
        .o_set_intr(set_reader_intr),
        .reader_fifo(reader_fifo_read),
        .writer_fifo(writer_fifo_write)
    );

    data_fifo #(
        .WIDTH(AXI_DATA_WIDTH),
        .LEN(WRITER_FIFO_LEN)
    ) data_fifo_writer_I (
        .clk(clk),
        .rstn(rstn),
        .read_port(writer_fifo_read),
        .write_port(writer_fifo_write)
    );

    aw_engine #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_MAX_AWLEN(AXI_MAX_AWLEN),
        .AXI_ADDR_OFFSET(AXI_WRITER_ADDR_OFFSET),
        .INTERNAL_ADDR_WIDTH(INTERNAL_WADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH),
        .SYNC_AW_W(SYNC_AW_W)
    ) aw_engine_I (
        .clk(clk),
        .rstn(rstn),
        .start_addr(write_start_addr),
        .btt(btt),
        .start(writer_start),
        .enable(aw_enable),
        .write_zero(write_zero),
        .w_sync(w_sync),
        .aw_sync(aw_sync),
        .writer_fifo_empty(writer_fifo_read.empty),
        .new_transaction(aw_new_transaction),
        .last_transaction(aw_last_transaction),
        .aw_chan(aw_chan)
    );

    w_engine #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_MAX_AWLEN(AXI_MAX_AWLEN),
        .INTERNAL_ADDR_WIDTH(INTERNAL_WADDR_WIDTH),
        .BTT_WIDTH(BTT_WIDTH),
        .SYNC_AW_W(SYNC_AW_W)
    ) w_engine_I (
        .clk(clk),
        .rstn(rstn),
        .start_addr(write_start_addr),
        .btt(btt),
        .start(writer_start),
        .enable(w_enable),
        .write_zero(write_zero),
        .new_transaction(w_new_transaction),
        .aw_sync(aw_sync),
        .w_sync(w_sync),
        .w_chan(w_chan),
        .data_fifo(writer_fifo_read)
    );

    b_engine #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .BTT_WIDTH(BTT_WIDTH)
    ) b_engine_I (
        .clk(clk),
        .rstn(rstn),
        .new_transaction(aw_new_transaction),
        .last_transaction(aw_last_transaction),
        .transaction_confirmed(b_transaction_confirmed),
        .start(writer_start),
        .set_intr(set_writer_intr),
        .b_chan(b_chan)
    );

endmodule
