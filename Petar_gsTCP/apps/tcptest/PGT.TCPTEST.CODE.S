*=================================================
* PGTTCPTest active-open phase
*
* This is intentionally a wire/state diagnostic rather than the streaming
* hot path.  It obtains a DHCP lease, resolves the TCP server's next-hop MAC,
* sends a checked SYN, accepts only the matching checksum-valid SYN+ACK, and
* sends the final ACK followed by FIN+ACK.  The next gate replaces RXFrame
* staging with the transactional W5100-to-DOC ring copy.
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

TCPLocalPortWire equ $00C0           ; port 49152, bytes $C0,$00
TCPRemotePortWire equ $6619          ; port 6502, bytes $19,$66
TCPSYNFrameLen equ 60
TCPACKFrameLen equ 60
TCPSYNIPLen    equ   44
TCPACKIPLen    equ   40
TCPSYNLen      equ   24
TCPACKLen      equ   20
TCPAdvertisedMSS equ 512             ; keeps the first RX oracle under 600 B
TCPAdvertisedWindow equ 32768
TCPWaitTicks   equ   180              ; three seconds at 60 Hz

RunTCPTest     rep   #$30
                pea   ^TCPTitleMsg
                pea   TCPTitleMsg
                _WriteCString
                pea   ^TCPTargetMsg
                pea   TCPTargetMsg
                _WriteCString
                lda   #TCPRemoteIP
                jsr   PrintIPv4At
                jsr   SelectTCPNextHop
                lda   #3
                sta   RetryCount
PGTTCPARPTry   jsr   BuildTCPARP
                jsr   SendTXFrame
                bcc   PGTTCPARPSendOK
                brl   PGTTCPTransmitFail
PGTTCPARPSendOK
                pea   ^TCPARPMsg
                pea   TCPARPMsg
                _WriteCString
                jsr   WaitTCPARP
                bcc   PGTTCPARPFound
                lda   Aborted
                beq   PGTTCPARPNotStopped
                brl   PGTTCPStopped
PGTTCPARPNotStopped
                dec   RetryCount
                bne   PGTTCPARPTry
                pea   ^TCPARPTimeoutMsg
                pea   TCPARPTimeoutMsg
                _WriteCString
                rts

PGTTCPARPFound pea   ^TCPNextHopMsg
                pea   TCPNextHopMsg
                _WriteCString
                lda   #TCPNextHopMAC
                jsr   PrintMACAt
                jsr   InitializeTCPConnection
                lda   #3
                sta   RetryCount
PGTTCPSYNTry   jsr   BuildTCPSYN
                jsr   SendTXFrame
                bcc   PGTTCPSYNSendOK
                brl   PGTTCPTransmitFail
PGTTCPSYNSendOK
                pea   ^TCPSYNMsg
                pea   TCPSYNMsg
                _WriteCString
                jsr   WaitTCPSYNACK
                bcc   PGTTCPEstablished
                lda   Aborted
                beq   PGTTCPSYNNotStopped
                brl   PGTTCPStopped
PGTTCPSYNNotStopped
                dec   RetryCount
                bne   PGTTCPSYNTry
                pea   ^TCPSYNTimeoutMsg
                pea   TCPSYNTimeoutMsg
                _WriteCString
                rts

PGTTCPEstablished
                jsr   BuildTCPACK
                jsr   SendTXFrame
                bcc   PGTTCPACKSendOK
                brl   PGTTCPTransmitFail
PGTTCPACKSendOK
                ldy   #PGTCAckPending
                lda   #0
                sta   [PGTtcpConn],y
                pea   ^TCPPassMsg
                pea   TCPPassMsg
                _WriteCString
                pea   ^TCPPeerMsg
                pea   TCPPeerMsg
                _WriteCString
                lda   PGTtcpSeq+2
                jsr   WriteHexWord
                lda   PGTtcpSeq
                jsr   WriteHexWord
                pea   ^TCPWindowMsg
                pea   TCPWindowMsg
                _WriteCString
                lda   PGTtcpWindow
                jsr   WriteHexWord
                pea   ^TCPMSSMsg
                pea   TCPMSSMsg
                _WriteCString
                lda   TCPPeerMSS
                jsr   WriteHexWord
                jsr   WriteCRLF

