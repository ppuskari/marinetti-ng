*=================================================
*
* PGTTCPRXTEST RX1-A established receive engine
*
* One 512-byte in-order payload.
* Payload travels directly W5100 -> final ring.
* Ring head is published only after TCP checksum.
*
*=================================================

InitializeTCPRXRing
                rep   #$30
                lda   #RXRing
                sta   PGTringBase
                lda   #^RXRing
                sta   PGTringBase+2
                lda   #$3FFF
                sta   PGTringMask
                stz   PGTringHead
                stz   PGTringTail
                stz   PGTringNeed
                stz   PGTringFirst
                stz   PGTringSaved
                stz   RXPayloadAccepted
                stz   RXChecksumFails
                stz   RXSeqRejects
                stz   RXRingFull
                stz   RXAcceptedSegments
                stz   RXAckCount
                stz   RXRingHighWater
                stz   RXPeerFINSeen
                stz   RX3BConsumerStarted
                stz   RX3BConsumerTick
                stz   RX3BNowTick
                stz   RX3BConsumePhase
                stz   RX3BConsumeQuota
                stz   RX3BConsumeRemain
                stz   RX3BUnderruns
                stz   RX3BPatternFails
                stz   RX3BWindowACKs
                stz   RX3BRecvLo
                stz   RX3BRecvHi
                stz   RX3BConsLo
                stz   RX3BConsHi
                stz   RX3BUsedMax
                stz   RX3BStreamDeadline
                stz   RX3BDrainCount
                lda   #1
                sta   RX3BExpectedByte
                lda   #$FFFF
                sta   RX3BUsedMin
                rts

*-------------------------------------------------
* Wait for one exact 512-byte accepted segment.
*-------------------------------------------------

WaitTCPRX8MSS
                jsr   StartTCPRXDeadline

PGTRX512Poll
                jsr   CheckEscape
                bcc   PGTRX512CheckCard
                sec
                rts

PGTRX512CheckCard
                jsl   PGTU2BeginRX
                bcc   PGTRX512HaveFrame
                bra   PGTRX512NoFrame

PGTRX512HaveFrame
                inc   RXFrameCount
                jsr   ProcessTCPRXFrame
                bcc   PGTRX512Processed
                sec
                rts

PGTRX512Processed
                lda   RXPayloadAccepted
                beq   PGTRX512NoFrame
                cmp   #1460
                beq   PGTRX512Done
                sec
                rts

PGTRX512NoFrame
                jsr   TCPRXDeadlineExpired
                bcc   PGTRX512Poll
                sec
                rts

PGTRX512Done
                clc
                rts

*-------------------------------------------------
* Wait for checksum-valid peer FIN.
*-------------------------------------------------

*-------------------------------------------------
* RX3-A continuous MSS / window receipt.
* 8 x 1460 = 11680 = $2DA0.
* 16383 usable - 11680 = 4703 = $125F.
*-------------------------------------------------

*-------------------------------------------------
* RX3-A cumulative eight-MSS receive controller.
* Production parser remains one-segment-at-a-time.
*-------------------------------------------------

WaitTCPRX8MSSLoop
                jsr   StartTCPRXDeadline

PGTRX3ALoop
                jsr   CheckEscape
                bcc   PGTRX3ACheckCard
                sec
                rts

PGTRX3ACheckCard
                jsl   PGTU2BeginRX
                bcc   PGTRX3AHaveFrame
                brl   PGTRX3ANoFrame

PGTRX3AHaveFrame
                inc   RXFrameCount
                jsr   ProcessTCPRXFrame
                bcc   PGTRX3AProcessed
                sec
                rts

PGTRX3AProcessed
* Cumulative committed application bytes.
                lda   RXAcceptedSegments
                cmp   #8
                beq   PGTRX3ADone

* Less than target: continue polling.
                bcc   PGTRX3ANoFrame

* More than target is a hard test failure.
                sec
                rts

PGTRX3ANoFrame
                jsr   TCPRXDeadlineExpired
                bcc   PGTRX3AContinue
                sec
                rts

PGTRX3AContinue
                brl   PGTRX3ALoop

PGTRX3ADone
                clc
                rts

VerifyTCPRX3AWindow
                rep   #$30

                lda   RXAcceptedSegments
                cmp   #8
                beq   PGTRX3AV01
                brl   PGTRX3AVBad
