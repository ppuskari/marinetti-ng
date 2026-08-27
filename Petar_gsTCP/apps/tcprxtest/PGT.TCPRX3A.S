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

