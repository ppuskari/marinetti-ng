*=================================================
* PGTPingTest application code
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

GSOS            equ   $E100A8
QuitCall        equ   $2029
TextTool        equ   $000C
RXCopyMax       equ   96
ARPFrameLen     equ   60
PingFrameLen    equ   74
PingIPLen       equ   60
PingICMPLen     equ   40

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
                stz   ARPResolved
                stz   EchoReceived
                stz   RXFrameCount
                stz   TXFrameCount

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
                bcc   PGTPingConsoleReady
                brl   ExitProgram

PGTPingConsoleReady jsr AllocateDirectPage
                bcc   PGTPingDPReady
                pea   ^DPErrorMsg
                pea   DPErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTPingDPReady  pea   ^TitleMsg
                pea   TitleMsg
                _WriteCString
                pea   ^SafetyMsg
                pea   SafetyMsg
                _WriteCString

                jsr   ReadSlot
                bcc   PGTPingSlotReady
                brl   WaitAndExit
PGTPingSlotReady lda  SelectedSlot
                jsl   PGTU2SelectSlot
                bcc   PGTPingSlotSelected
                brl   PGTNoCard
PGTPingSlotSelected jsl PGTU2Probe
                bcc   PGTPingCardProbed
                brl   PGTNoCard

PGTPingCardProbed
                jsr   LoadConfig
                pea   ^FoundMsg
                pea   FoundMsg
                _WriteCString
                lda   SelectedSlot
                jsr   WriteHexByte
                jsr   WriteCRLF
                jsr   PrintConfig
                jsr   ConfigValid
                bcc   PGTPingConfigOK
                pea   ^ConfigErrorMsg
                pea   ConfigErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTPingConfigOK jsl  PGTU2StartRaw
                bcc   PGTPingRawStarted
                brl   PGTStartFailed
PGTPingRawStarted
                lda   #1
                sta   RawActive
                stz   PGTu2WrapCount
                stz   PGTu2TXWrapCount

                lda   #3
                sta   RetryCount
PGTARPAttempt   jsr   BuildARPRequest
                jsr   SendTXFrame
                bcc   PGTARPSent
                brl   PGTTXFailed
PGTARPSent      pea   ^ARPSentMsg
                pea   ARPSentMsg
                _WriteCString
                lda   #$FFFF
                sta   PollCount
PGTARPWait      jsr   CheckEscape
                bcc   PGTARPContinue
                brl   PGTAborted
PGTARPContinue
                jsl   PGTU2BeginRX
                bcs   PGTARPNoFrame
                jsr   CopyAndReleaseRX
                bcc   PGTARPReleaseOK
                brl   PGTRuntimeFailed
PGTARPReleaseOK
                jsr   ParseARPReply
                bcc   PGTARPFound
PGTARPNoFrame   dec   PollCount
                bne   PGTARPWait
                dec   RetryCount
                bne   PGTARPAttempt
                pea   ^ARPTimeoutMsg
                pea   ARPTimeoutMsg
                _WriteCString
                brl   PrintStatsAndExit

PGTARPFound     pea   ^ARPReplyMsg
                pea   ARPReplyMsg
                _WriteCString
                jsr   PrintGatewayMAC
                jsr   BuildEchoRequest
                jsr   SendTXFrame
                bcc   PGTEchoSent
                brl   PGTTXFailed
PGTEchoSent     pea   ^EchoSentMsg
                pea   EchoSentMsg
                _WriteCString
                lda   #$FFFF
                sta   PollCount
PGTEchoWait     jsr   CheckEscape
                bcs   PGTAborted
                jsl   PGTU2BeginRX
                bcs   PGTEchoNoFrame
                jsr   CopyAndReleaseRX
                bcc   PGTEchoReleaseOK
                brl   PGTRuntimeFailed
PGTEchoReleaseOK
                jsr   ParseEchoReply
                bcc   PGTEchoFound
