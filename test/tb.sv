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

module tb ();

    reg clk;
    reg rstn;

    localparam NTESTS = 400;
    localparam longint unsigned MEM_SIZE = 1048576;
    localparam longint unsigned LAST_MEM_ADDR = MEM_SIZE-1;
    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE);

    logic [31:0] io_control_aw_awaddr;
    logic [2:0] io_control_aw_awprot;
    logic io_control_aw_awvalid;
    logic io_control_aw_awready;
    logic [31:0] io_control_w_wdata;
    logic [3:0] io_control_w_wstrb;
    logic io_control_w_wvalid;
    logic io_control_w_wready;
    logic [1:0] io_control_b_bresp;
    logic io_control_b_bvalid;
    logic io_control_b_bready;
    logic [31:0] io_control_ar_araddr;
    logic [2:0] io_control_ar_arprot;
    logic io_control_ar_arvalid;
    logic io_control_ar_arready;
    logic [31:0] io_control_r_rdata;
    logic [1:0] io_control_r_rresp;
    logic io_control_r_rvalid;
    logic io_control_r_rready;

    logic [3:0] mem_axi_ar_arid;
    logic [31:0] mem_axi_ar_araddr;
    logic [7:0] mem_axi_ar_arlen;
    logic [2:0] mem_axi_ar_arsize;
    logic [1:0] mem_axi_ar_arburst;
    logic mem_axi_ar_arlock;
    logic [3:0] mem_axi_ar_arcache;
    logic [2:0] mem_axi_ar_arprot;
    logic [3:0] mem_axi_ar_arqos;
    logic mem_axi_ar_arvalid;
    logic mem_axi_ar_arready;
    logic [3:0] mem_axi_r_rid;
    logic [127:0] mem_axi_r_rdata;
    logic [1:0] mem_axi_r_rresp;
    logic mem_axi_r_rlast;
    logic mem_axi_r_rvalid;
    logic mem_axi_r_rready;
    logic [3:0] mem_axi_aw_awid;
    logic [31:0] mem_axi_aw_awaddr;
    logic [7:0] mem_axi_aw_awlen;
    logic [2:0] mem_axi_aw_awsize;
    logic [1:0] mem_axi_aw_awburst;
    logic mem_axi_aw_awlock;
    logic [3:0] mem_axi_aw_awcache;
    logic [2:0] mem_axi_aw_awprot;
    logic [3:0] mem_axi_aw_awqos;
    logic mem_axi_aw_awvalid;
    logic mem_axi_aw_awready;
    logic [127:0] mem_axi_w_wdata;
    logic [15:0] mem_axi_w_wstrb;
    logic mem_axi_w_wlast;
    logic mem_axi_w_wvalid;
    logic mem_axi_w_wready;
    logic [3:0] mem_axi_b_bid;
    logic [1:0] mem_axi_b_bresp;
    logic mem_axi_b_bvalid;
    logic mem_axi_b_bready;

    logic [3:0] dma_axi_ar_arid;
    logic [31:0] dma_axi_ar_araddr;
    logic [7:0] dma_axi_ar_arlen;
    logic [2:0] dma_axi_ar_arsize;
    logic [1:0] dma_axi_ar_arburst;
    logic dma_axi_ar_arlock;
    logic [3:0] dma_axi_ar_arcache;
    logic [2:0] dma_axi_ar_arprot;
    logic [3:0] dma_axi_ar_arqos;
    logic dma_axi_ar_arvalid;
    logic dma_axi_ar_arready;
    logic [3:0] dma_axi_r_rid;
    logic [127:0] dma_axi_r_rdata;
    logic [1:0] dma_axi_r_rresp;
    logic dma_axi_r_rlast;
    logic dma_axi_r_rvalid;
    logic dma_axi_r_rready;
    logic [3:0] dma_axi_aw_awid;
    logic [31:0] dma_axi_aw_awaddr;
    logic [7:0] dma_axi_aw_awlen;
    logic [2:0] dma_axi_aw_awsize;
    logic [1:0] dma_axi_aw_awburst;
    logic dma_axi_aw_awlock;
    logic [3:0] dma_axi_aw_awcache;
    logic [2:0] dma_axi_aw_awprot;
    logic [3:0] dma_axi_aw_awqos;
    logic dma_axi_aw_awvalid;
    logic dma_axi_aw_awready;
    logic [127:0] dma_axi_w_wdata;
    logic [15:0] dma_axi_w_wstrb;
    logic dma_axi_w_wlast;
    logic dma_axi_w_wvalid;
    logic dma_axi_w_wready;
    logic [3:0] dma_axi_b_bid;
    logic [1:0] dma_axi_b_bresp;
    logic dma_axi_b_bvalid;
    logic dma_axi_b_bready;

    logic reader_intr;
    logic writer_intr;

    wor progress;
    int cycles;

    logic driver_done;

    typedef enum {
        IDLE,
        START_DMA_OPERATION,
        SYNC_DRIVER,
        WAIT_INTR
    } State_t;

    State_t state;

    longint unsigned reader_start_addr;
    longint unsigned writer_start_addr;
    longint unsigned btt;
    reg start;

    redma_top #(
        .AXI_LITE_ADDR_WIDTH(32),
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(128),
        .AXI_ID_WIDTH(4),
        .AXI_MAX_ARLEN(255),
        .AXI_MAX_AWLEN(255),
        .READER_FIFO_LEN(2),
        .WRITER_FIFO_LEN(2),
        .ELM_BITS(8),
        .SYNC_AW_W(0),
        .MAX_OUTSTANDING_WRITES(0),
        .MAX_OUTSTANDING_READS(0)
    ) redma_top_I (
        .clk(clk),
        .rstn(rstn),
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
        .io_control_r_rready(io_control_r_rready),
        .m_axi_ar_arid(dma_axi_ar_arid),
        .m_axi_ar_araddr(dma_axi_ar_araddr),
        .m_axi_ar_arlen(dma_axi_ar_arlen),
        .m_axi_ar_arsize(dma_axi_ar_arsize),
        .m_axi_ar_arburst(dma_axi_ar_arburst),
        .m_axi_ar_arlock(dma_axi_ar_arlock),
        .m_axi_ar_arcache(dma_axi_ar_arcache),
        .m_axi_ar_arprot(dma_axi_ar_arprot),
        .m_axi_ar_arqos(dma_axi_ar_arqos),
        .m_axi_ar_arvalid(dma_axi_ar_arvalid),
        .m_axi_ar_arready(dma_axi_ar_arready),
        .m_axi_r_rid(dma_axi_r_rid),
        .m_axi_r_rdata(dma_axi_r_rdata),
        .m_axi_r_rresp(dma_axi_r_rresp),
        .m_axi_r_rlast(dma_axi_r_rlast),
        .m_axi_r_rvalid(dma_axi_r_rvalid),
        .m_axi_r_rready(dma_axi_r_rready),
        .m_axi_aw_awid(dma_axi_aw_awid),
        .m_axi_aw_awaddr(dma_axi_aw_awaddr),
        .m_axi_aw_awlen(dma_axi_aw_awlen),
        .m_axi_aw_awsize(dma_axi_aw_awsize),
        .m_axi_aw_awburst(dma_axi_aw_awburst),
        .m_axi_aw_awlock(dma_axi_aw_awlock),
        .m_axi_aw_awcache(dma_axi_aw_awcache),
        .m_axi_aw_awprot(dma_axi_aw_awprot),
        .m_axi_aw_awqos(dma_axi_aw_awqos),
        .m_axi_aw_awvalid(dma_axi_aw_awvalid),
        .m_axi_aw_awready(dma_axi_aw_awready),
        .m_axi_w_wdata(dma_axi_w_wdata),
        .m_axi_w_wstrb(dma_axi_w_wstrb),
        .m_axi_w_wlast(dma_axi_w_wlast),
        .m_axi_w_wvalid(dma_axi_w_wvalid),
        .m_axi_w_wready(dma_axi_w_wready),
        .m_axi_b_bid(dma_axi_b_bid),
        .m_axi_b_bresp(dma_axi_b_bresp),
        .m_axi_b_bvalid(dma_axi_b_bvalid),
        .m_axi_b_bready(dma_axi_b_bready),
        .reader_intr(reader_intr),
        .writer_intr(writer_intr)
    );

    axi_sim_mem_linear #(
        .AXI_ID_WIDTH(4),
        .AXI_DATA_WIDTH(128),
        .AXI_ADDR_WIDTH(32),
        .MEM_SIZE(MEM_SIZE)
    ) axi_sim_mem_linear_I (
        .aclk(clk),
        .aresetn(rstn),
        .s_axi_awid(mem_axi_aw_awid),
        .s_axi_awaddr(mem_axi_aw_awaddr),
        .s_axi_awlen(mem_axi_aw_awlen),
        .s_axi_awsize(mem_axi_aw_awsize),
        .s_axi_awburst(mem_axi_aw_awburst),
        .s_axi_awlock(mem_axi_aw_awlock),
        .s_axi_awcache(mem_axi_aw_awcache),
        .s_axi_awprot(mem_axi_aw_awprot),
        .s_axi_awqos(mem_axi_aw_awqos),
        .s_axi_awregion(),
        .s_axi_awvalid(mem_axi_aw_awvalid),
        .s_axi_awready(mem_axi_aw_awready),
        .s_axi_wdata(mem_axi_w_wdata),
        .s_axi_wstrb(mem_axi_w_wstrb),
        .s_axi_wlast(mem_axi_w_wlast),
        .s_axi_wvalid(mem_axi_w_wvalid),
        .s_axi_wready(mem_axi_w_wready),
        .s_axi_bid(mem_axi_b_bid),
        .s_axi_bresp(mem_axi_b_bresp),
        .s_axi_bvalid(mem_axi_b_bvalid),
        .s_axi_bready(mem_axi_b_bready),
        .s_axi_arid(mem_axi_ar_arid),
        .s_axi_araddr(mem_axi_ar_araddr),
        .s_axi_arlen(mem_axi_ar_arlen),
        .s_axi_arsize(mem_axi_ar_arsize),
        .s_axi_arburst(mem_axi_ar_arburst),
        .s_axi_arlock(mem_axi_ar_arlock),
        .s_axi_arcache(mem_axi_ar_arcache),
        .s_axi_arprot(mem_axi_ar_arprot),
        .s_axi_arqos(mem_axi_ar_arqos),
        .s_axi_arregion(),
        .s_axi_arvalid(mem_axi_ar_arvalid),
        .s_axi_arready(mem_axi_ar_arready),
        .s_axi_rid(mem_axi_r_rid),
        .s_axi_rdata(mem_axi_r_rdata),
        .s_axi_rresp(mem_axi_r_rresp),
        .s_axi_rlast(mem_axi_r_rlast),
        .s_axi_rvalid(mem_axi_r_rvalid),
        .s_axi_rready(mem_axi_r_rready)
    );

    axi_delayer #(
        .READ_LATENCY(100),
        .READ_BANDWIDTH_UP(1),
        .READ_BANDWIDTH_DOWN(0),
        .READ_BANDWIDTH_RAND(1),
        .READ_BANDWIDTH_UP_PROB(50),
        .READ_BANDWIDTH_DOWN_PROB(50),
        .WRITE_LATENCY(16),
        .WRITE_BANDWIDTH_UP(1),
        .WRITE_BANDWIDTH_DOWN(0),
        .WRITE_BANDWIDTH_RAND(1),
        .WRITE_BANDWIDTH_UP_PROB(50),
        .WRITE_BANDWIDTH_DOWN_PROB(50),
        .MAX_OUTSTANDING_REQUESTS(8),
        .AXI_ID_WIDTH(4),
        .AXI_DATA_WIDTH(128),
        .AXI_ADDR_WIDTH(32)
    ) axi_delayer_I (
        .aclk(clk),
        .aresetn(rstn),
        .s_axi_awid(dma_axi_aw_awid),
        .s_axi_awaddr(dma_axi_aw_awaddr),
        .s_axi_awlen(dma_axi_aw_awlen),
        .s_axi_awsize(dma_axi_aw_awsize),
        .s_axi_awburst(dma_axi_aw_awburst),
        .s_axi_awlock(dma_axi_aw_awlock),
        .s_axi_awcache(dma_axi_aw_awcache),
        .s_axi_awprot(dma_axi_aw_awprot),
        .s_axi_awqos(dma_axi_aw_awqos),
        .s_axi_awregion(),
        .s_axi_awvalid(dma_axi_aw_awvalid),
        .s_axi_awready(dma_axi_aw_awready),
        .s_axi_wdata(dma_axi_w_wdata),
        .s_axi_wstrb(dma_axi_w_wstrb),
        .s_axi_wlast(dma_axi_w_wlast),
        .s_axi_wvalid(dma_axi_w_wvalid),
        .s_axi_wready(dma_axi_w_wready),
        .s_axi_bid(dma_axi_b_bid),
        .s_axi_bresp(dma_axi_b_bresp),
        .s_axi_bvalid(dma_axi_b_bvalid),
        .s_axi_bready(dma_axi_b_bready),
        .s_axi_arid(dma_axi_ar_arid),
        .s_axi_araddr(dma_axi_ar_araddr),
        .s_axi_arlen(dma_axi_ar_arlen),
        .s_axi_arsize(dma_axi_ar_arsize),
        .s_axi_arburst(dma_axi_ar_arburst),
        .s_axi_arlock(dma_axi_ar_arlock),
        .s_axi_arcache(dma_axi_ar_arcache),
        .s_axi_arprot(dma_axi_ar_arprot),
        .s_axi_arqos(dma_axi_ar_arqos),
        .s_axi_arregion(),
        .s_axi_arvalid(dma_axi_ar_arvalid),
        .s_axi_arready(dma_axi_ar_arready),
        .s_axi_rid(dma_axi_r_rid),
        .s_axi_rdata(dma_axi_r_rdata),
        .s_axi_rresp(dma_axi_r_rresp),
        .s_axi_rlast(dma_axi_r_rlast),
        .s_axi_rvalid(dma_axi_r_rvalid),
        .s_axi_rready(dma_axi_r_rready),
        .m_axi_awid(mem_axi_aw_awid),
        .m_axi_awaddr(mem_axi_aw_awaddr),
        .m_axi_awlen(mem_axi_aw_awlen),
        .m_axi_awsize(mem_axi_aw_awsize),
        .m_axi_awburst(mem_axi_aw_awburst),
        .m_axi_awlock(mem_axi_aw_awlock),
        .m_axi_awcache(mem_axi_aw_awcache),
        .m_axi_awprot(mem_axi_aw_awprot),
        .m_axi_awqos(mem_axi_aw_awqos),
        .m_axi_awregion(),
        .m_axi_awvalid(mem_axi_aw_awvalid),
        .m_axi_awready(mem_axi_aw_awready),
        .m_axi_wdata(mem_axi_w_wdata),
        .m_axi_wstrb(mem_axi_w_wstrb),
        .m_axi_wlast(mem_axi_w_wlast),
        .m_axi_wvalid(mem_axi_w_wvalid),
        .m_axi_wready(mem_axi_w_wready),
        .m_axi_bid(mem_axi_b_bid),
        .m_axi_bresp(mem_axi_b_bresp),
        .m_axi_bvalid(mem_axi_b_bvalid),
        .m_axi_bready(mem_axi_b_bready),
        .m_axi_arid(mem_axi_ar_arid),
        .m_axi_araddr(mem_axi_ar_araddr),
        .m_axi_arlen(mem_axi_ar_arlen),
        .m_axi_arsize(mem_axi_ar_arsize),
        .m_axi_arburst(mem_axi_ar_arburst),
        .m_axi_arlock(mem_axi_ar_arlock),
        .m_axi_arcache(mem_axi_ar_arcache),
        .m_axi_arprot(mem_axi_ar_arprot),
        .m_axi_arqos(mem_axi_ar_arqos),
        .m_axi_arregion(),
        .m_axi_arvalid(mem_axi_ar_arvalid),
        .m_axi_arready(mem_axi_ar_arready),
        .m_axi_rid(mem_axi_r_rid),
        .m_axi_rdata(mem_axi_r_rdata),
        .m_axi_rresp(mem_axi_r_rresp),
        .m_axi_rlast(mem_axi_r_rlast),
        .m_axi_rvalid(mem_axi_r_rvalid),
        .m_axi_rready(mem_axi_r_rready)
    );

    redma_driver redma_driver_I (
        .clk(clk),
        .rst(!rstn),
        .start(start),
        .reader_start_addr(reader_start_addr[31:0]),
        .writer_start_addr(writer_start_addr[31:0]),
        .btt(btt[31:0]),
        .done(driver_done),
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
        .io_control_b_bready(io_control_b_bready)
    );

    assign io_control_ar_arvalid = 0;
    assign io_control_ar_aready = 0;
    assign io_control_r_rready = 1;

    assign progress = dma_axi_ar_arvalid & dma_axi_ar_arready;
    assign progress = dma_axi_r_rvalid & dma_axi_r_rready;
    assign progress = dma_axi_aw_awvalid & dma_axi_aw_awready;
    assign progress = dma_axi_w_wvalid & dma_axi_w_wready;
    assign progress = dma_axi_b_bvalid & dma_axi_b_bready;

    reg [7:0] mem_ref[];

    int n;

    initial begin
        clk = 0;
        rstn = 0;
        n = 0;
        mem_ref = new[MEM_SIZE];
        cycles = 0;
        #100
        rstn = 1;;
    end

    always begin
        #1
        clk = !clk;
    end

    function longint unsigned min(longint unsigned a, longint unsigned b);
        return a < b ? a : b;
    endfunction

    always @(posedge clk) begin

        start <= 0;

        if (progress) begin
            cycles = 0;
        end else begin
            cycles = cycles + 1;
        end

        assert (cycles < 300000) else begin
            $error("Simulation is not progressing, parameters are: read address %0X write address %0X btt %0X", reader_start_addr, writer_start_addr, btt); $fatal;
        end

        case (state)

            IDLE: begin
                state <= START_DMA_OPERATION;
            end

            START_DMA_OPERATION: begin
                int r;
                longint unsigned left_range;
                longint unsigned right_range;
                bit left_range_valid;
                bit right_range_valid;
                do begin
                    left_range_valid = 1;
                    right_range_valid = 1;
                    btt = $urandom_range(1, MEM_SIZE/2);
                    reader_start_addr = $urandom_range(0, MEM_SIZE-btt);

                    if (reader_start_addr != 0) begin
                        left_range = $urandom_range(0, reader_start_addr-1);
                    end else begin
                        left_range_valid = 0;
                    end
                    if (reader_start_addr + btt != MEM_SIZE) begin
                        right_range = $urandom_range(reader_start_addr+btt, LAST_MEM_ADDR);
                    end else begin
                        right_range_valid = 0;
                    end

                    if (left_range_valid && left_range + btt > reader_start_addr) begin
                        left_range_valid = 0;
                    end
                    if (right_range_valid && right_range + btt > MEM_SIZE) begin
                        right_range_valid = 0;
                    end

                    if (left_range_valid && right_range_valid) begin
                        writer_start_addr = $urandom%2 ? left_range : right_range;
                    end else if (left_range_valid) begin
                        writer_start_addr = left_range;
                    end else if (right_range_valid) begin
                        writer_start_addr = right_range;
                    end
                end while (!left_range_valid && !right_range_valid);

                reader_start_addr[31:MEM_ADDR_WIDTH] = $urandom;
                writer_start_addr[31:MEM_ADDR_WIDTH] = reader_start_addr[31:MEM_ADDR_WIDTH];

                start <= 1;
                for (int i = 0; i < MEM_SIZE; ++i) begin
                    axi_sim_mem_linear_I.mem[i] = $urandom;
                    mem_ref[i] = axi_sim_mem_linear_I.mem[i];
                end
                for (int i = 0; i < btt; ++i) begin
                    mem_ref[writer_start_addr[MEM_ADDR_WIDTH-1:0] + i] = mem_ref[reader_start_addr[MEM_ADDR_WIDTH-1:0] + i];
                end
                $info("Starting test %0d of %0d", n+1, NTESTS);
                state <= SYNC_DRIVER;
            end

            SYNC_DRIVER: begin
                if (driver_done) begin
                    state <= WAIT_INTR;
                end
            end

            WAIT_INTR: begin
                if (writer_intr) begin
                    int error;
                    error = 0;
                    for (int i = 0; i < MEM_SIZE; ++i) begin
                        assert (axi_sim_mem_linear_I.mem[i] == mem_ref[i]) else begin
                            error = 1;
                            $error("Data mismatch at addr %0X: expected %0X found %0X", i, mem_ref[i], axi_sim_mem_linear_I.mem[i]);
                        end
                    end
                    if (error) begin
                        $error("Failed with parameters reader %0X writer %0X btt %0d", reader_start_addr, writer_start_addr, btt);
                        $fatal;
                    end
                    if (n == NTESTS-1) begin
                        $finish;
                    end else begin
                        n = n+1;
                        state <= START_DMA_OPERATION;
                    end
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
