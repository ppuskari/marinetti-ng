*=================================================
* PGTStreamTest application code
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

GSOS            equ   $E100A8
QuitCall        equ   $2029
TextTool        equ   $000C
StreamPortWire  equ   $6619           ; UDP port 6502 bytes $19,$66
                do    PGTDocMode
StreamPrebuffer equ   65520           ; exactly 60 default sender frames
StreamRingMask  equ   $FFFF
StreamRingBytesLo equ $0000
StreamRingBytesHi equ $0001
DOCStatusPtr    equ   $50             ; exported Tool 225 status pointer
DOCRefillBlocks equ   64              ; one 16 KiB true-22K refill
DOCPrefillBlocks equ  128             ; initial 32 KiB DOC preload
                else
StreamPrebuffer equ   4096
StreamRateLo    equ   367
StreamRingMask  equ   $3FFF
StreamRingBytesLo equ $4000
StreamRingBytesHi equ $0000
                fin

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
                stz   RingHandle
                stz   RingHandle+2
                stz   RawActive
                stz   PlaybackToolLoaded
                stz   PlaybackToolActive
                stz   PlaybackStreamActive
                stz   DOCStartError
                stz   TestComplete
                stz   PlaybackActive
                stz   StreamPhase
                stz   FramesSeen
                stz   FramesAccepted
                stz   FramesDropped
                stz   Underruns
                stz   MaxTickGap
                stz   RingHighWater
                stz   PayloadBytes
                stz   PayloadBytes+2
                stz   ConsumedBytes
                stz   ConsumedBytes+2
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
                bcc   PGTStreamConsoleReady
                brl   ExitProgram
PGTStreamConsoleReady jsr AllocateDirectPage
                bcc   PGTStreamDPReady
                pea   ^DPErrorMsg
                pea   DPErrorMsg
                _WriteCString
                brl   WaitAndExit
PGTStreamDPReady jsr  AllocateStreamRing
                bcc   PGTStreamRingReady
                pea   ^RingErrorMsg
                pea   RingErrorMsg
                _WriteCString
                brl   WaitAndExit

PGTStreamRingReady
                do    PGTDocMode
                jsr   StartPlaybackTool
                bcc   PGTStreamToolReady
                pea   ^ToolErrorMsg
                pea   ToolErrorMsg
                _WriteCString
                brl   WaitAndExit
PGTStreamToolReady
                fin
                pea   ^TitleMsg
                pea   TitleMsg
                _WriteCString
                pea   ^SafetyMsg
                pea   SafetyMsg
                _WriteCString
                jsr   ReadSlot
                bcc   PGTStreamSlotReady
                brl   WaitAndExit
PGTStreamSlotReady lda SelectedSlot
                jsl   PGTU2SelectSlot
                bcc   PGTStreamSelected
                brl   PGTNoCard
PGTStreamSelected jsl PGTU2Probe
                bcc   PGTStreamProbed
                brl   PGTNoCard
PGTStreamProbed pea   ^FoundMsg
                pea   FoundMsg
                _WriteCString
                lda   SelectedSlot
                jsr   WriteHexByte
                jsr   WriteCRLF
                jsl   PGTU2StartRaw
                bcc   PGTStreamRaw
                brl   PGTStartFailed
PGTStreamRaw    lda   #1
                sta   RawActive
                stz   PGTu2WrapCount
                lda   RingPointer
                sta   PGTringBase
                lda   RingPointer+2
                sta   PGTringBase+2
                lda   #StreamRingMask
                sta   PGTringMask
                stz   PGTringHead
                stz   PGTringTail
                lda   >$E100DC
                sta   LastTick
                pea   ^RunningMsg
                pea   RunningMsg
                _WriteCString

PGTStreamLoop   jsr   UpdateConsumer
                jsr   CheckEscape
                bcs   PGTStreamStopped
                jsl   PGTU2BeginRX
                bcs   PGTStreamLoop
                inc   FramesSeen
                jsr   ReadStreamHeader
                bcs   PGTStreamRelease
                jsr   AcceptStreamFrame
PGTStreamRelease
                jsl   PGTU2ReleaseRX
                bcs   PGTRuntimeFailed
                do    PGTDocMode
                jsr   StartDOCIfReady
                bcs   PGTDOCStartFailed
                fin
                lda   TestComplete
                beq   PGTStreamLoop
                bra   PGTStreamFinished

PGTStreamStopped pea  ^StoppedMsg
                pea   StoppedMsg
                _WriteCString
                bra   PGTStreamSummary
PGTStreamFinished pea ^FinishedMsg
                pea   FinishedMsg
                _WriteCString
