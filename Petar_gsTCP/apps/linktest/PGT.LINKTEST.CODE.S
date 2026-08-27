*=================================================
* PGTLinkTest application code
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

GSOS            equ   $E100A8
QuitCall        equ   $2029
TextTool        equ   $000C

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
                stz   FrameCount
                stz   FrameCount+2
                stz   ByteCount
                stz   ByteCount+2
                stz   IPv4Count
                stz   ARPCount
                stz   OtherCount

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
                bcc   PGTConsoleReady
                brl   ExitProgram

PGTConsoleReady jsr   AllocateDirectPage
                bcc   PGTDPReady
                pea   ^DPErrorMsg
                pea   DPErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTDPReady      pea   ^TitleMsg
                pea   TitleMsg
                _WriteCString
                pea   ^SafetyMsg
                pea   SafetyMsg
                _WriteCString

                jsr   ReadSlot
                bcc   PGTSlotReady
                brl   WaitAndExit

PGTSlotReady    lda   SelectedSlot
                jsl   PGTU2SelectSlot
                bcc   PGTSlotSelected
                brl   PGTNoCard
PGTSlotSelected jsl   PGTU2Probe
                bcc   PGTCardProbed
                brl   PGTNoCard

PGTCardProbed
                pea   ^FoundMsg
                pea   FoundMsg
                _WriteCString
                lda   SelectedSlot
                jsr   WriteHexByte
                jsr   WriteCRLF

                jsr   PrintW5100Config

                jsl   PGTU2StartRaw
                bcc   PGTRawStarted
                brl   PGTStartFailed
PGTRawStarted
                lda   #1
                sta   RawActive
                stz   PGTu2WrapCount

                pea   ^RunningMsg
                pea   RunningMsg
                _WriteCString

PGTPollLoop     jsr   CheckEscape
                bcs   PGTStopRequested
                jsl   PGTU2BeginRX
                bcs   PGTPollLoop

                jsr   CountFrame
                jsr   InspectEthernet
                jsl   PGTU2ReleaseRX
                bcs   PGTRuntimeFailed

                lda   FrameCount+2
                bne   PGTPollLoop
                lda   FrameCount
                cmp   #33
                bcs   PGTPollLoop
                jsr   PrintFrameLine
                bra   PGTPollLoop

PGTStopRequested pea  ^StoppedMsg
                pea   StoppedMsg
                _WriteCString
                jsr   PrintSummary
                bra   WaitAndExit

PGTRuntimeFailed pea  ^RuntimeMsg
                pea   RuntimeMsg
                _WriteCString
                bra   WaitAndExit

PGTNoCard       pea   ^NoCardMsg
                pea   NoCardMsg
                _WriteCString
                bra   WaitAndExit

PGTStartFailed  pea   ^StartErrorMsg
                pea   StartErrorMsg
                _WriteCString

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
* Tool and direct-page lifecycle
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

*-------------------------------------------------
* User input and display
*-------------------------------------------------

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

PrintW5100Config
                pea   ^MACMsg
                pea   MACMsg
                _WriteCString
                stz   PrintIndex
PGTPrintMAC     lda   PrintIndex
                clc
                adc   #W5SHAR
                tax
                jsl   PGTU2Read8
                jsr   WriteHexByte
                inc   PrintIndex
                lda   PrintIndex
                cmp   #6
                beq   PGTPrintMACDone
                pea   #':'
                _WriteChar
                bra   PGTPrintMAC
PGTPrintMACDone jsr   WriteCRLF

                pea   ^IPMsg
                pea   IPMsg
                _WriteCString
                ldx   #W5SIPR
                jsr   PrintIPv4Register
                pea   ^GatewayMsg
                pea   GatewayMsg
                _WriteCString
                ldx   #W5GAR
                jsr   PrintIPv4Register
                rts

PrintIPv4Register
                stx   PrintRegister
                stz   PrintIndex
PGTPrintIPLoop  lda   PrintRegister
                clc
                adc   PrintIndex
                tax
                jsl   PGTU2Read8
                jsr   WriteHexByte
                inc   PrintIndex
                lda   PrintIndex
                cmp   #4
                beq   PGTPrintIPDone
                pea   #'.'
                _WriteChar
                bra   PGTPrintIPLoop
PGTPrintIPDone  jsr   WriteCRLF
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

*-------------------------------------------------
* Frame inspection and counters
*-------------------------------------------------

CountFrame      inc   FrameCount
                bne   PGTFrameCountOK
                inc   FrameCount+2
