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

`timescale 1 ns / 1 ps

module axi_sim_mem_linear #(
    parameter AXI_ID_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0,
    parameter MEM_SIZE = 0
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
    input wire s_axi_rready
);

    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE);

    reg [7:0] mem[MEM_SIZE];

    typedef struct {
        reg [MEM_ADDR_WIDTH-1:0] addr;
        reg [7:0] len;
        reg [AXI_ID_WIDTH-1:0] id;
    } AddrCmd_t;

    AddrCmd_t read_queue[$];
    AddrCmd_t write_queue[$];
    reg [AXI_ID_WIDTH-1:0] wresp_queue[$];

    assign s_axi_arready = 1;

    always @(posedge aclk) begin

        if (s_axi_arvalid) begin
            AddrCmd_t cmd;
            cmd.addr = s_axi_araddr[MEM_ADDR_WIDTH-1:0];
            cmd.len = s_axi_arlen;
            cmd.id = s_axi_arid;
            read_queue.push_back(cmd);
        end

        if (!aresetn) begin
            read_queue = {};
        end
    end

    typedef enum {
        R_IDLE,
        READ_BURST
    } ReadState_t;

    localparam BYTES_PER_WORD = AXI_DATA_WIDTH/8;
    localparam OFFSET_ADDR_BITS = $clog2(BYTES_PER_WORD);

    ReadState_t read_state;
    int bursts_left;
    reg [MEM_ADDR_WIDTH-1:0] raddr;
    reg [AXI_DATA_WIDTH-1:0] rdata;
    reg [AXI_ID_WIDTH-1:0] rid;

    function reg [AXI_DATA_WIDTH-1:0] read_data(reg [MEM_ADDR_WIDTH-1:0] addr);
        reg [AXI_DATA_WIDTH-1:0] axi_word;
        int word_offset;
        word_offset = addr[OFFSET_ADDR_BITS-1:0];
        addr[OFFSET_ADDR_BITS-1:0] = 0;
        axi_word = {AXI_DATA_WIDTH{1'bX}};
        for (int i = word_offset; i < BYTES_PER_WORD; ++i) begin
            axi_word[i*8 +: 8] = mem[addr + i];
        end
        return axi_word;
    endfunction

    assign s_axi_rvalid = read_state == READ_BURST;
    assign s_axi_rdata = rdata;
    assign s_axi_rlast = bursts_left == 0;
    assign s_axi_rid = rid;
    assign s_axi_rresp = 2'b10;

    always @(posedge aclk) begin

        case (read_state)

            R_IDLE: begin
                if (read_queue.size() != 0) begin
                    AddrCmd_t cmd;
                    cmd = read_queue.pop_front();
                    raddr = cmd.addr;
                    bursts_left <= cmd.len;
                    rid <= cmd.id;
                    rdata = read_data(raddr);
                    read_state <= READ_BURST;
                end
            end

            READ_BURST: begin
                if (s_axi_rready) begin
                    raddr[OFFSET_ADDR_BITS-1:0] = 0;
                    raddr += BYTES_PER_WORD;
                    rdata = read_data(raddr);
                    bursts_left <= bursts_left - 1;
                    if (bursts_left == 0) begin
                        read_state <= R_IDLE;
                    end
                end
            end

        endcase

        if (!aresetn) begin
            read_state <= R_IDLE;
        end
    end

    assign s_axi_awready = 1;

    always @(posedge aclk) begin

        if (s_axi_awvalid) begin
            AddrCmd_t cmd;
            cmd.addr = s_axi_awaddr[MEM_ADDR_WIDTH-1:0];
            cmd.len = s_axi_awlen;
            cmd.id = s_axi_awid;
            write_queue.push_back(cmd);
        end

        if (!aresetn) begin
            write_queue = {};
        end
    end

    typedef enum {
        W_IDLE,
        WRITE_BURST
    } WriteState_t;

    WriteState_t write_state;
    reg [MEM_ADDR_WIDTH-1:0] waddr;
    reg [AXI_ID_WIDTH-1:0] wid;

    assign s_axi_wready = write_state == WRITE_BURST;

    always @(posedge aclk) begin

        case (write_state)

            W_IDLE: begin
                if (write_queue.size() != 0) begin
                    AddrCmd_t cmd;
                    cmd = write_queue.pop_front();
                    waddr = cmd.addr;
                    waddr[OFFSET_ADDR_BITS-1:0] = 0;
                    wid <= cmd.id;
                    write_state <= WRITE_BURST;
                end
            end

            WRITE_BURST: begin
                if (s_axi_wvalid) begin
                    for (int i = 0; i < BYTES_PER_WORD; ++i) begin
                        if (s_axi_wstrb[i]) begin
                            mem[waddr+i] = s_axi_wdata[i*8 +: 8];
                        end
                    end
                    waddr += BYTES_PER_WORD;
                    if (s_axi_wlast) begin
                        wresp_queue.push_back(wid);
                        write_state <= W_IDLE;
                    end
                end
            end

        endcase

        if (!aresetn) begin
            write_state <= W_IDLE;
            wresp_queue = {};
        end
    end

    typedef enum {
        B_IDLE,
        SEND_WRESP
    } WrespState_t;

    WrespState_t wresp_state;
    reg [AXI_ID_WIDTH-1:0] bid;

    assign s_axi_bvalid = wresp_state == SEND_WRESP;;
    assign s_axi_bid = bid;
    assign s_axi_bresp = 2'b10;

    always @(posedge aclk) begin

        case (wresp_state)

            B_IDLE: begin
                if (wresp_queue.size() != 0) begin
                    bid <= wresp_queue.pop_front();
                    wresp_state <= SEND_WRESP;
                end
            end

            SEND_WRESP: begin
                if (s_axi_bready) begin
                    wresp_state <= B_IDLE;
                end
            end

        endcase

        if (!aresetn) begin
            wresp_state <= B_IDLE;
        end
    end

endmodule
