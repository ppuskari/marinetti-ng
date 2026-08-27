*=================================================
* PGTDHCPTest application code
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

GSOS            equ   $E100A8
QuitCall        equ   $2029
TextTool        equ   $000C
RXCopyMax       equ   600
TXBufferSize    equ   620
DiscoverLen     equ   304
RequestLen      equ   316
DiscoverIPLen   equ   290
RequestIPLen    equ   302
DiscoverUDPLen  equ   270
RequestUDPLen   equ   282
DHCPOptions     equ   282
DHCPDiscover    equ   1
DHCPOffer       equ   2
DHCPRequest     equ   3
DHCPAck         equ   5
DHCPNak         equ   6

Start           clc
                xce
                rep   #$30
                phk
                plb
                stz   TLStarted
                stz   MMStarted
                stz   TextLoaded
                stz   TextActive
                stz   DPHandle
                stz   DPHandle+2
                stz   RawActive
                stz   RXFrameCount
                stz   TXFrameCount
                stz   Aborted
                tdc
                sta   SavedDP

                _TLStartUp
                lda   #1
                sta   TLStarted
                pha
                _MMStartUp
                pla
                sta   MasterID
                ora   #$0100
                sta   MemoryID
                lda   #1
                sta   MMStarted

                jsr   StartConsole
                bcc   PGTDHCPConsoleReady
                brl   ExitProgram
PGTDHCPConsoleReady jsr AllocateDirectPage
                bcc   PGTDHCPDPReady
                pea   ^DPErrorMsg
                pea   DPErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTDHCPDPReady  pea   ^TitleMsg
                pea   TitleMsg
                _WriteCString
                pea   ^SafetyMsg
                pea   SafetyMsg
                _WriteCString
                jsr   ReadSlot
                bcc   PGTDHCPSlotReady
                brl   WaitAndExit
PGTDHCPSlotReady lda  SelectedSlot
                jsl   PGTU2SelectSlot
                bcc   PGTDHCPSlotSelected
                brl   PGTNoCard
PGTDHCPSlotSelected jsl PGTU2Probe
                bcc   PGTDHCPCardProbed
                brl   PGTNoCard

PGTDHCPCardProbed
                jsr   LoadMAC
                jsr   BuildXID
                pea   ^FoundMsg
                pea   FoundMsg
                _WriteCString
                lda   SelectedSlot
                jsr   WriteHexByte
                jsr   WriteCRLF
                jsr   PrintIdentity
                jsr   MACValid
                bcc   PGTDHCPMACOK
                pea   ^MACErrorMsg
                pea   MACErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTDHCPMACOK    jsl   PGTU2StartRaw
                bcc   PGTDHCPRawStarted
                brl   PGTStartFailed
PGTDHCPRawStarted
                lda   #1
                sta   RawActive
                stz   PGTu2WrapCount
                stz   PGTu2TXWrapCount
                jsr   ClearLease

                lda   #3
                sta   RetryCount
PGTDiscoverTry  jsr   BuildDiscover
                jsr   SendTXFrame
                bcc   PGTDiscoverSent
                brl   PGTTXFailed
PGTDiscoverSent pea   ^DiscoverMsg
                pea   DiscoverMsg
                _WriteCString
                lda   #DHCPOffer
                sta   ExpectedType
                jsr   WaitDHCPReply
                bcc   PGTOfferReceived
                lda   Aborted
                beq   PGTDiscoverNotAborted
                brl   PGTAborted
PGTDiscoverNotAborted
                dec   RetryCount
                bne   PGTDiscoverTry
                pea   ^OfferTimeoutMsg
                pea   OfferTimeoutMsg
                _WriteCString
                brl   PrintStatsAndExit

PGTOfferReceived
                pea   ^OfferMsg
                pea   OfferMsg
                _WriteCString
                lda   #OfferedIP
                jsr   PrintIPv4At
                pea   ^ServerMsg
                pea   ServerMsg
                _WriteCString
                lda   #ServerIP
                jsr   PrintIPv4At

                jsr   ClearAckOptions
                lda   #3
                sta   RetryCount
PGTRequestTry   jsr   BuildRequest
                jsr   SendTXFrame
                bcc   PGTRequestSent
                brl   PGTTXFailed
PGTRequestSent  pea   ^RequestMsg
                pea   RequestMsg
                _WriteCString
                lda   #DHCPAck
                sta   ExpectedType
                jsr   WaitDHCPReply
                bcc   PGTAckReceived
                lda   Aborted
                beq   PGTRequestNotAborted
                brl   PGTAborted
PGTRequestNotAborted
                lda   LastDHCPType
                cmp   #DHCPNak
                beq   PGTNakReceived
                dec   RetryCount
                bne   PGTRequestTry
                pea   ^AckTimeoutMsg
                pea   AckTimeoutMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTNakReceived  pea   ^NakMsg
                pea   NakMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTAckReceived  jsr   LeaseValid
                bcc   PGTLeaseReady
                pea   ^LeaseErrorMsg
                pea   LeaseErrorMsg
                _WriteCString
                bra   PrintStatsAndExit
PGTLeaseReady   jsr   ApplyLease
                pea   ^PassMsg
                pea   PassMsg
                _WriteCString
                jsr   PrintLease
                do    DNS_PHASE
                jsr   RunDNSTest
                fin
                do    TCP_PHASE
                jsr   RunTCPTest
                fin
                bra   PrintStatsAndExit

PGTAborted      pea   ^AbortedMsg
                pea   AbortedMsg
                _WriteCString
                bra   PrintStatsAndExit
PGTTXFailed     pea   ^TXErrorMsg
                pea   TXErrorMsg
                _WriteCString
                bra   PrintStatsAndExit
PGTNoCard       pea   ^NoCardMsg
                pea   NoCardMsg
                _WriteCString
                bra   WaitAndExit
PGTStartFailed  pea   ^StartErrorMsg
                pea   StartErrorMsg
                _WriteCString
                bra   WaitAndExit

PrintStatsAndExit
                pea   ^StatsTXMsg
                pea   StatsTXMsg
                _WriteCString
                lda   TXFrameCount
                jsr   WriteHexWord
                pea   ^StatsRXMsg
                pea   StatsRXMsg
                _WriteCString
                lda   RXFrameCount
                jsr   WriteHexWord
                pea   ^StatsWrapMsg
                pea   StatsWrapMsg
                _WriteCString
                lda   PGTu2WrapCount
                jsr   WriteHexWord
                jsr   WriteCRLF

WaitAndExit     pea   ^ExitMsg
                pea   ExitMsg
                _WriteCString
                pea   $0000
                pea   $0000
                _ReadChar
                pla
ExitProgram     jsr   ShutEverything
                jsl   GSOS
                dw    QuitCall
                adrl  QuitPB
