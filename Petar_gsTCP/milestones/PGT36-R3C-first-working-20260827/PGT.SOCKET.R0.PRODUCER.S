*=================================================
* PGT.NATIVE.PRODUCER.S
*
* R3A-PGT36 native TCP socket-ring adapter for HARDEN-R1K1 semantics.
*
* - private 256-byte direct page
* - Uthernet II / W5100 MACRAW socket 0
* - static first-gate IPv4 tuple
* - direct W5100 -> existing application ring
* - N8 fused W5100->ring copy + TCP payload checksum
* - TCP checksum before logical publication
* - exact request-sized receive window
* - no packet-time allocation / no payload buffer
*=================================================

NP0CLocalPortWire  equ   $00C0       ; 49152 -> C0 00
NP0CRemotePortWire equ   $EE57       ; 22510 -> 57 EE
NP0CSYNFrameLen    equ   60
NP0CACKFrameLen    equ   60
NP0CSYNIPLen       equ   44
NP0CACKIPLen       equ   40
NP0CSYNLen         equ   24
NP0CACKLen         equ   20
NP0CAdvertisedMSS  equ   1460
NP0CSockSize       equ   $4000       ; private 16 KiB software receive ring
NP0CSockMask       equ   $3FFF
NP0CWireWindow     equ   $0B68       ; do not outrun 4 KiB W5100 MACRAW RX RAM
NP0CFuseScratch    equ   PGTdpPrivate ; $40-$47 checksum/copy scratch
NP0COpenTicks      equ   180         ; 3 seconds
NP0CReadTicks      equ   1800        ; 30 seconds without progress
NP0CErrDP           equ   $FC01
NP0CErrCard         equ   $FC02
NP0CErrARP          equ   $FC03
NP0CErrConnect      equ   $FC04
NP0CErrRead         equ   $FC05
NP0CErrClosed       equ   $FC06
NP0CErrRange        equ   $FC07
NP0CErrTimeout      equ   $FC08
NP0CErrHard         equ   $FC09

*-------------------------------------------------
* PGTNativeStart
*
* Control path.  Allocate the private DP once and
* probe Uthernet II slot 4.  Does not open MACRAW.
*-------------------------------------------------

PGTNativeStart  ent
                rep   #$30
                lda   NP0CDirectPage
                beq   NP0CStartAllocate
                clc
                rts

NP0CStartAllocate
                phd
                pha
                pha
                pea   $0000
                pea   $0100
                lda   MemoryID
                pha
                pea   $C005
                pea   $0000
                pea   $0000
                ldx   #$0902
                jsl   $E10000
                bcc   NP0CStartDPAllocated

                pla
                pla
                pld
                lda   #NP0CErrDP
                sec
                rts

NP0CStartDPAllocated
                tsc
                tcd
                lda   1
                sta   NP0CDPHandle
                lda   3
                sta   NP0CDPHandle+2
                lda   [1]
                sta   NP0CDirectPage
                pla
                pla
                pld

                lda   NP0CDirectPage
                bne   NP0CStartDPValid
                lda   #NP0CErrDP
                sec
                rts

NP0CStartDPValid
                phd
                lda   NP0CDirectPage
                tcd
                ldx   #$00FE
                lda   #0
NP0CStartClear  sta   0,x
                dex
                dex
                bpl   NP0CStartClear

                lda   #4
                jsl   PGTU2SelectSlot
                bcc   NP0CStartSlotOK
                pld
                lda   #$FCA1
                sec
                rts

NP0CStartSlotOK jsl   PGTU2Probe
                bcc   NP0CStartProbeOK
                pld
                lda   #$FCA2
                sec
                rts

NP0CStartProbeOK
                jsr   NP0CLoadMAC
                jsr   NP0CMACValid
                bcc   NP0CStartMACOK

* A fresh/reset W5100 leaves SHAR at all zero.  The Uthernet II
* programmer manual requires software to configure a MAC address.
* Preserve any existing valid MAC (for example one left by Marinetti),
* otherwise install our locally-administered unicast test identity and
* read it back before proceeding.
                jsr   NP0CProgramDefaultMAC
                jsr   NP0CLoadMAC
                jsr   NP0CMACValid
                bcc   NP0CStartMACOK
                pld
                lda   #$FCA3
                sec
                rts

NP0CStartMACOK  lda   #1
                sta   NP0CStarted
                pld
                clc
                rts

NP0CStartCardFail
                pld
                lda   #NP0CErrCard
                sec
                rts

*-------------------------------------------------
* PGTNativeStop
*-------------------------------------------------

PGTNativeStop   ent
                rep   #$30
                lda   NP0CDirectPage
                beq   NP0CStopNoDP

                phd
                lda   NP0CDirectPage
                tcd
                lda   NP0CRawActive
                beq   NP0CStopRawDone
                jsl   PGTU2StopRaw
                stz   NP0CRawActive
NP0CStopRawDone pld

                lda   NP0CDPHandle
                ora   NP0CDPHandle+2
                beq   NP0CStopNoDP
                lda   NP0CDPHandle+2
                pha
                lda   NP0CDPHandle
                pha
                ldx   #$1002
                jsl   $E10000
                stz   NP0CDPHandle
                stz   NP0CDPHandle+2
                stz   NP0CDirectPage

NP0CStopNoDP    stz   NP0CStarted
                stz   NP0CConnected
                stz   NP0CRequestActive
                clc
                rts

*-------------------------------------------------
* PGTNativeOpen
*
* Static first hardware gate:
*   local    192.168.7.54:49152
*   remote   192.168.5.235:22510
* Same /22, so ARP the provider directly.
*-------------------------------------------------

PGTNativeOpen   ent
                rep   #$30
                lda   NP0CStarted
                bne   NP0COpenStarted
                jsr   PGTNativeStart
                bcc   NP0COpenStarted
                rts

NP0COpenStarted lda  NP0CDirectPage
                bne   NP0COpenHaveDP
                lda   #NP0CErrDP
                sec
                rts

NP0COpenHaveDP  phd
                lda   NP0CDirectPage
                tcd
                stz   NP0CConnected
                stz   NP0CRequestActive
                stz   NP0CRequestRemaining
                stz   NP0CARPResolved
                stz   NP0CPeerFIN
                stz   NP0CLastError
                stz   NP0CRXFrames
                stz   NP0CTXFrames
                stz   NP0CAcceptedSegments
                stz   NP0CBadChecksum
                stz   NP0CSeqRejects
                stz   NP0CSeqDupRejects
                stz   NP0CSeqFutureRejects
                stz   NP0CWindowRejects
                stz   NP0CIPv4Rejects
                stz   NP0CHeaderRejects
                stz   NP0CPortRejects
                stz   NP0CAckRejects
                stz   NP0CHardFails

                lda   NP0CRawActive
                bne   NP0COpenRawReady
                jsl   PGTU2StartRaw
                bcc   NP0COpenRawStarted
                pld
                lda   #$FCB1
                sec
                rts
NP0COpenRawStarted
                lda   #1
                sta   NP0CRawActive
                stz   PGTu2WrapCount
                stz   PGTu2TXWrapCount

NP0COpenRawReady
                lda   #3
                sta   NP0CRetryCount
NP0COpenARPTry  jsr   NP0CBuildARPRequest
                jsr   NP0CSendTXFrame
                bcc   NP0COpenARPSent
                pld
                lda   #$FCB2
                sec
                rts
NP0COpenARPSent jsr   NP0CStartOpenDeadline
NP0COpenARPWait lda   NP0CARPResolved
                bne   NP0COpenARPDone
                jsr   NP0CServiceOneDP
                bcc   NP0COpenARPServiceOK
                pld
                lda   #$FCB3
                sec
                rts
NP0COpenARPServiceOK
                jsr   NP0COpenDeadlineExpired
                bcc   NP0COpenARPWait
                dec   NP0CRetryCount
                bne   NP0COpenARPTry
                pld
                lda   #$FCB4
                sec
                rts

