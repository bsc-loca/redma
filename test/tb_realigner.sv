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

module tb_realigner ();

    localparam time CLK_PERIOD          = 1000ps;
	localparam time APPL_DELAY          = 300ps;
    localparam time ACQ_DELAY           = 600ps;
    localparam time TEST_DELAY          = 900ps;
    localparam unsigned RST_CLK_CYCLES  = 10;

    localparam ADDR_WIDTH = 32;      // AXI Address width
    localparam DATA_WIDTH = 128;     // AXI Data width
    localparam BTT_WIDTH = 20;       // Width of the BTT signal
    localparam ELM_BITS = 16;        // Number of bits of the data elements (realign granularity)

    reg clk;
    reg rstn;

    logic                         i_start;
    logic     [ADDR_WIDTH-1:0]    i_read_start_addr;
    logic     [ADDR_WIDTH-1:0]    i_write_start_addr;
    logic     [BTT_WIDTH-1:0]     i_btt;
    logic                         i_disable_realign;

    FIFO_READ #(.DATA_WIDTH(DATA_WIDTH)) reader_fifo_read();
    FIFO_WRITE #(.DATA_WIDTH(DATA_WIDTH)) reader_fifo_write();
    FIFO_READ #(.DATA_WIDTH(DATA_WIDTH)) writer_fifo_read();
    FIFO_WRITE #(.DATA_WIDTH(DATA_WIDTH)) writer_fifo_write();

    realigner #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BTT_WIDTH(BTT_WIDTH),
        .ELM_BITS(ELM_BITS)
    ) dut_i (
        .i_clk(clk),
        .i_rstn(rstn),
        .i_start(i_start),
        .i_read_start_addr(i_read_start_addr),
        .i_write_start_addr(i_write_start_addr),
        .i_btt(i_btt),
        .i_disable_realign(i_disable_realign),
        .reader_fifo(reader_fifo_read),
        .writer_fifo(writer_fifo_write)
    );

    // Read FIFO
    data_fifo #(
        .WIDTH(128),
        .LEN(2)
    ) data_fifo_reader_I (
        .clk(clk),
        .rstn(rstn),
        .read_port(reader_fifo_read),
        .write_port(reader_fifo_write)
    );

    // Write FIFO
    data_fifo #(
        .WIDTH(128),
        .LEN(2)
    ) data_fifo_writer_I (
        .clk(clk),
        .rstn(rstn),
        .read_port(writer_fifo_read),
        .write_port(writer_fifo_write)
    );

    // Reset
	initial begin: reset_block
		rstn = 0;
		#(CLK_PERIOD*RST_CLK_CYCLES);
		rstn = 1;
	end
	
    // System clock
	initial begin: clock_block
		forever begin
			clk = 0;
			#(CLK_PERIOD/2);
			clk = 1;
			#(CLK_PERIOD/2);
		end
	end

    logic starve_fifo;

    // Process that fills the read FIFO with random stuff & reads the write FIFO
	initial begin: FIFOs_block
		forever begin

            @(posedge clk);
            #APPL_DELAY;

            reader_fifo_write.write = (!reader_fifo_write.full) && (!starve_fifo);
            reader_fifo_write.data = {$urandom(),$urandom(),$urandom(),$urandom()};

            writer_fifo_read.read = (!writer_fifo_read.empty);

		end
	end

    // Tests
    initial begin

        starve_fifo = 0;
        i_disable_realign = 0;
        i_btt = 0;
        i_read_start_addr = 0;
        i_write_start_addr = 0;
        i_start = 0;

        // Wait until RST is high
        wait (rstn);

        // Both sides aligned
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 200;
        i_read_start_addr = 32'h00;
        i_write_start_addr = 32'h00;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Reader misaligned
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 200;
        i_read_start_addr = 32'h04;
        i_write_start_addr = 32'h00;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Writer misaligned
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 200;
        i_read_start_addr = 32'h00;
        i_write_start_addr = 32'h0C;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Both sides misaligned
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 200;
        i_read_start_addr = 32'h0C;
        i_write_start_addr = 32'h02;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Very small, misaligned transfer
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 5;
        i_read_start_addr = 32'h0C;
        i_write_start_addr = 32'h02;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Very small, misaligned transfer
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 4;
        i_read_start_addr = 32'h02;
        i_write_start_addr = 32'h0C;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;
        #(CLK_PERIOD*500);

        // Very big, misaligned transfer
        @(posedge clk);
        #(APPL_DELAY);
        i_disable_realign = 0;
        i_btt = 12288;
        i_read_start_addr = 32'h04;
        i_write_start_addr = 32'h00;
        i_start = 1;
        @(posedge clk);
        #(APPL_DELAY);
        i_start = 0;

        // Wait for some CLK cycles and starve read FIFO (simulate ending a burst, pause in pipeline)
        #(CLK_PERIOD*54);
        starve_fifo = 1;
        #(CLK_PERIOD*10);
        starve_fifo = 0;
        #(CLK_PERIOD*200);
        starve_fifo = 1;
        #(CLK_PERIOD*10);
        starve_fifo = 0;
        #(CLK_PERIOD*100);
        starve_fifo = 1;
        #(CLK_PERIOD*10);
        starve_fifo = 0;
        #(CLK_PERIOD*500);

        $stop();
    end

endmodule