PGTQuitReturned bra   PGTQuitReturned

*-------------------------------------------------
* DHCP packet construction
*-------------------------------------------------

BuildDiscover   lda   #DHCPDiscover
                sta   OutMessageType
                lda   #DiscoverLen
                sta   TXFrameLength
                lda   #DiscoverIPLen
                sta   OutIPLength
                lda   #DiscoverUDPLen
                sta   OutUDPLength
                jsr   BuildClientBase
                ldx   #0
PGTDiscoverParams
                sep   #$20
                lda   ParameterList,x
                sta   TXFrame+294,x
                rep   #$20
                inx
                cpx   #10
                bne   PGTDiscoverParams
                jsr   FinishClientFrame
                rts

BuildRequest    lda   #DHCPRequest
                sta   OutMessageType
                lda   #RequestLen
                sta   TXFrameLength
                lda   #RequestIPLen
                sta   OutIPLength
                lda   #RequestUDPLen
                sta   OutUDPLength
                jsr   BuildClientBase
                sep   #$20
                lda   #50
                sta   TXFrame+294
                lda   #4
                sta   TXFrame+295
                rep   #$20
                lda   OfferedIP
                sta   TXFrame+296
                lda   OfferedIP+2
                sta   TXFrame+298
                sep   #$20
                lda   #54
                sta   TXFrame+300
                lda   #4
                sta   TXFrame+301
                rep   #$20
                lda   ServerIP
                sta   TXFrame+302
                lda   ServerIP+2
                sta   TXFrame+304
                ldx   #0
PGTRequestParams
                sep   #$20
                lda   ParameterList,x
                sta   TXFrame+306,x
                rep   #$20
                inx
                cpx   #10
                bne   PGTRequestParams
                jsr   FinishClientFrame
                rts

BuildClientBase rep   #$30
                lda   #0
                ldx   #TXBufferSize-2
PGTClientZero   sta   TXFrame,x
                dex
                dex
                bpl   PGTClientZero
                lda   #$FFFF
                sta   TXFrame
                sta   TXFrame+2
                sta   TXFrame+4
                ldx   #4
PGTClientMACs   lda   LocalMAC,x
                sta   TXFrame+6,x
                sta   TXFrame+70,x
                dex
                dex
                bpl   PGTClientMACs
                lda   #$0008
                sta   TXFrame+12
                lda   #$0045
                sta   TXFrame+14
                lda   OutIPLength
                xba
                sta   TXFrame+16
                lda   XID+2
                sta   TXFrame+18
                lda   #$0040
                sta   TXFrame+20
                lda   #$1140
                sta   TXFrame+22
                lda   #$FFFF
                sta   TXFrame+30
                sta   TXFrame+32
                lda   #$4400
                sta   TXFrame+34
                lda   #$4300
                sta   TXFrame+36
                lda   OutUDPLength
                xba
                sta   TXFrame+38
                lda   #$0101
                sta   TXFrame+42
                lda   #$0006
                sta   TXFrame+44
                lda   XID
                sta   TXFrame+46
                lda   XID+2
                sta   TXFrame+48
                lda   #$0080
                sta   TXFrame+52
                lda   #$8263
                sta   TXFrame+278
                lda   #$6353
                sta   TXFrame+280
                sep   #$20
                lda   #53
                sta   TXFrame+282
                lda   #1
                sta   TXFrame+283
                lda   OutMessageType
                sta   TXFrame+284
                lda   #61
                sta   TXFrame+285
                lda   #7
                sta   TXFrame+286
                lda   #1
                sta   TXFrame+287
                rep   #$20
                ldx   #4
PGTClientID     lda   LocalMAC,x
                sta   TXFrame+288,x
                dex
                dex
                bpl   PGTClientID
                rts

FinishClientFrame
                lda   #TXFrame+14
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   TXFrame+24
                rts

SendTXFrame     lda   #TXFrame
                sta   PGTu2TXPtr
                lda   #^TXFrame
                sta   PGTu2TXPtr+2
                lda   TXFrameLength
                sta   PGTu2TXLen
                jsl   PGTU2SendFrame
                bcs   PGTDHCPSendReturn
                inc   TXFrameCount
PGTDHCPSendReturn rts

*-------------------------------------------------
* Receive loop and DHCP validation
*-------------------------------------------------

WaitDHCPReply   stz   Aborted
                stz   LastDHCPType
                lda   #$FFFF
                sta   PollCount
PGTDHCPPoll     jsr   CheckEscape
                bcc   PGTDHCPPollCard
                lda   #1
                sta   Aborted
                sec
                rts
PGTDHCPPollCard jsl   PGTU2BeginRX
                bcs   PGTDHCPNoFrame
                jsr   CopyAndReleaseRX
                bcs   PGTDHCPReceiveFail
                jsr   ParseDHCPReply
                bcc   PGTDHCPReplyOK
                lda   LastDHCPType
                cmp   #DHCPNak
                beq   PGTDHCPReceiveFail
PGTDHCPNoFrame  dec   PollCount
                bne   PGTDHCPPoll
PGTDHCPReceiveFail sec
                rts
PGTDHCPReplyOK  clc
                rts

CopyAndReleaseRX
                rep   #$30
                inc   RXFrameCount
                stz   RXCopyLength
                ldx   #0
PGTDHCPCopyLoop cpx   #RXCopyMax
                bcs   PGTDHCPCopyDone
                jsl   PGTU2ReadFrame8
                bcs   PGTDHCPCopyDone
                sep   #$20
                sta   RXFrame,x
                rep   #$20
                inx
                bra   PGTDHCPCopyLoop
PGTDHCPCopyDone stx   RXCopyLength
                jsl   PGTU2ReleaseRX
                rts

ParseDHCPReply  rep   #$30
                stz   LastDHCPType
                lda   RXCopyLength
                cmp   #285
                bcs   PGTDHCPSizeOK
                sec
                rts
PGTDHCPSizeOK   lda   RXFrame+12
                cmp   #$0008
                beq   PGTDHCPEtherOK
                sec
                rts
PGTDHCPEtherOK  lda   RXFrame+14
                and   #$00FF
                cmp   #$0045
                beq   PGTDHCPIHLOK
                sec
                rts
PGTDHCPIHLOK    lda   RXFrame+22
                xba
                and   #$00FF
                cmp   #PGTIPUDP
                beq   PGTDHCPProtoOK
                sec
                rts
PGTDHCPProtoOK  lda   RXFrame+20
                xba
                and   #$3FFF
                beq   PGTDHCPFragOK
                sec
                rts
PGTDHCPFragOK   lda   RXFrame+16
                xba
                sta   InIPLength
                cmp   #268
                bcs   PGTDHCPIPMinOK
                sec
                rts