PGTStreamSummary
                do    PGTDocMode
                jsr   StopPlaybackTool
                fin
                jsr   PrintSummary
                bra   WaitAndExit

                do    PGTDocMode
PGTDOCStartFailed pea  ^DOCStartErrorMsg
                pea   DOCStartErrorMsg
                _WriteCString
                bra   WaitAndExit
                fin

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
* UDP frame selection and production ring copy
*-------------------------------------------------

ReadStreamHeader
                lda   PGTu2FrameLen
                cmp   #42
                bcs   PGTStreamHeaderSizeOK
                sec
                rts
PGTStreamHeaderSizeOK
                stz   HeaderIndex
PGTStreamHeaderLoop
                jsl   PGTU2ReadFrame8
                bcs   PGTStreamHeaderFail
                ldx   HeaderIndex
                sep   #$20
                sta   HeaderBuffer,x
                rep   #$20
                inc   HeaderIndex
                lda   HeaderIndex
                cmp   #42
                bne   PGTStreamHeaderLoop
                clc
                rts
PGTStreamHeaderFail sec
                rts

PGTStreamRejectEarly sec
                rts

AcceptStreamFrame
                lda   HeaderBuffer+12
                cmp   #$0008
                bne   PGTStreamRejectEarly
                lda   HeaderBuffer+14
                and   #$00FF
                cmp   #$0045
                bne   PGTStreamRejectEarly
                lda   HeaderBuffer+20
                xba
                and   #$3FFF
                bne   PGTStreamRejectEarly
                lda   HeaderBuffer+22
                xba
                and   #$00FF
                cmp   #PGTIPUDP
                bne   PGTStreamRejectEarly
                lda   HeaderBuffer+36
                cmp   #StreamPortWire
                bne   PGTStreamRejectEarly
                lda   #HeaderBuffer+14
                sta   PGTcsPtr
                lda   #^HeaderBuffer
                sta   PGTcsPtr+2
                lda   #20
                sta   PGTcsLen
                jsl   PGTChecksum
                bne   PGTStreamReject
                lda   HeaderBuffer+38
                xba
                cmp   #8
                bcc   PGTStreamReject
                sta   UDPSize
                sec
                sbc   #8
                sta   PGTringNeed
                beq   PGTStreamEndMarker
                cmp   PGTu2Remain
                bcc   PGTStreamPayloadOK
                beq   PGTStreamPayloadOK
                bra   PGTStreamReject
PGTStreamPayloadOK
                lda   UDPSize
                clc
                adc   #20
                sta   HeaderTemp
                lda   HeaderBuffer+16
                xba
                cmp   HeaderTemp
                bcc   PGTStreamReject
                jsl   PGTRingCopyRX
                bcs   PGTStreamRingFull
                inc   FramesAccepted
                lda   PayloadBytes
                clc
                adc   PGTringNeed
                sta   PayloadBytes
                bcc   PGTStreamByteCountOK
                inc   PayloadBytes+2
PGTStreamByteCountOK
                jsl   PGTRingUsed
                cmp   RingHighWater
                bcc   PGTStreamAccepted
                sta   RingHighWater
PGTStreamAccepted clc
                rts
PGTStreamEndMarker lda #1
                sta   TestComplete
                clc
                rts
PGTStreamRingFull inc FramesDropped
PGTStreamReject sec
                rts

*-------------------------------------------------
* 22.05 kHz consumer.  The baseline build simulates it at 60 Hz.  The DOC
* build follows Tool 225's monotonic 256-byte refill counter and advances the
* very same network ring only after a 16 KiB half has entered DOC RAM.
*-------------------------------------------------

                do    PGTDocMode
UpdateConsumer  lda   >$E100DC
                sta   CurrentTick
                sec
                sbc   LastTick
                beq   PGTDOCTickReady
                sta   TickDelta
                cmp   MaxTickGap
                bcc   PGTDOCGapOK
                sta   MaxTickGap
PGTDOCGapOK     lda   CurrentTick
                sta   LastTick