PGTRX3AV01

                lda   RXChecksumFails
                beq   PGTRX3ACheckRingFull
                brl   PGTRX3AVBad
PGTRX3ACheckRingFull
                lda   RXRingFull
                beq   PGTRX3AV02
                brl   PGTRX3AVBad
PGTRX3AV02

                lda   RXAcceptedSegments
                clc
                adc   RXSeqRejects
                cmp   RXAckCount
                beq   PGTRX3AV03
                brl   PGTRX3AVBad
PGTRX3AV03

                lda   PGTringHead
                cmp   #$2DA0
                beq   PGTRX3AV04
                brl   PGTRX3AVBad
PGTRX3AV04

                lda   PGTringTail
                beq   PGTRX3AV05
                brl   PGTRX3AVBad
PGTRX3AV05

                jsl   PGTRingUsed
                cmp   #11680
                beq   PGTRX3AV06
                brl   PGTRX3AVBad
PGTRX3AV06

                jsl   PGTRingFree
                cmp   #4703
                beq   PGTRX3AV07
                brl   PGTRX3AVBad
PGTRX3AV07

                ldy   #PGTCRecvWindow
                lda   [PGTtcpConn],y
                cmp   #4703
                beq   PGTRX3AV08
                brl   PGTRX3AVBad
PGTRX3AV08

                lda   RXRingHighWater
                cmp   #11680
                beq   PGTRX3AVGood
                brl   PGTRX3AVBad

PGTRX3AVGood
                clc
                rts

PGTRX3AVBad
                sec
                rts

*=================================================
* RX3-B 22.4 kB/s streaming consumer gate.
*
* Prebuffer: 8192 bytes.
* Consume: 373,373,374 bytes per 60 Hz ticks.
* Average = 22400 bytes/sec exactly.
*=================================================

RunTCPRX3BStream
                rep   #$30
                lda   >$E100DC
                clc
                adc   #1800
                sta   RX3BStreamDeadline

PGTRX3BStreamLoop
* Producer first: move pending wire data into final ring.
                jsr   CheckEscape
                bcc   PGTRX3BCheckCard
                sec
                rts

PGTRX3BCheckCard
                jsl   PGTU2BeginRX
                bcc   PGTRX3BHaveFrame
                bra   PGTRX3BAfterRX

PGTRX3BHaveFrame
                inc   RXFrameCount
                jsr   ProcessTCPRXFrame
                bcc   PGTRX3BFrameDone
                sec
                rts

PGTRX3BFrameDone
                jsr   RecordTCPRX3BOccupancy

PGTRX3BAfterRX
* Then account for real-time DOC consumption.
                jsr   ServiceTCPRX3BConsumer
                bcc   PGTRX3BConsumerOK
                sec
                rts

PGTRX3BConsumerOK
                lda   RXPeerFINSeen
                beq   PGTRX3BCheckDeadline
                brl   PGTRX3BStreamFinished

PGTRX3BCheckDeadline
                lda   >$E100DC
                sec
                sbc   RX3BStreamDeadline
                bmi   PGTRX3BStreamContinue
                sec
                rts

PGTRX3BStreamContinue
                brl   PGTRX3BStreamLoop

PGTRX3BStreamFinished
                lda   RX3BConsumerStarted
                bne   PGTRX3BDrain
                sec
                rts

PGTRX3BDrain
                jsr   DrainTCPRX3BRemaining
                bcc   PGTRX3BStreamDone
                sec
                rts

PGTRX3BStreamDone
                clc
                rts

*-------------------------------------------------
* Start at 8 KiB, then consume 22.4 kB/s.
* Consumer is bulk/tick based, not byte based.
*-------------------------------------------------

ServiceTCPRX3BConsumer
                rep   #$30
                lda   RX3BConsumerStarted
                bne   PGTRX3BConsumerActive

                jsl   PGTRingUsed
                cmp   #8192
                bcs   PGTRX3BStartConsumer
                clc
                rts

PGTRX3BStartConsumer
                lda   #1
                sta   RX3BConsumerStarted
                lda   >$E100DC
                sta   RX3BConsumerTick
                jsr   RecordTCPRX3BOccupancy
                clc
                rts

PGTRX3BConsumerActive
                lda   >$E100DC
                sta   RX3BNowTick
                cmp   RX3BConsumerTick
                bne   PGTRX3BTickLoop
                clc
                rts

