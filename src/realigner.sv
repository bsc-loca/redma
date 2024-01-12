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
// MODULE DECLARATION
// --------------------

module realigner #(
    parameter ADDR_WIDTH = 0, // AXI Address width
    parameter DATA_WIDTH = 0, // AXI Data width
    parameter BTT_WIDTH = 0,  // Width of the BTT signal
    parameter ELM_BITS = 0    // Number of bits of the data elements (realign granularity)
)(
    input  logic                         i_clk,
    input  logic                         i_rstn,
    input  logic                         i_reader_start,
    input  logic                         i_writer_start,
    input  logic     [ADDR_WIDTH-1:0]    i_read_start_addr,
    input  logic     [ADDR_WIDTH-1:0]    i_write_start_addr,
    input  logic     [BTT_WIDTH-1:0]     i_btt,
    input  logic                         i_disable_realign,
    output logic                         o_set_intr,
    FIFO_READ.master                    reader_fifo,
    FIFO_WRITE.master                   writer_fifo
);

// ----------
// PARAMS
// ----------

localparam N_ELEMENTS = DATA_WIDTH/ELM_BITS;
localparam N_BUFS_TOTAL = 2*N_ELEMENTS;

localparam WOFFS_BITS = $clog2(N_ELEMENTS);
localparam BYTE = 8;
localparam AXI_BYTE_NUM = DATA_WIDTH/BYTE;
localparam BYTE_CNT_BITS = $clog2(256*AXI_BYTE_NUM);

localparam ELM_BYTES = ELM_BITS/BYTE;
localparam ELM_B_BITS = $clog2(ELM_BYTES);
localparam N_CNT_BITS = $clog2(2*N_ELEMENTS+1);

// ----------
// SIGNALS
// ----------

// Parameters double buffering
logic [ADDR_WIDTH-1:0]  read_start_addr_q, read_start_addr_d;
logic [ADDR_WIDTH-1:0]  write_start_addr_q, write_start_addr_d;
logic [DATA_WIDTH-1:0]  btt_q, btt_d;
logic                   disable_realign_d, disable_realign_q;

// {Source, destination} {initial, final} word offset in number of elements
logic [WOFFS_BITS-1:0]              src_woffs_init, src_woffs_end;
logic [WOFFS_BITS-1:0]              dst_woffs_init, dst_woffs_end;

// Intermediate signals
logic [BYTE_CNT_BITS-1:0]           src_addr_end, dst_addr_end;

// Interconnection control signals
logic [N_CNT_BITS-1:0]                      elm_number;
logic [N_CNT_BITS-1:0]                      regs_used_idx;
logic [N_CNT_BITS:0]                        new_active_idx;
logic [0:N_BUFS_TOTAL-1]                    regs_active_new;

// Wrapper signals (encapsulate ping & pong)
logic [0:N_BUFS_TOTAL-1]                regs_active_d, regs_active_q;
logic [0:N_BUFS_TOTAL-1]                regs_en_d;
logic [0:N_BUFS_TOTAL-1][ELM_BITS-1:0]  regs_d;

// Shifter signals
logic [N_CNT_BITS-1:0]                      start_idx;
logic [N_CNT_BITS-1:0]                      wdata_shamt;
logic [3*DATA_WIDTH-1:0]                wdata_padded, wdata_shifted;

// Ping-Pong registers
logic [0:N_ELEMENTS-1]                 ping_active_d, pong_active_d, ping_active_q, pong_active_q;
logic [0:N_ELEMENTS-1]                 ping_en_d, pong_en_d;
logic [0:N_ELEMENTS-1][ELM_BITS-1:0]   ping_d, pong_d, ping_q, pong_q;

// Control signals
logic signed [BTT_WIDTH:0]   byte_cnt_d, byte_cnt_q;
logic done;
logic active_transfer_d, active_transfer_q;
logic first_word_q, first_word_d;
logic last_word_q, last_word_d, last_word_shim_q;
logic push, regs_push, buffer_select_d, buffer_select_q;
logic pop, pop_shim_q;
logic start;
logic reader_started_d, reader_started_q;
logic writer_started_d, writer_started_q;