PGTDOCTickReady lda   PlaybackActive
                beq   PGTConsumerDone

                php
                sei
                ldy   #0
                lda   [DOCStatusPtr],y
                sta   CurrentDOCBlocks
                ldy   #62
                lda   [DOCStatusPtr],y
                sta   CurrentDOCBlocks+2
                plp

                lda   CurrentDOCBlocks
                sec
                sbc   LastDOCBlocks
                sta   DOCBlockDelta
                lda   CurrentDOCBlocks+2
                sbc   LastDOCBlocks+2
                bne   PGTDOCBadDelta
                lda   DOCBlockDelta
                beq   PGTConsumerDone
                cmp   #DOCRefillBlocks+1
                bcs   PGTDOCBadDelta

                lda   CurrentDOCBlocks
                sta   LastDOCBlocks
                lda   CurrentDOCBlocks+2
                sta   LastDOCBlocks+2
                lda   DOCBlockDelta
                xba
                sta   ConsumeAmount
                jsl   PGTRingUsed
                cmp   ConsumeAmount
                bcs   PGTDOCConsumeReady
                inc   Underruns
                lda   PGTringHead
                sta   PGTringTail
                bra   PGTConsumerDone
PGTDOCConsumeReady
                lda   PGTringTail
                clc
                adc   ConsumeAmount
                and   PGTringMask
                sta   PGTringTail
                lda   ConsumedBytes
                clc
                adc   ConsumeAmount
                sta   ConsumedBytes
                bcc   PGTConsumerDone
                inc   ConsumedBytes+2
                bra   PGTConsumerDone
PGTDOCBadDelta  inc   Underruns
                lda   CurrentDOCBlocks
                sta   LastDOCBlocks
                lda   CurrentDOCBlocks+2
                sta   LastDOCBlocks+2
PGTConsumerDone rts

* Tool 225 P0.9G-M2-R12A selector $19 copies the prepared 32 KiB source
* ring into the two DOC halves before enabling playback.  Those bytes are
* then free in system memory, so producer and consumer restart together at
* ring offset zero while the DOC owns about 1.49 seconds of audio headroom.

StartDOCIfReady lda   PlaybackActive
                bne   PGTDOCCanContinue
                jsl   PGTRingUsed
                cmp   #StreamPrebuffer
                bcc   PGTDOCCanContinue
                lda   RingPointer
                sta   DOCRingPointer
                lda   RingPointer+2
                sta   DOCRingPointer+2
                pea   ^DOCRingDescriptor
                pea   DOCRingDescriptor
                ldx   #$19E1
                jsl   $E10000
                bcs   PGTDOCStartCarry
                lda   #1
                sta   PlaybackActive
                sta   PlaybackStreamActive
* Selector $19 consumed the first 32 KiB into DOC.  Keep the producer at the
* prebuffer end and publish $8000 as the consumer tail; the remaining source
* data bridges the blocking DOC preload without relying on sender timing.
                lda   #$8000
                sta   PGTringTail
                lda   #DOCPrefillBlocks
                sta   LastDOCBlocks
                stz   LastDOCBlocks+2
                pea   ^DOCStartedMsg
                pea   DOCStartedMsg
                _WriteCString
PGTDOCCanContinue clc
                rts
PGTDOCStartCarry sta   DOCStartError
                sec
                rts

                else
UpdateConsumer  lda   >$E100DC
                sta   CurrentTick
                sec
                sbc   LastTick
                beq   PGTConsumerDone
                sta   TickDelta
                cmp   MaxTickGap
                bcc   PGTConsumerGapOK
                sta   MaxTickGap
PGTConsumerGapOK
PGTConsumerTick inc   LastTick
                lda   PlaybackActive
                bne   PGTConsumeAudio
                jsl   PGTRingUsed
                cmp   #StreamPrebuffer
                bcc   PGTConsumerNext
                lda   #1
                sta   PlaybackActive
                bra   PGTConsumerNext

PGTConsumeAudio lda   StreamPhase
                eor   #1
                sta   StreamPhase
                clc
                adc   #StreamRateLo
                sta   ConsumeAmount
                jsl   PGTRingUsed
                cmp   ConsumeAmount
                bcs   PGTConsumeReady
                inc   Underruns
                lda   PGTringHead
                sta   PGTringTail
                bra   PGTConsumerNext
PGTConsumeReady lda   PGTringTail
                clc
                adc   ConsumeAmount
                and   PGTringMask
                sta   PGTringTail
                lda   ConsumedBytes
                clc
                adc   ConsumeAmount
                sta   ConsumedBytes
                bcc   PGTConsumerNext
                inc   ConsumedBytes+2
PGTConsumerNext dec   TickDelta
                bne   PGTConsumerTick
PGTConsumerDone rts
                fin

*-------------------------------------------------
* Summary
*-------------------------------------------------