PGTDHCPIPMinOK  clc
                adc   #14
                cmp   RXCopyLength
                bcc   PGTDHCPIPBoundsOK
                beq   PGTDHCPIPBoundsOK
                sec
                rts
PGTDHCPIPBoundsOK
                lda   #RXFrame+14
                sta   PGTcsPtr
                lda   #^RXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                beq   PGTDHCPIPChecksumOK
                sec
                rts
PGTDHCPIPChecksumOK
                lda   RXFrame+34
                cmp   #$4300
                beq   PGTDHCPSrcPortOK
                sec
                rts
PGTDHCPSrcPortOK lda  RXFrame+36
                cmp   #$4400
                beq   PGTDHCPDstPortOK
                sec
                rts
PGTDHCPDstPortOK lda  RXFrame+38
                xba
                sta   InUDPLength
                cmp   #248
                bcs   PGTDHCPUDPMinOK
                sec
                rts
PGTDHCPUDPMinOK clc
                adc   #20
                cmp   InIPLength
                bcc   PGTDHCPUDPIPBoundsOK
                beq   PGTDHCPUDPIPBoundsOK
                sec
                rts
PGTDHCPUDPIPBoundsOK
                lda   InUDPLength
                clc
                adc   #34
                cmp   RXCopyLength
                bcc   PGTDHCPUDPBoundsOK
                beq   PGTDHCPUDPBoundsOK
                sec
                rts
PGTDHCPUDPBoundsOK
                lda   RXFrame+40
                beq   PGTDHCPUDPChecksumOK
                jsr   ValidateUDPChecksum
                bcc   PGTDHCPUDPChecksumOK
                sec
                rts
PGTDHCPUDPChecksumOK
                lda   RXFrame+42
                cmp   #$0102
                beq   PGTDHCPBootOpOK
                sec
                rts
PGTDHCPBootOpOK lda   RXFrame+44
                cmp   #$0006
                beq   PGTDHCPBootHWOK
                sec
                rts
PGTDHCPBootHWOK lda   RXFrame+46
                cmp   XID
                beq   PGTDHCPXIDHighOK
                sec
                rts
PGTDHCPXIDHighOK lda  RXFrame+48
                cmp   XID+2
                beq   PGTDHCPXIDLowOK
                sec
                rts
PGTDHCPXIDLowOK ldx   #4
PGTDHCPCheckMAC lda   RXFrame+70,x
                cmp   LocalMAC,x
                bne   PGTDHCPIdentityBad
                dex
                dex
                bpl   PGTDHCPCheckMAC
                bra   PGTDHCPIdentityOK
PGTDHCPIdentityBad sec
                rts
PGTDHCPIdentityOK
                lda   RXFrame+278
                cmp   #$8263
                bne   PGTDHCPCookieBad
                lda   RXFrame+280
                cmp   #$6353
                beq   PGTDHCPCookieOK
PGTDHCPCookieBad sec
                rts
PGTDHCPCookieOK
                lda   RXFrame+58
                ora   RXFrame+60
                beq   PGTDHCPNoNewIP
                lda   RXFrame+58
                sta   OfferedIP
                lda   RXFrame+60
                sta   OfferedIP+2
PGTDHCPNoNewIP  lda   #DHCPOptions
                sta   OptionIndex
                lda   InUDPLength
                clc
                adc   #34
                sta   OptionEnd

PGTDHCPOptionLoop
                lda   OptionIndex
                cmp   OptionEnd
                bcc   PGTDHCPOptionCode
                sec
                rts
PGTDHCPOptionCode tax
                sep   #$20
                lda   RXFrame,x
                sta   OptionCode
                rep   #$20
                inc   OptionIndex
                lda   OptionCode
                and   #$00FF
                beq   PGTDHCPOptionLoop
                cmp   #255
                bne   PGTDHCPOptionHasData
                brl   PGTDHCPOptionsDone
PGTDHCPOptionHasData
                lda   OptionIndex
                cmp   OptionEnd
                bcc   PGTDHCPOptionLength
                sec
                rts
PGTDHCPOptionLength tax
                sep   #$20
                lda   RXFrame,x
                sta   OptionLength
                rep   #$20
                inc   OptionIndex
                lda   OptionLength
                and   #$00FF
                clc
                adc   OptionIndex
                sta   OptionNext
                cmp   OptionEnd
                bcc   PGTDHCPOptionDispatch
                beq   PGTDHCPOptionDispatch
                sec
                rts

PGTDHCPOptionDispatch
                lda   OptionCode
                and   #$00FF
                cmp   #53
                beq   PGTDHCPMessageOption
                cmp   #1
                beq   PGTDHCPMaskOption
                cmp   #3
                beq   PGTDHCPRouterOption
                cmp   #6
                beq   PGTDHCPDNSOption
                cmp   #54
                bne   PGTDHCPCheckLeaseOption
                brl   PGTDHCPServerOption
PGTDHCPCheckLeaseOption
                cmp   #51
                bne   PGTDHCPUnknownOption
                brl   PGTDHCPLeaseOption
PGTDHCPUnknownOption
                brl   PGTDHCPOptionNext

PGTDHCPMessageOption
                lda   OptionLength
                and   #$00FF
                cmp   #1
                bne   PGTDHCPOptionAdvance
                ldx   OptionIndex
                sep   #$20
                lda   RXFrame,x
                sta   LastDHCPType
                rep   #$20
                bra   PGTDHCPOptionAdvance

PGTDHCPMaskOption
                lda   OptionLength
                and   #$00FF
                cmp   #4
                bne   PGTDHCPOptionAdvance
                ldx   OptionIndex
                lda   RXFrame,x
                sta   SubnetMask
                lda   RXFrame+2,x
                sta   SubnetMask+2
                bra   PGTDHCPOptionAdvance

PGTDHCPRouterOption
                lda   OptionLength
                and   #$00FF
                cmp   #4
                bcc   PGTDHCPOptionAdvance
                ldx   OptionIndex
                lda   RXFrame,x
                sta   RouterIP
                lda   RXFrame+2,x
                sta   RouterIP+2
                bra   PGTDHCPOptionAdvance

PGTDHCPOptionAdvance
                brl   PGTDHCPOptionNext

PGTDHCPDNSOption
                lda   OptionLength
                and   #$00FF
                cmp   #4
                bcc   PGTDHCPOptionAdvance
                ldx   OptionIndex
                lda   RXFrame,x
                sta   DNS1
                lda   RXFrame+2,x
                sta   DNS1+2
                lda   OptionLength
                and   #$00FF
                cmp   #8
                bcc   PGTDHCPOptionAdvance
                lda   RXFrame+4,x
                sta   DNS2
                lda   RXFrame+6,x
                sta   DNS2+2
                bra   PGTDHCPOptionAdvance