PGTRX3BTickLoop
                inc   RX3BConsumerTick

                lda   RX3BConsumePhase
                cmp   #2
                beq   PGTRX3BQuota374

                lda   #373
                sta   RX3BConsumeQuota
                inc   RX3BConsumePhase
                bra   PGTRX3BQuotaReady

PGTRX3BQuota374
                lda   #374
                sta   RX3BConsumeQuota
                stz   RX3BConsumePhase

PGTRX3BQuotaReady
                jsl   PGTRingUsed
                cmp   RX3BConsumeQuota
                bcs   PGTRX3BHaveQuota

                inc   RX3BUnderruns
                sec
                rts

PGTRX3BHaveQuota
* Sample one byte at this tick boundary.
* Full payload integrity remains protected by TCP checksum.
                ldx   PGTringTail
                sep   #$20
                mx    %10
                lda   RXRing,x
                cmp   RX3BExpectedByte
                beq   PGTRX3BSampleOK

                rep   #$20
                mx    %00
                inc   RX3BPatternFails
                sec
                rts

PGTRX3BSampleOK
                mx    %10
                rep   #$20
                mx    %00

* Advance final-ring consumer in one operation.
                lda   PGTringTail
                clc
                adc   RX3BConsumeQuota
                and   #$3FFF
                sta   PGTringTail

* Advance expected 01..FF pattern by quota modulo 255.
                lda   RX3BExpectedByte
                and   #$00FF
                clc
                adc   RX3BConsumeQuota
                cmp   #256
                bcc   PGTRX3BExpectedStore
                sec
                sbc   #255
                cmp   #256
                bcc   PGTRX3BExpectedStore
                sec
                sbc   #255

PGTRX3BExpectedStore
                sta   RX3BExpectedByte

* 32-bit consumed-byte receipt.
                lda   RX3BConsumeQuota
                clc
                adc   RX3BConsLo
                sta   RX3BConsLo
                bcc   PGTRX3BConsCountOK
                inc   RX3BConsHi

PGTRX3BConsCountOK
                jsr   ServiceTCPRX3BWindowUpdate
                bcc   PGTRX3BWindowUpdateOK
                sec
                rts

PGTRX3BWindowUpdateOK
                jsr   RecordTCPRX3BOccupancy

                lda   RX3BConsumerTick
                cmp   RX3BNowTick
                beq   PGTRX3BServiceDone
                brl   PGTRX3BTickLoop

PGTRX3BServiceDone
                clc
                rts

*-------------------------------------------------
* Track live occupancy only before peer FIN.
*-------------------------------------------------

*-------------------------------------------------
* RX3-B TCP receive-window update.
*
* Send an ACK when the consumer has reopened at
* least one MSS beyond the last advertised window.
* BuildTCPACK publishes the exact current free size.
*-------------------------------------------------

ServiceTCPRX3BWindowUpdate
                rep   #$30

                jsl   PGTRingFree
                ldy   #PGTCRecvWindow
                sec
                sbc   [PGTtcpConn],y

* Current free <= advertised: nothing to announce.
                bcc   PGTRX3BWindowNoUpdate

* Avoid tiny-window chatter. Reopen by >= one MSS.
                cmp   #1460
                bcc   PGTRX3BWindowNoUpdate

                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTRX3BWindowSent

                sec
                rts

PGTRX3BWindowSent
                inc   RXAckCount
                inc   RX3BWindowACKs
                clc
                rts

PGTRX3BWindowNoUpdate
                clc
                rts

RecordTCPRX3BOccupancy
                rep   #$30
                lda   RX3BConsumerStarted
                beq   PGTRX3BOccDone
                lda   RXPeerFINSeen
                bne   PGTRX3BOccDone

                jsl   PGTRingUsed
                cmp   RX3BUsedMin
                bcs   PGTRX3BMinOK
                sta   RX3BUsedMin

PGTRX3BMinOK
                cmp   RX3BUsedMax
                bcc   PGTRX3BOccDone
                beq   PGTRX3BOccDone
                sta   RX3BUsedMax

PGTRX3BOccDone
                clc
                rts

*-------------------------------------------------
* After FIN, validate and drain final prebuffer.
*-------------------------------------------------

DrainTCPRX3BRemaining
                rep   #$30
                jsl   PGTRingUsed
                sta   RX3BConsumeQuota
                beq   PGTRX3BDrainDone

