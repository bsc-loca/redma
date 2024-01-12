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

interface AXI4_AR #(parameter ADDR_WIDTH = 0);

    logic arvalid;
    logic arready;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;

    modport master(output arvalid, input arready, output araddr, output arlen, output arsize, output arburst);
    modport slave(input arvalid, output arready, input araddr, input arlen, input arsize, input arburst);

endinterface

interface AXI4_R #(parameter DATA_WIDTH = 0);

    logic rvalid;
    logic rready;
    logic [DATA_WIDTH-1:0] rdata;
    logic rlast;

    modport master(input rvalid, output rready, input rdata, input rlast);
    modport slave(output rvalid, input rready, output rdata, output rlast);

endinterface

interface AXI4_AW #(parameter ADDR_WIDTH = 0);

    logic awvalid;
    logic awready;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;

    modport master(output awvalid, input awready, output awaddr, output awlen, output awsize, output awburst);
    modport slave(input awvalid, output awready, input awaddr, input awlen, input awsize, input awburst);

endinterface

interface AXI4_W #(parameter DATA_WIDTH = 0);

    logic wvalid;
    logic wready;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic wlast;

    modport master(output wvalid, input wready, output wdata, output wstrb, output wlast);
    modport slave(input wvalid, output wready, input wdata, input wstrb, input wlast);

endinterface

interface AXI4_B;

    logic bvalid;
    logic bready;
    logic [1:0] bresp;

    modport master(input bvalid, output bready, input bresp);
    modport slave(output bvalid, input bready, output bresp);

endinterface

interface FIFO_READ #(parameter DATA_WIDTH = 0);

    logic empty;
    logic read;
    logic [DATA_WIDTH-1:0] data;

    modport master(input empty, output read, input data);
    modport slave(output empty, input read, output data);

endinterface

interface FIFO_WRITE #(parameter DATA_WIDTH = 0);

    logic full;
    logic write;
    logic [DATA_WIDTH-1:0] data;

    modport master(input full, output write, output data);
    modport slave(output full, input write, input data);

endinterface