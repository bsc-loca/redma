# Realigned DMA (redma)

This repository contains the implementation of a Direct Memory Access (DMA) engine.
It was developed due to the lack of an open source DMA engine that supports moving data between regions that are not aligned with the data bus width. ReDMA supports reading and writing to any address with any alingment, even with different alignments between the read and write addresses.
A DMA operation is descibed with three registers: the reader start address, writer start address and the bytes to transfer (btt).
The memory and configuration interfaces are AXI4 and AXI4-Lite respectively.

ReDMA implements the following features:

- Configurable AXI and AXI-Lite address width.
- Configurable AXI data and ID width.
- Configurable max AXI ARLEN and AWLEN
- Configurable width of the internal addresses and btt registers (between 12 and 128 bits).
    - The internal address width determines the bits that are updated between AXI transactions. Therefore, DMA operations must not cross any address boundary of regions multiple of 2^internal_address_width.
    - If the AXI address width is greater than the internal address width, a fixed offset can be specified for the read and address channels.
    - The btt width determines the maximum number of bytes that can be moved in a single DMA operation.
- Configurable internal FIFO lengths.
- Configurable max outstanding reads and writes, zero implies unlimited.
- Configurable realignment granularity. Increasing the granularity reduces area usage and removes critical paths, but limits the alignment of the addresses. For example, setting a granularity of 16 bits constraints the reader and writer initial addresses to be multiple of 2 bytes.
- AW and W channel synchronization. By default, the AW channel starts sending AXI write commands as soon as the DMA operation starts. However, the W channnel depends on the R channel. In systems with high read latency, the write channel can become empty for a large number of cycles, leaving the bus unused because it is already reserved by the AW commands, and preventing other components of using it. With this option, the AW channel waits for the W channel to have data available before sending the command.
- Write zero. This feature allows the DMA to initialize any memory region with 0. While using this mode, the read AXI channels remain unused, and thus the initial read address register is not used.

## Licensing

ReDMA is released under the [Solderpad v2.1 license](https://solderpad.org/licenses/SHL-2.1/).