* Peer FIN means no more payload can arrive.
* Consume remaining final-ring occupancy at once.
                lda   PGTringHead
                sta   PGTringTail

                lda   RX3BConsumeQuota
                clc
                adc   RX3BConsLo
                sta   RX3BConsLo
                bcc   PGTRX3BDrainDone
                inc   RX3BConsHi

PGTRX3BDrainDone
                clc
                rts

*-------------------------------------------------
* Final RX3-B proof.
*-------------------------------------------------

VerifyTCPRX3BStream
                rep   #$30

                lda   RX3BConsumerStarted
                bne   PGTRX3BV01
                brl   PGTRX3BVBad
PGTRX3BV01

                lda   RXPeerFINSeen
                bne   PGTRX3BV02
                brl   PGTRX3BVBad
PGTRX3BV02

                lda   RX3BUnderruns
                beq   PGTRX3BV03
                brl   PGTRX3BVBad
PGTRX3BV03

                lda   RX3BPatternFails
                beq   PGTRX3BV04
                brl   PGTRX3BVBad
PGTRX3BV04

                lda   RXChecksumFails
                beq   PGTRX3BV05
                brl   PGTRX3BVBad
PGTRX3BV05

                lda   RXRingFull
                beq   PGTRX3BV06
                brl   PGTRX3BVBad
PGTRX3BV06

                lda   RX3BRecvHi
                cmp   #$0005
                beq   PGTRX3BV07
                brl   PGTRX3BVBad
PGTRX3BV07

                lda   RX3BRecvLo
                cmp   #$2080
                beq   PGTRX3BV08
                brl   PGTRX3BVBad
PGTRX3BV08

                lda   RX3BConsHi
                cmp   RX3BRecvHi
                beq   PGTRX3BV09
                brl   PGTRX3BVBad
PGTRX3BV09

                lda   RX3BConsLo
                cmp   RX3BRecvLo
                beq   PGTRX3BV10
                brl   PGTRX3BVBad
PGTRX3BV10

                jsl   PGTRingUsed
                beq   PGTRX3BV11
                brl   PGTRX3BVBad
PGTRX3BV11

                lda   RXRingHighWater
                cmp   #8192
                bcs   PGTRX3BV12
                brl   PGTRX3BVBad
PGTRX3BV12

                cmp   #$3FFF
                bcc   PGTRX3BV13
                brl   PGTRX3BVBad
PGTRX3BV13

* Accepted data/FIN plus SEQ rejects each generated ACK.
                lda   RXAcceptedSegments
                clc
                adc   RXSeqRejects
                adc   RX3BWindowACKs
                cmp   RXAckCount
                beq   PGTRX3BVGood
                brl   PGTRX3BVBad

PGTRX3BVGood
                clc
                rts

PGTRX3BVBad
                sec
                rts

*-------------------------------------------------
* Additional streaming receipts.
*-------------------------------------------------

PrintTCPRX3BStats
                pea   ^TCPRX3BRecvMsg
                pea   TCPRX3BRecvMsg
                _WriteCString
                lda   RX3BRecvHi
                jsr   WriteHexWord
                lda   RX3BRecvLo
                jsr   WriteHexWord

                pea   ^TCPRX3BConsMsg
                pea   TCPRX3BConsMsg
                _WriteCString
                lda   RX3BConsHi
                jsr   WriteHexWord
                lda   RX3BConsLo
                jsr   WriteHexWord
                jsr   WriteCRLF

                pea   ^TCPRX3BUnderMsg
                pea   TCPRX3BUnderMsg
                _WriteCString
                lda   RX3BUnderruns
                jsr   WriteHexWord

                pea   ^TCPRX3BPatMsg
                pea   TCPRX3BPatMsg
                _WriteCString
                lda   RX3BPatternFails
                jsr   WriteHexWord

                pea   ^TCPRX3BMinMsg
                pea   TCPRX3BMinMsg
                _WriteCString
                lda   RX3BUsedMin
                jsr   WriteHexWord

                pea   ^TCPRX3BMaxMsg
                pea   TCPRX3BMaxMsg
                _WriteCString
                lda   RX3BUsedMax
                jsr   WriteHexWord
                jsr   WriteCRLF

                pea   ^TCPRX3BWackMsg
                pea   TCPRX3BWackMsg
                _WriteCString
                lda   RX3BWindowACKs
                jsr   WriteHexWord
                jsr   WriteCRLF
                rts