PGTDHCPServerOption
                lda   OptionLength
                and   #$00FF
                cmp   #4
                bne   PGTDHCPOptionAdvance
                ldx   OptionIndex
                lda   RXFrame,x
                sta   ServerIP
                lda   RXFrame+2,x
                sta   ServerIP+2
                bra   PGTDHCPOptionAdvance

PGTDHCPLeaseOption
                lda   OptionLength
                and   #$00FF
                cmp   #4
                bne   PGTDHCPOptionAdvance
                ldx   OptionIndex
                lda   RXFrame,x
                sta   LeaseTime
                lda   RXFrame+2,x
                sta   LeaseTime+2

PGTDHCPOptionNext
                lda   OptionNext
                sta   OptionIndex
                brl   PGTDHCPOptionLoop

PGTDHCPOptionsDone
                lda   LastDHCPType
                and   #$00FF
                cmp   ExpectedType
                beq   PGTDHCPExpectedReply
                sec
                rts
PGTDHCPExpectedReply
                lda   OfferedIP
                ora   OfferedIP+2
                beq   PGTDHCPMissingRequired
                lda   ExpectedType
                cmp   #DHCPOffer
                bne   PGTDHCPParsed
                lda   ServerIP
                ora   ServerIP+2
                beq   PGTDHCPMissingRequired
PGTDHCPParsed   clc
                rts
PGTDHCPMissingRequired sec
                rts

ValidateUDPChecksum
                rep   #$30
                lda   RXFrame+26
                sta   TXFrame
                lda   RXFrame+28
                sta   TXFrame+2
                lda   RXFrame+30
                sta   TXFrame+4
                lda   RXFrame+32
                sta   TXFrame+6
                stz   TXFrame+8
                sep   #$20
                lda   #PGTIPUDP
                sta   TXFrame+9
                rep   #$20
                lda   RXFrame+38
                sta   TXFrame+10
                ldx   #0
PGTDHCPUDPCopy  cpx   InUDPLength
                bcs   PGTDHCPUDPCopied
                sep   #$20
                lda   RXFrame+34,x
                sta   TXFrame+12,x
                rep   #$20
                inx
                bra   PGTDHCPUDPCopy
PGTDHCPUDPCopied
                lda   #TXFrame
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   InUDPLength
                clc
                adc   #12
                sta   PGTcsLen
                jsl   PGTChecksum
                beq   PGTDHCPUDPValid
                sec
                rts
PGTDHCPUDPValid clc
                rts

                do    DNS_PHASE
*-------------------------------------------------
* End-to-end DNS test: next-hop ARP, query and response parser
*-------------------------------------------------

RunDNSTest      lda   DNS1
                ora   DNS1+2
                bne   PGTDNSHasServer
                pea   ^DNSMissingMsg
                pea   DNSMissingMsg
                _WriteCString
                rts
PGTDNSHasServer jsr   SelectDNSNextHop
                lda   #3
                sta   RetryCount
PGTDNSARPTry    jsr   BuildDNSARP
                jsr   SendTXFrame
                bcc   PGTDNSARPSent
                pea   ^DNSTXErrorMsg
                pea   DNSTXErrorMsg
                _WriteCString
                rts
PGTDNSARPSent   pea   ^DNSARPMsg
                pea   DNSARPMsg
                _WriteCString
                jsr   WaitDNSARP
                bcc   PGTDNSARPFound
                lda   Aborted
                beq   PGTDNSARPNotStopped
                brl   PGTDNSStopped
PGTDNSARPNotStopped
                dec   RetryCount
                bne   PGTDNSARPTry
                pea   ^DNSARPTimeoutMsg
                pea   DNSARPTimeoutMsg
                _WriteCString
                rts
PGTDNSARPFound  pea   ^DNSMACMsg
                pea   DNSMACMsg
                _WriteCString
                lda   #NextHopMAC
                jsr   PrintMACAt
                jsr   BuildDNSID
                lda   #3
                sta   RetryCount
PGTDNSQueryTry  jsr   BuildDNSQuery
                jsr   SendTXFrame
                bcc   PGTDNSQuerySent
                pea   ^DNSTXErrorMsg
                pea   DNSTXErrorMsg
                _WriteCString
                rts
PGTDNSQuerySent pea   ^DNSQueryMsg
                pea   DNSQueryMsg
                _WriteCString
                jsr   WaitDNSReply
                bcc   PGTDNSResolved
                lda   Aborted
                beq   PGTDNSQueryNotStopped
                brl   PGTDNSStopped
PGTDNSQueryNotStopped
                dec   RetryCount
                bne   PGTDNSQueryTry
                pea   ^DNSTimeoutMsg
                pea   DNSTimeoutMsg
                _WriteCString
                rts
PGTDNSResolved  pea   ^DNSPassMsg
                pea   DNSPassMsg
                _WriteCString
                lda   #ResolvedIP
                jsr   PrintIPv4At
                rts
PGTDNSStopped   pea   ^AbortedMsg
                pea   AbortedMsg
                _WriteCString
                rts

SelectDNSNextHop
                lda   DNS1
                and   SubnetMask
                sta   DNSTemp
                lda   OfferedIP
                and   SubnetMask
                cmp   DNSTemp
                bne   PGTDNSUseRouter
                lda   DNS1+2
                and   SubnetMask+2
                sta   DNSTemp
                lda   OfferedIP+2
                and   SubnetMask+2
                cmp   DNSTemp
                bne   PGTDNSUseRouter
                lda   DNS1
                sta   NextHopIP
                lda   DNS1+2
                sta   NextHopIP+2
                rts
PGTDNSUseRouter lda   RouterIP
                sta   NextHopIP
                lda   RouterIP+2
                sta   NextHopIP+2
                rts

BuildDNSARP     rep   #$30
                lda   #0
                ldx   #58
PGTDNSARPZero   sta   TXFrame,x
                dex
                dex
                bpl   PGTDNSARPZero
                lda   #$FFFF
                sta   TXFrame
                sta   TXFrame+2
                sta   TXFrame+4
                ldx   #4
PGTDNSARPMAC    lda   LocalMAC,x
                sta   TXFrame+6,x
                sta   TXFrame+22,x
                dex
                dex
                bpl   PGTDNSARPMAC
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
                lda   NextHopIP
                sta   TXFrame+38
                lda   NextHopIP+2
                sta   TXFrame+40
                lda   #60
                sta   TXFrameLength
                rts

WaitDNSARP      stz   Aborted
                lda   #$FFFF
                sta   PollCount
PGTDNSARPPoll   jsr   CheckEscape
                bcc   PGTDNSARPCard
                lda   #1
                sta   Aborted
                sec
                rts