// Output reshape and muxing
logic [DATA_WIDTH-1:0] ping_obus, pong_obus;

// Watchdg signals
logic [15:0]        wdog_cnt_d, wdog_cnt_q;
logic               wdog_force_finish;

assign o_set_intr = done;
assign start = reader_started_q & writer_started_q;

// ------------------------------------------------------------
// Parameters latching
// ------------------------------------------------------------

// Only accept new parameter values with start high
always_comb begin

    read_start_addr_d = read_start_addr_q;
    write_start_addr_d = write_start_addr_q;
    btt_d = btt_q;
    disable_realign_d = disable_realign_q;
    reader_started_d = reader_started_q;
    writer_started_d = writer_started_q;

    if (i_reader_start) begin
        read_start_addr_d = i_read_start_addr;
        btt_d = i_btt;
        disable_realign_d = i_disable_realign;
        reader_started_d = 1'b1;
    end
    if (i_writer_start) begin
        write_start_addr_d = i_write_start_addr;
        writer_started_d = 1'b1;
    end
    if (reader_started_q & writer_started_q) begin
        reader_started_d = 1'b0;
        writer_started_d = 1'b0;
    end
end

// Register
always_ff @(posedge i_clk or negedge i_rstn) begin : params_reg
    if(~i_rstn) begin
        btt_q <= '0;
        disable_realign_q <= '0;
        read_start_addr_q <= '0;
        write_start_addr_q <= '0;
        reader_started_q <= '0;
        writer_started_q <= '0;
    end else begin
        btt_q <= btt_d;
        disable_realign_q <= disable_realign_d;
        read_start_addr_q <= read_start_addr_d;
        write_start_addr_q <= write_start_addr_d;
        reader_started_q <= reader_started_d;
        writer_started_q <= writer_started_d;
    end
end

// ----------------
// IO Management
// ----------------

always_comb begin

    // Initialize values to bypass everything
    reader_fifo.read =   !reader_fifo.empty && !writer_fifo.full;
    writer_fifo.write =  !reader_fifo.empty && !writer_fifo.full;
    writer_fifo.data =   reader_fifo.data;

    // If Realignment is enabled...
    if (!disable_realign_q) begin

        reader_fifo.read =      pop;
        writer_fifo.write =     push;

        // Output data: select current register
        if (buffer_select_q) begin
            writer_fifo.data = pong_obus;
        end else begin
            writer_fifo.data = ping_obus;
        end
    end
end

// FIFO pop signal
assign pop = active_transfer_q && (!reader_fifo.empty) && (!writer_fifo.full) && (!last_word_q);

// -------------------------------
// First/last flags generation
// -------------------------------

// Logic
always_comb begin

    first_word_d = first_word_q;
    last_word_d = last_word_q;
    byte_cnt_d = byte_cnt_q;

    // First flag asserted with start flag
    if (reader_started_q & writer_started_q) begin
        first_word_d = 1;
    end
    // And deasserted after first word has been read
    if (pop_shim_q) begin
        first_word_d = 0;
    end

    // Start flag initializes byte counter to BTT
    if (i_reader_start) begin
        byte_cnt_d = i_btt;

    // Every time we pop, we decrement the counter
    end else if (pop) begin

        // On the first word we take less values
        if (first_word_d) begin
            byte_cnt_d = byte_cnt_q - (AXI_BYTE_NUM) + (src_woffs_init<<ELM_B_BITS);

        // Normally we take all bytes
        end else begin
            byte_cnt_d = byte_cnt_q - (AXI_BYTE_NUM);
        end
    end

    // Last flag asserted when byte counter is smaller than 1
    if (active_transfer_q && (byte_cnt_d<1)) begin
        last_word_d = 1;
    end
    // And deasserted when we get the 'done' flag
    if (done) begin
        last_word_d = 0;
    end

end

