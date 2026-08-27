*=================================================
* Tool $36 ipid to native connection mapping
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

* Input A = Marinetti-compatible one-based TCP ipid.
* Success: PGTtcpConn points at the 64-byte native record, carry clear.
* Failure: carry set.  The adapter converts this to the public invalid-ipid
* error; the protocol core never sees unchecked compatibility handles.

PGT36ResolveIPID ent
                rep   #$30
                dec
                cmp   #PGTMaxConnections
                bcs   PGT36BadIPID
                asl
                asl
                asl
                asl
                asl
                asl
                clc
                adc   PGT36ConnTable
                sta   PGTtcpConn
                lda   PGT36ConnTable+2
                adc   #0
                sta   PGTtcpConn+2
                clc
                rtl
PGT36BadIPID   sec
                rtl