PGTDNSARPCard   jsl   PGTU2BeginRX
                bcs   PGTDNSARPNoFrame
                jsr   CopyAndReleaseRX
                bcs   PGTDNSARPFail
                jsr   ParseDNSARP
                bcc   PGTDNSARPOK
PGTDNSARPNoFrame dec  PollCount
                bne   PGTDNSARPPoll
PGTDNSARPFail   sec
                rts
PGTDNSARPOK     clc
                rts

ParseDNSARP     lda   RXCopyLength
                cmp   #42
                bcs   PGTDNSARPSizeOK
                sec
                rts
PGTDNSARPSizeOK lda   RXFrame+12
                cmp   #$0608
                bne   PGTDNSARPReject
                lda   RXFrame+14
                cmp   #$0100
                bne   PGTDNSARPReject
                lda   RXFrame+16
                cmp   #$0008
                bne   PGTDNSARPReject
                lda   RXFrame+18
                cmp   #$0406
                bne   PGTDNSARPReject
                lda   RXFrame+20
                cmp   #$0200
                bne   PGTDNSARPReject
                lda   RXFrame+28
                cmp   NextHopIP
                bne   PGTDNSARPReject
                lda   RXFrame+30
                cmp   NextHopIP+2
                bne   PGTDNSARPReject
                lda   RXFrame+38
                cmp   OfferedIP
                bne   PGTDNSARPReject
                lda   RXFrame+40
                cmp   OfferedIP+2
                bne   PGTDNSARPReject
                ldx   #4
PGTDNSCopyMAC   lda   RXFrame+22,x
                sta   NextHopMAC,x
                dex
                dex
                bpl   PGTDNSCopyMAC
                clc
                rts
PGTDNSARPReject sec
                rts

BuildDNSID      lda   >$E100DC
                eor   XID
                sta   DNSID
                rts

BuildDNSQuery   rep   #$30
                lda   #0
                ldx   #70
PGTDNSQueryZero sta   TXFrame,x
                dex
                dex
                bpl   PGTDNSQueryZero
                ldx   #4
PGTDNSQueryMACs lda   NextHopMAC,x
                sta   TXFrame,x
                lda   LocalMAC,x
                sta   TXFrame+6,x
                dex
                dex
                bpl   PGTDNSQueryMACs
                lda   #$0008
                sta   TXFrame+12
                lda   #$0045
                sta   TXFrame+14
                lda   #$3900
                sta   TXFrame+16
                lda   DNSID
                sta   TXFrame+18
                lda   #$0040
                sta   TXFrame+20
                lda   #$1140
                sta   TXFrame+22
                lda   OfferedIP
                sta   TXFrame+26
                lda   OfferedIP+2
                sta   TXFrame+28
                lda   DNS1
                sta   TXFrame+30
                lda   DNS1+2
                sta   TXFrame+32
                lda   #$6619
                sta   TXFrame+34
                lda   #$3500
                sta   TXFrame+36
                lda   #$2500
                sta   TXFrame+38
                lda   DNSID
                sta   TXFrame+42
                lda   #$0001
                sta   TXFrame+44
                lda   #$0100
                sta   TXFrame+46
                ldx   #0
PGTDNSQuestionCopy
                sep   #$20
                lda   DNSQuestion,x
                sta   TXFrame+54,x
                rep   #$20
                inx
                cpx   #17
                bne   PGTDNSQuestionCopy
                lda   #TXFrame+14
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   TXFrame+24
                lda   #71
                sta   TXFrameLength
                rts

WaitDNSReply    stz   Aborted
                lda   #$FFFF
                sta   PollCount
PGTDNSPoll      jsr   CheckEscape
                bcc   PGTDNSPollCard
                lda   #1
                sta   Aborted
                sec
                rts
PGTDNSPollCard  jsl   PGTU2BeginRX
                bcs   PGTDNSNoFrame
                jsr   CopyAndReleaseRX
                bcs   PGTDNSReceiveFail
                jsr   ParseDNSReply
                bcc   PGTDNSReplyOK
PGTDNSNoFrame   dec   PollCount
                bne   PGTDNSPoll
PGTDNSReceiveFail sec
                rts
PGTDNSReplyOK   clc
                rts

ParseDNSReply   rep   #$30
                lda   RXCopyLength
                cmp   #62
                bcs   PGTDNSSizeOK
                sec
                rts
PGTDNSSizeOK    lda   RXFrame+12
                cmp   #$0008
                beq   PGTDNSEtherOK
                sec
                rts
PGTDNSEtherOK   lda   RXFrame+14
                and   #$00FF
                cmp   #$0045
                beq   PGTDNSIHLOK
                sec
                rts
PGTDNSIHLOK     lda   RXFrame+22
                xba
                and   #$00FF
                cmp   #PGTIPUDP
                beq   PGTDNSProtoOK
                sec
                rts
PGTDNSProtoOK   lda   RXFrame+26
                pha
                lda   RXFrame+20
                xba
                and   #$3FFF
                beq   PGTDNSFragOK
                pla
                sec
                rts
PGTDNSFragOK    pla
                cmp   DNS1
                bne   PGTDNSHeaderReject
                lda   RXFrame+28
                cmp   DNS1+2
                bne   PGTDNSHeaderReject
                lda   RXFrame+30
                cmp   OfferedIP
                bne   PGTDNSHeaderReject
                lda   RXFrame+32
                cmp   OfferedIP+2
                beq   PGTDNSAddressesOK
PGTDNSHeaderReject sec
                rts
PGTDNSAddressesOK
                lda   RXFrame+16
                xba
                sta   InIPLength
                clc
                adc   #14
                cmp   RXCopyLength
                bcc   PGTDNSIPBoundsOK
                beq   PGTDNSIPBoundsOK
                sec
                rts
PGTDNSIPBoundsOK
                lda   #RXFrame+14
                sta   PGTcsPtr
                lda   #^RXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                beq   PGTDNSIPChecksumOK
                sec
                rts
PGTDNSIPChecksumOK
                lda   RXFrame+34
                cmp   #$3500
                bne   PGTDNSPortReject
                lda   RXFrame+36
                cmp   #$6619
                beq   PGTDNSPortsOK
PGTDNSPortReject sec
                rts
PGTDNSPortsOK   lda   RXFrame+38
                xba
                sta   InUDPLength
                cmp   #20
                bcs   PGTDNSUDPMinOK
                sec
                rts
PGTDNSUDPMinOK  clc
                adc   #20
                cmp   InIPLength
                bcc   PGTDNSUDPIPBoundsOK
                beq   PGTDNSUDPIPBoundsOK
                sec
                rts
PGTDNSUDPIPBoundsOK
                lda   InUDPLength
                clc
                adc   #34
                sta   DNSEnd
                cmp   RXCopyLength
                bcc   PGTDNSUDPBoundsOK
                beq   PGTDNSUDPBoundsOK
                sec
                rts