// Registers
always_ff @(posedge i_clk or negedge i_rstn) begin : flags_reg
    if(~i_rstn) begin
        first_word_q <= '0;
        last_word_q <= '0;
        byte_cnt_q <= '0;
        pop_shim_q <= '0;
    end else begin
        first_word_q <= first_word_d;
        last_word_q <= last_word_d;
        byte_cnt_q <= byte_cnt_d;

        // Shimming for pop signal must be gated with FIFO full
        if (!writer_fifo.full) begin
            pop_shim_q <= pop;
        end
    end
end

// -------------------------------
// Active transfer monitoring
// -------------------------------

// Logic
always_comb begin

    active_transfer_d = active_transfer_q;

    // Active transfer asserted with start
    if (start) begin
        active_transfer_d = 1;
    end
    // And deasserted with done
    if (done) begin
        active_transfer_d = 0;
    end
end

// Register
always_ff @(posedge i_clk or negedge i_rstn) begin : active_transfer_reg
    if(~i_rstn) begin
        active_transfer_q <= '0;
    end else begin
        active_transfer_q <= active_transfer_d;
    end
end

// ---------------------------------------------------------------------
// Extraction of Woffs, initial and final + AWLEN and ADDR correction
// ---------------------------------------------------------------------

always_comb begin

    // Values default to all bits being taken
    dst_woffs_init = '0;
    // dst_woffs_end = '1;
    // dst_addr_end = '0;
    src_woffs_init = '0;
    src_woffs_end = '1;
    src_addr_end = '0;

    // If realignment is not disabled
    if (!disable_realign_q) begin

        // Initial word offsets
        dst_woffs_init = write_start_addr_q[WOFFS_BITS+ELM_B_BITS-1:ELM_B_BITS];
        src_woffs_init = read_start_addr_q[WOFFS_BITS+ELM_B_BITS-1:ELM_B_BITS];

        // Address end signals: sum of addr_init and BTT
        // dst_addr_end = write_start_addr_q + (btt_q-1);
        src_addr_end = read_start_addr_q + (btt_q-1);

        // Word offset end signals
        // dst_woffs_end = dst_addr_end[WOFFS_BITS+ELM_B_BITS-1:ELM_B_BITS];
        src_woffs_end = src_addr_end[WOFFS_BITS+ELM_B_BITS-1:ELM_B_BITS];

    end
end

// ----------------------------------------------------------------
// Number of elements to take
// ----------------------------------------------------------------

always_comb begin

    // Default to taking all elements
    elm_number = N_ELEMENTS;

    // If realignment is not disabled
    if (!disable_realign_q) begin

        // Current word is the last
        if (last_word_q) begin

            // First & Last => Take into account both offsets
            if (first_word_q) begin
                elm_number = src_woffs_end+1 - src_woffs_init;

            // Only Last => Active elements end at src_woffs_end (inclusive)
            end else begin
                elm_number = src_woffs_end+1;
            end

        // Only First => Active elements start after src_woffs_init
        end else if (first_word_q) begin
            elm_number = N_ELEMENTS - src_woffs_init;
        end
    end
end

// ----------------------------------------------------------------
// Realignment Shifter
// ----------------------------------------------------------------

always_comb begin

    // Initialize values
    start_idx = '0;
    wdata_padded = '0;
    wdata_shamt = '0;
    wdata_shifted = '0;

    // If realignment is not disabled
    if (!disable_realign_q) begin

        // Assign elements to big padded vector
        wdata_padded[DATA_WIDTH-1:0] = reader_fifo.data;

        // First word
        if (first_word_q) begin
            start_idx = src_woffs_init;
        end

        // Prepare shift amount
        wdata_shamt = N_ELEMENTS + regs_used_idx - start_idx;

        // Perform shift
        wdata_shifted = wdata_padded << (wdata_shamt*ELM_BITS);
    end

    // Get values of interest into regs_d
    for (integer i=0; i<N_BUFS_TOTAL; i++) begin
        regs_d[i] = wdata_shifted[(N_ELEMENTS+i)*ELM_BITS+:ELM_BITS];
    end
end

// ----------------------------------------------------------------
// Ping-Pong feedback signals muxing
// ----------------------------------------------------------------

