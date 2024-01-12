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

module r_engine(
    output transaction_complete,
    AXI4_R.master r_chan,
    FIFO_WRITE.master data_fifo
);

    assign transaction_complete = r_chan.rvalid && !data_fifo.full && r_chan.rlast;
    assign r_chan.rready = !data_fifo.full;
    assign data_fifo.write = r_chan.rvalid && !data_fifo.full;
    assign data_fifo.data = r_chan.rdata;

endmodule
