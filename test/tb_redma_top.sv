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
// Jordi Fornt <jfornt@bsc.es>
// Juan Miguel de Haro <juan.deharoruiz@bsc.es>

// --------------------
//      INCLUDES
// --------------------

`include "axi/axi_assign.svh"
`include "axi/axi_typedef.svh"

// --------------------
//      DEFINES
// --------------------

//`define POWER
//`define NETLIST

module tb_redma_top ();

	// --------------------------
	// Simulation Parameters
	// --------------------------
	
    timeunit 1ps;
    timeprecision 1ps;

    localparam time CLK_PERIOD          = 1800ps;
	localparam time APPL_DELAY          = 400ps;
    localparam time ACQ_DELAY           = 900ps;
    localparam time TEST_DELAY          = 1400ps;
	
    localparam time CLK_PERIOD_SLO      = 5400ps;

    localparam unsigned RST_CLK_CYCLES  = 10;

	// Number of Input Vectors & Number of tests
	localparam unsigned N_VECTORS = 6000;	

    // DUT Parameters
	localparam SAURIA_OFFSET 			= 32'hFA000000;
    localparam SAURIA_OFFSET_MSBs      	= 8;

	localparam MEM_BYTES = 8*1024*1024;

    localparam CFG_AXI_DATA_WIDTH    = 32;
    localparam CFG_AXI_ADDR_WIDTH    = 32;
    localparam CFG_AXI_RESP_WIDTH    = 2;
    localparam CFG_AXI_PROT_WIDTH    = 3;
    localparam CFG_IF_LSB_BITS       = 2;

    localparam DATA_AXI_DATA_WIDTH    = 128;
    localparam DATA_AXI_ADDR_WIDTH    = 32;
    localparam DATA_AXI_RESP_WIDTH    = 2;
    localparam DATA_AXI_PROT_WIDTH    = 3;
    localparam DATA_IF_LSB_BITS       = 4;
	localparam DATA_AXI_ID_WIDTH      = 4;

    localparam  BYTE = 8;
    localparam  CFG_AXI_BYTE_NUM = CFG_AXI_DATA_WIDTH/BYTE;
    localparam  DATA_AXI_BYTE_NUM = DATA_AXI_DATA_WIDTH/BYTE;
    localparam  BYTE_CNT_BITS = $clog2(256*DATA_AXI_BYTE_NUM);

	// --------------------------
	// Signals
	// --------------------------
	
    logic       clk, rstn;
	logic 		dma_interrupt;

	// ----------------------------------------------------
	// CFG AXI Lite Driver - Definitions and instantiation
	// ----------------------------------------------------

    // AXI4 Lite for CONFIG
    typedef axi_test::axi_lite_rand_master #(
        // AXI interface parameters
        .AW ( CFG_AXI_ADDR_WIDTH ),
        .DW ( CFG_AXI_DATA_WIDTH ),
        // Stimuli application and test time
        .TA ( APPL_DELAY  ),
        .TT ( TEST_DELAY  ),
        .MIN_ADDR ( '0 ),
        .MAX_ADDR ( '1   ),
        .MAX_READ_TXNS  ( 10 ),
        .MAX_WRITE_TXNS ( 10 )
    ) cfg_rand_lite_master_t;

    // AXI4 Lite configuration interface
    AXI_LITE #(
        .AXI_ADDR_WIDTH ( CFG_AXI_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( CFG_AXI_DATA_WIDTH      )
    ) cfg_bus_lite ();

    // AXI4 Lite configuration interface (DESIGN VERIFICATION)
    AXI_LITE_DV #(
        .AXI_ADDR_WIDTH ( CFG_AXI_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( CFG_AXI_DATA_WIDTH      )
    ) cfg_master_dv (clk);

    // AXI4 data interface
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( DATA_AXI_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( DATA_AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( DATA_AXI_ID_WIDTH        )
    ) dat_bus ();

	// Assign requests and responses to their respective slaves
	`AXI_LITE_ASSIGN(cfg_bus_lite, cfg_master_dv)

	`AXI_ASSIGN_TO_REQ(        dma_req, dat_bus)
	`AXI_ASSIGN_FROM_RESP(     dat_bus, dma_resp)

	// `AXI_LITE_ASSIGN_FROM_RESP(     cfg_master, cfg_lite_resp)
	// `AXI_LITE_ASSIGN_TO_REQ(        cfg_lite_req, cfg_master)

	// ------------------------------------------
	// Golden Stimuli and Golden Outputs (IF)
	// ------------------------------------------

    // Golden model stimuli
    logic [N_VECTORS-1:0][CFG_AXI_DATA_WIDTH-1:0]   gold_cfg_data_in;
    logic [N_VECTORS-1:0][CFG_AXI_ADDR_WIDTH-1:0]   gold_cfg_address;
    logic [N_VECTORS-1:0]                           gold_cfg_wren;
    logic [N_VECTORS-1:0]                           gold_cfg_rden;
    logic [N_VECTORS-1:0][1:0]                      gold_cfg_waitflag;

    localparam IM_size = 5;  //Modify - numberof sequences

    longint  Input_Matrix [0:N_VECTORS-1][0:IM_size-1];

    // Expected data_out
    logic [DATA_AXI_DATA_WIDTH-1:0] exp_data_out, acq_data_out;

	// AXI type definitions
	typedef logic [DATA_AXI_ADDR_WIDTH-1:0]     dat_addr_t;
	typedef logic [DATA_AXI_ID_WIDTH-1:0]       dat_id_t;
	typedef logic [DATA_AXI_DATA_WIDTH-1:0]     dat_data_t;
	typedef logic [DATA_AXI_BYTE_NUM-1:0]       dat_strb_t;

	// Derivative typedefs (with macros)
	`AXI_TYPEDEF_AW_CHAN_T(    dat_aw_chan_t, dat_addr_t, dat_id_t, logic)
	`AXI_TYPEDEF_W_CHAN_T(     dat_w_chan_t, dat_data_t, dat_strb_t, logic)
	`AXI_TYPEDEF_B_CHAN_T(     dat_b_chan_t, dat_id_t, logic)
	`AXI_TYPEDEF_AR_CHAN_T(    dat_ar_chan_t, dat_addr_t, dat_id_t, logic)
	`AXI_TYPEDEF_R_CHAN_T(     dat_r_chan_t, dat_data_t, dat_id_t, logic)

	`AXI_TYPEDEF_REQ_T(    dat_req_t, dat_aw_chan_t, dat_w_chan_t, dat_ar_chan_t)
	`AXI_TYPEDEF_RESP_T(   dat_resp_t, dat_b_chan_t, dat_r_chan_t)

	// AXI lite type definitions
	typedef logic [CFG_AXI_ADDR_WIDTH-1:0]      cfg_addr_t;
	typedef logic [CFG_AXI_DATA_WIDTH-1:0]      cfg_data_t;
	typedef logic [CFG_AXI_BYTE_NUM-1:0]        cfg_strb_t;

	// Derivative typedefs (with macros)
	`AXI_LITE_TYPEDEF_AW_CHAN_T(    cfg_aw_chan_lite_t, cfg_addr_t)
	`AXI_LITE_TYPEDEF_W_CHAN_T(     cfg_w_chan_lite_t, cfg_data_t, cfg_strb_t)
	`AXI_LITE_TYPEDEF_B_CHAN_T(     cfg_b_chan_lite_t)
	`AXI_LITE_TYPEDEF_AR_CHAN_T(    cfg_ar_chan_lite_t, cfg_addr_t)
	`AXI_LITE_TYPEDEF_R_CHAN_T(     cfg_r_chan_lite_t, cfg_data_t)

	`AXI_LITE_TYPEDEF_REQ_T(    cfg_req_lite_t, cfg_aw_chan_lite_t, cfg_w_chan_lite_t, cfg_ar_chan_lite_t)
	`AXI_LITE_TYPEDEF_RESP_T(   cfg_resp_lite_t, cfg_b_chan_lite_t, cfg_r_chan_lite_t)

	// AXI responses and requests
	dat_req_t      dat_axi_sauria_req;
	dat_resp_t     dat_axi_sauria_resp;
	dat_req_t      dat_axi_memory_req;
	dat_resp_t     dat_axi_memory_resp;

	dat_req_t      dat_axi_memory_req_slow;
	dat_resp_t     dat_axi_memory_resp_slow;

	dat_req_t       dma_req;
	dat_resp_t 	    dma_resp;

	// Simulated AXI Slave + memory
	axi_sim_mem #(
		.DataWidth(DATA_AXI_DATA_WIDTH),
		.AddrWidth(DATA_AXI_ADDR_WIDTH),
		.IdWidth(DATA_AXI_ID_WIDTH),
		.UserWidth(1),
		.axi_req_t(dat_req_t),
		.axi_rsp_t(dat_resp_t),
		.ApplDelay(APPL_DELAY),
		.AcqDelay(ACQ_DELAY)
	) i_sim_mem_0(
		.clk_i(clk),
		.rst_ni(rstn),

		.axi_req_i      (dat_axi_sauria_req),
		.axi_rsp_o      (dat_axi_sauria_resp)
	);

	// Simulated AXI Slave + memory
	axi_sim_mem #(
		.DataWidth(DATA_AXI_DATA_WIDTH),
		.AddrWidth(DATA_AXI_ADDR_WIDTH),
		.IdWidth(DATA_AXI_ID_WIDTH),
		.UserWidth(1),
		.axi_req_t(dat_req_t),
		.axi_rsp_t(dat_resp_t),
		.ApplDelay(APPL_DELAY),
		.AcqDelay(ACQ_DELAY)
	) i_sim_mem_1(
		.clk_i(clk),
		.rst_ni(rstn),

		.axi_req_i        (dat_axi_memory_req_slow),
		.axi_rsp_o        (dat_axi_memory_resp_slow)
	);

    axi_delayer #(
        .READ_LATENCY(4),
        .READ_BANDWIDTH(3),
        .WRITE_LATENCY(5),
        .WRITE_BANDWIDTH(3),
        .MAX_OUTSTANDING_REQUESTS(2),
        .AXI_ID_WIDTH(DATA_AXI_ID_WIDTH),
        .AXI_DATA_WIDTH(DATA_AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(DATA_AXI_ADDR_WIDTH)
    ) axi_delayer_I (
        .aclk(clk),
        .aresetn(rstn),
        .s_axi_arid    (dat_axi_memory_req.ar.id),
        .s_axi_araddr  (dat_axi_memory_req.ar.addr),
        .s_axi_arlen   (dat_axi_memory_req.ar.len),
        .s_axi_arsize  (dat_axi_memory_req.ar.size),
        .s_axi_arburst (dat_axi_memory_req.ar.burst),
        .s_axi_arlock  (dat_axi_memory_req.ar.lock),
        .s_axi_arcache (dat_axi_memory_req.ar.cache),
        .s_axi_arprot  (dat_axi_memory_req.ar.prot),
        .s_axi_arqos   (dat_axi_memory_req.ar.qos),
        .s_axi_arvalid (dat_axi_memory_req.ar_valid),
        .s_axi_arready (dat_axi_memory_resp.ar_ready),
        .s_axi_rid     (dat_axi_memory_resp.r.id),
        .s_axi_rdata   (dat_axi_memory_resp.r.data),
        .s_axi_rresp   (dat_axi_memory_resp.r.resp),
        .s_axi_rlast   (dat_axi_memory_resp.r.last),
        .s_axi_rvalid  (dat_axi_memory_resp.r_valid),
        .s_axi_rready  (dat_axi_memory_req.r_ready),
        .s_axi_awid    (dat_axi_memory_req.aw.id),
        .s_axi_awaddr  (dat_axi_memory_req.aw.addr),
        .s_axi_awlen   (dat_axi_memory_req.aw.len),
        .s_axi_awsize  (dat_axi_memory_req.aw.size),
        .s_axi_awburst (dat_axi_memory_req.aw.burst),
        .s_axi_awlock  (dat_axi_memory_req.aw.lock),
        .s_axi_awcache (dat_axi_memory_req.aw.cache),
        .s_axi_awprot  (dat_axi_memory_req.aw.prot),
        .s_axi_awqos   (dat_axi_memory_req.aw.qos),
        .s_axi_awvalid (dat_axi_memory_req.aw_valid),
        .s_axi_awready (dat_axi_memory_resp.aw_ready),
        .s_axi_wdata   (dat_axi_memory_req.w.data),
        .s_axi_wstrb   (dat_axi_memory_req.w.strb),
        .s_axi_wlast   (dat_axi_memory_req.w.last),
        .s_axi_wvalid  (dat_axi_memory_req.w_valid),
        .s_axi_wready  (dat_axi_memory_resp.w_ready),
        .s_axi_bid     (dat_axi_memory_resp.b.id),
        .s_axi_bresp   (dat_axi_memory_resp.b.resp),
        .s_axi_bvalid  (dat_axi_memory_resp.b_valid),
        .s_axi_bready  (dat_axi_memory_req.b_ready),
        .m_axi_arid    (dat_axi_memory_req_slow.ar.id),
        .m_axi_araddr  (dat_axi_memory_req_slow.ar.addr),
        .m_axi_arlen   (dat_axi_memory_req_slow.ar.len),
        .m_axi_arsize  (dat_axi_memory_req_slow.ar.size),
        .m_axi_arburst (dat_axi_memory_req_slow.ar.burst),
        .m_axi_arlock  (dat_axi_memory_req_slow.ar.lock),
        .m_axi_arcache (dat_axi_memory_req_slow.ar.cache),
        .m_axi_arprot  (dat_axi_memory_req_slow.ar.prot),
        .m_axi_arqos   (dat_axi_memory_req_slow.ar.qos),
        .m_axi_arvalid (dat_axi_memory_req_slow.ar_valid),
        .m_axi_arready (dat_axi_memory_resp_slow.ar_ready),
        .m_axi_rid     (dat_axi_memory_resp_slow.r.id),
        .m_axi_rdata   (dat_axi_memory_resp_slow.r.data),
        .m_axi_rresp   (dat_axi_memory_resp_slow.r.resp),
        .m_axi_rlast   (dat_axi_memory_resp_slow.r.last),
        .m_axi_rvalid  (dat_axi_memory_resp_slow.r_valid),
        .m_axi_rready  (dat_axi_memory_req_slow.r_ready),
        .m_axi_awid    (dat_axi_memory_req_slow.aw.id),
        .m_axi_awaddr  (dat_axi_memory_req_slow.aw.addr),
        .m_axi_awlen   (dat_axi_memory_req_slow.aw.len),
        .m_axi_awsize  (dat_axi_memory_req_slow.aw.size),
        .m_axi_awburst (dat_axi_memory_req_slow.aw.burst),
        .m_axi_awlock  (dat_axi_memory_req_slow.aw.lock),
        .m_axi_awcache (dat_axi_memory_req_slow.aw.cache),
        .m_axi_awprot  (dat_axi_memory_req_slow.aw.prot),
        .m_axi_awqos   (dat_axi_memory_req_slow.aw.qos),
        .m_axi_awvalid (dat_axi_memory_req_slow.aw_valid),
        .m_axi_awready (dat_axi_memory_resp_slow.aw_ready),
        .m_axi_wdata   (dat_axi_memory_req_slow.w.data),
        .m_axi_wstrb   (dat_axi_memory_req_slow.w.strb),
        .m_axi_wlast   (dat_axi_memory_req_slow.w.last),
        .m_axi_wvalid  (dat_axi_memory_req_slow.w_valid),
        .m_axi_wready  (dat_axi_memory_resp_slow.w_ready),
        .m_axi_bid     (dat_axi_memory_resp_slow.b.id),
        .m_axi_bresp   (dat_axi_memory_resp_slow.b.resp),
        .m_axi_bvalid  (dat_axi_memory_resp_slow.b_valid),
        .m_axi_bready  (dat_axi_memory_req_slow.b_ready)
    );

	// --------------------------
	// Reset and Clock generation
	// --------------------------
	initial begin: reset_block
		rstn = 0;
		#(CLK_PERIOD*RST_CLK_CYCLES);
		rstn = 1;
	end
	
	initial begin: clock_block
		forever begin
			clk = 0;
			#(CLK_PERIOD/2);
			clk = 1;
			#(CLK_PERIOD/2);
		end
	end

	// --------------------------
    // Instantiate the DUTs
	// --------------------------

    redma_top #(
      .AXI_LITE_ADDR_WIDTH(CFG_AXI_ADDR_WIDTH),
      .AXI_ADDR_WIDTH(DATA_AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(DATA_AXI_DATA_WIDTH),
      .AXI_ID_WIDTH(DATA_AXI_ID_WIDTH),
      .AXI_MAX_ARLEN(255),
      .AXI_MAX_AWLEN(255),
      .READER_FIFO_LEN(2),
      .WRITER_FIFO_LEN(2),
      .AXI_READER_ADDR_OFFSET('0),
      .AXI_WRITER_ADDR_OFFSET('0),
      .ELM_BITS(8),
      .SYNC_AW_W(0),
      .MAX_OUTSTANDING_WRITES(0)
    ) dut(
		.clk(clk),
        .rstn(rstn),

        .io_control_ar_arprot         (cfg_bus_lite.ar_prot),
        .io_control_ar_araddr         (cfg_bus_lite.ar_addr),
        .io_control_ar_arvalid        (cfg_bus_lite.ar_valid),
        .io_control_ar_arready        (cfg_bus_lite.ar_ready),
        .io_control_r_rdata          (cfg_bus_lite.r_data),
        .io_control_r_rresp          (cfg_bus_lite.r_resp),
        .io_control_r_rvalid         (cfg_bus_lite.r_valid),
        .io_control_r_rready         (cfg_bus_lite.r_ready),
        .io_control_aw_awprot         (cfg_bus_lite.aw_prot),
        .io_control_aw_awaddr         (cfg_bus_lite.aw_addr),
        .io_control_aw_awvalid        (cfg_bus_lite.aw_valid),
        .io_control_aw_awready        (cfg_bus_lite.aw_ready),
        .io_control_w_wdata          (cfg_bus_lite.w_data),
        .io_control_w_wstrb          (cfg_bus_lite.w_strb),
        .io_control_w_wvalid         (cfg_bus_lite.w_valid),
        .io_control_w_wready         (cfg_bus_lite.w_ready),
        .io_control_b_bresp          (cfg_bus_lite.b_resp),
        .io_control_b_bvalid         (cfg_bus_lite.b_valid),
        .io_control_b_bready         (cfg_bus_lite.b_ready),

        .m_axi_ar_arid           (dat_bus.ar_id),
        .m_axi_ar_arprot         (dat_bus.ar_prot),
        .m_axi_ar_araddr         (dat_bus.ar_addr),
        .m_axi_ar_arburst        (dat_bus.ar_burst),
        .m_axi_ar_arlen          (dat_bus.ar_len),
        .m_axi_ar_arvalid        (dat_bus.ar_valid),
        .m_axi_ar_arready        (dat_bus.ar_ready),
        .m_axi_ar_arsize         (dat_bus.ar_size),
        .m_axi_ar_arlock         (dat_bus.ar_lock),
        .m_axi_ar_arcache        (dat_bus.ar_cache),
        .m_axi_ar_arqos          (dat_bus.ar_qos),
        .m_axi_r_rid            (dat_bus.r_id),
        .m_axi_r_rdata          (dat_bus.r_data),
        .m_axi_r_rresp          (dat_bus.r_resp),
        .m_axi_r_rvalid         (dat_bus.r_valid),
        .m_axi_r_rlast          (dat_bus.r_last),
        .m_axi_r_rready         (dat_bus.r_ready),
        .m_axi_aw_awid           (dat_bus.aw_id),
        .m_axi_aw_awprot         (dat_bus.aw_prot),
        .m_axi_aw_awaddr         (dat_bus.aw_addr),
        .m_axi_aw_awburst        (dat_bus.aw_burst),
        .m_axi_aw_awlen          (dat_bus.aw_len),
        .m_axi_aw_awvalid        (dat_bus.aw_valid),
        .m_axi_aw_awready        (dat_bus.aw_ready),
        .m_axi_aw_awsize         (dat_bus.aw_size),
        .m_axi_aw_awlock         (dat_bus.aw_lock),
        .m_axi_aw_awcache        (dat_bus.aw_cache),
        .m_axi_aw_awqos          (dat_bus.aw_qos),
        .m_axi_w_wdata          (dat_bus.w_data),
        .m_axi_w_wstrb          (dat_bus.w_strb),
        .m_axi_w_wlast          (dat_bus.w_last),
        .m_axi_w_wvalid         (dat_bus.w_valid),
        .m_axi_w_wready         (dat_bus.w_ready),
        .m_axi_b_bid            (dat_bus.b_id),
        .m_axi_b_bresp          (dat_bus.b_resp),
        .m_axi_b_bvalid         (dat_bus.b_valid),
        .m_axi_b_bready         (dat_bus.b_ready),

		.writer_intr	    (dma_interrupt)
    );

	// -----------------------------------
    // AXI Demux
	// -----------------------------------

    // AXI Demux selection signals
    logic           demx_aw_sel, demx_ar_sel;
    logic           demx_aw_sel_q, demx_ar_sel_q;

    always_comb begin : demux_sel

        // Default to zero (MEMORY port)
        demx_aw_sel = demx_aw_sel_q;
        demx_ar_sel = demx_ar_sel_q;

        // Only if valid
        if (dma_req.aw_valid) begin
            // Switch to 1 if data region is selected
            if (dma_req.aw.addr[DATA_AXI_ADDR_WIDTH-1-:SAURIA_OFFSET_MSBs]
            == SAURIA_OFFSET[DATA_AXI_ADDR_WIDTH-1-:SAURIA_OFFSET_MSBs]) begin

                demx_aw_sel = 1'b1;
            end else begin
                demx_aw_sel = 1'b0;
            end
        end

        // Only if valid
        if (dma_req.ar_valid) begin
            // Switch to 1 if data region is selected
            if (dma_req.ar.addr[DATA_AXI_ADDR_WIDTH-1-:SAURIA_OFFSET_MSBs]
            == SAURIA_OFFSET[DATA_AXI_ADDR_WIDTH-1-:SAURIA_OFFSET_MSBs]) begin

                demx_ar_sel = 1'b1;
            end else begin
                demx_ar_sel = 1'b0;
            end
        end
    end

    // Register - Only accept new values if axvalid
    always_ff @(posedge clk or negedge rstn) begin : demx_reg
        if(~rstn) begin
            demx_aw_sel_q <= 0;
            demx_ar_sel_q <= 0;
        end else begin
            demx_aw_sel_q <= demx_aw_sel;
            demx_ar_sel_q <= demx_ar_sel;
        end
    end

    // AXI Demux
    axi_demux #(
        .AxiIdWidth     (DATA_AXI_ID_WIDTH),
        .aw_chan_t      (dat_aw_chan_t),
        .w_chan_t       (dat_w_chan_t),
        .b_chan_t       (dat_b_chan_t),
        .ar_chan_t      (dat_ar_chan_t),
        .r_chan_t       (dat_r_chan_t),
        .axi_req_t      (dat_req_t),
        .axi_resp_t     (dat_resp_t),
        .NoMstPorts     (2),
        .MaxTrans       (8),                    // Not sure how to dimension this...
        .AxiLookBits    (DATA_AXI_ID_WIDTH),    // Not sure how to dimension this...
        .UniqueIds      (1'b1),                 // Less than or equal to ID (so set it to ID)
        .FallThrough    (1'b0),
        .SpillAw        (1'b1),                 // Add spill registers before the multiplexer (+1 latency)
        .SpillW         (1'b1),
        .SpillB         (1'b1),
        .SpillAr        (1'b1),
        .SpillR         (1'b1)
    ) axi_demux_i (
        .clk_i              (clk),
        .rst_ni             (rstn),
        .test_i             (1'b0),

        .slv_aw_select_i    (demx_aw_sel),
        .slv_ar_select_i    (demx_ar_sel),

        .slv_req_i          (dma_req),
        .slv_resp_o         (dma_resp),

        .mst_reqs_o         ({dat_axi_sauria_req,  dat_axi_memory_req}),
        .mst_resps_i        ({dat_axi_sauria_resp, dat_axi_memory_resp})
    );

	// -----------------------------------
    // Load golden stimuli & outputs
	// -----------------------------------

    initial begin: load_golden_model

        // Load data matrices from file
		$readmemh("GoldenStimuli.txt", Input_Matrix);
		//$readmemh("GoldenOutputs.txt", Output_Matrix);

        // Assign values to the specific vectors
        for (integer i=0; i < N_VECTORS; i++) begin

            gold_cfg_data_in[i] =     Input_Matrix[i][0];
            gold_cfg_address[i] =     Input_Matrix[i][1];
            gold_cfg_wren[i] =        Input_Matrix[i][2];
            gold_cfg_rden[i] =        Input_Matrix[i][3];
            gold_cfg_waitflag[i] =    Input_Matrix[i][4];

        end
    end

	// ----------------------------------
	// Apply stimuli & get exp. response
	// ----------------------------------

    // PROCESS FOR CONFIGURATION INTERFACE
    // ***********************************
    cfg_rand_lite_master_t cfg_lite_axi_master;

    initial begin: config_stimuli_block

        // Temp response and data for reading
        automatic axi_pkg::resp_t               rsp_tmp;
        automatic logic [CFG_AXI_DATA_WIDTH-1:0]      data_tmp;

        // Internal signals
        integer                             idx_i=0;

        logic   [CFG_AXI_DATA_WIDTH-1:0]    cfg_data_in;
        logic   [CFG_AXI_ADDR_WIDTH-1:0]    cfg_addr;
        logic                               cfg_wren;
        logic                               cfg_rden;

		logic wait_flag_cfg;

		// Temp mems for checking values
		logic [7:0] gold_sauria_mem[dat_addr_t];
		logic [7:0] gold_dram_mem[dat_addr_t];

		integer n_errs, n_checks;
		
		// AXI Lite Master tasks
        cfg_lite_axi_master = new ( cfg_master_dv, "Lite Master");

		// Initialize one of the sim_mems with a .txt generated from Python
		$readmemh("register_map_sauria.txt", i_sim_mem_0.mem, SAURIA_OFFSET);
		$readmemh("register_map_memory.txt", i_sim_mem_1.mem);

        // Start by RESET-ing the masters
        cfg_lite_axi_master.reset();

        // Wait until RST is high
        wait (rstn);

        while (idx_i < N_VECTORS) begin

            // @(posedge clk);          // Clock is managed internally by AXI masters
			// #(APPL_DELAY);

            // Gather stimuli
            cfg_data_in =       gold_cfg_data_in[idx_i];
            cfg_addr =          gold_cfg_address[idx_i];
            cfg_wren =          gold_cfg_wren[idx_i];
            cfg_rden =          gold_cfg_rden[idx_i];

            // Manage wait signals
            if (gold_cfg_waitflag[idx_i]==1) begin
                wait_flag_cfg = 1'b1;
            end else begin
                wait_flag_cfg = 1'b0;
            end

            // If we are writing
            if (cfg_wren) begin
                cfg_lite_axi_master.write(cfg_addr, '0, cfg_data_in, '1, rsp_tmp);

            // If we are reading
            end else if (cfg_rden) begin
                cfg_lite_axi_master.read(cfg_addr, '0, data_tmp, rsp_tmp);

            // If we need to do nothing, wait during the current CLK cycle
            end else begin
                @(posedge clk);
            end

            // Upon SAURIA wait flag, wait for done interrupt
            if (wait_flag_cfg) begin

                // If interrupt is already high we don't need to wait
                if (!dma_interrupt) begin
                    @(dma_interrupt);
                end
            end

            idx_i += 1;
        end

		// Read golden positions
		$readmemh("gold_register_map_sauria.txt", gold_sauria_mem, SAURIA_OFFSET);
		$readmemh("gold_register_map_memory.txt", gold_dram_mem);

		n_errs = 0;
		n_checks = 0;

		// Check values for both memories
		for (integer i=0; i<(MEM_BYTES); i++) begin

			n_checks+=2;

			if ((gold_sauria_mem[SAURIA_OFFSET+i]!=i_sim_mem_0.mem[SAURIA_OFFSET+i])
				|| ($isunknown(gold_sauria_mem[SAURIA_OFFSET+i]))
				|| ($isunknown(i_sim_mem_0.mem[SAURIA_OFFSET+i]))) begin

				$displayh("ERROR IN SAURIA[",SAURIA_OFFSET+i,"] : expected ", gold_sauria_mem[SAURIA_OFFSET+i] ," but obtained ", i_sim_mem_0.mem[SAURIA_OFFSET+i]);
				n_errs += 1;
			end

			if ((gold_dram_mem[i]!=i_sim_mem_1.mem[i])
				|| ($isunknown(gold_dram_mem[i]))
				|| ($isunknown(i_sim_mem_1.mem[i]))) begin

				$displayh("ERROR IN DRAM[",i,"] : expected ", gold_dram_mem[i] ," but obtained ", i_sim_mem_1.mem[i]);
				n_errs += 1;
			end
		end

		if (n_errs==0) begin
			$displayh("Test passed with no errors out of ", n_checks ," checks. :)");
			$finish;
		end else begin
			$displayh("Test FAILED with ", n_errs ," errors out of ", n_checks ," checks.");
			$finish;
		end

    end

endmodule