WaitTCPPeerFIN
                jsr   StartTCPRXDeadline

PGTRXFINPoll
                lda   RXPeerFINSeen
                bne   PGTRXFINDone

                jsr   CheckEscape
                bcc   PGTRXFINCheckCard
                sec
                rts

PGTRXFINCheckCard
                jsl   PGTU2BeginRX
                bcc   PGTRXFINHaveFrame
                bra   PGTRXFINNoFrame

PGTRXFINHaveFrame
                inc   RXFrameCount
                jsr   ProcessTCPRXFrame
                bcc   PGTRXFINProcessed
                sec
                rts

PGTRXFINProcessed
                lda   RXPeerFINSeen
                bne   PGTRXFINDone

PGTRXFINNoFrame
                jsr   TCPRXDeadlineExpired
                bcc   PGTRXFINPoll
                sec
                rts

PGTRXFINDone
                clc
                rts

*-------------------------------------------------
* Process one current MACRAW record.
*
* On entry PGTU2BeginRX already succeeded.
* Every non-hard path releases the record exactly once.
*-------------------------------------------------

ProcessTCPRXFrame
                rep   #$30
                stz   RXPayloadAccepted
                stz   RXCurrentFIN
                stz   PGTringSaved
                stz   PGTringFirst

* Ethernet 14 + IPv4 20 + minimum TCP 20 = 54 bytes.
                ldx   #0

PGTRXRead54
                cpx   #54
                bcs   PGTRXBaseHeaderDone
                jsl   PGTU2ReadFrame8
                bcc   PGTRXStoreHeaderByte
                brl   PGTRXReleaseIgnore

PGTRXStoreHeaderByte
                sep   #$20
                sta   HeaderBuffer,x
                rep   #$20
                inx
                bra   PGTRXRead54

PGTRXBaseHeaderDone

* Ethernet type IPv4.
                lda   HeaderBuffer+12
                cmp   #$0008
                beq   PGTRXEtherOK
                brl   PGTRXReleaseIgnore

PGTRXEtherOK
* IPv4, IHL=5 only for first native receive path.
                lda   HeaderBuffer+14
                and   #$00FF
                cmp   #$0045
                beq   PGTRXIPv4OK
                brl   PGTRXReleaseIgnore

PGTRXIPv4OK
* No IPv4 fragmentation.
                lda   HeaderBuffer+20
                xba
                and   #$3FFF
                beq   PGTRXFragmentOK
                brl   PGTRXReleaseIgnore

PGTRXFragmentOK
* TCP only.
                lda   HeaderBuffer+22
                xba
                and   #$00FF
                cmp   #PGTIPTCP
                beq   PGTRXProtocolOK
                brl   PGTRXReleaseIgnore

PGTRXProtocolOK
* Exact remote -> local IPv4 tuple.
                lda   HeaderBuffer+26
                cmp   TCPRemoteIP
                beq   PGTRXSrcIPLowOK
                brl   PGTRXReleaseIgnore

PGTRXSrcIPLowOK
                lda   HeaderBuffer+28
                cmp   TCPRemoteIP+2
                beq   PGTRXSrcIPHighOK
                brl   PGTRXReleaseIgnore

PGTRXSrcIPHighOK
                lda   HeaderBuffer+30
                cmp   OfferedIP
                beq   PGTRXDstIPLowOK
                brl   PGTRXReleaseIgnore

PGTRXDstIPLowOK
                lda   HeaderBuffer+32
                cmp   OfferedIP+2
                beq   PGTRXDstIPHighOK
                brl   PGTRXReleaseIgnore

PGTRXDstIPHighOK
* IPv4 total length.
                lda   HeaderBuffer+16
                xba
                sta   TCPRXIPLength
                cmp   #40
                bcs   PGTRXIPMinOK
                brl   PGTRXReleaseIgnore

PGTRXIPMinOK
                clc
                adc   #14
                cmp   PGTu2FrameLen
                bcc   PGTRXIPBoundsOK
                beq   PGTRXIPBoundsOK
                brl   PGTRXReleaseIgnore