PGTDNSUDPBoundsOK
                lda   RXFrame+40
                beq   PGTDNSUDPChecksumOK
                jsr   ValidateUDPChecksum
                bcc   PGTDNSUDPChecksumOK
                sec
                rts
PGTDNSUDPChecksumOK
                lda   RXFrame+42
                cmp   DNSID
                beq   PGTDNSIDOK
                sec
                rts
PGTDNSIDOK      lda   RXFrame+44
                and   #$0080
                bne   PGTDNSResponseBitOK
                sec
                rts
PGTDNSResponseBitOK
                lda   RXFrame+44
                and   #$0002
                beq   PGTDNSNotTruncated
                sec
                rts
PGTDNSNotTruncated
                lda   RXFrame+44
                xba
                and   #$000F
                beq   PGTDNSRCodeOK
                sec
                rts
PGTDNSRCodeOK   lda   RXFrame+46
                xba
                cmp   #1
                beq   PGTDNSQuestionCountOK
                sec
                rts
PGTDNSQuestionCountOK
                lda   RXFrame+48
                xba
                sta   AnswerCount
                beq   PGTDNSNoAnswer
                cmp   #17
                bcc   PGTDNSAnswerCountOK
PGTDNSNoAnswer  sec
                rts
PGTDNSAnswerCountOK
                lda   #54
                sta   DNSCursor
                jsr   SkipDNSName
                bcs   PGTDNSParseReject
                lda   DNSCursor
                clc
                adc   #4
                cmp   DNSEnd
                bcc   PGTDNSQuestionSkipped
                beq   PGTDNSQuestionSkipped
PGTDNSParseReject sec
                rts
PGTDNSQuestionSkipped
                sta   DNSCursor
                stz   AnswerIndex
PGTDNSAnswerLoop
                lda   AnswerIndex
                cmp   AnswerCount
                bcc   PGTDNSAnswerNext
                sec
                rts
PGTDNSAnswerNext jsr  SkipDNSName
                bcs   PGTDNSParseReject
                lda   DNSCursor
                clc
                adc   #10
                cmp   DNSEnd
                bcc   PGTDNSAnswerFixedOK
                beq   PGTDNSAnswerFixedOK
                sec
                rts
PGTDNSAnswerFixedOK
                ldx   DNSCursor
                lda   RXFrame+8,x
                xba
                sta   RDataLength
                txa
                clc
                adc   #10
                sta   RDataStart
                clc
                adc   RDataLength
                sta   RDataNext
                cmp   DNSEnd
                bcc   PGTDNSRDataBoundsOK
                beq   PGTDNSRDataBoundsOK
                sec
                rts
PGTDNSRDataBoundsOK
                ldx   DNSCursor
                lda   RXFrame,x
                cmp   #$0100
                bne   PGTDNSSkipRecord
                lda   RXFrame+2,x
                cmp   #$0100
                bne   PGTDNSSkipRecord
                lda   RDataLength
                cmp   #4
                bne   PGTDNSSkipRecord
                ldx   RDataStart
                lda   RXFrame,x
                sta   ResolvedIP
                lda   RXFrame+2,x
                sta   ResolvedIP+2
                clc
                rts
PGTDNSSkipRecord lda  RDataNext
                sta   DNSCursor
                inc   AnswerIndex
                brl   PGTDNSAnswerLoop

SkipDNSName     stz   NameSteps
PGTDNSNameLoop  lda   DNSCursor
                cmp   DNSEnd
                bcc   PGTDNSNameByte
                sec
                rts
PGTDNSNameByte  tax
                sep   #$20
                lda   RXFrame,x
                sta   NameLength
                rep   #$20
                lda   NameLength
                and   #$00FF
                beq   PGTDNSNameRoot
                and   #$00C0
                cmp   #$00C0
                beq   PGTDNSNamePointer
                bne   PGTDNSNameLabelCheck
PGTDNSNameLabelCheck
                lda   NameLength
                and   #$00C0
                bne   PGTDNSNameBad
                lda   NameLength
                and   #$00FF
                cmp   #64
                bcs   PGTDNSNameBad
                inc
                clc
                adc   DNSCursor
                cmp   DNSEnd
                bcc   PGTDNSNameAdvance
                beq   PGTDNSNameAdvance
PGTDNSNameBad   sec
                rts
PGTDNSNameAdvance sta DNSCursor
                inc   NameSteps
                lda   NameSteps
                cmp   #128
                bcc   PGTDNSNameLoop
                sec
                rts
PGTDNSNameRoot  inc   DNSCursor
                clc
                rts
PGTDNSNamePointer
                lda   DNSCursor
                clc
                adc   #2
                cmp   DNSEnd
                bcc   PGTDNSPointerOK
                beq   PGTDNSPointerOK
                sec
                rts
PGTDNSPointerOK sta   DNSCursor
                clc
                rts
                fin

*-------------------------------------------------
* Lease state, W5100 configuration and display
*-------------------------------------------------

ClearLease      lda   #0
                ldx   #26
PGTClearLeaseLoop sta OfferedIP,x
                dex
                dex
                bpl   PGTClearLeaseLoop
                rts

ClearAckOptions lda   #0
                ldx   #18
PGTClearAckLoop sta   SubnetMask,x
                dex
                dex
                bpl   PGTClearAckLoop
                rts

LeaseValid      lda   OfferedIP
                ora   OfferedIP+2
                beq   PGTLeaseBad
                lda   SubnetMask
                ora   SubnetMask+2
                beq   PGTLeaseBad
                lda   RouterIP
                ora   RouterIP+2
                beq   PGTLeaseBad
                clc
                rts
PGTLeaseBad     sec
                rts

ApplyLease      lda   #RouterIP
                sta   PGTcsPtr
                lda   #^RouterIP
                sta   PGTcsPtr+2
                ldx   #W5GAR
                jsr   WriteIPv4Register
                lda   #SubnetMask
                sta   PGTcsPtr
                lda   #^SubnetMask
                sta   PGTcsPtr+2
                ldx   #W5SUBR
                jsr   WriteIPv4Register
                lda   #OfferedIP
                sta   PGTcsPtr
                lda   #^OfferedIP
                sta   PGTcsPtr+2
                ldx   #W5SIPR
                jsr   WriteIPv4Register
                rts

WriteIPv4Register
                stx   RegisterBase
                ldy   #0
PGTWriteIPv4    lda   [PGTcsPtr],y
                and   #$00FF
                pha
                tya
                clc
                adc   RegisterBase
                tax
                pla
                phy
                jsl   PGTU2Write8
                ply
                iny
                cpy   #4
                bne   PGTWriteIPv4
                rts

