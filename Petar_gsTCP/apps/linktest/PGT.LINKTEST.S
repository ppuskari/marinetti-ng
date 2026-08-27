*=================================================
*
* PGTLinkTest - safe Uthernet II receive diagnostic
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*
*=================================================

                lst   off
                rel
                typ   S16
                dsk   ../../../build-local/PGTLINKTEST
                mx    %00

                use   4/Util.Macs
                use   4/Locator.Macs
                use   4/Mem.Macs
                use   4/Text.Macs

* The S16 loader enters at the first byte of the segment.  Keep this branch
* ahead of shared routines so startup always reaches the application entry.

PGTLinkEntry    brl   Start

                put   ../../include/PGT.EQU.S
                put   ../../include/PGT.WIRE.EQU.S
                put   ../../link/uthernet2/U2.EQU.S
                put   ../../core/PGT.CHECKSUM.S
                put   ../../link/uthernet2/U2.BUS.S
                put   ../../link/uthernet2/U2.MACRAW.S
                put   PGT.LINKTEST.CODE.S