NP0COpenARPDone jsr   NP0CInitConnection
                lda   #3
                sta   NP0CRetryCount
NP0COpenSYNTry  jsr   NP0CBuildSYN
                jsr   NP0CSendTXFrame
                bcc   NP0COpenSYNSent
                pld
                lda   #$FCB5
                sec
                rts
NP0COpenSYNSent jsr   NP0CStartOpenDeadline
NP0COpenSYNWait lda   NP0CConnected
                bne   NP0COpenSuccess
                jsr   NP0CServiceOneDP
                bcc   NP0COpenSYNServiceOK
                pld
                lda   #$FCB6
                sec
                rts
NP0COpenSYNServiceOK
                jsr   NP0COpenDeadlineExpired
                bcc   NP0COpenSYNWait
                dec   NP0CRetryCount
                bne   NP0COpenSYNTry
                pld
                lda   #$FCB7
                sec
                rts

NP0COpenSuccess pld
                clc
                rts

NP0COpenCardFail
                pld
                lda   #NP0CErrCard
                sec
                rts

*-------------------------------------------------
* PGTNativeReadExact
*
* Existing streamer ABI:
*   A = exact byte count
*   X = destination low word
*   Y = destination bank
*
* The destination is already the final M3R36A ring
* address.  This routine never owns another ring.
*-------------------------------------------------

PGTNativeReadExact ent
                rep   #$30
                sta   NP0CRequestRemaining
                sta   NP0CRequestTotal
                stx   NP0CRequestPtr
                sty   NP0CRequestPtr+2
                stx   NP0CRequestStart
                sty   NP0CRequestStart+2
                stx   NP0CStagePtr
                sty   NP0CStagePtr+2
                stz   NP0CLastError

                lda   NP0CConnected
                bne   NP0CReadConnected
                lda   #NP0CErrClosed
                sta   NP0CLastError
                sec
                rts

NP0CReadConnected
                lda   NP0CRequestRemaining
                bne   NP0CReadCheckRange
                clc
                rts

* Firewall the final-ring ABI before opening the TCP
* receive window.  No MACRAW payload byte may be copied
* outside [LeftRingPtr, LeftRingPtr+selected ring bytes).
NP0CReadCheckRange
                jsr   NP0CValidateRequestRange
                bcc   NP0CReadNonZero
                lda   #NP0CErrRange
                sta   NP0CLastError
                sec
                rts

NP0CReadNonZero phd
                lda   NP0CDirectPage
                tcd
                lda   #1
                sta   NP0CRequestActive

* Reopen exactly this producer reservation.
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                bcs   NP0CReadHardFail
                jsr   NP0CStartReadDeadline
                lda   NP0CRequestRemaining
                sta   NP0CLastRemaining

NP0CReadLoop    lda   NP0CRequestRemaining
                beq   NP0CReadDone
                lda   NP0CConnected
                beq   NP0CReadClosed

                jsr   NP0CServiceOneDP
                bcs   NP0CReadHardFail

                lda   NP0CRequestRemaining
                cmp   NP0CLastRemaining
                beq   NP0CReadNoProgress
                sta   NP0CLastRemaining
                jsr   NP0CStartReadDeadline
                bra   NP0CReadLoop

NP0CReadNoProgress
                jsr   NP0CReadDeadlineExpired
                bcc   NP0CReadLoop
                bra   NP0CReadTimeout

NP0CReadDone    stz   NP0CRequestActive
                stz   NP0CLastError
                pld
                clc
                rts

NP0CReadClosed  stz   NP0CRequestActive
                pld
                lda   #NP0CErrClosed
                sta   NP0CLastError
                sec
                rts

NP0CReadHardFail
                stz   NP0CRequestActive
                inc   NP0CHardFails
                pld
                lda   #NP0CErrHard
                sta   NP0CLastError
                sec
                rts

NP0CReadTimeout stz   NP0CRequestActive
                pld
                lda   #NP0CErrTimeout
                sta   NP0CLastError
                sec
                rts

* Validate the exact-write destination against the one
* physical M3R36A mono ring.  Request fields are already
* captured by PGTNativeReadExact and request count is nonzero.
NP0CValidateRequestRange
                lda   NP0CRequestStart
                sec
                sbc   LeftRingPtr
                sta   NP0CRangeDelta
                lda   NP0CRequestStart+2
                sbc   LeftRingPtr+2
                bcc   NP0CRangeBad
                sta   NP0CRangeDelta+2

* A nonzero request may not start at or beyond ring end.
                cmp   RingBytesHighSelected
                bcc   NP0CRangeStartOK
                bra   NP0CRangeBad

NP0CRangeStartOK
                lda   NP0CRangeDelta
                clc
                adc   NP0CRequestTotal
                sta   NP0CRangeEnd
                lda   NP0CRangeDelta+2
                adc   #0
                sta   NP0CRangeEnd+2
                cmp   RingBytesHighSelected
                bcc   NP0CRangeGood
                bne   NP0CRangeBad
                lda   NP0CRangeEnd
                bne   NP0CRangeBad

NP0CRangeGood   clc
                rts
NP0CRangeBad    sec
                rts

*-------------------------------------------------
* PGTNativeServiceOne
*
* Background-safe packet service entry.  At most one
* complete MACRAW record is dispatched.  No Tool calls,
* UI calls, GS/OS calls, or allocation occur here.
*-------------------------------------------------

PGTNativeServiceOne ent
                rep   #$30
                lda   NP0CDirectPage
                bne   NP0CServiceHaveDP
                lda   #NP0CErrDP
                sec
                rts
NP0CServiceHaveDP
                phd
                lda   NP0CDirectPage
                tcd
                jsr   NP0CServiceOneDP
                bcc   NP0CServiceReturnOK
                pld
                sec
                rts
NP0CServiceReturnOK
                pld
                clc
                rts

* Golden compatibility poll.  Service one bounded frame
* so ARP remains alive even when no payload reservation
* is currently open.  Poll failures are not promoted to
* the golden UI status path; ReadExact/Open own errors.

PGTNativePollCompat ent
                rep   #$30
                jsr   PGTNativeServiceOne
                rts

*-------------------------------------------------
* PGTNativeClose
*
* Send RST+ACK for deterministic immediate reconnect,
* but retain MACRAW ownership until PGTNativeStop.
*-------------------------------------------------

PGTNativeClose  ent
                rep   #$30
                lda   NP0CDirectPage
                beq   NP0CCloseDone
                lda   NP0CConnected
                beq   NP0CCloseState
                phd
                lda   NP0CDirectPage
                tcd
                stz   NP0CRequestActive
                stz   NP0CRequestRemaining
                jsr   NP0CBuildRST
                jsr   NP0CSendTXFrame
                pld
NP0CCloseState  stz   NP0CConnected
                stz   NP0CSockHead
                stz   NP0CSockTail
                stz   NP0CSockUsed
                stz   NP0CLastAdvertisedWindow
NP0CCloseDone   clc
                rts

*-------------------------------------------------
* One-record dispatcher, current DP already private.
*-------------------------------------------------

NP0CServiceOneDP
                rep   #$30
                jsl   PGTU2BeginRX
                bcc   NP0CServiceHaveFrame
                clc
                rts

NP0CServiceHaveFrame
* R0 passive diagnostics: no per-frame RX counter.
* N10 BULK HEADER: fetch the Ethernet header in one W5100 span.
* This replaces fourteen JSL PGTU2ReadFrame8 calls on every frame.
                lda   #NP0CHeader
                sta   PGTu2BulkPtr
                lda   #^NP0CHeader
                sta   PGTu2BulkPtr+2
                lda   #14
                sta   PGTu2BulkLen
                jsl   PGTU2CopyRXSpan
                bcs   NP0CServiceRelease

NP0CServiceEtherDone
                lda   NP0CHeader+12
                cmp   #$0608
                beq   NP0CServiceARP
                cmp   #$0008
                beq   NP0CServiceIPv4
                bra   NP0CServiceRelease