assign regs_active_q =  (buffer_select_d)? {pong_active_q, ping_active_q} : {ping_active_q, pong_active_q};

// ----------------------------------------------------------------
// Generation of Interconnect Control signals
// ----------------------------------------------------------------

always_comb begin

    // Registers Used Index -> Look for 1 crossing in regs_active_q
    regs_used_idx = 0;

    for (integer i=1; i<N_BUFS_TOTAL; i++) begin
        // When current location is 0 and previous location was 1, we take index
        if ((!regs_active_q[i]) && regs_active_q[i-1]) begin
            regs_used_idx = i;
        end
    end

    // New Active Index -> Last index of values to be written
    new_active_idx = regs_used_idx + elm_number;

    // Regs Active New -> Marks positions to be written to
    regs_active_new = 0;

    for (integer b=0; b<N_BUFS_TOTAL; b++) begin
        // Set bits to 1 between Registers Used Index and New Active Index
        if ((b>=regs_used_idx) && (b<new_active_idx)) begin
            regs_active_new[b] = 1'b1;
        end
    end
end

// ----------------------------------------------------------------
// Register and status maintainance
// ----------------------------------------------------------------

always_comb begin

    // Default: registers not reading, activity maintained
    regs_en_d = 0;
    regs_active_d = regs_active_q;

    // If idle, free all registers
    if (!active_transfer_q) begin
        regs_active_d = '0;

    // On first word
    end else if (first_word_q) begin

        // Clear registers by default
        regs_active_d = '0;

        // Mark first dst_woffs_init positions as active to not write them
        for (integer i=0; i<N_ELEMENTS; i++) begin
            if (i<dst_woffs_init) begin
                regs_active_d[i] = 1'b1;
            end
        end
    end

    // Push forces all positions to zero on (previous) selected buff
    if (push) begin
        regs_active_d[N_ELEMENTS:N_BUFS_TOTAL-1] = 0;
    end

    // Normal operation => Enabled by popping data, delayed 1 shimming cycle; Disabled by FIFO Full
    if (pop_shim_q && (!writer_fifo.full)) begin

        // Registers Enable values have been computed already as regs_active_new
        regs_en_d = regs_active_new;

        // New Active Registers achieved by simpli ORing the old and the new
        regs_active_d = regs_active_d | regs_active_new;

    end
end

// ----------------------------------------------------------------
// Final Muxing (between Ping and Pong regions)
// ----------------------------------------------------------------

assign ping_d = (buffer_select_d)? regs_d[N_ELEMENTS:N_BUFS_TOTAL-1] : regs_d[0:N_ELEMENTS-1];
assign pong_d = (buffer_select_d)? regs_d[0:N_ELEMENTS-1] : regs_d[N_ELEMENTS:N_BUFS_TOTAL-1];

assign ping_en_d = (buffer_select_d)? regs_en_d[N_ELEMENTS:N_BUFS_TOTAL-1] : regs_en_d[0:N_ELEMENTS-1];
assign pong_en_d = (buffer_select_d)? regs_en_d[0:N_ELEMENTS-1] : regs_en_d[N_ELEMENTS:N_BUFS_TOTAL-1];

assign ping_active_d = (buffer_select_d)? regs_active_d[N_ELEMENTS:N_BUFS_TOTAL-1] : regs_active_d[0:N_ELEMENTS-1];
assign pong_active_d = (buffer_select_d)? regs_active_d[0:N_ELEMENTS-1] : regs_active_d[N_ELEMENTS:N_BUFS_TOTAL-1];

// ----------------------------------------------------------------
// Ping and Pong Registers
// ----------------------------------------------------------------