PGTEchoNoFrame  dec   PollCount
                bne   PGTEchoWait
                pea   ^EchoTimeoutMsg
                pea   EchoTimeoutMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTEchoFound    lda   #1
                sta   EchoReceived
                pea   ^EchoReplyMsg
                pea   EchoReplyMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTAborted      pea   ^AbortedMsg
                pea   AbortedMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTTXFailed     pea   ^TXErrorMsg
                pea   TXErrorMsg
                _WriteCString
                bra   PrintStatsAndExit

PGTRuntimeFailed pea  ^RuntimeMsg
                pea   RuntimeMsg
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
* Packet construction
*-------------------------------------------------

BuildARPRequest rep   #$30
                lda   #0
                ldx   #ARPFrameLen-2
PGTARPZero      sta   TXFrame,x
                dex
                dex
                bpl   PGTARPZero
                lda   #$FFFF
                sta   TXFrame
                sta   TXFrame+2
                sta   TXFrame+4
                ldx   #4
PGTARPSrcMAC    lda   LocalMAC,x
                sta   TXFrame+6,x
                sta   TXFrame+22,x
                dex
                dex
                bpl   PGTARPSrcMAC
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
                lda   LocalIP
                sta   TXFrame+28
                lda   LocalIP+2
                sta   TXFrame+30
                lda   GatewayIP
                sta   TXFrame+38
                lda   GatewayIP+2
                sta   TXFrame+40
                lda   #ARPFrameLen
                sta   TXFrameLength
                rts

BuildEchoRequest rep  #$30
                lda   #0
                ldx   #PingFrameLen-2
PGTEchoZero     sta   TXFrame,x
                dex
                dex
                bpl   PGTEchoZero
                ldx   #4
PGTEchoMACs     lda   GatewayMAC,x
                sta   TXFrame,x
                lda   LocalMAC,x
                sta   TXFrame+6,x
                dex
                dex
                bpl   PGTEchoMACs
                lda   #$0008
                sta   TXFrame+12
                lda   #$0045
                sta   TXFrame+14
                lda   #$3C00
                sta   TXFrame+16
                lda   #$0100
                sta   TXFrame+18
                lda   #$0040
                sta   TXFrame+20
                lda   #$0140
                sta   TXFrame+22
                lda   LocalIP
                sta   TXFrame+26
                lda   LocalIP+2
                sta   TXFrame+28
                lda   GatewayIP
                sta   TXFrame+30
                lda   GatewayIP+2
                sta   TXFrame+32
                lda   #$0008
                sta   TXFrame+34
                lda   #$4750
                sta   TXFrame+38
                lda   #$0100
                sta   TXFrame+40
                ldx   #30
PGTEchoPayload  lda   PingPayload,x
                sta   TXFrame+42,x
                dex
                dex
                bpl   PGTEchoPayload

                lda   #TXFrame+14
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   TXFrame+24

                lda   #TXFrame+34
                sta   PGTcsPtr
                lda   #^TXFrame
                sta   PGTcsPtr+2
                lda   #PingICMPLen
                sta   PGTcsLen
                jsl   PGTChecksum
                xba
                sta   TXFrame+36
                lda   #PingFrameLen
                sta   TXFrameLength
                rts

SendTXFrame     lda   #TXFrame
                sta   PGTu2TXPtr
                lda   #^TXFrame
                sta   PGTu2TXPtr+2
                lda   TXFrameLength
                sta   PGTu2TXLen
                jsl   PGTU2SendFrame
                bcs   PGTSendReturn
                inc   TXFrameCount
PGTSendReturn   rts

*-------------------------------------------------
* Receive and validation
*-------------------------------------------------

CopyAndReleaseRX
                rep   #$30
                inc   RXFrameCount
                stz   RXCopyLength
                ldx   #0
PGTRXCopyLoop   cpx   #RXCopyMax
                bcs   PGTRXCopyDone
                jsl   PGTU2ReadFrame8
                bcs   PGTRXCopyDone
                sep   #$20
                sta   RXFrame,x
                rep   #$20
                inx
                bra   PGTRXCopyLoop
PGTRXCopyDone   stx   RXCopyLength
                jsl   PGTU2ReleaseRX
                rts