NP0CServiceARP  jsr   NP0CProcessARP
                rts

NP0CServiceIPv4 lda  NP0CConnected
                bne   NP0CServiceEstablished
                lda   PGTtcpConn
                ora   PGTtcpConn+2
                beq   NP0CServiceRelease
                ldy   #PGTCState
                lda   [PGTtcpConn],y
                cmp   #PGTTSynSent
                beq   NP0CServiceSYNACK
                bra   NP0CServiceRelease

NP0CServiceSYNACK
                jsr   NP0CProcessSYNACK
                rts

NP0CServiceEstablished
                jsr   NP0CProcessTCPFrame
                rts

NP0CServiceRelease
                jsl   PGTU2ReleaseRX
                clc
                rts

*-------------------------------------------------
* ARP receive / responder.
* Ethernet bytes 0..13 are already in NP0CHeader.
*-------------------------------------------------

NP0CProcessARP  rep   #$30
                ldx   #14
NP0CARPReadRest cpx   #42
                bcs   NP0CARPReadDone
                jsl   PGTU2ReadFrame8
                bcc   NP0CARPByteOK
                brl   NP0CARPReleaseOnly
NP0CARPByteOK   sep   #$20
                mx    %10
                sta   NP0CHeader,x
                rep   #$20
                mx    %00
                inx
                bra   NP0CARPReadRest

NP0CARPReadDone lda   NP0CHeader+14
                cmp   #$0100
                beq   NP0CARPTypeOK
                brl   NP0CARPReleaseOnly
NP0CARPTypeOK   lda   NP0CHeader+16
                cmp   #$0008
                beq   NP0CARPProtoOK
                brl   NP0CARPReleaseOnly
NP0CARPProtoOK  lda   NP0CHeader+18
                cmp   #$0406
                beq   NP0CARPLensOK
                brl   NP0CARPReleaseOnly
NP0CARPLensOK   lda   NP0CHeader+20
                cmp   #$0200
                beq   NP0CARPReply
                cmp   #$0100
                beq   NP0CARPRequest
                bra   NP0CARPReleaseOnly

NP0CARPReply    lda   NP0CHeader+28
                cmp   NP0CRemoteIP
                beq   NP0CARPReplyIP1
                brl   NP0CARPReleaseOnly
NP0CARPReplyIP1 lda   NP0CHeader+30
                cmp   NP0CRemoteIP+2
                beq   NP0CARPReplyIP2
                brl   NP0CARPReleaseOnly
NP0CARPReplyIP2 lda   NP0CHeader+38
                cmp   NP0CLocalIP
                beq   NP0CARPReplyDst1
                brl   NP0CARPReleaseOnly
NP0CARPReplyDst1 lda  NP0CHeader+40
                cmp   NP0CLocalIP+2
                beq   NP0CARPReplyDst2
                brl   NP0CARPReleaseOnly
NP0CARPReplyDst2 ldx  #4
NP0CARPCopyRemote
                lda   NP0CHeader+22,x
                sta   NP0CRemoteMAC,x
                dex
                dex
                bpl   NP0CARPCopyRemote
                lda   #1
                sta   NP0CARPResolved
                jsl   PGTU2ReleaseRX
                clc
                rts

NP0CARPRequest  lda   NP0CHeader+38
                cmp   NP0CLocalIP
                beq   NP0CARPReqDst1
                brl   NP0CARPReleaseOnly
NP0CARPReqDst1  lda   NP0CHeader+40
                cmp   NP0CLocalIP+2
                beq   NP0CARPReqDst2
                brl   NP0CARPReleaseOnly
NP0CARPReqDst2  ldx   #4
NP0CARPCopyPeer lda   NP0CHeader+22,x
                sta   NP0CARPPeerMAC,x
                dex
                dex
                bpl   NP0CARPCopyPeer
                lda   NP0CHeader+28
                sta   NP0CARPPeerIP
                lda   NP0CHeader+30
                sta   NP0CARPPeerIP+2
                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildARPReply
                jsr   NP0CSendTXFrame
                rts

NP0CARPReleaseOnly
                jsl   PGTU2ReleaseRX
                clc
                rts

*-------------------------------------------------
* SYN+ACK receive.  No application payload is legal.
*-------------------------------------------------

NP0CProcessSYNACK
                rep   #$30
                ldx   #14
NP0CSYNRead54   cpx   #54
                bcs   NP0CSYNBaseDone
                jsl   PGTU2ReadFrame8
                bcc   NP0CSYNByteOK
                brl   NP0CSYNReleaseReject
NP0CSYNByteOK   sep   #$20
                mx    %10
                sta   NP0CHeader,x
                rep   #$20
                mx    %00
                inx
                bra   NP0CSYNRead54

NP0CSYNBaseDone jsr   NP0CValidateIPv4Base
                bcs   NP0CSYNReleaseReject
                lda   NP0CTCPRXSegmentLength
                cmp   #20
                bcc   NP0CSYNReleaseReject
                jsr   NP0CReadTCPOptions
                bcs   NP0CSYNReleaseReject
                lda   NP0CTCPRXPayloadLength
                bne   NP0CSYNReleaseReject

                lda   NP0CHeader+34
                cmp   #NP0CRemotePortWire
                bne   NP0CSYNReleaseReject
                lda   NP0CHeader+36
                cmp   #NP0CLocalPortWire
                bne   NP0CSYNReleaseReject

                lda   NP0CHeader+47
                and   #$003F
                cmp   #PGTTCPF_SYN+PGTTCPF_ACK
                bne   NP0CSYNReleaseReject

                jsr   NP0CChecksumTCPHeaderOnly
                bcs   NP0CSYNReleaseReject

                lda   NP0CHeader+40
                xba
                sta   PGTtcpSeq
                lda   NP0CHeader+38
                xba
                sta   PGTtcpSeq+2
                lda   NP0CHeader+44
                xba
                sta   PGTtcpAck
                lda   NP0CHeader+42
                xba
                sta   PGTtcpAck+2
                lda   NP0CHeader+48
                xba
                sta   PGTtcpWindow
                lda   NP0CHeader+47
                and   #$00FF
                sta   PGTtcpFlags
                stz   PGTtcpLength
                jsl   PGTTCPAcceptSYNACK
                bcs   NP0CSYNReleaseReject

                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                bcs   NP0CSYNHardFail
                ldy   #PGTCAckPending
                lda   #0
                sta   [PGTtcpConn],y
                lda   #1
                sta   NP0CConnected
                clc
                rts

NP0CSYNReleaseReject
                jsl   PGTU2ReleaseRX
                clc
                rts
NP0CSYNHardFail sec
                rts

*-------------------------------------------------
* Established TCP receive.
*-------------------------------------------------

NP0CProcessTCPFrame
                rep   #$30
* N10 BULK HEADER: Ethernet bytes 0..13 are already present.
* Fetch the fixed 20-byte IPv4 + 20-byte TCP base header in one span
* instead of forty far byte-read calls.
                lda   #NP0CHeader+14
                sta   PGTu2BulkPtr
                lda   #^NP0CHeader
                sta   PGTu2BulkPtr+2
                lda   #40
                sta   PGTu2BulkLen
                jsl   PGTU2CopyRXSpan
                bcc   NP0CRXBaseDone
                brl   NP0CRXReleaseIgnore

NP0CRXBaseDone  jsr   NP0CValidateIPv4Base
                bcc   NP0CRXIPv4OK
                inc   NP0CIPv4Rejects
                brl   NP0CRXReleaseIgnore
NP0CRXIPv4OK    jsr   NP0CReadTCPOptions
                bcc   NP0CRXOptionsOK
                inc   NP0CHeaderRejects
                brl   NP0CRXReleaseIgnore
NP0CRXOptionsOK

                lda   NP0CHeader+34
                cmp   #NP0CRemotePortWire
                beq   NP0CRXSrcPortOK
                brl   NP0CRXPortReject
NP0CRXSrcPortOK lda   NP0CHeader+36
                cmp   #NP0CLocalPortWire
                beq   NP0CRXDstPortOK
                brl   NP0CRXPortReject
