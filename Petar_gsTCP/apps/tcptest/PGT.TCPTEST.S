*=================================================
* PGTTCPTest - DHCP-backed native TCP active-open diagnostic
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

                lst   off
                rel
                typ   S16
                dsk   ../../../build-local/PGTTCPTEST
                mx    %00

                use   4/Util.Macs
                use   4/Locator.Macs
                use   4/Mem.Macs
                use   4/Text.Macs

DNS_PHASE       equ   0
TCP_PHASE       equ   1

PGTTCPEntry     brl   Start

                put   ../../include/PGT.EQU.S
                put   ../../include/PGT.WIRE.EQU.S
                put   ../../include/PGT.STREAM.EQU.S
                put   ../../include/PGT.TCP.EQU.S
                put   ../../link/uthernet2/U2.EQU.S
                put   ../../core/PGT.CHECKSUM.S
                put   ../../link/uthernet2/U2.BUS.S
                put   ../../link/uthernet2/U2.MACRAW.S
                put   ../../core/PGT.TCP.STATE.S
                put   ../dhcptest/PGT.DHCPTEST.CODE.S
                put   PGT.TCPTEST.CODE.S
