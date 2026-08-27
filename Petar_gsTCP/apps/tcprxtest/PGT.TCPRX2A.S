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
                lda   RX2RingBase
                sta   PGTringBase
                lda   RX2RingBase+2
                sta   PGTringBase+2
                lda   #$FFFF
                sta   PGTringMask
                lda   #$FE01
                sta   PGTringHead
                sta   PGTringTail
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

WaitTCPRX1000
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
                cmp   #1000
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
* RX2-A receipt: capture the actual ring split.
                lda   PGTringFirst
                sta   RX2AFirstSpan
                lda   PGTringSaved
                sec
                sbc   PGTringFirst
                sta   RX2ASecondSpan
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

*-------------------------------------------------
* RX2-A forced 64 KiB ring-wrap verification.
*
* Initial head/tail = $FE01
* Payload           = 1000 / $03E8
* Expected split    = 511 + 489
* Expected new head = $01E9
*-------------------------------------------------

*-------------------------------------------------
* RX2-A runtime bank-aligned 64 KiB receive ring.
*-------------------------------------------------

AllocateTCPRX2Ring
                rep   #$30

* NewHandle return slot.
                pha
                pha

* $00020000 = 128 KiB.
                pea   $0002
                pea   $0000

                lda   MemoryID
                pha
                pea   $8000           ; locked; 128 KiB may cross banks
                pea   $0000
                pea   $0000

                _NewHandle
                bcc   PGTRX2AHandleOK

                pla
                pla
                sec
                rts

PGTRX2AHandleOK
* Same proven stack-DP handle access used by
* AllocateDirectPage.
                tsc
                tcd

                lda   1
                sta   >RX2RingHandle
                lda   3
                sta   >RX2RingHandle+2

* Dereference Memory Manager handle.
                lda   [1]
                sta   >RX2AllocBase

                ldy   #2
                lda   [1],y
                sta   >RX2AllocBase+2

                pla
                pla

* Restore application DP.
                lda   >DirectPage
                tcd

* Use next bank boundary as logical ring base.
                lda   RX2AllocBase+2
                and   #$00FF
                cmp   #$00FF
                beq   PGTRX2AAllocBad

                inc
                and   #$00FF
                sta   RX2RingBase+2
                stz   RX2RingBase

                clc
                rts

PGTRX2AAllocBad
                sec
                rts

VerifyTCPRX2AWrap
                rep   #$30

                lda   RXAcceptedSegments
                cmp   #1
                beq   PGTRX2AVOK01
                brl   PGTRX2AVerifyBad
PGTRX2AVOK01

                lda   RXPayloadAccepted
                cmp   #1000
                beq   PGTRX2AVOK02
                brl   PGTRX2AVerifyBad
PGTRX2AVOK02

                lda   RX2AFirstSpan
                cmp   #511
                beq   PGTRX2AVOK03
                brl   PGTRX2AVerifyBad
PGTRX2AVOK03

                lda   RX2ASecondSpan
                cmp   #489
                beq   PGTRX2AVOK04
                brl   PGTRX2AVerifyBad
PGTRX2AVOK04

* 16-bit logical ring head must wrap through $0000.
                lda   PGTringHead
                cmp   #$01E9
                beq   PGTRX2AVOK05
                brl   PGTRX2AVerifyBad
PGTRX2AVOK05

                lda   PGTringTail
                cmp   #$FE01
                beq   PGTRX2AVOK06
                brl   PGTRX2AVerifyBad
PGTRX2AVOK06

                jsl   PGTRingUsed
                cmp   #1000
                beq   PGTRX2AVOK07
                brl   PGTRX2AVerifyBad
PGTRX2AVOK07

                lda   RXRingHighWater
                cmp   #1000
                beq   PGTRX2AVOK08
                brl   PGTRX2AVerifyBad
PGTRX2AVOK08

* Host pattern starts at byte $01.
                lda   #1
                sta   RXExpectedByte

* First logical span: RX2Ring+$FE01, 511 bytes.
                lda   RX2RingBase
                clc
                adc   #$FE01
                sta   PGTcsPtr
                lda   RX2RingBase+2
                adc   #0
                sta   PGTcsPtr+2

                lda   #511
                sta   RX2AVerifyRemain
                ldy   #0

PGTRX2AFirstLoop
                sep   #$20
                mx    %10
                lda   [PGTcsPtr],y
                cmp   RXExpectedByte
                beq   PGTRX2APOK01
                brl   PGTRX2APatternBad8
PGTRX2APOK01

                inc   RXExpectedByte
                lda   RXExpectedByte
                bne   PGTRX2AFirstNext
                lda   #1
                sta   RXExpectedByte

PGTRX2AFirstNext
                rep   #$20
                mx    %00
                iny
                dec   RX2AVerifyRemain
                bne   PGTRX2AFirstLoop

* Wrapped span resumes at logical ring byte zero.
                lda   RX2RingBase
                sta   PGTcsPtr
                lda   RX2RingBase+2
                sta   PGTcsPtr+2

                lda   #489
                sta   RX2AVerifyRemain
                ldy   #0

PGTRX2ASecondLoop
                sep   #$20
                mx    %10
                lda   [PGTcsPtr],y
                cmp   RXExpectedByte
                beq   PGTRX2APOK02
                brl   PGTRX2APatternBad8
PGTRX2APOK02

                inc   RXExpectedByte
                lda   RXExpectedByte
                bne   PGTRX2ASecondNext
                lda   #1
                sta   RXExpectedByte

PGTRX2ASecondNext
                rep   #$20
                mx    %00
                iny
                dec   RX2AVerifyRemain
                bne   PGTRX2ASecondLoop

                clc
                rts

PGTRX2APatternBad8
                rep   #$20
                mx    %00

PGTRX2AVerifyBad
                sec
                rts

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


*-------------------------------------------------
* RX2-A dedicated 64 KiB logical receive ring.
* Must remain the final allocation in this segment.
*-------------------------------------------------