NP0CRXDstPortOK

* Parsed TCP values.
                lda   NP0CHeader+40
                xba
                sta   PGTtcpSeq
                lda   NP0CHeader+38
                xba
                sta   PGTtcpSeq+2
                lda   NP0CHeader+44
                xba
                sta   PGTtcpAck
                lda   NP0CHeader+42
                xba
                sta   PGTtcpAck+2
                lda   NP0CHeader+48
                xba
                sta   PGTtcpWindow
                lda   NP0CHeader+47
                and   #$00FF
                sta   PGTtcpFlags

                bit   #PGTTCPF_RST
                beq   NP0CRXNoRST
                jsl   PGTU2ReleaseRX
                stz   NP0CConnected
                clc
                rts

NP0CRXNoRST     lda   PGTtcpFlags
                bit   #PGTTCPF_SYN
                beq   NP0CRXNoSYN
                brl   NP0CRXReleaseIgnore
NP0CRXNoSYN      bit   #PGTTCPF_ACK
                bne   NP0CRXHasACK
                brl   NP0CRXReleaseIgnore
NP0CRXHasACK

* ACK must equal our SND.NXT.
                ldy   #PGTCSendNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck
                beq   NP0CRXAckLowOK
                brl   NP0CRXAckReject
NP0CRXAckLowOK   iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpAck+2
                beq   NP0CRXAckHighOK
                brl   NP0CRXAckReject
NP0CRXAckHighOK

* Exact RCV.NXT only.
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq
                beq   NP0CRXSeqLowOK
                brl   NP0CRXSequenceReject
NP0CRXSeqLowOK   iny
                iny
                lda   [PGTtcpConn],y
                cmp   PGTtcpSeq+2
                beq   NP0CRXSeqHighOK
                brl   NP0CRXSequenceReject
NP0CRXSeqHighOK

* R0 socket contract: TCP acceptance depends only on free space in the
* private 16 KiB socket ring, never on the application's current 16K read.
                lda   NP0CTCPRXPayloadLength
                beq   NP0CRXChecksumStart
                jsr   NP0CSockFree
                cmp   NP0CTCPRXPayloadLength
                bcs   NP0CRXStagePayload
                brl   NP0CRXWindowReject

NP0CRXStagePayload
* The payload is copied into the unpublished socket ring.  A checksum failure
* may overwrite free bytes but does not advance head/used, so it is invisible
* to the application and will be overwritten by the next valid segment.
                lda   NP0CTCPRXPayloadLength
                sta   NP0CSockCopyRemain

NP0CRXChecksumStart
* N10 BULK-HDR FUSED CHECKSUM: initialize pseudo/header checksum state BEFORE
* consuming payload from W5100.  Payload bytes are checksummed while
* they are copied directly into the final 512K Tool225 ring, so there
* is no second traversal of ring memory.
                jsr   NP0CBuildRXPseudo
                jsl   PGTChecksumInit
                lda   #NP0CRXPseudo
                sta   PGTcsPtr
                lda   #^NP0CRXPseudo
                sta   PGTcsPtr+2
                lda   #12
                sta   PGTcsLen
                jsl   PGTChecksumAdd

                lda   #NP0CHeader+34
                sta   PGTcsPtr
                lda   #^NP0CHeader
                sta   PGTcsPtr+2
                lda   NP0CTCPRXHeaderLength
                sta   PGTcsLen
                jsl   PGTChecksumAdd

                lda   NP0CTCPRXPayloadLength
                beq   NP0CRXChecksumFinal
                jsr   NP0CSockFusedPayload
                bcc   NP0CRXChecksumFinal
                brl   NP0CRXHardFail

NP0CRXChecksumFinal
                jsl   PGTChecksumFinal
                beq   NP0CRXChecksumGood
                inc   NP0CBadChecksum
                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                rts

NP0CRXChecksumGood
                ldy   #PGTCSendWindow
                lda   PGTtcpWindow
                sta   [PGTtcpConn],y

* Pure ACK: never ACK an ACK.
                lda   NP0CTCPRXPayloadLength
                bne   NP0CRXCommit
                lda   PGTtcpFlags
                bit   #PGTTCPF_FIN
                bne   NP0CRXCommit
                jsl   PGTU2ReleaseRX
                clc
                rts

NP0CRXCommit    lda   NP0CTCPRXPayloadLength
                sta   PGTtcpLength
                jsl   PGTTCPCommitInOrder
                bcc   NP0CRXCommitStateOK
                brl   NP0CRXHardFail
NP0CRXCommitStateOK

* TCP state has committed.  Publish to the private socket ring only now.
                lda   NP0CTCPRXPayloadLength
                beq   NP0CRXAfterPayload
                clc
                adc   NP0CSockHead
                and   #NP0CSockMask
                sta   NP0CSockHead
                lda   NP0CSockUsed
                clc
                adc   NP0CTCPRXPayloadLength
                sta   NP0CSockUsed
* Accepted-segment counter is retained for existing cold diagnostics; this is
* one INC per payload segment and no timing/high-water work occurs here.
* R0 passive diagnostics: no per-segment success counter.

NP0CRXAfterPayload
                lda   PGTtcpFlags
                bit   #PGTTCPF_FIN
                beq   NP0CRXReleaseAccepted
                lda   #1
                sta   NP0CPeerFIN

NP0CRXReleaseAccepted
                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                bcs   NP0CRXHardFailAfterRelease
                ldy   #PGTCAckPending
                lda   #0
                sta   [PGTtcpConn],y
                lda   NP0CPeerFIN
                beq   NP0CRXAcceptedDone
                stz   NP0CConnected
NP0CRXAcceptedDone
                clc
                rts

NP0CRXPortReject
                inc   NP0CPortRejects
                brl   NP0CRXReleaseIgnore

NP0CRXAckReject
                inc   NP0CAckRejects
                brl   NP0CRXReleaseIgnore

NP0CRXSequenceReject
                inc   NP0CSeqRejects
* Reject-only classification: no cost on accepted payload hot path.
* For this LAN benchmark ranges never approach 32-bit wrap.
                ldy   #PGTCRecvNext+2
                lda   PGTtcpSeq+2
                cmp   [PGTtcpConn],y
                bcc   NP0CRXSeqWasDuplicate
                bne   NP0CRXSeqWasFuture
                dey
                dey
                lda   PGTtcpSeq
                cmp   [PGTtcpConn],y
                bcc   NP0CRXSeqWasDuplicate
NP0CRXSeqWasFuture
                inc   NP0CSeqFutureRejects
                bra   NP0CRXSeqClassified
NP0CRXSeqWasDuplicate
                inc   NP0CSeqDupRejects
NP0CRXSeqClassified
                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                rts

NP0CRXWindowReject
                inc   NP0CWindowRejects
                jsl   PGTU2ReleaseRX
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                rts

NP0CRXReleaseIgnore
                jsl   PGTU2ReleaseRX
                clc
                rts

NP0CRXHardFail  inc   NP0CHardFails
                jsl   PGTU2ReleaseRX
                sec
                rts
NP0CRXHardFailAfterRelease
                inc   NP0CHardFails
                sec
                rts


*-------------------------------------------------
* R0-PGT36 private socket-ring helpers
*-------------------------------------------------

NP0CSockFree
                lda   #NP0CSockSize
                sec
                sbc   NP0CSockUsed
                rts

NP0CSockAdvertisedWindow
                jsr   NP0CSockFree
                cmp   #NP0CWireWindow
                bcc   NP0CSockWindowReady
                lda   #NP0CWireWindow
NP0CSockWindowReady
                rts

* Copy one current TCP payload from W5100 into the private 16K ring while
* continuing the checksum state established for pseudo-header + TCP header.
* Destination wrap is split into at most two calls.
NP0CSockFusedPayload
                rep   #$30
                lda   NP0CTCPRXPayloadLength
                sta   NP0CSockCopyRemain