* Close our side immediately so the host listener is reusable.  P3's full
* close state machine will validate the peer ACK/FIN and TIME-WAIT interval.
                jsr   BuildTCPFIN
                jsr   SendTXFrame
                bcc   PGTTCPFINSent
                brl   PGTTCPTransmitFail
PGTTCPFINSent
                ldy   #PGTCState
                lda   #PGTTFinWait1
                sta   [PGTtcpConn],y
                pea   ^TCPFINMsg
                pea   TCPFINMsg
                _WriteCString
                rts

PGTTCPTransmitFail
                pea   ^TCPTXErrorMsg
                pea   TCPTXErrorMsg
                _WriteCString
                rts
PGTTCPStopped   pea   ^AbortedMsg
                pea   AbortedMsg
                _WriteCString
                rts

*-------------------------------------------------
* Address selection and ARP
*-------------------------------------------------

SelectTCPNextHop
                lda   TCPRemoteIP
                and   SubnetMask
                sta   TCPTemp
                lda   OfferedIP
                and   SubnetMask
                cmp   TCPTemp
                bne   PGTTCPUseRouter
                lda   TCPRemoteIP+2
                and   SubnetMask+2
                sta   TCPTemp
                lda   OfferedIP+2
                and   SubnetMask+2
                cmp   TCPTemp
                bne   PGTTCPUseRouter
                lda   TCPRemoteIP
                sta   TCPNextHopIP
                lda   TCPRemoteIP+2
                sta   TCPNextHopIP+2
                rts
PGTTCPUseRouter lda   RouterIP
                sta   TCPNextHopIP
                lda   RouterIP+2
                sta   TCPNextHopIP+2
                rts

BuildTCPARP     rep   #$30
                lda   #0
                ldx   #58
PGTTCPARPZero  sta   TXFrame,x
                dex
                dex
                bpl   PGTTCPARPZero
                lda   #$FFFF
                sta   TXFrame
                sta   TXFrame+2
                sta   TXFrame+4
                ldx   #4
PGTTCPARPMAC   lda   LocalMAC,x
                sta   TXFrame+6,x
                sta   TXFrame+22,x
                dex
                dex
                bpl   PGTTCPARPMAC
                lda   #$0608
                sta   TXFrame+12
                lda   #$0100
                sta   TXFrame+14
                lda   #$0008
                sta   TXFrame+16
                lda   #$0406
                sta   TXFrame+18
                lda   #$0100
                sta   TXFrame+20
                lda   OfferedIP
                sta   TXFrame+28
                lda   OfferedIP+2
                sta   TXFrame+30
                lda   TCPNextHopIP
                sta   TXFrame+38
                lda   TCPNextHopIP+2
                sta   TXFrame+40
                lda   #60
                sta   TXFrameLength
                rts

WaitTCPARP     stz   Aborted
                jsr   StartTCPDeadline
PGTTCPARPPoll  jsr   CheckEscape
                bcc   PGTTCPARPCard
                lda   #1
                sta   Aborted
                sec
                rts
PGTTCPARPCard  jsl   PGTU2BeginRX
                bcs   PGTTCPARPNoFrame
                jsr   CopyAndReleaseRX
                bcs   PGTTCPARPFail
                jsr   ParseTCPARP
                bcc   PGTTCPARPOK
PGTTCPARPNoFrame
                jsr   TCPDeadlineExpired
                bcc   PGTTCPARPPoll
PGTTCPARPFail  sec
                rts
PGTTCPARPOK    clc
                rts

ParseTCPARP    lda   RXCopyLength
                cmp   #42
                bcc   PGTTCPARPReject
                lda   RXFrame+12
                cmp   #$0608
                bne   PGTTCPARPReject
                lda   RXFrame+14
                cmp   #$0100
                bne   PGTTCPARPReject
                lda   RXFrame+16
                cmp   #$0008
                bne   PGTTCPARPReject
                lda   RXFrame+18
                cmp   #$0406
                bne   PGTTCPARPReject
                lda   RXFrame+20
                cmp   #$0200
                bne   PGTTCPARPReject
                lda   RXFrame+28
                cmp   TCPNextHopIP
                bne   PGTTCPARPReject
                lda   RXFrame+30
                cmp   TCPNextHopIP+2
                bne   PGTTCPARPReject
                lda   RXFrame+38
                cmp   OfferedIP
                bne   PGTTCPARPReject
                lda   RXFrame+40
                cmp   OfferedIP+2
                bne   PGTTCPARPReject
                ldx   #4