LoadMAC         ldx   #0
PGTLoadMACLoop  phx
                txa
                clc
                adc   #W5SHAR
                tax
                jsl   PGTU2Read8
                plx
                sep   #$20
                sta   LocalMAC,x
                rep   #$20
                inx
                cpx   #6
                bne   PGTLoadMACLoop
                rts

BuildXID        rep   #$30
                lda   >$E100DC
                eor   LocalMAC+2
                eor   #$5047
                sta   XID
                lda   >$E100DC
                xba
                eor   LocalMAC+4
                eor   #$A55A
                sta   XID+2
                rts

MACValid        lda   LocalMAC
                ora   LocalMAC+2
                ora   LocalMAC+4
                beq   PGTBadMAC
                lda   LocalMAC
                and   #$0001
                bne   PGTBadMAC
                clc
                rts
PGTBadMAC       sec
                rts

PrintIdentity   pea   ^MACMsg
                pea   MACMsg
                _WriteCString
                lda   #LocalMAC
                jsr   PrintMACAt
                pea   ^XIDMsg
                pea   XIDMsg
                _WriteCString
                lda   #XID
                sta   PGTcsPtr
                lda   #^XID
                sta   PGTcsPtr+2
                stz   PrintIndex
PGTPrintXID     lda   PrintIndex
                tay
                lda   [PGTcsPtr],y
                and   #$00FF
                jsr   WriteHexByte
                inc   PrintIndex
                lda   PrintIndex
                cmp   #4
                bne   PGTPrintXID
                jsr   WriteCRLF
                rts

PrintLease      pea   ^AddressMsg
                pea   AddressMsg
                _WriteCString
                lda   #OfferedIP
                jsr   PrintIPv4At
                pea   ^MaskMsg
                pea   MaskMsg
                _WriteCString
                lda   #SubnetMask
                jsr   PrintIPv4At
                pea   ^RouterMsg
                pea   RouterMsg
                _WriteCString
                lda   #RouterIP
                jsr   PrintIPv4At
                pea   ^DNS1Msg
                pea   DNS1Msg
                _WriteCString
                lda   #DNS1
                jsr   PrintIPv4At
                pea   ^DNS2Msg
                pea   DNS2Msg
                _WriteCString
                lda   #DNS2
                jsr   PrintIPv4At
                pea   ^LeaseMsg
                pea   LeaseMsg
                _WriteCString
                lda   LeaseTime
                xba
                jsr   WriteHexWord
                lda   LeaseTime+2
                xba
                jsr   WriteHexWord
                jsr   WriteCRLF
                rts

PrintIPv4At     sta   PGTcsPtr
                lda   #^OfferedIP
                sta   PGTcsPtr+2
                lda   #4
                sta   PrintLength
                lda   #'.'
                sta   PrintSeparator
                jsr   PrintByteList
                rts
PrintMACAt      sta   PGTcsPtr
                lda   #^LocalMAC
                sta   PGTcsPtr+2
                lda   #6
                sta   PrintLength
                lda   #':'
                sta   PrintSeparator
                jsr   PrintByteList
                rts
PrintByteList   stz   PrintIndex
PGTPrintBytes   lda   PrintIndex
                tay
                lda   [PGTcsPtr],y
                and   #$00FF
                jsr   WriteHexByte
                inc   PrintIndex
                lda   PrintIndex
                cmp   PrintLength
                beq   PGTPrintDone
                lda   PrintSeparator
                pha
                _WriteChar
                bra   PGTPrintBytes
PGTPrintDone    jsr   WriteCRLF
                rts

*-------------------------------------------------
* Tool, direct-page and console lifecycle
*-------------------------------------------------

StartConsole    pea   TextTool
                pea   $0000
                _LoadOneTool
                bcc   PGTTextLoaded
                rts
PGTTextLoaded   lda   #1
                sta   TextLoaded
                _TextStartUp
                bcc   PGTTextStarted
                rts
PGTTextStarted  lda   #1
                sta   TextActive
                pea   $0000
                pea   $0000
                pea   $0003
                _SetInputDevice
                pea   $0000
                _InitTextDev
                pea   $0000
                pea   $0000
                pea   $0003
                _SetOutputDevice
                pea   $0001
                _InitTextDev
                pea   $000C
                _WriteChar
                clc
                rts

AllocateDirectPage
                pha
                pha
                pea   $0000
                pea   $0100
                lda   MemoryID
                pha
                pea   $C005
                pea   $0000
                pea   $0000
                _NewHandle
                bcc   PGTDPAllocated
                pla
                pla
                sec
                rts
PGTDPAllocated  tsc
                tcd
                lda   1
                sta   >DPHandle
                lda   3
                sta   >DPHandle+2
                lda   [1]
                sta   >DirectPage
                pla
                pla
                lda   >DirectPage
                tcd
                ldx   #$00FE
                lda   #0
PGTClearDP      sta   0,x
                dex
                dex
                bpl   PGTClearDP
                clc
                rts

ShutEverything lda   RawActive
                beq   PGTRawStopped
                jsl   PGTU2StopRaw
                stz   RawActive
PGTRawStopped   lda   SavedDP
                tcd
                lda   DPHandle
                ora   DPHandle+2
                beq   PGTDPDisposed
                lda   DPHandle+2
                pha
                lda   DPHandle
                pha
                _DisposeHandle
                stz   DPHandle
                stz   DPHandle+2
PGTDPDisposed   lda   TextActive
                beq   PGTTextInactive
                _TextShutDown
                stz   TextActive
PGTTextInactive lda   TextLoaded
                beq   PGTTextUnloaded
                pea   TextTool
                _UnloadOneTool
                stz   TextLoaded
PGTTextUnloaded lda   MMStarted
                beq   PGTMMStopped
                lda   MasterID
                pha
                _MMShutDown
                stz   MMStarted
PGTMMStopped    lda   TLStarted
                beq   PGTTLStopped
                _TLShutDown
                stz   TLStarted
PGTTLStopped    rts

ReadSlot        pea   ^SlotPrompt
                pea   SlotPrompt
                _WriteCString
                pea   $0000
                pea   $0000
                _ReadChar
                pla
                and   #$007F
                cmp   #$000D
                beq   PGTDefaultSlot
                cmp   #'1'
                bcc   PGTBadSlotInput
                cmp   #'8'
                bcs   PGTBadSlotInput
                sta   LastKey
                pha
                _WriteChar
                lda   LastKey
                sec
                sbc   #'0'
                sta   SelectedSlot
                jsr   WriteCRLF
                clc
                rts
PGTDefaultSlot  lda   #3
                sta   SelectedSlot
                pea   #'3'
                _WriteChar
                jsr   WriteCRLF
                clc
                rts
PGTBadSlotInput pea   ^SlotErrorMsg
                pea   SlotErrorMsg
                _WriteCString
                sec
                rts