PrintSummary    pea   ^FramesMsg
                pea   FramesMsg
                _WriteCString
                lda   FramesAccepted
                jsr   WriteHexWord
                pea   ^PayloadMsg
                pea   PayloadMsg
                _WriteCString
                lda   PayloadBytes+2
                jsr   WriteHexWord
                lda   PayloadBytes
                jsr   WriteHexWord
                jsr   WriteCRLF
                pea   ^ConsumedMsg
                pea   ConsumedMsg
                _WriteCString
                lda   ConsumedBytes+2
                jsr   WriteHexWord
                lda   ConsumedBytes
                jsr   WriteHexWord
                pea   ^HighWaterMsg
                pea   HighWaterMsg
                _WriteCString
                lda   RingHighWater
                jsr   WriteHexWord
                jsr   WriteCRLF
                pea   ^DropsMsg
                pea   DropsMsg
                _WriteCString
                lda   FramesDropped
                jsr   WriteHexWord
                pea   ^UnderrunMsg
                pea   UnderrunMsg
                _WriteCString
                lda   Underruns
                jsr   WriteHexWord
                pea   ^GapMsg
                pea   GapMsg
                _WriteCString
                lda   MaxTickGap
                jsr   WriteHexWord
                pea   ^WrapMsg
                pea   WrapMsg
                _WriteCString
                lda   PGTu2WrapCount
                jsr   WriteHexWord
                jsr   WriteCRLF
                lda   TestComplete
                beq   PGTNoVerdict
                lda   PlaybackActive
                beq   PGTStreamNotPass
                lda   FramesDropped
                ora   Underruns
                bne   PGTStreamNotPass
                pea   ^PassMsg
                pea   PassMsg
                _WriteCString
                rts
PGTStreamNotPass pea  ^FailMsg
                pea   FailMsg
                _WriteCString
PGTNoVerdict    rts

*-------------------------------------------------
* Tool and memory lifecycle
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

AllocateStreamRing
                pha
                pha
                pea   StreamRingBytesHi
                pea   StreamRingBytesLo
                lda   MemoryID
                pha
                do    PGTDocMode
                pea   $8000           ; locked; 64 KiB may cross a bank
                else
                pea   $C005
                fin
                pea   $0000
                pea   $0000
                _NewHandle
                bcc   PGTRingAllocated
                pla
                pla
                sec
                rts
PGTRingAllocated tsc
                tcd
                lda   1
                sta   >RingHandle
                lda   3
                sta   >RingHandle+2
                lda   [1]
                sta   >RingPointer
                ldy   #2
                lda   [1],y
                sta   >RingPointer+2
                pla
                pla
                lda   >DirectPage
                tcd
                lda   RingPointer
                sta   PGTringBase
                lda   RingPointer+2
                sta   PGTringBase+2
                do    PGTDocMode
* DOC interprets zero as an early waveform terminator.  Silence-fill the
* whole source ring before the network overlays its prebuffer.
                ldy   #0
                sep   #$20
                lda   #$80
PGTClearDOCRing sta   [PGTringBase],y
                iny
                bne   PGTClearDOCRing
                rep   #$20
                fin
                clc
                rts

                do    PGTDocMode
StartPlaybackTool
                pea   $00E1
                pea   $0000
                _LoadOneTool
                bcs   PGTPlaybackToolFail
                lda   #1
                sta   PlaybackToolLoaded
                pea   $E1AD
                ldx   #$02E1
                jsl   $E10000
                bcs   PGTPlaybackToolFail
                lda   #1
                sta   PlaybackToolActive
                ldx   #$15E1
                jsl   $E10000
                bcs   PGTPlaybackToolFail

                pea   $0000
                pea   $0000
                ldx   #$1AE1
                jsl   $E10000
                bcs   PGTPlaybackStatusFail
                pla
                sta   DOCStatusPtr
                pla
                sta   DOCStatusPtr+2
                lda   DOCStatusPtr
                ora   DOCStatusPtr+2
                beq   PGTPlaybackToolFail
                clc
                rts
PGTPlaybackStatusFail
                pla
                pla
PGTPlaybackToolFail sec
                rts

StopPlaybackTool
                lda   PlaybackStreamActive
                beq   PGTPlaybackStreamStopped
                ldx   #$17E1
                jsl   $E10000
                stz   PlaybackStreamActive
PGTPlaybackStreamStopped
                lda   PlaybackToolActive
                beq   PGTPlaybackToolStopped
                ldx   #$03E1
                jsl   $E10000
                stz   PlaybackToolActive
PGTPlaybackToolStopped
                lda   PlaybackToolLoaded
                beq   PGTPlaybackToolUnloaded
                pea   $00E1
                _UnloadOneTool
                stz   PlaybackToolLoaded
PGTPlaybackToolUnloaded
                rts
                fin

ShutEverything lda   RawActive
                beq   PGTRawStopped
                jsl   PGTU2StopRaw
                stz   RawActive