PGTTCPCopyMAC  lda   RXFrame+22,x
                sta   TCPNextHopMAC,x
                dex
                dex
                bpl   PGTTCPCopyMAC
                clc
                rts
PGTTCPARPReject sec
                rts

*-------------------------------------------------
* Active-open state, transmit constructors and checksums
*-------------------------------------------------

InitializeTCPConnection
                lda   #TCPConnection
                sta   PGTtcpConn
                lda   #^TCPConnection
                sta   PGTtcpConn+2
                lda   #0
                ldx   #PGTCSize-2
PGTTCPClearConn sta   TCPConnection,x
                dex
                dex
                bpl   PGTTCPClearConn
                lda   #49152
                sta   TCPConnection+PGTCLocalPort
                lda   #6502
                sta   TCPConnection+PGTCRemotePort
                lda   TCPRemoteIP
                sta   TCPConnection+PGTCRemoteIP
                lda   TCPRemoteIP+2
                sta   TCPConnection+PGTCRemoteIP+2
                lda   #TCPAdvertisedWindow
                sta   TCPConnection+PGTCRecvWindow
                lda   XID
                eor   >$E100DC
                sta   PGTtcpISS
                lda   XID+2
                eor   LocalMAC+4
                sta   PGTtcpISS+2
                jsl   PGTTCPBeginActive
                rts

BuildTCPSYN     rep   #$30
                lda   #0
                ldx   #58
PGTTCPSYNZero  sta   TXFrame,x
                dex
                dex
                bpl   PGTTCPSYNZero
                jsr   BuildTCPEtherIP
                lda   #TCPSYNIPLen
                jsr   SetTCPIPLength
                lda   #TCPLocalPortWire
                sta   TXFrame+34
                lda   #TCPRemotePortWire
                sta   TXFrame+36
                lda   PGTtcpISS+2
                xba
                sta   TXFrame+38
                lda   PGTtcpISS
                xba
                sta   TXFrame+40
                lda   #$0260           ; data offset 6, SYN
                sta   TXFrame+46
                lda   #TCPAdvertisedWindow
                xba
                sta   TXFrame+48
                lda   #$0402           ; MSS option kind=2,length=4
                sta   TXFrame+54
                lda   #TCPAdvertisedMSS
                xba
                sta   TXFrame+56
                lda   #TCPSYNLen
                sta   TCPSegmentLength
                jsr   FinishTCPFrame
                lda   #TCPSYNFrameLen
                sta   TXFrameLength
                rts

BuildTCPACK     lda   #PGTTCPF_ACK
                bra   BuildTCPControl
BuildTCPFIN     lda   #PGTTCPF_FIN+PGTTCPF_ACK
BuildTCPControl sta   TCPOutFlags
                rep   #$30
                lda   #0
                ldx   #58
PGTTCPACKZero  sta   TXFrame,x
                dex
                dex
                bpl   PGTTCPACKZero
                jsr   BuildTCPEtherIP
                lda   #TCPACKIPLen
                jsr   SetTCPIPLength
                lda   #TCPLocalPortWire
                sta   TXFrame+34
                lda   #TCPRemotePortWire
                sta   TXFrame+36
                ldy   #PGTCSendNext+2
                lda   [PGTtcpConn],y
                xba
                sta   TXFrame+38
                ldy   #PGTCSendNext
                lda   [PGTtcpConn],y
                xba
                sta   TXFrame+40
                ldy   #PGTCRecvNext+2
                lda   [PGTtcpConn],y
                xba
                sta   TXFrame+42
                ldy   #PGTCRecvNext
                lda   [PGTtcpConn],y
                xba
                sta   TXFrame+44
                lda   TCPOutFlags
                and   #$00FF
                xba
                ora   #$0050
                sta   TXFrame+46
                lda   #TCPAdvertisedWindow
                xba
                sta   TXFrame+48
                lda   #TCPACKLen
                sta   TCPSegmentLength
                jsr   FinishTCPFrame
                lda   #TCPACKFrameLen
                sta   TXFrameLength
                rts