CheckEscape     php
                sei
                sep   #$20
                mx    %10
                lda   >$E0C000
                bpl   PGTNoEscape
                and   #$7F
                sta   >LastKey
                lda   >$E0C010
                rep   #$20
                mx    %00
                plp
                lda   LastKey
                and   #$00FF
                cmp   #$001B
                beq   PGTEscapeFound
                clc
                rts
PGTNoEscape     rep   #$20
                mx    %00
                plp
                clc
                rts
PGTEscapeFound  sec
                rts

WriteCRLF       pea   ^CRLFMsg
                pea   CRLFMsg
                _WriteCString
                rts
WriteHexByte    sta   HexValue
                lsr
                lsr
                lsr
                lsr
                jsr   WriteHexNibble
                lda   HexValue
                jsr   WriteHexNibble
                rts
WriteHexWord    sta   HexWordValue
                xba
                jsr   WriteHexByte
                lda   HexWordValue
                jsr   WriteHexByte
                rts
WriteHexNibble  and   #$000F
                cmp   #10
                bcc   PGTHexDigit
                clc
                adc   #$0037
                bra   PGTHexOut
PGTHexDigit     clc
                adc   #$0030
PGTHexOut       pha
                _WriteChar
                rts

*-------------------------------------------------
* State, buffers and strings
*-------------------------------------------------

TLStarted       ds    2
MMStarted       ds    2
TextLoaded      ds    2
TextActive      ds    2
RawActive       ds    2
MasterID        ds    2
MemoryID        ds    2
SavedDP         ds    2
DirectPage      ds    2
DPHandle        ds    4
SelectedSlot    ds    2
LastKey         ds    2
HexValue        ds    2
HexWordValue    ds    2
PrintLength     ds    2
PrintIndex      ds    2
PrintSeparator  ds    2
RegisterBase    ds    2
RetryCount      ds    2
PollCount       ds    2
Aborted         ds    2
ExpectedType    ds    2
LastDHCPType    ds    2
OutMessageType  ds    2
OutIPLength     ds    2
OutUDPLength    ds    2
InIPLength      ds    2
InUDPLength     ds    2
OptionIndex     ds    2
OptionEnd       ds    2
OptionNext      ds    2
OptionCode      ds    2
OptionLength    ds    2
RXFrameCount    ds    2
TXFrameCount    ds    2
TXFrameLength   ds    2
RXCopyLength    ds    2
LocalMAC        ds    6
XID             ds    4
OfferedIP       ds    4
ServerIP        ds    4
SubnetMask      ds    4
RouterIP        ds    4
DNS1            ds    4
DNS2            ds    4
LeaseTime       ds    4
                do    DNS_PHASE
NextHopIP       ds    4
NextHopMAC      ds    6
DNSID           ds    2
ResolvedIP      ds    4
DNSTemp         ds    2
DNSEnd          ds    2
DNSCursor       ds    2
AnswerCount     ds    2
AnswerIndex     ds    2
NameSteps       ds    2
NameLength      ds    2
RDataLength     ds    2
RDataStart      ds    2
RDataNext       ds    2
                fin
TXFrame         ds    TXBufferSize
RXFrame         ds    RXCopyMax

ParameterList   hex   370701030633363A3BFF
                do    DNS_PHASE
DNSQuestion     hex   076578616D706C6503636F6D0000010001
                fin
QuitPB          dw    0

                do    DNS_PHASE
TitleMsg        asc   0D,'Petar_gsTCP Uthernet II DHCP/DNS Test',0D,00
                else
TitleMsg        asc   0D,'Petar_gsTCP Uthernet II DHCP Test',0D,00
                fin
                do    DNS_PHASE
SafetyMsg       asc   'P2 DHCP/DNS; disconnect Marinetti first.',0D,00
                else
SafetyMsg       asc   'P2 DHCP; disconnect Marinetti first.',0D,00
                fin
SlotPrompt      asc   'Uthernet II slot [3]: ',00
SlotErrorMsg    asc   0D,'Slot must be 1 through 7.',0D,00
DPErrorMsg      asc   'Could not allocate a bank-zero direct page.',0D,00
FoundMsg        asc   'W5100 found in slot $',00
NoCardMsg       asc   'W5100 detection failed.',0D,00
StartErrorMsg   asc   'Could not open W5100 socket 0 MACRAW.',0D,00
MACErrorMsg     asc   'MAC is zero or multicast; DHCP cannot start.',0D,00
MACMsg          asc   'Client MAC: $',00
XIDMsg          asc   'Transaction ID: $',00
DiscoverMsg     asc   'DHCP DISCOVER sent; waiting for OFFER...',0D,00
OfferMsg        asc   'OFFER address: $',00
ServerMsg       asc   'DHCP server: $',00
OfferTimeoutMsg asc   'No valid OFFER after three attempts.',0D,00
RequestMsg      asc   'DHCP REQUEST sent; waiting for ACK...',0D,00
AckTimeoutMsg   asc   'No valid ACK after three attempts.',0D,00
NakMsg          asc   'DHCP server returned NAK.',0D,00
LeaseErrorMsg   asc   'ACK omitted required address, mask, or router.',0D,00
PassMsg         asc   'PASS: DHCP ACK validated and applied.',0D,00
AddressMsg      asc   'Address: $',00
MaskMsg         asc   'Subnet mask: $',00
RouterMsg       asc   'Router: $',00
DNS1Msg         asc   'DNS 1: $',00
DNS2Msg         asc   'DNS 2: $',00
LeaseMsg        asc   'Lease seconds (hex): $',00
TXErrorMsg      asc   'W5100 transmit failed or timed out.',0D,00
AbortedMsg      asc   'Stopped by Escape.',0D,00
StatsTXMsg      asc   'TX=$',00
StatsRXMsg      asc   ' RX=$',00
StatsWrapMsg    asc   ' RXwrap=$',00
ExitMsg         asc   'Press Return to exit.',0D,00
CRLFMsg         asc   0D,00
                do    DNS_PHASE
DNSMissingMsg   asc   'DNS phase skipped: ACK supplied no DNS server.',0D,00
DNSARPMsg       asc   'ARP for DNS next hop; waiting...',0D,00
DNSARPTimeoutMsg asc  'DNS next-hop ARP timed out.',0D,00
DNSMACMsg       asc   'DNS next-hop MAC: $',00
DNSQueryMsg     asc   'DNS A query for example.com sent; waiting...',0D,00
DNSTimeoutMsg   asc   'No valid DNS response after three attempts.',0D,00
DNSTXErrorMsg   asc   'W5100 DNS-phase transmit failed.',0D,00
DNSPassMsg      asc   'PASS: example.com A address: $',00
                fin
