*=================================================
* Petar_gsTCP lean TCP state-transition primitives
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

* Begin an active open after the caller has populated address/port/ring
* fields.  SND.UNA=ISS, SND.NXT=ISS+1 because SYN consumes one sequence byte.

PGTTCPBeginActive ent
                rep   #$30
                ldy   #PGTCSendUnacked
                lda   PGTtcpISS
                sta   [PGTtcpConn],y
                iny
                iny
                lda   PGTtcpISS+2
                sta   [PGTtcpConn],y
                ldy   #PGTCSendNext
                lda   PGTtcpISS
                clc
                adc   #1
                sta   [PGTtcpConn],y
                iny
                iny
                lda   PGTtcpISS+2
                adc   #0
                sta   [PGTtcpConn],y
                ldy   #PGTCRecvNext
                lda   #0
                sta   [PGTtcpConn],y
                iny
                iny
                sta   [PGTtcpConn],y
                ldy   #PGTCAckPending
                sta   [PGTtcpConn],y
                ldy   #PGTCSendWindow
                sta   [PGTtcpConn],y
                ldy   #PGTCFlags
                lda   #PGTCFActive
                sta   [PGTtcpConn],y
                ldy   #PGTCState
                lda   #PGTTSynSent
                sta   [PGTtcpConn],y
                clc
                rtl

* Accept exactly SYN+ACK for our outstanding active-open SYN.  RST is always
* rejected here.  Options (including MSS) are parsed by the bounded header
* parser before this transition routine is entered.

PGTTCPAcceptSYNACK ent
                rep   #$30
                ldy   #PGTCState
                lda   [PGTtcpConn],y
                cmp   #PGTTSynSent
                bne   PGTSYNACKReject
                lda   PGTtcpFlags
                bit   #PGTTCPF_RST
                bne   PGTSYNACKReject
                and   #PGTTCPF_SYN+PGTTCPF_ACK
                cmp   #PGTTCPF_SYN+PGTTCPF_ACK
                bne   PGTSYNACKReject

                ldy   #PGTCSendNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck
                bne   PGTSYNACKReject
                iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck+2
                bne   PGTSYNACKReject

                ldy   #PGTCSendUnacked
                lda   PGTtcpAck
                sta   [PGTtcpConn],y
                iny
                iny
                lda   PGTtcpAck+2
                sta   [PGTtcpConn],y
                ldy   #PGTCRecvNext
                lda   PGTtcpSeq
                clc
                adc   #1
                sta   [PGTtcpConn],y
                iny
                iny
                lda   PGTtcpSeq+2
                adc   #0
                sta   [PGTtcpConn],y
                ldy   #PGTCSendWindow
                lda   PGTtcpWindow
                sta   [PGTtcpConn],y
                ldy   #PGTCAckPending
                lda   #1
                sta   [PGTtcpConn],y
                ldy   #PGTCState
                lda   #PGTTEstablished
                sta   [PGTtcpConn],y
                clc
                rtl
PGTSYNACKReject sec
                rtl

* Commit payload only after the caller has validated IPv4/TCP checksums and
* PGTRingCopyRX has committed the bytes.  Future/out-of-order data is rejected
* without changing RCV.NXT and therefore causes the caller to send a duplicate
* ACK.  Zero-length pure ACKs are legal and leave RCV.NXT unchanged.

PGTTCPCommitInOrder ent
                rep   #$30
                ldy   #PGTCState
                lda   [PGTtcpConn],y
                cmp   #PGTTEstablished
                bne   PGTDataReject
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq
                bne   PGTDataReject
                iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq+2
                bne   PGTDataReject

                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                clc
                adc   PGTtcpLength
                sta   [PGTtcpConn],y
                iny
                iny
                lda   [PGTtcpConn],y
                adc   #0
                sta   [PGTtcpConn],y
                lda   PGTtcpFlags
                bit   #PGTTCPF_FIN
                beq   PGTDataNoFIN
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                clc
                adc   #1
                sta   [PGTtcpConn],y
                iny
                iny
                lda   [PGTtcpConn],y
                adc   #0
                sta   [PGTtcpConn],y
                ldy   #PGTCFlags
                lda   [PGTtcpConn],y
                ora   #PGTCFPeerFIN
                sta   [PGTtcpConn],y
                ldy   #PGTCState
                lda   #PGTTCloseWait
                sta   [PGTtcpConn],y
PGTDataNoFIN   ldy   #PGTCAckPending
                lda   #1
                sta   [PGTtcpConn],y
                clc
                rtl
PGTDataReject  sec
                rtl