BuildTCPEtherIP
                ldx   #4
PGTTCPFrameMAC lda   TCPNextHopMAC,x
                sta   TXFrame,x
                lda   LocalMAC,x
                sta   TXFrame+6,x
                dex
                dex
                bpl   PGTTCPFrameMAC
                lda   #$0008
                sta   TXFrame+12
                lda   #$0045
                sta   TXFrame+14
                lda   PGTtcpISS
                xba
                sta   TXFrame+18
                lda   #$0040           ; don't fragment
                sta   TXFrame+20
                lda   #$0640           ; TTL 64, TCP
                sta   TXFrame+22
                lda   OfferedIP
                sta   TXFrame+26
                lda   OfferedIP+2
                sta   TXFrame+28
                lda   TCPRemoteIP
                sta   TXFrame+30
                lda   TCPRemoteIP+2
                sta   TXFrame+32
                rts

SetTCPIPLength xba
                sta   TXFrame+16
                rts

FinishTCPFrame lda   #TXFrame+14
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   TXFrame+24
                jsr   PrepareTXTCPChecksum
                jsl   PGTChecksum
                xba
                sta   TXFrame+50
                rts

PrepareTXTCPChecksum
                lda   OfferedIP
                sta   TCPChecksumBuffer
                lda   OfferedIP+2
                sta   TCPChecksumBuffer+2
                lda   TCPRemoteIP
                sta   TCPChecksumBuffer+4
                lda   TCPRemoteIP+2
                sta   TCPChecksumBuffer+6
                lda   #$0600
                sta   TCPChecksumBuffer+8
                lda   TCPSegmentLength
                xba
                sta   TCPChecksumBuffer+10
                ldx   #0
PGTTCPTXCSCopy cpx   TCPSegmentLength
                bcs   PGTTCPTXCSDone
                sep   #$20
                lda   TXFrame+34,x
                sta   TCPChecksumBuffer+12,x
                rep   #$20
                inx
                bra   PGTTCPTXCSCopy
PGTTCPTXCSDone lda   #TCPChecksumBuffer
                sta   PGTcsPtr
                lda   #^TCPChecksumBuffer
                sta   PGTcsPtr+2
                lda   TCPSegmentLength
                clc
                adc   #12
                sta   PGTcsLen
                rts

*-------------------------------------------------
* Checked SYN+ACK receive
*-------------------------------------------------

WaitTCPSYNACK  stz   Aborted
                jsr   StartTCPDeadline
                ldy   #PGTCRTODeadline
                lda   TCPDeadline
                sta   [PGTtcpConn],y
PGTTCPSYNACKPoll
                jsr   CheckEscape
                bcc   PGTTCPSYNACKCard
                lda   #1
                sta   Aborted
                sec
                rts
PGTTCPSYNACKCard
                jsl   PGTU2BeginRX
                bcs   PGTTCPSYNACKNoFrame
                jsr   CopyAndReleaseRX
                bcs   PGTTCPSYNACKFail
                jsr   ParseTCPSYNACK
                bcc   PGTTCPSYNACKOK
PGTTCPSYNACKNoFrame
                jsr   TCPDeadlineExpired
                bcc   PGTTCPSYNACKPoll
PGTTCPSYNACKFail sec
                rts
PGTTCPSYNACKOK clc
                rts