PGTFrameCountOK lda   ByteCount
                clc
                adc   PGTu2FrameLen
                sta   ByteCount
                bcc   PGTByteCountOK
                inc   ByteCount+2
PGTByteCountOK  rts

InspectEthernet ldx   #12
PGTSkipMACs     jsl   PGTU2ReadFrame8
                bcs   PGTEtherShort
                dex
                bne   PGTSkipMACs
                jsl   PGTU2ReadFrame8
                bcs   PGTEtherShort
                xba
                sta   EtherType
                jsl   PGTU2ReadFrame8
                bcs   PGTEtherShort
                ora   EtherType
                sta   EtherType
                cmp   #PGTEthIPv4
                beq   PGTCountIPv4
                cmp   #PGTEthARP
                beq   PGTCountARP
                inc   OtherCount
                rts
PGTCountIPv4    inc   IPv4Count
                rts
PGTCountARP     inc   ARPCount
                rts
PGTEtherShort   lda   #$FFFF
                sta   EtherType
                inc   OtherCount
                rts

PrintFrameLine  pea   ^FrameMsg
                pea   FrameMsg
                _WriteCString
                lda   FrameCount
                jsr   WriteHexWord
                pea   ^LengthMsg
                pea   LengthMsg
                _WriteCString
                lda   PGTu2FrameLen
                jsr   WriteHexWord
                pea   ^TypeMsg
                pea   TypeMsg
                _WriteCString
                lda   EtherType
                jsr   WriteHexWord
                jsr   WriteCRLF
                rts

PrintSummary    pea   ^SummaryFrames
                pea   SummaryFrames
                _WriteCString
                lda   FrameCount+2
                jsr   WriteHexWord
                lda   FrameCount
                jsr   WriteHexWord
                pea   ^SummaryBytes
                pea   SummaryBytes
                _WriteCString
                lda   ByteCount+2
                jsr   WriteHexWord
                lda   ByteCount
                jsr   WriteHexWord
                jsr   WriteCRLF
                pea   ^SummaryTypes
                pea   SummaryTypes
                _WriteCString
                lda   IPv4Count
                jsr   WriteHexWord
                pea   ^SummaryARP
                pea   SummaryARP
                _WriteCString
                lda   ARPCount
                jsr   WriteHexWord
                pea   ^SummaryOther
                pea   SummaryOther
                _WriteCString
                lda   OtherCount
                jsr   WriteHexWord
                pea   ^SummaryWrap
                pea   SummaryWrap
                _WriteCString
                lda   PGTu2WrapCount
                jsr   WriteHexWord
                jsr   WriteCRLF
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
* Application state and strings
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
PrintIndex      ds    2
PrintRegister   ds    2
LastKey         ds    2
HexValue        ds    2
HexWordValue    ds    2
EtherType       ds    2
FrameCount      ds    4
ByteCount       ds    4
IPv4Count       ds    2
ARPCount        ds    2
OtherCount      ds    2

QuitPB          dw    0

TitleMsg        asc   0D,'Petar_gsTCP Uthernet II Link Test',0D,00
SafetyMsg       asc   'Receive-only P0.1; disconnect Marinetti first.',0D,00
SlotPrompt      asc   'Uthernet II slot [3]: ',00
SlotErrorMsg    asc   0D,'Slot must be 1 through 7.',0D,00
DPErrorMsg      asc   'Could not allocate a bank-zero direct page.',0D,00
FoundMsg        asc   'W5100 found in slot $',00
NoCardMsg       asc   'W5100 detection failed.',0D,00
StartErrorMsg   asc   'Could not open W5100 socket 0 MACRAW.',0D,00
RuntimeMsg      asc   'W5100 receive/release command failed.',0D,00
MACMsg          asc   'MAC: $',00
IPMsg           asc   'Saved IP bytes: $',00
GatewayMsg      asc   'Saved gateway bytes: $',00
RunningMsg      asc   'Receiving; press ESC to stop. First 32 frames:',0D,00
FrameMsg        asc   'frame=$',00
LengthMsg       asc   ' len=$',00
TypeMsg         asc   ' type=$',00
StoppedMsg      asc   0D,'Stopped.',0D,00
SummaryFrames   asc   'frames=$',00
SummaryBytes    asc   ' bytes=$',00
SummaryTypes    asc   'IPv4=$',00
SummaryARP      asc   ' ARP=$',00
SummaryOther    asc   ' other=$',00
SummaryWrap     asc   ' RXwrap=$',00
ExitMsg         asc   'Press Return to exit.',0D,00
CRLFMsg         asc   0D,00