genvar jj;
generate
    // Generate one instance per position
    for (jj=0; jj < N_ELEMENTS; jj++) begin
        // Normal FF behavior
        always_ff @(posedge i_clk or negedge i_rstn) begin : pingpong_reg
            if(~i_rstn) begin
                ping_q[jj] <= 0;
                ping_active_q[jj] <= 0;
                pong_q[jj] <= 0;
                pong_active_q[jj] <= 0;
            end else begin

                ping_active_q[jj] <= ping_active_d[jj];
                pong_active_q[jj] <= pong_active_d[jj];

                // Ping registers update
                if (ping_en_d[jj]) begin
                    ping_q[jj] <= ping_d[jj];
                end

                // Pong registers update
                if (pong_en_d[jj]) begin
                    pong_q[jj] <= pong_d[jj];
                end
            end
        end
    end
endgenerate

// -----------------------------
// Last word shimming register
// -----------------------------


always_ff @(posedge i_clk or negedge i_rstn) begin : last_shm_reg
    if(~i_rstn) begin
        last_word_shim_q <= '0;
    end else begin

        // Update exactly like data registers
        if (pop_shim_q && (!writer_fifo.full)) begin
            last_word_shim_q <= last_word_q;
        end

        // Reset when idle
        if (!active_transfer_q) begin
            last_word_shim_q <= '0;
        end
    end
end

// --------------------
// Push & wlast logic
// --------------------

always_comb begin

    regs_push = 0;
    done = 0;

    // Only push values if dst FIFO is not full
    if (!writer_fifo.full) begin

        // Ping selected & all ping positions full
        if ((!buffer_select_q)&&(ping_active_q == '1)) begin
            regs_push = 1;
        end

        // Pong selected & all pong positions full
        if ((buffer_select_q)&&(pong_active_q == '1)) begin
            regs_push = 1;
        end

        // If current cycle has last data
        if (last_word_shim_q) begin

            // If we are doing a natural push...
            if (regs_push) begin

                // Ping selected
                if (!buffer_select_q) begin

                    // If all pong locations are empty, this is the real wlast and we are done...
                    // otherwise, we need to wait for another push
                    if (pong_active_q == '0) begin
                        done = 1;
                    end

                // Pong selected
                end else begin

                    // Same as above, for ping
                    if (ping_active_q == '0) begin
                        done = 1;
                    end
                end

            // If we did not order a natural push and this is the last data, set burst_done will force the push
            end else begin
                done = 1;
            end
        end

        // If flag from watchdog is up
        else if (wdog_force_finish) begin
            done = 1;
        end
    end
end

// Push when registers require it or at the very end
assign push = (regs_push | done) & active_transfer_q;

// ------------------------
// Buffer select register
// ------------------------

// Transition after push
assign buffer_select_d = (push) ? (!buffer_select_q) : buffer_select_q;

always_ff @(posedge i_clk or negedge i_rstn) begin : buffsel_reg
    if(~i_rstn) begin
        buffer_select_q <= 0;
    end else begin
        buffer_select_q <= buffer_select_d;
    end
end

// -------------------------------
// Watch-dog to avoid deadlocks
// -------------------------------

// Logic
always_comb begin

    wdog_force_finish = 1'b0;
    wdog_cnt_d = wdog_cnt_q;

    // If reader FIFO is not empty or transfer is not active, reset watch-dog
    if ((!active_transfer_q) || (!reader_fifo.empty)) begin
        wdog_cnt_d = '1;

    // Otherwise, count down, if we reach zero we wake the DMA from a deadlock
    end else begin
        if (wdog_cnt_q > 0) begin
            wdog_cnt_d = wdog_cnt_q - 1;
        end else begin
            wdog_cnt_d = '1;
            wdog_force_finish = 1'b1;
        end
    end
end

// Register
always_ff @(posedge i_clk or negedge i_rstn) begin : wdog_reg
    if(~i_rstn) begin
        wdog_cnt_q <= '1;
    end else begin
        wdog_cnt_q <= wdog_cnt_d;
    end
end

// ------------------------------------------------------------
// Output buses
// ------------------------------------------------------------

genvar ii;
generate
    for (ii=0; ii < N_ELEMENTS; ii++) begin
        // Output values
        assign ping_obus[ii*ELM_BITS+:ELM_BITS] = ping_q[ii];
        assign pong_obus[ii*ELM_BITS+:ELM_BITS] = pong_q[ii];
    end
endgenerate

endmodule