ParseTCPSYNACK rep   #$30
                lda   RXCopyLength
                cmp   #54
                bcc   PGTTCPParseRejectA
                lda   RXFrame+12
                cmp   #$0008
                bne   PGTTCPParseRejectA
                lda   RXFrame+14
                and   #$00FF
                cmp   #$0045
                bne   PGTTCPParseRejectA
                lda   RXFrame+20
                xba
                and   #$3FFF
                bne   PGTTCPParseRejectA
                lda   RXFrame+22
                xba
                and   #$00FF
                cmp   #PGTIPTCP
                bne   PGTTCPParseRejectA
                lda   RXFrame+26
                cmp   TCPRemoteIP
                bne   PGTTCPParseRejectA
                lda   RXFrame+28
                cmp   TCPRemoteIP+2
                bne   PGTTCPParseRejectA
                lda   RXFrame+30
                cmp   OfferedIP
                bne   PGTTCPParseRejectA
                lda   RXFrame+32
                cmp   OfferedIP+2
                beq   PGTTCPAddressesOK
PGTTCPParseRejectA sec
                rts
PGTTCPAddressesOK
                lda   RXFrame+16
                xba
                sta   TCPIPLength
                cmp   #40
                bcc   PGTTCPParseRejectB
                clc
                adc   #14
                cmp   RXCopyLength
                bcc   PGTTCPIPBoundsOK
                beq   PGTTCPIPBoundsOK
                bra   PGTTCPParseRejectB
PGTTCPIPBoundsOK
                lda   #RXFrame+14
                sta   PGTcsPtr
                lda   #^RXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                beq   PGTTCPIPChecksumOK
PGTTCPParseRejectB sec
                rts
PGTTCPIPChecksumOK
                lda   RXFrame+34
                cmp   #TCPRemotePortWire
                bne   PGTTCPParseRejectB
                lda   RXFrame+36
                cmp   #TCPLocalPortWire
                bne   PGTTCPParseRejectB
                lda   TCPIPLength
                sec
                sbc   #20
                sta   TCPSegmentLength
                jsr   PrepareRXTCPChecksum
                jsl   PGTChecksum
                bne   PGTTCPParseRejectB
                lda   RXFrame+46
                and   #$00FF
                lsr
                lsr
                lsr
                lsr
                asl
                asl
                sta   TCPHeaderLength
                cmp   #20
                bcc   PGTTCPParseRejectB
                cmp   TCPSegmentLength
                bcc   PGTTCPTCPBoundsOK
                beq   PGTTCPTCPBoundsOK
                bra   PGTTCPParseRejectB
PGTTCPTCPBoundsOK
                cmp   TCPSegmentLength
                bne   PGTTCPParseRejectB ; SYN+ACK must not carry test data
                lda   RXFrame+47
                and   #$003F
                cmp   #PGTTCPF_SYN+PGTTCPF_ACK
                bne   PGTTCPParseRejectB
                jsr   ParseTCPSYNOptions
                bcs   PGTTCPParseRejectB
                lda   RXFrame+40
                xba
                sta   PGTtcpSeq
                lda   RXFrame+38
                xba
                sta   PGTtcpSeq+2
                lda   RXFrame+44
                xba
                sta   PGTtcpAck
                lda   RXFrame+42
                xba
                sta   PGTtcpAck+2
                lda   RXFrame+48
                xba
                sta   PGTtcpWindow
                lda   RXFrame+47
                and   #$00FF
                sta   PGTtcpFlags
                stz   PGTtcpLength
                jsl   PGTTCPAcceptSYNACK
                rts

PrepareRXTCPChecksum
                lda   RXFrame+26
                sta   TCPChecksumBuffer
                lda   RXFrame+28
                sta   TCPChecksumBuffer+2
                lda   RXFrame+30
                sta   TCPChecksumBuffer+4
                lda   RXFrame+32
                sta   TCPChecksumBuffer+6
                lda   #$0600
                sta   TCPChecksumBuffer+8
                lda   TCPSegmentLength
                xba
                sta   TCPChecksumBuffer+10
                ldx   #0
PGTTCPRXCSCopy cpx   TCPSegmentLength
                bcs   PGTTCPRXCSDone
                sep   #$20
                lda   RXFrame+34,x
                sta   TCPChecksumBuffer+12,x
                rep   #$20
                inx
                bra   PGTTCPRXCSCopy
PGTTCPRXCSDone lda   #TCPChecksumBuffer
                sta   PGTcsPtr
                lda   #^TCPChecksumBuffer
                sta   PGTcsPtr+2
                lda   TCPSegmentLength
                clc
                adc   #12
                sta   PGTcsLen
                rts