PGTRXIPBoundsOK
* IPv4 checksum must validate before TCP lengths are trusted.
                lda   #HeaderBuffer+14
                sta   PGTcsPtr
                lda   #^HeaderBuffer
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                beq   PGTRXIPChecksumOK
                brl   PGTRXReleaseIgnore

PGTRXIPChecksumOK
* TCP tuple.
                lda   HeaderBuffer+34
                cmp   #TCPRemotePortWire
                beq   PGTRXSrcPortOK
                brl   PGTRXReleaseIgnore

PGTRXSrcPortOK
                lda   HeaderBuffer+36
                cmp   #TCPLocalPortWire
                beq   PGTRXDstPortOK
                brl   PGTRXReleaseIgnore

PGTRXDstPortOK
* TCP segment bytes = IPv4 total - fixed 20-byte IP header.
                lda   TCPRXIPLength
                sec
                sbc   #20
                sta   TCPRXSegmentLength

* TCP data offset in bytes.
                lda   HeaderBuffer+46
                and   #$00FF
                lsr
                lsr
                lsr
                lsr
                asl
                asl
                sta   TCPRXHeaderLength
                cmp   #20
                bcs   PGTRXHeaderMinOK
                brl   PGTRXReleaseIgnore

PGTRXHeaderMinOK
                cmp   #61
                bcc   PGTRXHeaderMaxOK
                brl   PGTRXReleaseIgnore

PGTRXHeaderMaxOK
                cmp   TCPRXSegmentLength
                bcc   PGTRXHeaderBoundsOK
                beq   PGTRXHeaderBoundsOK
                brl   PGTRXReleaseIgnore

PGTRXHeaderBoundsOK
* Read TCP options, maximum 40 additional bytes.
                lda   TCPRXHeaderLength
                sec
                sbc   #20
                sta   TCPRXExtraHeader
                beq   PGTRXHeaderComplete

                ldx   #54

PGTRXReadOptions
                lda   TCPRXExtraHeader
                beq   PGTRXHeaderComplete
                jsl   PGTU2ReadFrame8
                bcc   PGTRXStoreOption
                brl   PGTRXReleaseIgnore

PGTRXStoreOption
                sep   #$20
                sta   HeaderBuffer,x
                rep   #$20
                inx
                dec   TCPRXExtraHeader
                bra   PGTRXReadOptions

PGTRXHeaderComplete
* Payload length excludes Ethernet padding.
                lda   TCPRXSegmentLength
                sec
                sbc   TCPRXHeaderLength
                sta   TCPRXPayloadLength

                cmp   PGTu2Remain
                bcc   PGTRXPayloadBoundsOK
                beq   PGTRXPayloadBoundsOK
                brl   PGTRXReleaseIgnore

PGTRXPayloadBoundsOK
* SEG.SEQ.
                lda   HeaderBuffer+40
                xba
                sta   PGTtcpSeq
                lda   HeaderBuffer+38
                xba
                sta   PGTtcpSeq+2

* SEG.ACK.
                lda   HeaderBuffer+44
                xba
                sta   PGTtcpAck
                lda   HeaderBuffer+42
                xba
                sta   PGTtcpAck+2

* Peer advertised window.
                lda   HeaderBuffer+48
                xba
                sta   PGTtcpWindow

* Flags.
                lda   HeaderBuffer+47
                and   #$00FF
                sta   PGTtcpFlags

* RST and unexpected SYN are not accepted here.
                bit   #PGTTCPF_RST
                beq   PGTRXNoRST
                brl   PGTRXReleaseIgnore

PGTRXNoRST
                lda   PGTtcpFlags
                bit   #PGTTCPF_SYN
                beq   PGTRXNoSYN
                brl   PGTRXReleaseIgnore

PGTRXNoSYN
* Established traffic must carry ACK.
                lda   PGTtcpFlags
                bit   #PGTTCPF_ACK
                bne   PGTRXACKFlagOK
                brl   PGTRXReleaseIgnore

PGTRXACKFlagOK
* ACK must match our current SND.NXT for RX1.
                ldy   #PGTCSendNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck
                beq   PGTRXAckLowOK
                brl   PGTRXReleaseIgnore

PGTRXAckLowOK
                iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck+2
                beq   PGTRXAckHighOK
                brl   PGTRXReleaseIgnore

PGTRXAckHighOK
* Exact RCV.NXT only.
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq
                beq   PGTRXSeqLowOK
                brl   PGTRXSequenceReject

