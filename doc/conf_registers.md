Configuration address space
===========================

Control (0x0) Write-only
------------------------

|Bit |Name            |Description                                                                                     |
|----|----------------|------------------------------------------------------------------------------------------------|
|0   |Reader start    |Write `1` to start the reader engine (This bit automatically resets itself to `0`)              |
|1   |Writer start    |Write `1` to start the writer engine (This bit automatically resets itself to `0`)              |
|2-7 |-               |Unused                                                                                          |
|8   |Write zero mode |Write `1` to activate the `write zero` mode. If activated, reader start bit must be set to `0`. |
|9-31|-               |Unused                                                                                          |

Interrupt enable (0x4) Read/Write
---------------------------------

|Bit |Name                    |Description                                                               |
|----|------------------------|--------------------------------------------------------------------------|
|0   |Reader interrupt enable |Write `1` to enable the reader engine interrupt. Write `0` to disable it. |
|1   |Writer interrupt enable |Write `1` to enable the writer engine interrupt. Write `0` to disable it. |
|2-31|-                       |Unused                                                                    |

Interrupt status (0xC) Read/Write
---------------------------------

|Bit |Name                    |Description                                                                                                |
|----|------------------------|-----------------------------------------------------------------------------------------------------------|
|0   |Reader interrupt status |Reads `1` if the reader engine has finished (even if it is disabled). Write `1` to clear reader interrupt. |
|1   |Writer interrupt status |Reads `1` if the writer engine has finished (even if it is disabled). Write `1` to clear writer interrupt. |
|2-31|-                       |Unused                                                                                                     |

Read start address (0x10-0x1C) Read/Write (depending on configured internal address width)
------------------------------------------------------------------------------------------

|Bit |Name               |Description                                                                                                          |
|----|-------------------|---------------------------------------------------------------------------------------------------------------------|
|0-31|Read start address |Initial address of the reader engine. The availability of the register depends on the width of the internal address. |

Write start address (0x20-0x2C) Read/Write (depending on configured internal address width)
-------------------------------------------------------------------------------------------

|Bit |Name                |Description                                                                                                          |
|----|--------------------|---------------------------------------------------------------------------------------------------------------------|
|0-31|Write start address |Initial address of the writer engine. The availability of the register depends on the width of the internal address. |

Bytes to transfer (BTT) (0x30-0x3C) Read/Write (depending on configured BTT width)
----------------------------------------------------------------------------------

|Bit |Name              |Description                                                                                                                |
|----|------------------|---------------------------------------------------------------------------------------------------------------------------|
|0-31|Bytes to transfer |Number of bytes to transfer, starting at 1. The availability of the register depends on the width of the internal address. |

