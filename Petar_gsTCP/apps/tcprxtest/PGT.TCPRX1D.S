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
                lda   #$0FFF
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
* RX1-D: withhold ACK for first accepted data MSS.
                lda   #1
                sta   RX1DSuppressACK
                rts

*-------------------------------------------------
* Wait for one exact 512-byte accepted segment.
*-------------------------------------------------

WaitTCPRX1460
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
* RX1-D: record state after first accepted MSS.
*-------------------------------------------------

PrepareTCPRX1DDuplicate
                rep   #$30

* Exactly one data segment was accepted.
                lda   RXAcceptedSegments
                cmp   #1
                bne   PGTRX1DPrepareBad

* Its ACK must have been intentionally suppressed.
                lda   RXAckCount
                bne   PGTRX1DPrepareBad

* One MSS must be published exactly once.
                lda   PGTringHead
                cmp   #1460
                bne   PGTRX1DPrepareBad
                sta   RX1DHeadBefore

                jsl   PGTRingUsed
                cmp   #1460
                bne   PGTRX1DPrepareBad

* Snapshot current RCV.NXT after first acceptance.
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                sta   RX1DRecvBefore
                iny
                iny
                lda   [PGTtcpConn],y
                sta   RX1DRecvBefore+2

                clc
                rts

PGTRX1DPrepareBad
                sec
                rts

*-------------------------------------------------
* Wait for Windows to retransmit the unACKed MSS.
*-------------------------------------------------

WaitTCPRXDuplicateReject
                jsr   StartTCPRXDeadline

PGTRX1DPoll
                jsr   CheckEscape
                bcc   PGTRX1DCheckCard
                sec
                rts

PGTRX1DCheckCard
                jsl   PGTU2BeginRX
                bcc   PGTRX1DHaveFrame
                bra   PGTRX1DNoFrame

PGTRX1DHaveFrame
                inc   RXFrameCount
                jsr   ProcessTCPRXFrame
                bcc   PGTRX1DProcessed
                sec
                rts

PGTRX1DProcessed
                lda   RXSeqRejects
                bne   PGTRX1DDuplicateSeen

PGTRX1DNoFrame
                jsr   TCPRXDeadlineExpired
                bcc   PGTRX1DPoll
                sec
                rts

PGTRX1DDuplicateSeen
                clc
                rts

*-------------------------------------------------
* Prove duplicate caused no second publication and
* no second RCV.NXT advance.
*-------------------------------------------------

VerifyTCPRX1DDuplicate
                rep   #$30

                lda   RXSeqRejects
                beq   PGTRX1DVerifyBad

                lda   RXChecksumFails
                bne   PGTRX1DVerifyBad

                lda   RXRingFull
                bne   PGTRX1DVerifyBad

* Still only one accepted data segment.
                lda   RXAcceptedSegments
                cmp   #1
                bne   PGTRX1DVerifyBad

* Duplicate reject must have emitted current ACK.
                lda   RXAckCount
                cmp   #1
                bne   PGTRX1DVerifyBad

* Ring head cannot move on duplicate.
                lda   PGTringHead
                cmp   RX1DHeadBefore
                bne   PGTRX1DVerifyBad

* Published byte count remains exactly one MSS.
                jsl   PGTRingUsed
                cmp   #1460
                bne   PGTRX1DVerifyBad

* RCV.NXT cannot move on duplicate.
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                cmp   RX1DRecvBefore
                bne   PGTRX1DVerifyBad

                iny
                iny
                lda   [PGTtcpConn],y
                cmp   RX1DRecvBefore+2
                bne   PGTRX1DVerifyBad

                clc
                rts

PGTRX1DVerifyBad
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
* RX1-D: force a genuine host retransmission.
                lda   RX1DSuppressACK
                beq   PGTRX1DSendAcceptedACK

* Suppress only an accepted payload ACK.
                lda   TCPRXPayloadLength
                beq   PGTRX1DSendAcceptedACK

                stz   RX1DSuppressACK
                clc
                rts

PGTRX1DSendAcceptedACK
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
                cpx   #1460
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