PGTRXSeqLowOK
                iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq+2
                beq   PGTRXSeqHighOK
                brl   PGTRXSequenceReject

PGTRXSeqHighOK
* Remember whether FIN is present.
                lda   PGTtcpFlags
                bit   #PGTTCPF_FIN
                beq   PGTRXFINFlagDone
                lda   #1
                sta   RXCurrentFIN

PGTRXFINFlagDone
* Stage payload directly into unpublished ring storage.
                lda   TCPRXPayloadLength
                beq   PGTRXNoPayloadStage

                sta   PGTringNeed
                jsl   PGTRingStageRX
                bcc   PGTRXStageOK

                inc   RXRingFull
                brl   PGTRXWindowReject

PGTRXStageOK
                bra   PGTRXChecksumStart

PGTRXNoPayloadStage
                stz   PGTringSaved
                stz   PGTringFirst

*-------------------------------------------------
* Incremental TCP checksum.
*-------------------------------------------------

PGTRXChecksumStart
                jsr   BuildTCPRXPseudo
                jsl   PGTChecksumInit

* Pseudoheader.
                lda   #TCPRXPseudo
                sta   PGTcsPtr
                lda   #^TCPRXPseudo
                sta   PGTcsPtr+2
                lda   #12
                sta   PGTcsLen
                jsl   PGTChecksumAdd

* TCP header including checksum field.
                lda   #HeaderBuffer+34
                sta   PGTcsPtr
                lda   #^HeaderBuffer
                sta   PGTcsPtr+2
                lda   TCPRXHeaderLength
                sta   PGTcsLen
                jsl   PGTChecksumAdd

* First direct-to-ring payload span.
                lda   TCPRXPayloadLength
                beq   PGTRXChecksumFinal

                lda   PGTringBase
                clc
                adc   PGTringHead
                sta   PGTcsPtr
                lda   PGTringBase+2
                adc   #0
                sta   PGTcsPtr+2
                lda   PGTringFirst
                sta   PGTcsLen
                jsl   PGTChecksumAdd

* Wrapped second ring span, if present.
                lda   PGTringSaved
                sec
                sbc   PGTringFirst
                beq   PGTRXChecksumFinal

                sta   PGTcsLen
                lda   PGTringBase
                sta   PGTcsPtr
                lda   PGTringBase+2
                sta   PGTcsPtr+2
                jsl   PGTChecksumAdd

PGTRXChecksumFinal
                jsl   PGTChecksumFinal
                beq   PGTRXChecksumValid

* Staged bytes remain invisible because head never moved.
                inc   RXChecksumFails
                stz   PGTringSaved
                stz   PGTringFirst
                brl   PGTRXChecksumReject

PGTRXChecksumValid
* Only checksum-valid traffic updates peer window.
                ldy   #PGTCSendWindow
                lda   PGTtcpWindow
                sta   [PGTtcpConn],y

* Pure ACK consumes no receive sequence and gets no ACK reply.
                lda   TCPRXPayloadLength
                bne   PGTRXCommitSegment
                lda   RXCurrentFIN
                bne   PGTRXCommitSegment
                brl   PGTRXReleasePureACK

PGTRXCommitSegment
* TCP state first; checksum and SEQ already passed.
                lda   TCPRXPayloadLength
                sta   PGTtcpLength
                jsl   PGTTCPCommitInOrder
                bcc   PGTRXStateCommitted
                sec
                rts

PGTRXStateCommitted
* Publish staged bytes only after state commit.
                lda   TCPRXPayloadLength
                beq   PGTRXRingPublished
                jsl   PGTRingCommitRX

PGTRXRingPublished
                inc   RXAcceptedSegments

                lda   TCPRXPayloadLength
                beq   PGTRXNoPayloadCount
                sta   RXPayloadAccepted
                clc
                adc   RX3BRecvLo
                sta   RX3BRecvLo
                bcc   PGTRX3BRecvCountOK
                inc   RX3BRecvHi
PGTRX3BRecvCountOK

                jsl   PGTRingUsed
                cmp   RXRingHighWater
                bcc   PGTRXNoPayloadCount
                sta   RXRingHighWater

PGTRXNoPayloadCount
                lda   RXCurrentFIN
                beq   PGTRXAcceptedRelease
                lda   #1
                sta   RXPeerFINSeen