ParseARPReply   rep   #$30
                lda   RXCopyLength
                cmp   #42
                bcc   PGTARPNotReply
                lda   RXFrame+12
                cmp   #$0608
                bne   PGTARPNotReply
                lda   RXFrame+14
                cmp   #$0100
                bne   PGTARPNotReply
                lda   RXFrame+16
                cmp   #$0008
                bne   PGTARPNotReply
                lda   RXFrame+18
                cmp   #$0406
                bne   PGTARPNotReply
                lda   RXFrame+20
                cmp   #$0200
                bne   PGTARPNotReply
                lda   RXFrame+28
                cmp   GatewayIP
                bne   PGTARPNotReply
                lda   RXFrame+30
                cmp   GatewayIP+2
                bne   PGTARPNotReply
                lda   RXFrame+38
                cmp   LocalIP
                bne   PGTARPNotReply
                lda   RXFrame+40
                cmp   LocalIP+2
                bne   PGTARPNotReply
                ldx   #4
PGTARPCopyMAC   lda   RXFrame+22,x
                sta   GatewayMAC,x
                dex
                dex
                bpl   PGTARPCopyMAC
                lda   #1
                sta   ARPResolved
                clc
                rts
PGTARPNotReply  sec
                rts

ParseEchoReply  rep   #$30
                lda   RXCopyLength
                cmp   #PingFrameLen
                bcs   PGTEchoLengthOK
                sec
                rts
PGTEchoLengthOK
                lda   RXFrame+12
                cmp   #$0008
                beq   PGTEchoTypeOK
                sec
                rts
PGTEchoTypeOK
                lda   RXFrame+14
                and   #$00FF
                cmp   #$0045
                beq   PGTEchoIHLOK
                sec
                rts
PGTEchoIHLOK
                lda   RXFrame+16
                cmp   #$3C00
                beq   PGTEchoIPLenOK
                sec
                rts
PGTEchoIPLenOK
                lda   RXFrame+22
                xba
                and   #$00FF
                cmp   #PGTIPICMP
                bne   PGTEchoNotReply
                lda   RXFrame+26
                cmp   GatewayIP
                bne   PGTEchoNotReply
                lda   RXFrame+28
                cmp   GatewayIP+2
                bne   PGTEchoNotReply
                lda   RXFrame+30
                cmp   LocalIP
                bne   PGTEchoNotReply
                lda   RXFrame+32
                cmp   LocalIP+2
                bne   PGTEchoNotReply
                lda   RXFrame+34
                bne   PGTEchoNotReply
                lda   RXFrame+38
                cmp   #$4750
                bne   PGTEchoNotReply
                lda   RXFrame+40
                cmp   #$0100
                bne   PGTEchoNotReply

                lda   #RXFrame+14
                sta   PGTcsPtr
                lda   #^RXFrame
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                cmp   #0
                bne   PGTEchoNotReply
                lda   #RXFrame+34
                sta   PGTcsPtr
                lda   #^RXFrame
                sta   PGTcsPtr+2
                lda   #PingICMPLen
                sta   PGTcsLen
                jsl   PGTChecksum
                cmp   #0
                bne   PGTEchoNotReply
                clc
                rts
PGTEchoNotReply sec
                rts

*-------------------------------------------------
* W5100 configuration and display
*-------------------------------------------------

LoadConfig      rep   #$30
                ldx   #0
PGTLoadMAC      phx
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
                bne   PGTLoadMAC
                ldx   #0
PGTLoadIP       phx
                txa
                clc
                adc   #W5SIPR
                tax
                jsl   PGTU2Read8
                plx
                sep   #$20
                sta   LocalIP,x
                rep   #$20
                inx
                cpx   #4
                bne   PGTLoadIP
                ldx   #0
PGTLoadGateway  phx
                txa
                clc
                adc   #W5GAR
                tax
                jsl   PGTU2Read8
                plx
                sep   #$20
                sta   GatewayIP,x
                rep   #$20
                inx
                cpx   #4
                bne   PGTLoadGateway
                rts

ConfigValid     lda   LocalIP
                ora   LocalIP+2
                beq   PGTConfigBad
                lda   GatewayIP
                ora   GatewayIP+2
                beq   PGTConfigBad
                clc
                rts
PGTConfigBad    sec
                rts