* First span starts at socket head.
                lda   #NP0CSocketRing
                clc
                adc   NP0CSockHead
                sta   PGTu2BulkPtr
                lda   #^NP0CSocketRing
                adc   #0
                sta   PGTu2BulkPtr+2

                lda   #NP0CSockSize
                sec
                sbc   NP0CSockHead
                cmp   NP0CSockCopyRemain
                bcc   NP0CSockFirstLenReady
                lda   NP0CSockCopyRemain
NP0CSockFirstLenReady
                sta   NP0CSockSpanLen
                sta   PGTu2BulkLen
                jsr   NP0CFusedCopyChecksum
                bcs   NP0CSockFusedFail

                lda   NP0CSockCopyRemain
                sec
                sbc   NP0CSockSpanLen
                sta   NP0CSockCopyRemain
                beq   NP0CSockFusedDone

* Wrapped suffix begins at ring base; checksum odd-phase carries across call.
                lda   #NP0CSocketRing
                sta   PGTu2BulkPtr
                lda   #^NP0CSocketRing
                sta   PGTu2BulkPtr+2
                lda   NP0CSockCopyRemain
                sta   PGTu2BulkLen
                jsr   NP0CFusedCopyChecksum
                bcs   NP0CSockFusedFail
NP0CSockFusedDone
                clc
                rts
NP0CSockFusedFail
                sec
                rts

* Marinetti-shaped immediate read from already-validated socket bytes.
* Input: A=requested bytes, X=dest low, Y=dest bank.
* Output: A=actual bytes (0..request), carry clear; carry set on impossible state.
* The common caller caps requests to <=8K and never asks for more than queued.
PGTNativeReadAvailable ent
* R3A: MVN socket-ring -> application drain from R1B, on R2B transport.
* R1B/R1C FAST DRAIN: use the 65816 MVN block-move engine instead of the
* R0 long-indirect word loop.  Caller still asks for <=8K, queued bytes only.
* Source-ring wrap and source/destination 64K bank boundaries are split
* before each MVN.  MVN changes DBR, so preserve/restore it around the move.
                rep   #$30
                sta   NP0CSockReadWant
                stx   NP0CSockReadDst
                sty   NP0CSockReadDst+2
                lda   NP0CSockUsed
                cmp   NP0CSockReadWant
                bcs   R1SockReadCountReady
                sta   NP0CSockReadWant
R1SockReadCountReady
                lda   NP0CSockReadWant
                sta   NP0CSockReadCount
                bne   R1SockReadNonZero
                lda   #0
                clc
                rts

R1SockReadNonZero
                phd
                lda   NP0CDirectPage
                tcd
                lda   NP0CSockReadDst
                sta   PGTu2BulkPtr
                lda   NP0CSockReadDst+2
                sta   PGTu2BulkPtr+2

R1SockReadMore
* Build 24-bit source pointer = ring base + circular tail.
                lda   #NP0CSocketRing
                clc
                adc   NP0CSockTail
                sta   PGTcsPtr
                lda   #^NP0CSocketRing
                adc   #0
                sta   PGTcsPtr+2

* Start with min(bytes-to-ring-wrap, remaining request).
                lda   #NP0CSockSize
                sec
                sbc   NP0CSockTail
                cmp   NP0CSockReadWant
                bcc   R1SockChunkRingReady
                lda   NP0CSockReadWant
R1SockChunkRingReady
                sta   NP0CSockReadChunk

* Do not let one MVN cross the source 64K bank boundary.
                lda   PGTcsPtr
                beq   R1SockSourceBankReady
                eor   #$FFFF
                inc   a
                cmp   NP0CSockReadChunk
                bcs   R1SockSourceBankReady
                sta   NP0CSockReadChunk
R1SockSourceBankReady

* Do not let one MVN cross the destination 64K bank boundary either.
                lda   PGTu2BulkPtr
                beq   R1SockDestBankReady
                eor   #$FFFF
                inc   a
                cmp   NP0CSockReadChunk
                bcs   R1SockDestBankReady
                sta   NP0CSockReadChunk
R1SockDestBankReady

* Merlin syntax is MVN source,destination; machine operand byte +1 is
* destination bank and +2 is source bank.  Patch those two bytes at runtime.
                phb
                sep   #$20
                mx    %10
                lda   PGTu2BulkPtr+2
                sta   R1SockMVN+1
                lda   PGTcsPtr+2
                sta   R1SockMVN+2
                rep   #$20
                mx    %00

                lda   NP0CSockReadChunk
                dec   a
                ldx   PGTcsPtr
                ldy   PGTu2BulkPtr
R1SockMVN       mvn   $00,$00
                plb

* Advance destination long pointer by the chunk just moved.
                lda   PGTu2BulkPtr
                clc
                adc   NP0CSockReadChunk
                sta   PGTu2BulkPtr
                bcc   R1SockReadDstOK
                inc   PGTu2BulkPtr+2
R1SockReadDstOK

* Advance circular socket tail and reduce queued/remaining counts.
                lda   NP0CSockTail
                clc
                adc   NP0CSockReadChunk
                and   #NP0CSockMask
                sta   NP0CSockTail
                lda   NP0CSockUsed
                sec
                sbc   NP0CSockReadChunk
                sta   NP0CSockUsed
                lda   NP0CSockReadWant
                sec
                sbc   NP0CSockReadChunk
                sta   NP0CSockReadWant
                beq   R1SockReadMoveDone
                brl   R1SockReadMore
R1SockReadMoveDone

* Preserve R0's cold window-reopen behavior.
                lda   NP0CLastAdvertisedWindow
                cmp   #NP0CAdvertisedMSS
                bcs   R1SockReadReturn
                jsr   NP0CSockAdvertisedWindow
                cmp   #NP0CAdvertisedMSS
                bcc   R1SockReadReturn
                jsr   NP0CBuildACK
                jsr   NP0CSendTXFrame
                bcs   R1SockReadSendFail
R1SockReadReturn
                lda   NP0CSockReadCount
                pld
                clc
                rts
R1SockReadSendFail
                pld
                sec
                rts

*-------------------------------------------------
* NP0CFusedCopyChecksum -- N8 direct-ring hot path
*
* Copy current W5100 MACRAW payload span directly to PGTu2BulkPtr
* while adding the same bytes to the incremental Internet checksum.
* Pseudo-header and TCP header have already been accumulated.
* Handles W5100 4K RX wrap and odd checksum phase transactionally.
* On success PGTu2BulkPtr is advanced exactly like PGTU2CopyRXSpan.
*-------------------------------------------------
NP0CFusedCopyChecksum
                rep   #$30
                mx    %00
                stz   PGTu2BulkCopied
                lda   PGTu2BulkLen
                bne   NP0CFuseHaveLen
                brl   NP0CFuseDone
NP0CFuseHaveLen cmp   PGTu2Remain
                bcc   NP0CFuseStart
                beq   NP0CFuseStart
                sec
                rts

NP0CFuseStart   lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                eor   #W5S0MemoryMask
                inc
                sta   PGTu2BulkChunk
                cmp   PGTu2BulkLen
                bcc   NP0CFuseChunkOK
                lda   PGTu2BulkLen
                sta   PGTu2BulkChunk
NP0CFuseChunkOK
                ldx   PGTu2BulkChunk
                ldy   #0

* If the previous socket chunk ended on an odd network byte, consume
* the first new byte as its low byte before entering the 8-byte loop.
                lda   PGTcsOddValid
                and   #$00FF
                beq   NP0CFuseBatchCheck
                cpx   #0
                bne   NP0CFusePendingHaveByte
                brl   NP0CFuseChunkCopied
NP0CFusePendingHaveByte
                sep   #$20
                mx    %10
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   PGTcsOddValid
                rep   #$20
                mx    %00
                lda   PGTcsOddByte
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFusePendingNoCy
                inc   PGTcsSumHi
NP0CFusePendingNoCy
                stz   PGTcsOddByte
                iny
                dex