PGTRXAcceptedRelease
                jsl   PGTU2ReleaseRX
                bcc   PGTRXAcceptedReleased
                sec
                rts

PGTRXAcceptedReleased
* ACK every accepted data or FIN segment in diagnostic mode.
                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTRXAcceptedACKSent
                sec
                rts

PGTRXAcceptedACKSent
                inc   RXAckCount
                ldy   #PGTCAckPending
                lda   #0
                sta   [PGTtcpConn],y
                clc
                rts

*-------------------------------------------------
* Duplicate/future sequence: no publish, ACK current RCV.NXT.
*-------------------------------------------------

*-------------------------------------------------
* Valid pure ACK: release only; never ACK an ACK.
*-------------------------------------------------

PGTRXReleasePureACK
                jsl   PGTU2ReleaseRX
                bcc   PGTRXPureACKReleased
                sec
                rts

PGTRXPureACKReleased
                clc
                rts

PGTRXSequenceReject
                inc   RXSeqRejects
                stz   PGTringSaved
                stz   PGTringFirst
                jsl   PGTU2ReleaseRX
                bcc   PGTRXSeqReleased
                sec
                rts

PGTRXSeqReleased
                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTRXSeqACKSent
                sec
                rts

PGTRXSeqACKSent
                inc   RXAckCount
                clc
                rts

*-------------------------------------------------
* Bad checksum: no publish, no RCV.NXT movement, ACK current.
*-------------------------------------------------

PGTRXChecksumReject
                jsl   PGTU2ReleaseRX
                bcc   PGTRXBadCSReleased
                sec
                rts

PGTRXBadCSReleased
                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTRXBadCSACKSent
                sec
                rts

PGTRXBadCSACKSent
                inc   RXAckCount
                clc
                rts

*-------------------------------------------------
* Ring full: ACK unchanged RCV.NXT with current free window.
*-------------------------------------------------

PGTRXWindowReject
                stz   PGTringSaved
                stz   PGTringFirst
                jsl   PGTU2ReleaseRX
                bcc   PGTRXWindowReleased
                sec
                rts

PGTRXWindowReleased
                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTRXWindowACKSent
                sec
                rts

PGTRXWindowACKSent
                inc   RXAckCount
                clc
                rts

* Unrelated/unsupported frame: silently release.
PGTRXReleaseIgnore
                stz   PGTringSaved
                stz   PGTringFirst
                jsl   PGTU2ReleaseRX
                rts

*-------------------------------------------------
* Build 12-byte TCP pseudoheader in wire byte order.
*-------------------------------------------------

BuildTCPRXPseudo
                lda   HeaderBuffer+26
                sta   TCPRXPseudo
                lda   HeaderBuffer+28
                sta   TCPRXPseudo+2
                lda   HeaderBuffer+30
                sta   TCPRXPseudo+4
                lda   HeaderBuffer+32
                sta   TCPRXPseudo+6
                lda   #$0600
                sta   TCPRXPseudo+8
                lda   TCPRXSegmentLength
                xba
                sta   TCPRXPseudo+10
                rts

*-------------------------------------------------
* Deterministic RX1-A ring verification.
* Host pattern: 01..FF repeated.
*-------------------------------------------------

VerifyTCPRXPattern
                rep   #$30
                ldx   #0
                lda   #1
                sta   RXExpectedByte

PGTRXPatternLoop
                cpx   #11680
                bcs   PGTRXPatternGood

                sep   #$20
                lda   RXRing,x
                cmp   RXExpectedByte
                bne   PGTRXPatternBad8

                inc   RXExpectedByte
                lda   RXExpectedByte
                bne   PGTRXPatternNext
                lda   #1
                sta   RXExpectedByte

PGTRXPatternNext
                rep   #$20
                inx
                bra   PGTRXPatternLoop

PGTRXPatternBad8
                rep   #$20
                sec
                rts

PGTRXPatternGood
                clc
                rts

*-------------------------------------------------
* Diagnostic deadline: ten seconds at 60 Hz.
*-------------------------------------------------

StartTCPRXDeadline
                lda   >$E100DC
                clc
                adc   #600
                sta   TCPRXDeadline
                rts

TCPRXDeadlineExpired
                lda   >$E100DC
                sec
                sbc   TCPRXDeadline
                bmi   PGTRXDeadlineOpen
                sec
                rts

PGTRXDeadlineOpen
                clc
                rts

