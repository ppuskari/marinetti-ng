*=================================================
* PGTStreamTest - 22.05 kHz receive-ring hardware diagnostic
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

                lst   off
                rel
                typ   S16
                dsk   ../../../build-local/PGTSTREAMTEST
                mx    %00

PGTDocMode      equ   0

                use   4/Util.Macs
                use   4/Locator.Macs
                use   4/Mem.Macs
                use   4/Text.Macs

PGTStreamEntry  brl   Start

                put   ../../include/PGT.EQU.S
                put   ../../include/PGT.WIRE.EQU.S
                put   ../../include/PGT.STREAM.EQU.S
                put   ../../link/uthernet2/U2.EQU.S
                put   ../../core/PGT.CHECKSUM.S
                put   ../../link/uthernet2/U2.BUS.S
                put   ../../link/uthernet2/U2.MACRAW.S
                put   ../../core/PGT.RING.S
                put   PGT.STREAMTEST.CODE.S