ParseTCPSYNOptions
                lda   #536
                sta   TCPPeerMSS
                lda   #54
                sta   TCPOptionIndex
                lda   TCPHeaderLength
                clc
                adc   #34
                sta   TCPOptionEnd
PGTTCPOptionLoop
                lda   TCPOptionIndex
                cmp   TCPOptionEnd
                bcc   PGTTCPOptionByte
                clc
                rts
PGTTCPOptionByte tax
                lda   RXFrame,x
                and   #$00FF
                beq   PGTTCPOptionDone
                cmp   #1
                beq   PGTTCPOptionNOP
                sta   TCPOptionKind
                inx
                cpx   TCPOptionEnd
                bcs   PGTTCPOptionBad
                lda   RXFrame,x
                and   #$00FF
                cmp   #2
                bcc   PGTTCPOptionBad
                sta   TCPOptionLength
                clc
                adc   TCPOptionIndex
                cmp   TCPOptionEnd
                bcc   PGTTCPOptionBoundsOK
                beq   PGTTCPOptionBoundsOK
                bra   PGTTCPOptionBad
PGTTCPOptionBoundsOK
                sta   TCPOptionIndex
                lda   TCPOptionKind
                cmp   #2
                bne   PGTTCPOptionLoop
                lda   TCPOptionLength
                cmp   #4
                bne   PGTTCPOptionLoop
                dex
                lda   RXFrame+2,x
                xba
                cmp   #536
                bcc   PGTTCPOptionLoop
                cmp   #PGTTCPMSS+1
                bcc   PGTTCPMSSStore
                lda   #PGTTCPMSS
PGTTCPMSSStore sta   TCPPeerMSS
                bra   PGTTCPOptionLoop
PGTTCPOptionNOP inc   TCPOptionIndex
                bra   PGTTCPOptionLoop
PGTTCPOptionDone clc
                rts
PGTTCPOptionBad sec
                rts

StartTCPDeadline
                lda   >$E100DC
                clc
                adc   #TCPWaitTicks
                sta   TCPDeadline
                rts
TCPDeadlineExpired
                lda   >$E100DC
                sec
                sbc   TCPDeadline
                bmi   PGTTCPDeadlineOpen
                sec
                rts
PGTTCPDeadlineOpen clc
                rts

*-------------------------------------------------
* Private state and user-visible results
*-------------------------------------------------

TCPConnection   ds    PGTCSize
TCPNextHopIP    ds    4
TCPNextHopMAC   ds    6
TCPTemp         ds    2
TCPDeadline     ds    2
TCPIPLength     ds    2
TCPSegmentLength ds  2
TCPHeaderLength ds    2
TCPOptionIndex  ds    2
TCPOptionEnd    ds    2
TCPOptionKind   ds    2
TCPOptionLength ds    2
TCPPeerMSS      ds    2
TCPOutFlags     ds    2
TCPChecksumBuffer ds  620

TCPRemoteIP     hex   C0A805EB       ; 192.168.5.235

TCPTitleMsg     asc   0D,'P3 native TCP active open; Marinetti off.',0D,00
TCPTargetMsg    asc   'TCP target: $',00
TCPARPMsg       asc   'ARP for TCP next hop; waiting...',0D,00
TCPARPTimeoutMsg asc  'TCP next-hop ARP timed out.',0D,00
TCPNextHopMsg   asc   'TCP next-hop MAC: $',00
TCPSYNMsg       asc   'TCP SYN sent; waiting for checked SYN+ACK...',0D,00
TCPSYNTimeoutMsg asc  'No valid SYN+ACK after three attempts.',0D,00
TCPPassMsg      asc   'PASS: native TCP active open established.',0D,00
TCPPeerMsg      asc   'Peer SEQ=$',00
TCPWindowMsg    asc   ' window=$',00
TCPMSSMsg       asc   ' MSS=$',00
TCPFINMsg       asc   'FIN+ACK sent; active close handoff complete.',0D,00
TCPTXErrorMsg   asc   'W5100 TCP-phase transmit failed.',0D,00