* Copy/checksum eight bytes per batch.  The extra scratch stores are
* direct-page accesses; they replace N7's later long-indirect reread
* of the final ring.  One SEP/REP pair covers four checksum words.
NP0CFuseBatchCheck
                cpx   #8
                bcc   NP0CFusePairCheck
                sep   #$20
                mx    %10
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+0
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+1
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+2
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+3
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+4
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+5
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+6
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+7
                iny
                rep   #$20
                mx    %00

                lda   NP0CFuseScratch+0
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFuseB0
                inc   PGTcsSumHi
NP0CFuseB0      lda   NP0CFuseScratch+2
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFuseB1
                inc   PGTcsSumHi
NP0CFuseB1      lda   NP0CFuseScratch+4
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFuseB2
                inc   PGTcsSumHi
NP0CFuseB2      lda   NP0CFuseScratch+6
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFuseB3
                inc   PGTcsSumHi
NP0CFuseB3      txa
                sec
                sbc   #8
                tax
                bra   NP0CFuseBatchCheck

* At most seven bytes remain.  Pairs use one short M-width transition.
NP0CFusePairCheck
                cpx   #2
                bcc   NP0CFuseOddCheck
                sep   #$20
                mx    %10
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+0
                iny
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   NP0CFuseScratch+1
                iny
                rep   #$20
                mx    %00
                lda   NP0CFuseScratch
                xba
                clc
                adc   PGTcsSumLo
                sta   PGTcsSumLo
                bcc   NP0CFusePairNoCy
                inc   PGTcsSumHi
NP0CFusePairNoCy
                dex
                dex
                bra   NP0CFusePairCheck

NP0CFuseOddCheck
                cpx   #0
                beq   NP0CFuseChunkCopied
                sep   #$20
                mx    %10
                lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                sta   PGTcsOddByte
                lda   #1
                sta   PGTcsOddValid
                rep   #$20
                mx    %00
                iny
                dex

NP0CFuseChunkCopied
                lda   PGTu2BulkPtr
                clc
                adc   PGTu2BulkChunk
                sta   PGTu2BulkPtr
                bcc   NP0CFusePtrOK
                inc   PGTu2BulkPtr+2
NP0CFusePtrOK   lda   PGTu2RXPtr
                clc
                adc   PGTu2BulkChunk
                sta   PGTu2RXPtr
                lda   PGTu2Remain
                sec
                sbc   PGTu2BulkChunk
                sta   PGTu2Remain
                lda   PGTu2BulkLen
                sec
                sbc   PGTu2BulkChunk
                sta   PGTu2BulkLen
                lda   PGTu2BulkCopied
                clc
                adc   PGTu2BulkChunk
                sta   PGTu2BulkCopied

                lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                bne   NP0CFuseMore
                lda   PGTu2Remain
                beq   NP0CFuseMore
                inc   PGTu2WrapCount
                ldx   #W5S0RXBase
                jsl   PGTU2SetAddress
NP0CFuseMore    lda   PGTu2BulkLen
                beq   NP0CFuseDone
                brl   NP0CFuseStart
NP0CFuseDone    rep   #$30
                mx    %00
                clc
                rts

*-------------------------------------------------
* IPv4/TCP header helpers.
*-------------------------------------------------

NP0CValidateIPv4Base
                lda   NP0CHeader+14
                and   #$00FF
                cmp   #$0045
                bne   NP0CIPv4Bad
                lda   NP0CHeader+20
                xba
                and   #$3FFF
                bne   NP0CIPv4Bad
                lda   NP0CHeader+22
                xba
                and   #$00FF
                cmp   #PGTIPTCP
                bne   NP0CIPv4Bad
                lda   NP0CHeader+26
                cmp   NP0CRemoteIP
                bne   NP0CIPv4Bad
                lda   NP0CHeader+28
                cmp   NP0CRemoteIP+2
                bne   NP0CIPv4Bad
                lda   NP0CHeader+30
                cmp   NP0CLocalIP
                bne   NP0CIPv4Bad
                lda   NP0CHeader+32
                cmp   NP0CLocalIP+2
                bne   NP0CIPv4Bad

                lda   NP0CHeader+16
                xba
                sta   NP0CTCPRXIPLength
                cmp   #40
                bcc   NP0CIPv4Bad
                clc
                adc   #14
                cmp   PGTu2FrameLen
                bcc   NP0CIPv4Bounds
                beq   NP0CIPv4Bounds
                bra   NP0CIPv4Bad

NP0CIPv4Bounds  lda   #NP0CHeader+14
                sta   PGTcsPtr
                lda   #^NP0CHeader
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                bne   NP0CIPv4Bad

                lda   NP0CTCPRXIPLength
                sec
                sbc   #20
                sta   NP0CTCPRXSegmentLength
                clc
                rts
NP0CIPv4Bad     sec
                rts

NP0CReadTCPOptions
                lda   NP0CTCPRXSegmentLength
                cmp   #20
                bcc   NP0CTCPOptionsBad
                lda   NP0CHeader+46
                and   #$00FF
                lsr
                lsr
                lsr
                lsr
                asl
                asl
                sta   NP0CTCPRXHeaderLength
                cmp   #20
                bcc   NP0CTCPOptionsBad
                cmp   #61
                bcs   NP0CTCPOptionsBad
                cmp   NP0CTCPRXSegmentLength
                bcc   NP0CTCPOptionsBounds
                beq   NP0CTCPOptionsBounds
                bra   NP0CTCPOptionsBad

NP0CTCPOptionsBounds
                lda   NP0CTCPRXHeaderLength
                sec
                sbc   #20
                sta   NP0CTCPRXExtraHeader
                beq   NP0CTCPOptionsDone
* N10 BULK OPTIONS: established timestamp/SACK-option bytes are contiguous
* too; fetch the entire option span with one W5100 bulk operation.
                lda   #NP0CHeader+54
                sta   PGTu2BulkPtr
                lda   #^NP0CHeader
                sta   PGTu2BulkPtr+2
                lda   NP0CTCPRXExtraHeader
                sta   PGTu2BulkLen
                jsl   PGTU2CopyRXSpan
                bcs   NP0CTCPOptionsBad

NP0CTCPOptionsDone
                lda   NP0CTCPRXSegmentLength
                sec
                sbc   NP0CTCPRXHeaderLength
                sta   NP0CTCPRXPayloadLength
                cmp   PGTu2Remain
                bcc   NP0CTCPOptionsOK
                beq   NP0CTCPOptionsOK
NP0CTCPOptionsBad sec
                rts
NP0CTCPOptionsOK clc
                rts

NP0CBuildRXPseudo
                lda   NP0CHeader+26
                sta   NP0CRXPseudo
                lda   NP0CHeader+28
                sta   NP0CRXPseudo+2
                lda   NP0CHeader+30
                sta   NP0CRXPseudo+4
                lda   NP0CHeader+32
                sta   NP0CRXPseudo+6
                lda   #$0600
                sta   NP0CRXPseudo+8
                lda   NP0CTCPRXSegmentLength
                xba
                sta   NP0CRXPseudo+10
                rts

NP0CChecksumTCPHeaderOnly
                jsr   NP0CBuildRXPseudo
                jsl   PGTChecksumInit
                lda   #NP0CRXPseudo
                sta   PGTcsPtr
                lda   #^NP0CRXPseudo
                sta   PGTcsPtr+2
                lda   #12
                sta   PGTcsLen
                jsl   PGTChecksumAdd
                lda   #NP0CHeader+34
                sta   PGTcsPtr
                lda   #^NP0CHeader
                sta   PGTcsPtr+2
                lda   NP0CTCPRXSegmentLength
                sta   PGTcsLen
                jsl   PGTChecksumAdd
                jsl   PGTChecksumFinal
                beq   NP0CTCPHeaderCSGood
                sec
                rts
NP0CTCPHeaderCSGood clc
                rts

*-------------------------------------------------
* TX constructors.
*-------------------------------------------------