PGTRawStopped   lda   SavedDP
                tcd
                do    PGTDocMode
                jsr   StopPlaybackTool
                fin
                lda   RingHandle
                ora   RingHandle+2
                beq   PGTRingDisposed
                lda   RingHandle+2
                pha
                lda   RingHandle
                pha
                _DisposeHandle
                stz   RingHandle
                stz   RingHandle+2
PGTRingDisposed lda   DPHandle
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
* State and messages
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
RingHandle      ds    4
RingPointer     ds    4
SelectedSlot    ds    2
LastKey         ds    2
HexValue        ds    2
HexWordValue    ds    2
HeaderIndex     ds    2
UDPSize         ds    2
HeaderTemp      ds    2
TestComplete    ds    2
PlaybackActive  ds    2
PlaybackToolLoaded ds 2
PlaybackToolActive ds 2
PlaybackStreamActive ds 2
DOCStartError   ds    2
CurrentDOCBlocks ds  4
LastDOCBlocks  ds    4
DOCBlockDelta  ds    2
StreamPhase     ds    2
LastTick        ds    2
CurrentTick     ds    2
TickDelta       ds    2
MaxTickGap      ds    2
ConsumeAmount   ds    2
FramesSeen      ds    2
FramesAccepted  ds    2
FramesDropped   ds    2
Underruns       ds    2
RingHighWater   ds    2
PayloadBytes    ds    4
ConsumedBytes   ds    4
HeaderBuffer    ds    42
QuitPB          dw    0

                do    PGTDocMode
TitleMsg        asc   0D,'Petar_gsTCP 22kHz UDP/DOC Test',0D,00
SafetyMsg       asc   'P3 real DOC audio; disconnect Marinetti first.',0D,00
RunningMsg      asc   'UDP 6502: buffering 65,520 bytes; ESC stops.',0D,00
RingErrorMsg    asc   'Could not allocate locked 64K stream ring.',0D,00
PassMsg         asc   'PASS: DOC playback had no drops or underruns.',0D,00
FailMsg         asc   'FAIL: DOC stream ring dropped or underrran.',0D,00
ToolErrorMsg    asc   'Tool 225 P0.9G-M2-R12A unavailable.',0D,00
DOCStartErrorMsg asc  'Tool 225 could not start the DOC ring.',0D,00
DOCStartedMsg   asc   'DOC playback started; streaming live audio.',0D,00
                else
TitleMsg        asc   0D,'Petar_gsTCP 22kHz Stream Ring Test',0D,00
SafetyMsg       asc   'UDP P3 precursor; disconnect Marinetti first.',0D,00
RunningMsg      asc   'Waiting for UDP port 6502 stream; ESC stops.',0D,00
RingErrorMsg    asc   'Could not allocate locked 16K stream ring.',0D,00
PassMsg         asc   'PASS: 22.05kHz consumer had no drops or underruns.',0D,00
FailMsg         asc   'FAIL: stream ring dropped or underrran.',0D,00
                fin
SlotPrompt      asc   'Uthernet II slot [3]: ',00
SlotErrorMsg    asc   0D,'Slot must be 1 through 7.',0D,00
DPErrorMsg      asc   'Could not allocate direct page.',0D,00
FoundMsg        asc   'W5100 found in slot $',00
NoCardMsg       asc   'W5100 detection failed.',0D,00
StartErrorMsg   asc   'Could not open W5100 socket 0 MACRAW.',0D,00
RuntimeMsg      asc   'W5100 receive/release failed.',0D,00
StoppedMsg      asc   0D,'Stopped by Escape.',0D,00
FinishedMsg     asc   0D,'Sender end marker received.',0D,00
FramesMsg       asc   'accepted=$',00
PayloadMsg      asc   ' payload=$',00
ConsumedMsg     asc   'consumed=$',00
HighWaterMsg    asc   ' high=$',00
DropsMsg        asc   'drops=$',00
UnderrunMsg     asc   ' underruns=$',00
GapMsg          asc   ' maxTickGap=$',00
WrapMsg         asc   ' RXwrap=$',00
ExitMsg         asc   'Press Return to exit.',0D,00
CRLFMsg         asc   0D,00

                do    PGTDocMode
DOCRingDescriptor
DOCRingPointer  adrl  $00000000
                adrl  $00010000
                dw    $0058           ; proven 21,972.65 Hz DOC frequency
                dfb   $80             ; 32 KiB DOC page, anchor oscillator 0
                dfb   $00
                dfb   $02             ; two audible oscillators
                dfb   $FF,$00          ; full-volume right
                dfb   $FF,$10          ; full-volume left
                fin
