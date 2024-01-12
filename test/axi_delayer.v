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

module axi_delayer #(
    parameter READ_LATENCY = 0,
    parameter READ_BANDWIDTH_UP = 1,
    parameter READ_BANDWIDTH_DOWN = 0,
    parameter READ_BANDWIDTH_RAND = 0,
    parameter READ_BANDWIDTH_UP_PROB = 0,
    parameter READ_BANDWIDTH_DOWN_PROB = 0,
    parameter WRITE_LATENCY = 0,
    parameter WRITE_BANDWIDTH_UP = 1,
    parameter WRITE_BANDWIDTH_DOWN = 0,
    parameter WRITE_BANDWIDTH_RAND = 0,
    parameter WRITE_BANDWIDTH_UP_PROB = 0,
    parameter WRITE_BANDWIDTH_DOWN_PROB = 0,
    parameter MAX_OUTSTANDING_REQUESTS = 0,
    parameter AXI_ID_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0
) (
    input wire aclk,
    input wire aresetn,
    input wire [AXI_ID_WIDTH-1:0] s_axi_awid,
    input wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire s_axi_awlock,
    input wire [3:0] s_axi_awcache,
    input wire [2:0] s_axi_awprot,
    input wire [3:0] s_axi_awqos,
    input wire [3:0] s_axi_awregion,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0] s_axi_bid,
    output wire [1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    input wire [AXI_ID_WIDTH-1:0] s_axi_arid,
    input wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire s_axi_arlock,
    input wire [3:0] s_axi_arcache,
    input wire [2:0] s_axi_arprot,
    input wire [3:0] s_axi_arqos,
    input wire [3:0] s_axi_arregion,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0] s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp,
    output wire s_axi_rlast,
    output wire s_axi_rvalid,
    input wire s_axi_rready,
    output wire [AXI_ID_WIDTH-1:0] m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awlock,
    output wire [3:0] m_axi_awcache,
    output wire [2:0] m_axi_awprot,
    output wire [3:0] m_axi_awqos,
    output wire [3:0] m_axi_awregion,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output wire m_axi_wlast,
    output wire m_axi_wvalid,
    input wire m_axi_wready,
    input wire [AXI_ID_WIDTH-1:0] m_axi_bid,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0] m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arlock,
    output wire [3:0] m_axi_arcache,
    output wire [2:0] m_axi_arprot,
    output wire [3:0] m_axi_arqos,
    output wire [3:0] m_axi_arregion,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [AXI_ID_WIDTH-1:0] m_axi_rid,
    input wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output wire m_axi_rready
);

    assign m_axi_araddr = s_axi_araddr;
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arcache = s_axi_arcache;
    assign m_axi_arid = s_axi_arid;
    assign m_axi_arlen = s_axi_arlen;
    assign m_axi_arlock = s_axi_arlock;
    assign m_axi_arprot = s_axi_arprot;
    assign m_axi_arqos = s_axi_arqos;
    assign m_axi_arregion = s_axi_arregion;
    assign m_axi_arsize = s_axi_arsize;

    assign m_axi_awaddr = s_axi_awaddr;
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_awcache = s_axi_awcache;
    assign m_axi_awid = s_axi_awid;
    assign m_axi_awlen = s_axi_awlen;
    assign m_axi_awlock = s_axi_awlock;
    assign m_axi_awprot = s_axi_awprot;
    assign m_axi_awqos = s_axi_awqos;
    assign m_axi_awregion = s_axi_awregion;
    assign m_axi_awsize = s_axi_awsize;

    assign s_axi_rdata = m_axi_rdata;
    assign s_axi_rresp = m_axi_rresp;
    assign s_axi_rlast = m_axi_rlast;
    assign s_axi_rid = m_axi_rid;
    assign m_axi_wdata = s_axi_wdata;
    assign m_axi_wstrb = s_axi_wstrb;
    assign m_axi_wlast = s_axi_wlast;
    assign s_axi_bresp = m_axi_bresp;
    assign s_axi_bid = m_axi_bid;

    localparam READ_FIFO_WIDTH = 40;
    localparam WRITE_FIFO_WIDTH = 40;

    localparam RU_BANDWIDTH_BITS = READ_BANDWIDTH_UP == 1 ? 1 : $clog2(READ_BANDWIDTH_UP);
    localparam RD_BANDWIDTH_BITS = (READ_BANDWIDTH_DOWN == 0 || READ_BANDWIDTH_DOWN == 1) ? 1 : $clog2(READ_BANDWIDTH_DOWN);
    localparam WU_BANDWIDTH_BITS = WRITE_BANDWIDTH_UP == 1 ? 1 : $clog2(WRITE_BANDWIDTH_UP);
    localparam WD_BANDWIDTH_BITS = (WRITE_BANDWIDTH_DOWN == 0 || WRITE_BANDWIDTH_DOWN == 1) ? 1 : $clog2(WRITE_BANDWIDTH_DOWN);
    localparam OUTSTANDING_REQ_BITS = $clog2(MAX_OUTSTANDING_REQUESTS+1);

    wire read_fifo_full;
    wire [READ_FIFO_WIDTH-1:0] read_fifo_din;
    wire read_fifo_wr_en;

    wire read_fifo_empty;
    reg [READ_FIFO_WIDTH-1:0] read_fifo_dout;
    wire read_fifo_rd_en;

    wire write_fifo_full;
    wire [WRITE_FIFO_WIDTH-1:0] write_fifo_din;
    wire write_fifo_wr_en;

    wire write_fifo_empty;
    reg [WRITE_FIFO_WIDTH-1:0] write_fifo_dout;
    wire write_fifo_rd_en;

    reg [39:0] count;

    localparam READ_IDLE = 0;
    localparam READ_DATA = 1;
    localparam READ_DATA_WAIT = 2;

    localparam WRITE_DATA = 0;
    localparam WRITE_DATA_WAIT = 1;

    localparam WRITE_RESPONSE_IDLE = 0;
    localparam WRITE_RESPONSE_ISSUE = 1;

    reg [1:0] read_state;
    reg [RU_BANDWIDTH_BITS-1:0] bandwidth_read_up_count;
    reg [RD_BANDWIDTH_BITS-1:0] bandwidth_read_down_count;
    reg [WU_BANDWIDTH_BITS-1:0] bandwidth_write_up_count;
    reg [WD_BANDWIDTH_BITS-1:0] bandwidth_write_down_count;
    reg [0:0] write_state;
    reg [OUTSTANDING_REQ_BITS-1:0] write_outsanding_reqs;
    reg [0:0] write_response_state;

    wire aw_transfer;
    wire b_transfer;

    integer r;

    assign aw_transfer = s_axi_awvalid && m_axi_awready;
    assign b_transfer = m_axi_bvalid && s_axi_bready && write_response_state == WRITE_RESPONSE_ISSUE;

    assign m_axi_arvalid = !read_fifo_full && s_axi_arvalid;
    assign s_axi_arready = !read_fifo_full && m_axi_arready;
    assign read_fifo_wr_en = s_axi_arvalid && !read_fifo_full && m_axi_arready;
    assign read_fifo_din = count;

    assign m_axi_rready = read_state == READ_DATA && s_axi_rready;
    assign s_axi_rvalid = read_state == READ_DATA && m_axi_rvalid;
    assign read_fifo_rd_en = read_state == READ_IDLE && !read_fifo_empty && count >= read_fifo_dout+READ_LATENCY;

    always @(posedge aclk) begin
        count <= count + 40'd1;
        case (read_state)

            READ_IDLE: begin
                if (READ_BANDWIDTH_UP != 1) begin
                    bandwidth_read_up_count <= 0;
                end
                if (!read_fifo_empty && count >= read_fifo_dout+READ_LATENCY) begin
                    read_state <= READ_DATA;
                end
            end

            READ_DATA: begin
                bandwidth_read_down_count <= 0;
                if (m_axi_rvalid && s_axi_rready && m_axi_rlast) begin
                    read_state <= READ_IDLE;
                end else if (m_axi_rvalid && s_axi_rready) begin
                    if (READ_BANDWIDTH_RAND) begin
                        r = $urandom_range(99);
                        if (r < READ_BANDWIDTH_DOWN_PROB) begin
                            read_state <= READ_DATA_WAIT;
                        end
                    end else begin
                        if (READ_BANDWIDTH_UP != 1) begin
                            bandwidth_read_up_count <= bandwidth_read_up_count + 1;
                        end
                        if (READ_BANDWIDTH_DOWN != 0) begin
                            if (READ_BANDWIDTH_UP == 1 || bandwidth_read_up_count == READ_BANDWIDTH_UP-1) begin
                                read_state <= READ_DATA_WAIT;
                            end
                        end
                    end
                end
            end

            READ_DATA_WAIT: begin
                if (READ_BANDWIDTH_RAND) begin
                    r = $urandom_range(99);
                    if (r < READ_BANDWIDTH_UP_PROB) begin
                        read_state <= READ_DATA;
                    end
                end else begin
                    if (READ_BANDWIDTH_UP != 1) begin
                        bandwidth_read_up_count <= 0;
                    end
                    bandwidth_read_down_count <= bandwidth_read_down_count + 1;
                    if (bandwidth_read_down_count == READ_BANDWIDTH_DOWN-1) begin
                        read_state <= READ_DATA;
                    end
                end
            end

        endcase

        if (!aresetn) begin
            read_state <= READ_IDLE;
            count <= 40'd0;
        end
    end

    assign m_axi_awvalid = write_outsanding_reqs != MAX_OUTSTANDING_REQUESTS && s_axi_awvalid;
    assign s_axi_awready = write_outsanding_reqs != MAX_OUTSTANDING_REQUESTS && m_axi_awready;
    assign m_axi_wvalid = s_axi_wvalid && !write_fifo_full && write_state == WRITE_DATA;
    assign s_axi_wready = m_axi_wready && !write_fifo_full && write_state == WRITE_DATA;
    assign write_fifo_wr_en = s_axi_wvalid && m_axi_wready && s_axi_wlast && write_state == WRITE_DATA;
    assign write_fifo_din = count;

    always @(posedge aclk) begin

        if (write_outsanding_reqs != MAX_OUTSTANDING_REQUESTS && aw_transfer && !b_transfer) begin
            write_outsanding_reqs <= write_outsanding_reqs + 1;
        end else if ((write_outsanding_reqs == MAX_OUTSTANDING_REQUESTS || !aw_transfer) && b_transfer) begin
            write_outsanding_reqs <= write_outsanding_reqs - 1;
        end

        if (!aresetn) begin
            write_outsanding_reqs <= 0;
        end
    end

    always @(posedge aclk) begin
        case (write_state)

            WRITE_DATA: begin
                bandwidth_write_down_count <= 0;
                if (s_axi_wvalid && m_axi_wready) begin
                    if (WRITE_BANDWIDTH_RAND) begin
                        r = $urandom_range(99);
                        if (r < WRITE_BANDWIDTH_DOWN_PROB) begin
                            write_state <= WRITE_DATA_WAIT;
                        end
                    end else begin
                        if (WRITE_BANDWIDTH_UP != 1) begin
                            bandwidth_write_up_count <= bandwidth_write_up_count + 1;
                        end
                        if (WRITE_BANDWIDTH_DOWN != 0) begin
                            if (WRITE_BANDWIDTH_UP == 1 || bandwidth_write_up_count == WRITE_BANDWIDTH_UP-1) begin
                                write_state <= WRITE_DATA_WAIT;
                            end
                        end
                    end
                end
            end

            WRITE_DATA_WAIT: begin
                if (WRITE_BANDWIDTH_RAND) begin
                    r = $urandom_range(99);
                    if (r < WRITE_BANDWIDTH_UP_PROB) begin
                        write_state <= WRITE_DATA;
                    end
                end else begin
                    bandwidth_write_up_count <= 0;
                    bandwidth_write_down_count <= bandwidth_write_down_count + 1;
                    if (bandwidth_write_down_count == WRITE_BANDWIDTH_DOWN-1) begin
                        write_state <= WRITE_DATA;
                    end
                end
            end

        endcase

        if (!aresetn) begin
            bandwidth_write_up_count <= 0;
            write_state <= WRITE_DATA;
        end
    end

    assign write_fifo_rd_en = write_response_state == WRITE_RESPONSE_ISSUE && !write_fifo_empty && count >= write_fifo_dout+WRITE_LATENCY;
    assign m_axi_bready = write_response_state == WRITE_RESPONSE_ISSUE && s_axi_bready;
    assign s_axi_bvalid = write_response_state == WRITE_RESPONSE_ISSUE && m_axi_bvalid;

    always @(posedge aclk) begin
        case(write_response_state)

            WRITE_RESPONSE_IDLE: begin
                if (!write_fifo_empty && count >= write_fifo_dout+WRITE_LATENCY) begin
                    write_response_state <= WRITE_RESPONSE_ISSUE;
                end
            end

            WRITE_RESPONSE_ISSUE: begin
                if (m_axi_bvalid && s_axi_bready) begin
                    write_response_state <= WRITE_RESPONSE_IDLE;
                end
            end

        endcase

        if (!aresetn) begin
            write_response_state <= WRITE_RESPONSE_IDLE;
        end
    end

    localparam LEN = MAX_OUTSTANDING_REQUESTS;
    localparam ADDR_BITS = $clog2(LEN);

    /// READ FIFO BEGIN
    reg [READ_FIFO_WIDTH-1:0] read_fifo_mem[0:LEN-1];

    reg [ADDR_BITS:0] read_fifo_rd_addr;
    reg [ADDR_BITS:0] read_fifo_wr_addr;

    assign read_fifo_empty = read_fifo_rd_addr == read_fifo_wr_addr;
    assign read_fifo_full = read_fifo_rd_addr[ADDR_BITS] != read_fifo_wr_addr[ADDR_BITS] && read_fifo_rd_addr[ADDR_BITS-1:0] == read_fifo_wr_addr[ADDR_BITS-1:0];

    always @(posedge aclk) begin
        read_fifo_dout <= read_fifo_mem[read_fifo_rd_addr[ADDR_BITS-1:0]];

        if (read_fifo_wr_en) begin
            read_fifo_mem[read_fifo_wr_addr[ADDR_BITS-1:0]] <= read_fifo_din;
            if (read_fifo_wr_addr[ADDR_BITS-1:0] == LEN-1) begin
                read_fifo_wr_addr[ADDR_BITS-1:0] <= 0;
                read_fifo_wr_addr[ADDR_BITS] <= !read_fifo_wr_addr[ADDR_BITS];
            end else begin
                read_fifo_wr_addr[ADDR_BITS-1:0] <= read_fifo_wr_addr[ADDR_BITS-1:0]+1;
            end
            if (read_fifo_empty) begin
                read_fifo_dout <= read_fifo_din;
            end
        end
        if (read_fifo_rd_en) begin
            if (read_fifo_rd_addr[ADDR_BITS-1:0] == LEN-1) begin
                read_fifo_rd_addr[ADDR_BITS-1:0] <= 0;
                read_fifo_rd_addr[ADDR_BITS] <= !read_fifo_rd_addr[ADDR_BITS];
                read_fifo_dout <= read_fifo_mem[0];
            end else begin
                read_fifo_rd_addr[ADDR_BITS-1:0] <= read_fifo_rd_addr[ADDR_BITS-1:0]+1;
                read_fifo_dout <= read_fifo_mem[read_fifo_rd_addr[ADDR_BITS-1:0]+1];
            end
        end

        if (!aresetn) begin
            read_fifo_rd_addr <= 0;
            read_fifo_wr_addr <= 0;
        end
    end
    /// WRITE FIFO BEGIN
    reg [WRITE_FIFO_WIDTH-1:0] write_fifo_mem[0:LEN-1];

    reg [ADDR_BITS:0] write_fifo_rd_addr;
    reg [ADDR_BITS:0] write_fifo_wr_addr;

    assign write_fifo_empty = write_fifo_rd_addr == write_fifo_wr_addr;
    assign write_fifo_full = write_fifo_rd_addr[ADDR_BITS] != write_fifo_wr_addr[ADDR_BITS] && write_fifo_rd_addr[ADDR_BITS-1:0] == write_fifo_wr_addr[ADDR_BITS-1:0];

    always @(posedge aclk) begin
        write_fifo_dout <= write_fifo_mem[write_fifo_rd_addr[ADDR_BITS-1:0]];

        if (write_fifo_wr_en) begin
            write_fifo_mem[write_fifo_wr_addr[ADDR_BITS-1:0]] <= write_fifo_din;
            if (write_fifo_wr_addr[ADDR_BITS-1:0] == LEN-1) begin
                write_fifo_wr_addr[ADDR_BITS-1:0] <= 0;
                write_fifo_wr_addr[ADDR_BITS] <= !write_fifo_wr_addr[ADDR_BITS];
            end else begin
                write_fifo_wr_addr[ADDR_BITS-1:0] <= write_fifo_wr_addr[ADDR_BITS-1:0]+1;
            end
            if (write_fifo_empty) begin
                write_fifo_dout <= write_fifo_din;
            end
        end
        if (write_fifo_rd_en) begin
            if (write_fifo_rd_addr[ADDR_BITS-1:0] == LEN-1) begin
                write_fifo_rd_addr[ADDR_BITS-1:0] <= 0;
                write_fifo_rd_addr[ADDR_BITS] <= !write_fifo_rd_addr[ADDR_BITS];
                write_fifo_dout <= write_fifo_mem[0];
            end else begin
                write_fifo_rd_addr[ADDR_BITS-1:0] <= write_fifo_rd_addr[ADDR_BITS-1:0]+1;
                write_fifo_dout <= write_fifo_mem[write_fifo_rd_addr[ADDR_BITS-1:0]+1];
            end
        end

        if (!aresetn) begin
            write_fifo_rd_addr <= 0;
            write_fifo_wr_addr <= 0;
        end
    end

endmodule