NP0CInitConnection
                lda   #TCPConnection
                sta   PGTtcpConn
                lda   #^TCPConnection
                sta   PGTtcpConn+2
                lda   #0
                ldx   #PGTCSize-2
NP0CClearConn   sta   TCPConnection,x
                dex
                dex
                bpl   NP0CClearConn
                lda   #49152
                sta   TCPConnection+PGTCLocalPort
                lda   #22510
                sta   TCPConnection+PGTCRemotePort
                lda   NP0CRemoteIP
                sta   TCPConnection+PGTCRemoteIP
                lda   NP0CRemoteIP+2
                sta   TCPConnection+PGTCRemoteIP+2
                lda   #NP0CWireWindow
                sta   TCPConnection+PGTCRecvWindow
                lda   >$E100DC
                eor   NP0CLocalMAC+2
                eor   #$4E50
                sta   PGTtcpISS
                lda   >$E100DC
                xba
                eor   NP0CLocalMAC+4
                eor   #$3043
                sta   PGTtcpISS+2
                jsl   PGTTCPBeginActive
                rts

NP0CBuildSYN    rep   #$30
                jsr   NP0CZeroTX60
                jsr   NP0CBuildEtherIP
                lda   #NP0CSYNIPLen
                jsr   NP0CSetIPLength
                lda   #NP0CLocalPortWire
                sta   NP0CTXFrame+34
                lda   #NP0CRemotePortWire
                sta   NP0CTXFrame+36
                lda   PGTtcpISS+2
                xba
                sta   NP0CTXFrame+38
                lda   PGTtcpISS
                xba
                sta   NP0CTXFrame+40
                lda   #$0260
                sta   NP0CTXFrame+46
                lda   #NP0CWireWindow
                xba
                sta   NP0CTXFrame+48
                lda   #$0402
                sta   NP0CTXFrame+54
                lda   #NP0CAdvertisedMSS
                xba
                sta   NP0CTXFrame+56
                lda   #NP0CSYNLen
                sta   NP0CTXSegmentLength
                jsr   NP0CFinishTCPFrame
                lda   #NP0CSYNFrameLen
                sta   NP0CTXFrameLength
                rts

NP0CBuildACK    lda   #PGTTCPF_ACK
                bra   NP0CBuildControl
NP0CBuildRST    lda   #PGTTCPF_RST+PGTTCPF_ACK
NP0CBuildControl
                sta   NP0CTXFlags
                rep   #$30
                jsr   NP0CZeroTX60
                jsr   NP0CBuildEtherIP
                lda   #NP0CACKIPLen
                jsr   NP0CSetIPLength
                lda   #NP0CLocalPortWire
                sta   NP0CTXFrame+34
                lda   #NP0CRemotePortWire
                sta   NP0CTXFrame+36
                ldy   #PGTCSendNext+2
                lda   [PGTtcpConn],y
                xba
                sta   NP0CTXFrame+38
                ldy   #PGTCSendNext
                lda   [PGTtcpConn],y
                xba
                sta   NP0CTXFrame+40
                ldy   #PGTCRecvNext+2
                lda   [PGTtcpConn],y
                xba
                sta   NP0CTXFrame+42
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                xba
                sta   NP0CTXFrame+44
                lda   NP0CTXFlags
                and   #$00FF
                xba
                ora   #$0050
                sta   NP0CTXFrame+46
                jsr   NP0CSockAdvertisedWindow
                sta   NP0CLastAdvertisedWindow
                sta   TCPConnection+PGTCRecvWindow
                xba
                sta   NP0CTXFrame+48
                lda   #NP0CACKLen
                sta   NP0CTXSegmentLength
                jsr   NP0CFinishTCPFrame
                lda   #NP0CACKFrameLen
                sta   NP0CTXFrameLength
                rts

NP0CBuildEtherIP
                ldx   #4
NP0CFrameMAC    lda   NP0CRemoteMAC,x
                sta   NP0CTXFrame,x
                lda   NP0CLocalMAC,x
                sta   NP0CTXFrame+6,x
                dex
                dex
                bpl   NP0CFrameMAC
                lda   #$0008
                sta   NP0CTXFrame+12
                lda   #$0045
                sta   NP0CTXFrame+14
                lda   NP0CIPID
                xba
                sta   NP0CTXFrame+18
                inc   NP0CIPID
                lda   #$0040
                sta   NP0CTXFrame+20
                lda   #$0640
                sta   NP0CTXFrame+22
                lda   NP0CLocalIP
                sta   NP0CTXFrame+26
                lda   NP0CLocalIP+2
                sta   NP0CTXFrame+28
                lda   NP0CRemoteIP
                sta   NP0CTXFrame+30
                lda   NP0CRemoteIP+2
                sta   NP0CTXFrame+32
                rts

NP0CSetIPLength xba
                sta   NP0CTXFrame+16
                rts

NP0CFinishTCPFrame
* IPv4 header checksum.
                lda   #NP0CTXFrame+14
                sta   PGTcsPtr
                lda   #^NP0CTXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   NP0CTXFrame+24

* TCP pseudoheader + TCP header.
                lda   NP0CLocalIP
                sta   NP0CTXPseudo
                lda   NP0CLocalIP+2
                sta   NP0CTXPseudo+2
                lda   NP0CRemoteIP
                sta   NP0CTXPseudo+4
                lda   NP0CRemoteIP+2
                sta   NP0CTXPseudo+6
                lda   #$0600
                sta   NP0CTXPseudo+8
                lda   NP0CTXSegmentLength
                xba
                sta   NP0CTXPseudo+10
                jsl   PGTChecksumInit
                lda   #NP0CTXPseudo
                sta   PGTcsPtr
                lda   #^NP0CTXPseudo
                sta   PGTcsPtr+2
                lda   #12
                sta   PGTcsLen
                jsl   PGTChecksumAdd
                lda   #NP0CTXFrame+34
                sta   PGTcsPtr
                lda   #^NP0CTXFrame
                sta   PGTcsPtr+2
                lda   NP0CTXSegmentLength
                sta   PGTcsLen
                jsl   PGTChecksumAdd
                jsl   PGTChecksumFinal
                xba
                sta   NP0CTXFrame+50
                rts

NP0CZeroTX60    lda   #0
                ldx   #58
NP0CZeroTXLoop  sta   NP0CTXFrame,x
                dex
                dex
                bpl   NP0CZeroTXLoop
                rts

NP0CSendTXFrame
                lda   #NP0CTXFrame
                sta   PGTu2TXPtr
                lda   #^NP0CTXFrame
                sta   PGTu2TXPtr+2
                lda   NP0CTXFrameLength
                sta   PGTu2TXLen
                jsl   PGTU2SendFrame
                bcs   NP0CSendTXDone
* R0 passive diagnostics: no per-frame TX counter.
NP0CSendTXDone  rts

*-------------------------------------------------
* ARP constructors.
*-------------------------------------------------

NP0CBuildARPRequest
                jsr   NP0CZeroTX60
                lda   #$FFFF
                sta   NP0CTXFrame
                sta   NP0CTXFrame+2
                sta   NP0CTXFrame+4
                ldx   #4
NP0CARPReqMAC   lda   NP0CLocalMAC,x
                sta   NP0CTXFrame+6,x
                sta   NP0CTXFrame+22,x
                dex
                dex
                bpl   NP0CARPReqMAC
                lda   #$0608
                sta   NP0CTXFrame+12
                lda   #$0100
                sta   NP0CTXFrame+14
                lda   #$0008
                sta   NP0CTXFrame+16
                lda   #$0406
                sta   NP0CTXFrame+18
                lda   #$0100
                sta   NP0CTXFrame+20
                lda   NP0CLocalIP
                sta   NP0CTXFrame+28
                lda   NP0CLocalIP+2
                sta   NP0CTXFrame+30
                lda   NP0CRemoteIP
                sta   NP0CTXFrame+38
                lda   NP0CRemoteIP+2
                sta   NP0CTXFrame+40
                lda   #60
                sta   NP0CTXFrameLength
                rts