PrintConfig     pea   ^MACMsg
                pea   MACMsg
                _WriteCString
                lda   #LocalMAC
                sta   PGTcsPtr
                lda   #^LocalMAC
                sta   PGTcsPtr+2
                lda   #6
                jsr   PrintByteList
                pea   ^IPMsg
                pea   IPMsg
                _WriteCString
                lda   #LocalIP
                sta   PGTcsPtr
                lda   #^LocalIP
                sta   PGTcsPtr+2
                lda   #4
                jsr   PrintByteList
                pea   ^GatewayMsg
                pea   GatewayMsg
                _WriteCString
                lda   #GatewayIP
                sta   PGTcsPtr
                lda   #^GatewayIP
                sta   PGTcsPtr+2
                lda   #4
                jsr   PrintByteList
                rts

PrintGatewayMAC lda   #GatewayMAC
                sta   PGTcsPtr
                lda   #^GatewayMAC
                sta   PGTcsPtr+2
                lda   #6
                jsr   PrintByteList
                rts

PrintByteList   sta   PrintLength
                stz   PrintIndex
PGTPrintBytes   ldx   PrintIndex
                txa
                tay
                lda   [PGTcsPtr],y
                and   #$00FF
                jsr   WriteHexByte
                inc   PrintIndex
                lda   PrintIndex
                cmp   PrintLength
                beq   PGTPrintDone
                lda   PrintLength
                cmp   #4
                beq   PGTPrintDot
                pea   #':'
                _WriteChar
                bra   PGTPrintBytes
PGTPrintDot     pea   #'.'
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
* Application state, packet buffers and strings
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
RetryCount      ds    2
PollCount       ds    2
ARPResolved     ds    2
EchoReceived    ds    2
RXFrameCount    ds    2
TXFrameCount    ds    2
TXFrameLength   ds    2
RXCopyLength    ds    2
LocalMAC        ds    6
LocalIP         ds    4
GatewayIP       ds    4
GatewayMAC      ds    6
TXFrame         ds    96
RXFrame         ds    RXCopyMax

PingPayload     asc   'Petar_gsTCP/IIgs ping payload!!!'

QuitPB          dw    0

TitleMsg        asc   0D,'Petar_gsTCP Uthernet II Ping Test',0D,00
SafetyMsg       asc   'P1 transmit/ARP/ICMP; disconnect Marinetti first.',0D,00
SlotPrompt      asc   'Uthernet II slot [3]: ',00
SlotErrorMsg    asc   0D,'Slot must be 1 through 7.',0D,00
DPErrorMsg      asc   'Could not allocate a bank-zero direct page.',0D,00
FoundMsg        asc   'W5100 found in slot $',00
NoCardMsg       asc   'W5100 detection failed.',0D,00
StartErrorMsg   asc   'Could not open W5100 socket 0 MACRAW.',0D,00
ConfigErrorMsg  asc   'Saved IP or gateway is zero; configure Marinetti first.',0D,00
MACMsg          asc   'MAC: $',00
IPMsg           asc   'Saved IP bytes: $',00
GatewayMsg      asc   'Gateway target: $',00
ARPSentMsg      asc   'ARP request sent; waiting for gateway...',0D,00
ARPReplyMsg     asc   'ARP reply received. Gateway MAC: $',00
ARPTimeoutMsg   asc   'ARP timed out after three requests.',0D,00
EchoSentMsg     asc   'ICMP echo request sent; waiting...',0D,00
EchoReplyMsg    asc   'PASS: valid ICMP echo reply received.',0D,00
EchoTimeoutMsg  asc   'ICMP echo reply timed out.',0D,00
TXErrorMsg      asc   'W5100 transmit failed or timed out.',0D,00
RuntimeMsg      asc   'W5100 receive/release command failed.',0D,00
AbortedMsg      asc   'Stopped by Escape.',0D,00
StatsTXMsg      asc   'TX=$',00
StatsRXMsg      asc   ' RX=$',00
StatsWrapMsg    asc   ' RXwrap=$',00
ExitMsg         asc   'Press Return to exit.',0D,00
CRLFMsg         asc   0D,00