NP0CBuildARPReply
                jsr   NP0CZeroTX60
                ldx   #4
NP0CARPRepMAC   lda   NP0CARPPeerMAC,x
                sta   NP0CTXFrame,x
                lda   NP0CLocalMAC,x
                sta   NP0CTXFrame+6,x
                sta   NP0CTXFrame+22,x
                lda   NP0CARPPeerMAC,x
                sta   NP0CTXFrame+32,x
                dex
                dex
                bpl   NP0CARPRepMAC
                lda   #$0608
                sta   NP0CTXFrame+12
                lda   #$0100
                sta   NP0CTXFrame+14
                lda   #$0008
                sta   NP0CTXFrame+16
                lda   #$0406
                sta   NP0CTXFrame+18
                lda   #$0200
                sta   NP0CTXFrame+20
                lda   NP0CLocalIP
                sta   NP0CTXFrame+28
                lda   NP0CLocalIP+2
                sta   NP0CTXFrame+30
                lda   NP0CARPPeerIP
                sta   NP0CTXFrame+38
                lda   NP0CARPPeerIP+2
                sta   NP0CTXFrame+40
                lda   #60
                sta   NP0CTXFrameLength
                rts

*-------------------------------------------------
* MAC / deadlines.
*-------------------------------------------------

NP0CProgramDefaultMAC
                ldx   #0
NP0CProgramMACLoop
                sep   #$20
                mx    %10
                lda   NP0CDefaultMAC,x
                rep   #$20
                mx    %00
                and   #$00FF
                pha
                txa
                clc
                adc   #W5SHAR
                tax
                pla
                jsl   PGTU2Write8
                txa
                sec
                sbc   #W5SHAR
                tax
                inx
                cpx   #6
                bne   NP0CProgramMACLoop
                rts

NP0CLoadMAC     ldx   #0
NP0CLoadMACLoop phx
                txa
                clc
                adc   #W5SHAR
                tax
                jsl   PGTU2Read8
                plx
                sep   #$20
                mx    %10
                sta   NP0CLocalMAC,x
                rep   #$20
                mx    %00
                inx
                cpx   #6
                bne   NP0CLoadMACLoop
                rts

NP0CMACValid    lda   NP0CLocalMAC
                ora   NP0CLocalMAC+2
                ora   NP0CLocalMAC+4
                beq   NP0CMACBad
                lda   NP0CLocalMAC
                and   #$0001
                bne   NP0CMACBad
                clc
                rts
NP0CMACBad      sec
                rts

NP0CStartOpenDeadline
                lda   >$E100DC
                clc
                adc   #NP0COpenTicks
                sta   NP0CDeadline
                rts
NP0COpenDeadlineExpired
                lda   >$E100DC
                sec
                sbc   NP0CDeadline
                bmi   NP0COpenDeadlineOpen
                sec
                rts
NP0COpenDeadlineOpen clc
                rts

NP0CStartReadDeadline
                lda   >$E100DC
                clc
                adc   #NP0CReadTicks
                sta   NP0CDeadline
                rts
NP0CReadDeadlineExpired
                lda   >$E100DC
                sec
                sbc   NP0CDeadline
                bmi   NP0CReadDeadlineOpen
                sec
                rts
NP0CReadDeadlineOpen clc
                rts

*-------------------------------------------------
* Static network identity and private state.
*-------------------------------------------------

NP0CDefaultMAC   hex   025047073604     ; 02:50:47:07:36:04, local/unicast
NP0CLocalIP      hex   C0A80736       ; 192.168.7.54
NP0CRemoteIP     hex   C0A805EB       ; 192.168.5.235

NP0CNativeStartErrMsg
                 asc   'Native Uthernet II/TCP startup failed.',0D,00
NP0CBuildIDMsg    asc   0D,'PGT36 R0 SOCKET RING 20260826',0D,00
NP0CFailHdrMsg    asc   0D,'NP0-C PREFILL FAIL err=$',00
NP0CFailRemMsg    asc   ' rem=$',00
NP0CFailRXMsg     asc   'RX=$',00
NP0CFailAccMsg    asc   ' acc=$',00
NP0CFailCSMsg     asc   ' cs=$',00
NP0CFailSeqMsg    asc   ' seq=$',00
NP0CFailWinMsg    asc   ' win=$',00
NP0CFailIPMsg     asc   'IP=$',00
NP0CFailHdr2Msg   asc   ' hdr=$',00
NP0CFailPortMsg   asc   ' port=$',00
NP0CFailAckMsg    asc   ' ack=$',00
NP0CFailHardMsg   asc   ' hard=$',00
NP0CFailTXMsg     asc   ' tx=$',00
NP0CFailReqMsg    asc   'REQ=$',00
NP0CFailRingMsg   asc   ' ring=$',00
NP0CFailLenMsg    asc   ' lenhi=$',00
NP0CFailKeyMsg    asc   'HALTED - capture this screen.',0D,00
NP0CStartFailMsg  asc   0D,'NP0-C START FAIL err=$',00
NP0COpenFailMsg   asc   0D,'NP0-C OPEN FAIL err=$',00
NP0CRingFailMsg   asc   0D,'NP0-C RING FAIL err=$',00
NP0CDPReadyMsg    asc   'DP=$',00
NP0CSPReadyMsg    asc   ' SP=$',00

NP0CDPHandle     ds    4
NP0CDirectPage   ds    2
NP0CStarted      ds    2
NP0CRawActive    ds    2
NP0CConnected    ds    2
NP0CARPResolved  ds    2
NP0CRequestActive ds   2
NP0CRequestRemaining ds 2
NP0CRequestTotal ds    2
NP0CRequestPtr   ds    4
NP0CRequestStart ds    4
NP0CStagePtr     ds    4
NP0CRangeDelta   ds    4
NP0CRangeEnd     ds    4
NP0CLastRemaining ds  2
NP0CLastError    ds    2
NP0CPeerFIN      ds    2
NP0CRetryCount   ds    2
NP0CDeadline     ds    2
NP0CIPID         ds    2
NP0CRXFrames     ds    2
NP0CTXFrames     ds    2
NP0CAcceptedSegments ds 2
NP0CBadChecksum  ds    2
NP0CSeqRejects   ds    2
NP0CSeqDupRejects ds    2
NP0CSeqFutureRejects ds 2
NP0CWindowRejects ds   2
NP0CIPv4Rejects   ds    2
NP0CHeaderRejects ds    2
NP0CPortRejects   ds    2
NP0CAckRejects    ds    2
NP0CHardFails     ds    2
NP0CLocalMAC     ds    6
NP0CRemoteMAC    ds    6
NP0CARPPeerMAC   ds    6
NP0CARPPeerIP    ds    4
NP0CHeader       ds    96
NP0CRXPseudo     ds    12
NP0CTXPseudo     ds    12
NP0CTXFrame      ds    60
NP0CTXFrameLength ds   2
NP0CTXSegmentLength ds 2
NP0CTXFlags      ds    2
NP0CTCPRXIPLength ds   2
NP0CTCPRXSegmentLength ds 2
NP0CTCPRXHeaderLength ds 2
NP0CTCPRXExtraHeader ds 2
NP0CTCPRXPayloadLength ds 2

* R0 private socket receive ring state.  Head/tail/used are transport state,
* not diagnostics; all diagnostic sampling occurs in the benchmark harness.
NP0CSockHead       ds 2
NP0CSockTail       ds 2
NP0CSockUsed       ds 2
NP0CLastAdvertisedWindow ds 2
NP0CSockCopyRemain ds 2
NP0CSockSpanLen    ds 2
NP0CSockReadWant   ds 2
NP0CSockReadCount  ds 2
NP0CSockReadChunk  ds 2
NP0CSockReadSrc    ds 4
NP0CSockReadDst    ds 4

TCPConnection    ds    PGTCSize

* 16 KiB software socket ring.  Data is accepted/checksummed here independently
* of any application producer request.
NP0CSocketRing    ds    NP0CSockSize
