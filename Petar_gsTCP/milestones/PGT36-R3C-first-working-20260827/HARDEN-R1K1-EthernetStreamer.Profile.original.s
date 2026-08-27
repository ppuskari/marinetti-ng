*
* EthernetStreamer Profiles v0.1.2 P0.6.2C-L3R3-M3R36A - 22m512
*
* Raw Marinetti TCP client for Petar's Ensoniq
* Stream Provider and the Tool225 Kit 1.1 ABI.
* Forked from the proven StreamTest P0.17
* foreground producer and ring-buffer design.
*
* Wire format:
*
* 21973 frames/second
* unsigned 8-bit stereo PCM
* planar 8192-byte L then 8192-byte R quanta
* no container header
* no $00 samples
*
* The application prompts for an IPv4 address or
* DNS host name and TCP port.  It opens a raw TCP
* client connection through Marinetti, transmits no
* request bytes, and accumulates arbitrary receive
* segments into exact producer quanta.
*
* Main-memory and DOC responsibilities remain split
* exactly as in StreamTest: foreground code performs
* all TCP reads; stereo network profiles write planar 8K planes directly
* into final ring memory; the provider performs DOC-zero sanitization;
* Tool225 performs all interrupt-time
* DOC RAM refills and oscillator control.
*
* Required Tool225 Kit 1.1 selector ABI:
*
* $1AE1 PCM225GetRingStatus
* $1DE1 PCM225GetPhaseStatus
* $1BE1 PCM225PrepareRing
* $1CE1 PCM225StartStereo
*
* The application prefers two locked 512K channel
* rings and falls back atomically to two locked 256K
* rings.  It clears both rings to unsigned silence
* and prefills the complete selected ring before playback.
*
* Tool225 DOC layout:
*
* $0000-$1FFF shared 8192-byte timer
* $4000-$7FFF right 16384-byte audible buffer
* $8000-$BFFF left 16384-byte audible buffer
*
* Right oscillators 0 and 1 share $4000-$7FFF.
* Left oscillators 2 and 3 share $8000-$BFFF.
* Oscillator 4 is the shared silent refill timer.
*
* Physical IIgs channel mapping:
*
* $00 = right
* $10 = left
*

         lst   off
         rel
         typ   S16
         dsk   EtherStrAuto.L
         lst   off

         use   4/Locator.Macs
         use   4/Mem.Macs
         use   4/Misc.Macs
         use   4/Event.Macs
         use   4/Qd.Macs
         use   4/Resource.Macs
         use   4/Std.Macs
         use   Text.Macs.s
         use   Marinetti.Macs.s
         use   Tool225.Macs.s
         use   4/Util.Macs

GSOS           equ   $E100A8

OpenCall       equ   $2010
ReadCall       equ   $2012
CloseCall      equ   $2014
SetMarkCall    equ   $2016
GetEOFCall     equ   $2019
QuitCall       equ   $2029

RingBytesLow   equ   $0000
Ring256High    equ   $0004
Ring512High    equ   $0008
Ring256Blocks  equ   $0400
Ring512Blocks  equ   $0800
ChunkBlocks     equ   $0040
PumpBurstLimit  equ   $0040
NetworkPrefill  equ   $001E
NetworkLowLead  equ   $0080
NetworkRescueLead equ   $0100
NetworkPaddleLead equ   $0660
NetworkPaddleExit equ   $0740
NetworkHiddenRefreshLead equ   $0600
DefaultPort    equ   22510
MarinettiTool  equ   $0036
MarinettiVer   equ   $0200
TextTool       equ   $000C

TCPClosed      equ   $0000
TCPSynSent     equ   $0002
TCPSynRcvd     equ   $0003
TCPEstablished equ   $0004
TCPTimeWait    equ   $000A
ConnectTimeout equ   15*60

DNRPending     equ   $0000
DNROkay        equ   $0001

NetErrTCPBase  equ   $FA00
NetErrBase     equ   $FB00
NetErrText     equ   $FB01
NetErrInactive equ   $FB02
NetErrDNS      equ   $FB03
NetErrLogin    equ   $FB04
NetErrOpen     equ   $FB05
NetErrStatus   equ   $FB06
NetErrRead     equ   $FB07
NetErrUnder    equ   $FB08
NetErrClosed   equ   $FB09
NetErrInput    equ   $FB0A
NetErrTimeout  equ   $FB0B
NetErrCancel   equ   $FB0C

ActionNone     equ   $0000
ActionExit     equ   $0001
ActionChange   equ   $0002
ActionReset    equ   $0003
ActionDiag     equ   $0004
ActionLost     equ   $0005

* Baseline build leaves automatic recovery disabled.
* The separate EtherStrAuto build enables this same
* watchdog logic for controlled long-duration testing.

AutoRecoverEnabled equ $0000
AutoSkewLimit       equ $0002
AutoLowLeadLimit    equ $0010
AutoLowLeadLoops    equ $0008

KeyDownMask    equ   $0008
EventPollLoops equ   $0400

InterleaveMax  equ   $4000
MinDataHigh     equ   $0008
Data512High    equ   $0010

ToneFreq        equ   $0058
DOCRight       equ   $00
DOCLeft        equ   $10

AttrLocked     equ   $8000

RingHighOff    equ   31*2
RightLowOff    equ   0
LeftLowOff     equ   2*2
RightHighOff   equ   RingHighOff
LeftHighOff    equ   RingHighOff+2*2

PhasePollOff       equ   $0008
PhaseFaultCountOff equ   $000A
PhaseFaultFlagsOff equ   $000C
PhaseCurrentOff    equ   $000E
PhaseStreak01Off   equ   $0010
PhaseStreak23Off   equ   $0012
PhaseMax01Off      equ   $0014
PhaseMax23Off      equ   $0016
PhaseSample01Off   equ   $0018
PhaseSample23Off   equ   $001A

* Private errors:
*
* $FA01 = not a RIFF/WAVE file
* $FA02 = unsupported or missing fmt chunk
* $FA03 = data chunk shorter than two 256K rings
* $FA04 = data length not divisible by 512
* $FA05 = malformed file or short GS/OS read
* $FA06 = Memory Manager allocation failed
* $FA07 = Memory Manager returned null pointer
* $FA08 = foreground producer underrun
* $FA09 = ring status pointer was null
* $FA0A = desktop/Standard File startup failed
* $FA0B = Tool225 phase-status selector unavailable

*-------------------------------------------------

Start
         clc
         xce
         rep   #$30
         phk
         plb

         stz   MMStartedFlag
         stz   WaveOpenFlag
         stz   FoundFmtFlag
         stz   SelectorToolsHandle
         stz   SelectorToolsHandle+2

         stz   NetworkModeFlag
         stz   TextToolLoaded
         stz   TextToolActive
         stz   TCPToolLoaded
         stz   TCPToolActive
         stz   NetIPID
         stz   NetSocketOpen
         stz   PlaybackRunningFlag
         stz   NetworkStopRequested
         stz   NetworkAction
         stz   PendingNetworkAction
         stz   LastNetworkError
         stz   ResetCount
         stz   DisconnectCount
         stz   AutoResetCount
         stz   LowWaterResetCount
         stz   LowWaterResetFlag
         stz   LowWaterLead
         stz   HiddenRefreshActive
         stz   HiddenRefreshArmed
         stz   HiddenRefreshReportPending
         stz   HiddenRefreshCount
         stz   HiddenRefreshSuccessCount
         stz   HiddenRefreshFailCount
         stz   HiddenRefreshLastLead
         stz   HiddenRefreshReason
         stz   HiddenRefreshRearmCount
         stz   HiddenRefreshSocketCount
         stz   PaddleEnterCount
         stz   PaddleExitCount
         stz   PaddleLastEnterLead
         stz   PaddleLastExitLead
         stz   PumpRescueActive
         stz   PumpRescueCount
         stz   PumpRescueQuanta
         stz   NetCarryBytes
         stz   AutoLowLeadCount
         stz   AutoResetPending
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   PlaybackStopError

         stz   TLStartedFlag
         stz   PlaybackToolActive
         stz   PlaybackToolLoaded

         stz   WorkHandle
         stz   WorkHandle+2

         stz   LeftHandle
         stz   LeftHandle+2

         stz   RightHandle
         stz   RightHandle+2

* Establish this application's Tool Locator
* lifecycle before using MM and StartUpTools.

         _TLStartUp

         lda   #1
         sta   TLStartedFlag

* Obtain a Memory Manager user ID.

         pha
         _MMStartUp
         pla
         sta   MasterID

         ora   #$0100
         sta   MemoryID

         lda   #1
         sta   MMStartedFlag

         lda   #1
         sta   NetworkModeFlag
         brl   NetworkEntry

* Start the desktop tools needed by Standard File.

         jsr   StartSelectorTools
         bcc   SelectorToolsReady

         ldx   #^SelectorStartErrMsg
         ldy   #SelectorStartErrMsg
         brl   FailAfterMemory

* Ask Standard File for a file.  The returned path
* is an FST-resolved Class 1 output string.

SelectorToolsReady
         jsr   SelectWaveFile
         bcc   WaveSelected

* Cancel is a normal clean exit.  If one or more
* files were played, shut down Tool 225 once here.
* The desktop tool group remains active between
* selections.

         jsr   ShutPlaybackTool
         jsr   StopSelectorTools
         bcc   CancelToolsStopped

         ldx   #^SelectorShutErrMsg
         ldy   #SelectorShutErrMsg
         brl   FailAfterMemory

CancelToolsStopped
         jsr   ShutMemory

* Use the canonical empty class-one Quit block.  A
* null restart request returns through GS/OS's quit
* return stack to the Finder that launched us.

         jsl   GSOS
         dw    QuitCall
         adrl  QuitPB

QuitReturned1
         bra   QuitReturned1

* Keep the complete desktop tool group active for
* the entire application lifetime.  Standard File
* and its dependencies are shut down only after
* playback and Tool 225 cleanup are complete.

WaveSelected

* Open the selected WAV and leave its mark at data.

         jsr   OpenAndParseWave
         bcc   WaveReady

         ldx   #^WaveErrMsg
         ldy   #WaveErrMsg
         brl   FailAfterMemory

* Prefer two locked 512K channel rings.  Fall back
* to two locked 256K rings as one atomic retry.

WaveReady
         jsr   AllocateStereoRings
         bcc   StereoRingsReady

         ldx   #^MemoryErrMsg
         ldy   #MemoryErrMsg
         brl   FailAfterMemory

* Fill both complete rings before sound starts.

StereoRingsReady
         jsr   FillInitialRings
         bcc   InitialRingsReady

         ldx   #^ReadErrMsg
         ldy   #ReadErrMsg
         brl   FailAfterMemory

* Convert interleaved byte count to the number of
* 256-sample channel blocks: data bytes / 512.

InitialRingsReady
         lda   NetworkModeFlag
         beq   FileInitialRingsReady

* A live source has no known final block.  Keep the
* 32-bit source limit effectively infinite and retain
* the exact prefill count made by FillInitialRings.

         lda   #$FFFF
         sta   TotalBlocks
         sta   TotalBlocks+2
         brl   LoadPlaybackTool

FileInitialRingsReady
         lda   WaveDataSize
         sta   TotalBlocks

         lda   WaveDataSize+2
         sta   TotalBlocks+2
         ldx   #8
SizeShiftLoop
         lsr   TotalBlocks+2
         ror   TotalBlocks
         dex
         bne   SizeShiftLoop

         lda   RingBlocksSelected
         sta   ProducedBlocks
         stz   ProducedBlocks+2

LoadPlaybackTool
* Load and start Tool 225 only for the first file.
* Keep it active while returning to Standard File
* between playback tests.

         lda   PlaybackToolActive
         bne   ToolAlreadyStarted

         pea   $00E1
         pea   $0000
         _LoadOneTool
         bcc   ToolLoaded

         ldx   #^LoadErrMsg
         ldy   #LoadErrMsg
         brl   FailAfterMemory

ToolLoaded
         lda   #1
         sta   PlaybackToolLoaded

         pea   $E1AD
         _PCM225StartUp
         bcc   ToolStarted

         ldx   #^StartErrMsg
         ldy   #StartErrMsg
         brl   FailAfterMemory

ToolStarted
         lda   #1
         sta   PlaybackToolActive

ToolAlreadyStarted
         _PCM225Init
         bcc   StreamModeReady

         ldx   #^InitErrMsg
         ldy   #InitErrMsg
         brl   FailAfterTool

* Obtain and patch the exported ring counters.

StreamModeReady
         pea   $0000
         pea   $0000
         _PCM225GetRingStatus
         bcc   RingStatusReturned

         pla
         pla

         ldx   #^StatusErrMsg
         ldy   #StatusErrMsg
         brl   FailAfterStream

RingStatusReturned
         pla
         sta   RingStatusPtr

         pla
         sta   RingStatusPtr+2

         lda   RingStatusPtr
         ora   RingStatusPtr+2
         bne   RingStatusValid

         lda   #$FA09
         ldx   #^StatusErrMsg
         ldy   #StatusErrMsg
         brl   FailAfterStream

RingStatusValid
         jsr   PatchRingCounterReads

* Tool225 P0.9B exports an append-only physical DOC
* oscillator-pair diagnostic block through selector $1D.

         pea   $0000
         pea   $0000
         _PCM225GetPhaseStatus
         bcc   PhaseStatusReturned

         pla
         pla
         lda   #$FA0B

         ldx   #^PhaseStatusErrMsg
         ldy   #PhaseStatusErrMsg
         brl   FailAfterStream

PhaseStatusReturned
         pla
         sta   PhaseStatusPtr

         pla
         sta   PhaseStatusPtr+2

         lda   PhaseStatusPtr
         ora   PhaseStatusPtr+2
         bne   PhaseStatusValid

         lda   #$FA0B
         ldx   #^PhaseStatusErrMsg
         ldy   #PhaseStatusErrMsg
         brl   FailAfterStream

PhaseStatusValid
         jsr   PatchPhaseDiagnosticReads
* M3 TRUE 22K MONO PLAYBACK.
*
* Tool225 P0.9G-M2-R12A experimental is required. Selector $19 uses a
* 16384-sample silent refill timer matching its 16K refill half, and
* immediate ring startup normalizes DOC enable to oscillators 0..4.
* Oscillator 0 is the silent refill anchor;
* oscillators 1 and 2 read the same DOC buffer and route to right/left.
*
* M3R15H WARM HANDOFF: print the human-visible Playing line before DOC
* oscillators start.  Once Tool225 returns, network mode enters the producer
* body immediately, so no Text Tool/control work sits between first sound and
* the first ring-counter refresh / TCP pump.

         lda   NetworkModeFlag
         beq   M3R15HStartDOC

         pea   ^PlayingMsg
         pea   PlayingMsg
         _WriteCString

M3R15HStartDOC
         pea   ^RightRingStream
         pea   RightRingStream
         _PCM225StreamRing
         bcc   M3MonoRingStarted

         ldx   #^RightSubmitErrMsg
         ldy   #RightSubmitErrMsg
         brl   FailAfterStream

M3MonoRingStarted
         stz   PlaybackEventPoll
         lda   #1
         sta   PlaybackRunningFlag

         lda   NetworkModeFlag
         beq   FeedLoop

* First post-start action is ReadRingCounters -> UpdateProducerLead -> pump.
         brl   PlaybackContinues


*-------------------------------------------------
* Foreground producer loop.
*
* One ring block is 256 mono samples.
* M3 true-22K-mono quantum is 64 blocks / 16384 bytes,
* transported as two sequential exact 8K lanes.
*
* Network playback uses a 64 KiB wire-service budget
* before yielding to the outer control loop. Generated
* M3 22K mono uses four 16K quanta; other mono uses eight 8K quanta.
* True-22K M3R14N Marinetti reads are capped at 16 KiB.
*-------------------------------------------------

FeedLoop
* M3R25B TRUE LIFE SUPPORT: while FULL PADDLE is active, dedicate the
* foreground CPU to DOC-safe network ingestion.  R24R Marinetti poll
* cadence is intentionally preserved unchanged.
         lda   PumpRescueActive
         bne   PlaybackContinues
         jsr   CheckPlaybackStop
         bcc   PlaybackContinues

         lda   NetworkModeFlag
         bne   NetworkControlReady
         brl   PlaybackStopped

NetworkControlReady
         lda   NetworkAction
         cmp   #ActionDiag
         beq   PlaybackDiagnostics

         jsr   CaptureDiagnostics
         brl   PlaybackStopped

PlaybackDiagnostics
         jsr   CaptureDiagnostics
         jsr   PrintDiagnosticsSnapshot
         stz   NetworkAction
         brl   FeedLoop

PlaybackContinues
         jsr   ReadRingCounters
         jsr   UpdateProducerLead
* M3R36 parent: start and remain in FULL PADDLE for the entire live epoch.
* Arm only after the first real post-start ring-counter sample, so the
* diagnostic entry lead reflects the actual playing reservoir.
         lda   NetworkModeFlag
         beq   M3R36PaddleReady
         lda   PlaybackRunningFlag
         beq   M3R36PaddleReady
         lda   PumpRescueActive
         bne   M3R36PaddleReady
         lda   #1
         sta   PumpRescueActive
         inc   PumpRescueCount
         inc   PaddleEnterCount
         lda   LastLeadBlocks
         sta   PaddleLastEnterLead
M3R36PaddleReady
         stz   PumpBurstCurrent
         stz   PumpStopReason
* M3R21F FULL PADDLE: keep PumpRescueActive latched across outer
* FeedLoop yields.  ResetProducerDiagnostics clears it for a new prefill.

PumpEvaluate

* Have all source blocks already been produced?

         lda   ProducedBlocks+2
         cmp   TotalBlocks+2
         bne   MoreSourceExists

         lda   ProducedBlocks
         cmp   TotalBlocks
         bne   MoreSourceExists

         brl   WaitForDrain

MoreSourceExists

* The faster channel must never catch the producer.

         lda   ConsumedMax+2
         cmp   ProducedBlocks+2
         bcc   ProducerSafe
         bne   ProducerUnderrun

         lda   ConsumedMax
         cmp   ProducedBlocks
         bcc   ProducerSafe

ProducerUnderrun
         lda   NetworkModeFlag
         beq   FileProducerUnderrun

* The low-water guard should normally fire first.  If a
* full 32-block timer step crosses the remaining margin,
* recover the live session instead of terminating it.

         stz   LowWaterLead
         lda   #1
         sta   LowWaterResetFlag
         stz   AutomaticResetFlag
         lda   #ActionReset
         sta   NetworkAction
         jsr   CaptureDiagnostics
         brl   PlaybackStopped

FileProducerUnderrun
         lda   #$FA08
         ldx   #^UnderrunErrMsg
         ldy   #UnderrunErrMsg
         brl   FailAfterStream

ProducerSafe

* RemainingBlocks = TotalBlocks-ProducedBlocks.

         lda   TotalBlocks
         sec
         sbc   ProducedBlocks
         sta   RemainingBlocks

         lda   TotalBlocks+2
         sbc   ProducedBlocks+2
         sta   RemainingBlocks+2

* M3R15H WARM HANDOFF / BREATHING RESERVE.
* Keep one 16K producer quantum (64 blocks) physically free
* in the live ring.  This prevents a mathematically full ring from hard-stopping
* foreground receive service/TCP progression.  Ring wrap safety still uses the
* full RingBlocksSelected allocation; only producer occupancy is capped here.
*
* FreeBlocks = ConsumedMin + usable ring blocks - ProducedBlocks.

         lda   ConsumedMin
         clc
         adc   #$07C0
         sta   FreeBlocks

         lda   ConsumedMin+2
         adc   #0
         sta   FreeBlocks+2

         lda   FreeBlocks
         sec
         sbc   ProducedBlocks
         sta   FreeBlocks

         lda   FreeBlocks+2
         sbc   ProducedBlocks+2
         sta   FreeBlocks+2

* Usually read one complete 32-block producer quantum.
* A finite file's final read may contain fewer blocks.

         lda   RemainingBlocks+2
         bne   NeedFullChunk

         lda   RemainingBlocks
         cmp   #ChunkBlocks
         bcs   NeedFullChunk

         sta   BlocksToRead

* Wait until the complete final chunk is free.

         lda   FreeBlocks+2
         bne   ReadChunkNow

         lda   FreeBlocks
         cmp   BlocksToRead
         bcs   FinalChunkReady

         lda   #$0002              ; WHY=2: ring/free-space pressure
         sta   PumpStopReason
         brl   PumpYield

FinalChunkReady
         bra   ReadChunkNow

NeedFullChunk
         lda   FreeBlocks+2
         bne   FullChunkReady

         lda   FreeBlocks
         cmp   #ChunkBlocks
         bcs   FullChunkReady

         lda   #$0002              ; WHY=2: ring/free-space pressure
         sta   PumpStopReason
         brl   PumpYield

FullChunkReady
         lda   #ChunkBlocks
         sta   BlocksToRead

ReadChunkNow
         lda   NetworkModeFlag
         beq   M3R7ReadChunkNow
         lda   PlaybackRunningFlag
         beq   M3R7ReadChunkNow

         _TCPIPPoll
         jsr   GetTCPStatus
         bcs   M3R7QueueStatusFailed

M3R7QueueStartCaptured
         lda   TCPStatusBuffer
         cmp   #TCPEstablished
         bne   M3R7QueueStatusFailed

         lda   TCPStatusBuffer+10
         bne   M3R7ReadChunkNow
         lda   TCPStatusBuffer+8
         cmp   #$0100
         bcs   M3R7ReadChunkNow

         lda   #$0001              ; WHY=1: <256 bytes queued
         sta   PumpStopReason
         brl   PumpYield

M3R7QueueStatusFailed
         lda   #$0006              ; WHY=6: TCP status/socket
         sta   PumpStopReason

* M3R24R STATUS ESCAPE.  This legacy branch used to bypass the entire
* Paddle/warm-restream controller.  At a safe pre-read boundary, an
* unusable TCP status while FULL PADDLE is active gets one armed warm
* socket replacement before the old hard-low fallback is considered.
         lda   PumpRescueActive
         beq   M3R24RStatusFallback
         lda   HiddenRefreshArmed
         beq   M3R24RStatusFallback
         lda   #$0002              ; restream WHY=2: TCP status/socket
         sta   HiddenRefreshReason
         inc   HiddenRefreshSocketCount
         jsr   M3R22HHiddenRefresh
         bcc   M3R24RStatusRefreshOkay
         cmp   #NetErrCancel
         bne   M3R24RStatusRefreshFailed
         lda   #ActionExit
         sta   NetworkAction
         jsr   CaptureDiagnostics
         brl   PlaybackStopped
M3R24RStatusRefreshFailed
         brl   M3R22HRefreshFailed
M3R24RStatusRefreshOkay
         brl   PumpYield

M3R24RStatusFallback
         brl   PumpLowWaterReset

M3R7ReadChunkNow
         jsr   ReadNextWaveChunk
         bcc   ChunkReadOkay
         sta   LastNetworkError

* A playback control key may be detected while the exact
* TCP reader is waiting for the rest of one producer quantum.
* A reset preserves the partial aligned staging data; exit
* and endpoint change discard it before Tool225 stops.

         lda   NetworkModeFlag
         beq   FileChunkReadFailed

         lda   NetworkStopRequested
         beq   NetworkChunkReadFailed
         stz   NetworkStopRequested
         jsr   CaptureDiagnostics
         brl   PlaybackStopped

NetworkChunkReadFailed
         lda   #ActionLost
         sta   NetworkAction
         inc   DisconnectCount
         jsr   CaptureDiagnostics
         brl   PlaybackStopped

FileChunkReadFailed
         lda   LastNetworkError
         ldx   #^ReadErrMsg
         ldy   #ReadErrMsg
         brl   FailAfterStream

ChunkReadOkay
         lda   ProducedBlocks
         clc
         adc   BlocksToRead
         sta   ProducedBlocks

         lda   ProducedBlocks+2
         adc   #0
         sta   ProducedBlocks+2

* The separate file path retains one producer operation per
* foreground loop.  Only live TCP playback enters the greedy
* bounded burst.

         lda   NetworkModeFlag
         bne   PumpChunkNetwork
         brl   PumpReturnOuter

PumpChunkNetwork
* M3R36 parent: FULL PADDLE uses a true repeating batch.  Keep the
* receive hot path lean, but amortize the outer ring/control boundary
* across 3 complete 16K producer quanta.
         lda   PumpRescueActive
         beq   M3R36NormalChunk
         inc   PumpBurstCurrent
         lda   PumpBurstCurrent
         cmp   #3
         bcc   M3R36PaddleContinue
         stz   PumpBurstCurrent
         brl   PumpYield
M3R36PaddleContinue
         brl   PumpEvaluate

M3R36NormalChunk
         inc   PumpBurstCurrent

* Normal mode retains the bounded 64 KiB service budget.

PumpCheckNormalLimit
         lda   PumpBurstCurrent
         cmp   #PumpBurstLimit
         bcc   M3R7NormalContinue
         lda   #$0003              ; WHY=3: starvation safety ceiling
         sta   PumpStopReason
         brl   PumpYield
M3R7NormalContinue
         brl   PumpEvaluate

PumpYield

* Safe producer boundary.  Refresh ring consumption first, then
* service network controls.  CheckNetworkControlKey includes an
* Event Manager key-down fallback in L3R3, so a single quick D/C/R
* tap is retained even when the direct hardware latch was already
* consumed.  No toolbox event polling occurs inside the exact 8K
* TCP reader.

         lda   NetworkModeFlag
         bne   PumpYieldNetwork
         brl   PumpReturnOuter

PumpYieldNetwork
         jsr   ReadRingCounters
         jsr   UpdateProducerLead

* HARDEN-R1K1 CONTROL BOUNDARY.  FULL PADDLE still owns the exact TCP
* reader, but once a completed producer batch reaches this outer safe
* boundary, sample and dispatch the existing keyboard controls.  This
* keeps all key polling, Event Manager fallback, Stop, diagnostics, and
* lifecycle work outside the sensitive receive operation.
         jsr   CheckNetworkControlKey
         bcc   PumpControlDone

         lda   NetworkAction
         cmp   #ActionDiag
         beq   PumpDiagnostics

         jsr   CaptureDiagnostics
         brl   PlaybackStopped

PumpDiagnostics
         jsr   CaptureDiagnostics
         jsr   PrintDiagnosticsSnapshot
         stz   NetworkAction

PumpControlDone

M3R21FFullPaddleBoundary

* M3R21F FULL PADDLE RESCUE.  One common rescue state for every Ethernet
* streamer.  Begin paddling while roughly 80% of the logical reservoir
* remains; stay in rescue until roughly 90% is restored.  Stereo is one
* interleaved TCP stream and therefore uses the same single logical lead.

         lda   PumpRescueActive
         bne   M3R20PPaddleActive
M3R20PPaddleActive
* M3R36 parent: ALWAYS PADDLE.  Above the original hard-low mark, the
* just-completed batch simply returns to the outer safe boundary.  Do not
* perform a second Poll/Status gate here; ReadNetworkBytes owns the fresh
* Marinetti status before every 8K TCP read.  At/below hard low, retain the
* proven queued-data rescue / hard-rebuffer authority below.
         lda   LastLeadBlocks
         cmp   #NetworkLowLead+1
         bcc   PumpCheckRescueQueue
         brl   PumpReturnOuter

* Retain the legacy status/socket warm-refresh failure target because the
* pre-read status path can still branch here on a real socket failure.
M3R22HRefreshFailed
         lda   LastLeadBlocks
         sta   LowWaterLead
         lda   #1
         sta   LowWaterResetFlag
         stz   AutomaticResetFlag
         lda   #ActionReset
         sta   NetworkAction
         jsr   CaptureDiagnostics
         brl   PlaybackStopped

PumpCheckRescueQueue
         _TCPIPPoll
         jsr   GetTCPStatus
         bcs   M3R20PNoUsableQueue

         lda   TCPStatusBuffer
         cmp   #TCPEstablished
         bne   M3R20PNoUsableQueue

         lda   TCPStatusBuffer+10
         bne   PumpRescueQueued
         lda   TCPStatusBuffer+8
         cmp   #$0100
         bcs   PumpRescueQueued

M3R20PNoUsableQueue
* At the paddling-water mark, lack of queued data is normal: yield and try
* again without destroying the connection.  Only the original hard low-water
* mark is allowed to escalate to the existing reset/reconnect policy.
         lda   LastLeadBlocks
         cmp   #NetworkLowLead+1
         bcc   PumpLowWaterReset
         brl   PumpReturnOuter

PumpRescueQueued
         lda   PumpRescueActive
         bne   PumpRescueContinue

         lda   #1
         sta   PumpRescueActive
         inc   PumpRescueCount

PumpRescueContinue
         brl   PumpEvaluate

PumpLowWaterReset
         lda   PumpStopReason
         bne   M3R7LowWaterReasonReady
         lda   #$0004              ; WHY=4: low water with no usable queue
         sta   PumpStopReason
M3R7LowWaterReasonReady
         jsr   CheckLowWaterRecovery
         bcc   PumpReturnOuter
         jsr   CaptureDiagnostics
         brl   PlaybackStopped

PumpReturnOuter
         brl   FeedLoop

*-------------------------------------------------
* All WAV data has been produced.  Wait until both
* rings have copied every source block into DOC.
*
* The preparation script appends $80 silence, so
* stopping here does not cut off program material.
*-------------------------------------------------

WaitForDrain
         lda   ConsumedMin+2
         cmp   TotalBlocks+2
         bcc   DrainNotReady
         bne   PlaybackDone

         lda   ConsumedMin
         cmp   TotalBlocks
         bcs   PlaybackDone

DrainNotReady
         brl   FeedLoop

PlaybackStopped
         brl   PlaybackDone

PlaybackDone
         stz   PlaybackStopError
         jsr   StopPlaybackIRQLive
         bcs   PlaybackStopFailed
         brl   StreamsStopped

PlaybackStopFailed
* File playback retains its original fatal Tool225
* error behavior.  A network session may disappear at
* any point, so preserve the stop error and continue
* through the recoverable session state machine.

         sta   PlaybackStopError
         lda   NetworkModeFlag
         bne   NetworkStopWasImperfect

         lda   PlaybackStopError
         ldx   #^StopErrMsg
         ldy   #StopErrMsg
         brl   FailAfterStream

NetworkStopWasImperfect
         pea   ^StopWarningMsg
         pea   StopWarningMsg
         _WriteCString
         lda   PlaybackStopError
         jsr   WriteHexWord
         jsr   WriteCRLF

StreamsStopped
         stz   PlaybackRunningFlag

         lda   NetworkModeFlag
         bne   NetworkStreamsStopped
         brl   FileStreamsStopped

NetworkStreamsStopped
         lda   NetworkAction
         cmp   #ActionReset
         bne   NetworkActionNotReset
         brl   NetworkResetAfterStop

NetworkActionNotReset
         cmp   #ActionChange
         bne   NetworkActionNotChange
         brl   NetworkChangeAfterStop

NetworkActionNotChange
         cmp   #ActionLost
         bne   NetworkCleanExit
         brl   NetworkLostAfterStop

NetworkCleanExit
         jsr   ShutPlaybackTool
         jsr   ShutNetworkFrontend
         jsr   ReleaseAllRings
         jsr   ShutMemory

         jsl   GSOS
         dw    QuitCall
         adrl  QuitPB

NetworkQuitReturned
         bra   NetworkQuitReturned

NetworkResetAfterStop
         inc   ResetCount
         lda   LowWaterResetFlag
         beq   NetworkResetNotLowWater

         inc   LowWaterResetCount
         pea   ^LowWaterResettingMsg
         pea   LowWaterResettingMsg
         _WriteCString
         lda   LowWaterLead
         jsr   WriteHexWord
         jsr   WriteCRLF
         jsr   PrintPaddleStateLine
         bra   NetworkResetMessageDone

NetworkResetNotLowWater
         lda   AutomaticResetFlag
         beq   NetworkManualResetMessage

         inc   AutoResetCount
         lda   PhaseResetFlag
         beq   NetworkGenericAutoReset

         pea   ^PhaseResettingMsg
         pea   PhaseResettingMsg
         _WriteCString
         lda   PhaseTriggerFlags
         jsr   WriteHexWord
         jsr   WriteCRLF
         bra   NetworkResetMessageDone

NetworkGenericAutoReset
         pea   ^AutoResettingMsg
         pea   AutoResettingMsg
         _WriteCString
         bra   NetworkResetMessageDone

NetworkManualResetMessage
         pea   ^ResettingMsg
         pea   ResettingMsg
         _WriteCString

NetworkResetMessageDone
         lda   LowWaterResetFlag
         bne   M3R18GLowWaterReconnect

* Manual/phase resets retain the traditional full snapshot and same socket.
         jsr   PrintDiagnosticsSnapshot
         brl   M3R18GResetRestartTool

M3R18GLowWaterReconnect
* M3R18G SPIKE ESCAPE: a hard low-water event tears down the current TCP
* state before rebuffering.  The endpoint IP/port are already resolved and
* remain in DestinationIP/DestinationPort, so reopen without returning to the
* endpoint prompt.  The concise low-water lead line above is the only console
* output before reconnect; the expensive full D-style dump is intentionally
* skipped on this recovery path.
         pea   ^LowWaterReconnectMsg
         pea   LowWaterReconnectMsg
         _WriteCString
         jsr   CloseNetworkSession
         jsr   OpenNetworkStream
         bcc   M3R18GResetRestartTool

         sta   LastNetworkError
         jsr   PrintConnectionError
         jsr   CloseNetworkSession
         jsr   ReleaseAllRings
         brl   NetworkSessionPrompt

M3R18GResetRestartTool
         jsr   RestartPlaybackTool
         bcc   NetworkToolRestarted

         jsr   PrintToolRestartError
         brl   NetworkCleanExit

NetworkToolRestarted
         stz   NetworkAction
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         brl   NetworkBeginPrefill

NetworkChangeAfterStop
         pea   ^ChangingEndpointMsg
         pea   ChangingEndpointMsg
         _WriteCString
         jsr   PrintDiagnosticsSnapshot
* A successful Stop is not a reusable streaming state.
* Always recycle Tool225 before a future StreamRing.
         jsr   RestartPlaybackTool
         bcc   NetworkChangeToolReady

         jsr   PrintToolRestartError
         brl   NetworkCleanExit

NetworkChangeToolReady
         jsr   CloseNetworkSession
         jsr   ReleaseAllRings
         brl   NetworkSessionPrompt

NetworkLostAfterStop
         jsr   PrintStreamEnded
         jsr   PrintDiagnosticsSnapshot
* Treat normal Stop as terminal for the current Tool225
* streaming epoch.  Recycle before any later StreamRing.
         jsr   RestartPlaybackTool
         bcc   NetworkLostToolReady

         jsr   PrintToolRestartError
         brl   NetworkCleanExit

NetworkLostToolReady
         jsr   CloseNetworkSession
         jsr   ReleaseAllRings
         brl   NetworkSessionPrompt

FileStreamsStopped
         jsr   CloseWaveFile
         jsr   ReleaseAllRings

* Stop does not establish a reusable StreamRing state.
* Recycle the tool now; the next selected file will run
* Init/GetRingStatus before starting its next ring.
         jsr   RestartPlaybackTool
         bcc   FilePlaybackToolReady

         ldx   #^StartErrMsg
         ldy   #StartErrMsg
         brl   FailAfterTool

FilePlaybackToolReady
* Keep Tool 225, Standard File, and the desktop tool
* group active.  Return directly to the selector for
* another playback test.

         brl   SelectorToolsReady


*-------------------------------------------------
* NetworkEntry
*
* The original StreamTest desktop/file path remains
* below as a provenance reference.  The P0.1 build
* enters here and substitutes Marinetti reads for
* GS/OS WAV reads while retaining Tool225's proven
* producer/ring/interrupt architecture.
*-------------------------------------------------

NetworkEntry
         jsr   StartTextConsole
         bcc   TextConsoleReady

         ldx   #^NetworkStartErrMsg
         ldy   #NetworkStartErrMsg
         brl   FailAfterMemory

TextConsoleReady
         pea   ^BannerMsg
         pea   BannerMsg
         _WriteCString

         jsr   StartMarinetti
         bcc   MarinettiReady

         ldx   #^MarinettiErrMsg
         ldy   #MarinettiErrMsg
         brl   FailAfterMemory

MarinettiReady
         brl   NetworkSessionPrompt

* One application launch may open many provider endpoints.
* Tool225, Marinetti, and the Text Tool stay loaded while
* each TCP login/socket and pair of source rings is recycled.

NetworkSessionPrompt
         stz   NetworkAction
         stz   PendingNetworkAction
         stz   NetworkStopRequested
         stz   PlaybackRunningFlag
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         stz   NetCarryBytes
         stz   PlaybackStopError
         stz   RingStatusPtr
         stz   RingStatusPtr+2
         stz   PhaseStatusPtr
         stz   PhaseStatusPtr+2

         pea   ^EndpointPromptMsg
         pea   EndpointPromptMsg
         _WriteCString

         jsr   PromptHostAndPort
         bcc   NetworkInputReady

         cmp   #NetErrCancel
         beq   NetworkPromptExit

         jsr   PrintInputError
         brl   NetworkSessionPrompt

NetworkPromptExit
         brl   NetworkCleanExit

NetworkInputReady
         jsr   BuildHostCString
         bcc   HostCStringReady

         jsr   PrintInputError
         brl   NetworkSessionPrompt

HostCStringReady
         pea   ^ResolvingMsg
         pea   ResolvingMsg
         _WriteCString

         jsr   ResolveHost
         bcc   HostResolved

         cmp   #NetErrCancel
         bne   ResolveFailureNotCancel
         brl   NetworkPromptExit

ResolveFailureNotCancel
         jsr   PrintConnectionError
         jsr   CloseNetworkSession
         brl   NetworkSessionPrompt

HostResolved
         pea   ^ConnectingMsg
         pea   ConnectingMsg
         _WriteCString

         jsr   OpenNetworkStream
         bcs   NetworkStreamFailed
         brl   NetworkStreamOpen

NetworkStreamFailed
         cmp   #NetErrCancel
         bne   OpenFailureNotCancel
         brl   NetworkPromptExit

OpenFailureNotCancel
         jsr   PrintConnectionError
         jsr   CloseNetworkSession
         brl   NetworkSessionPrompt

NetworkStreamOpen
         pea   ^ConnectedMsg
         pea   ConnectedMsg
         _WriteCString

* Force the adaptive allocator to attempt 512K rings.

         lda   #$FFFF
         sta   WaveDataSize
         sta   WaveDataSize+2

         jsr   AllocateStereoRings
         bcc   NetworkRingsAllocated

         ldx   #^MemoryErrMsg
         ldy   #MemoryErrMsg
         brl   FailAfterMemory

NetworkRingsAllocated
         brl   NetworkBeginPrefill

* Reset and initial startup share the same clean-ring,
* full-selected-ring prefill path.  A reset retains the current
* TCP socket but reinitializes every Tool225 playback state.

NetworkBeginPrefill
         stz   NetworkAction
         stz   PendingNetworkAction
         stz   NetworkStopRequested
         stz   PlaybackRunningFlag
         stz   AutoResetPending
         stz   AutoLowLeadCount
         jsr   ClearStereoRings
         jsr   ResetProducerDiagnostics

         lda   #NetworkPrefill
         sta   InitialChunksSelected

         pea   ^BufferingMsg
         pea   BufferingMsg
         _WriteCString

         jsr   FillInitialRings
         bcs   NetworkPrefillFailed
         brl   NetworkPrefillReady

NetworkPrefillFailed
         sta   LastNetworkError
         lda   NetworkStopRequested
         bne   NetworkPrefillControl

         lda   #ActionLost
         sta   NetworkAction
         inc   DisconnectCount
         jsr   CaptureDiagnostics
         jsr   PrintStreamEnded
         jsr   PrintDiagnosticsSnapshot
         jsr   CloseNetworkSession
         jsr   ReleaseAllRings
         brl   NetworkSessionPrompt

NetworkPrefillControl
         stz   NetworkStopRequested
         lda   NetworkAction
         cmp   #ActionExit
         beq   NetworkPrefillExit
         cmp   #ActionChange
         beq   NetworkPrefillChange
         cmp   #ActionReset
         beq   NetworkPrefillReset
         brl   NetworkBeginPrefill

NetworkPrefillExit
         brl   NetworkCleanExit

NetworkPrefillChange
         jsr   CloseNetworkSession
         jsr   ReleaseAllRings
         brl   NetworkSessionPrompt

NetworkPrefillReset
         inc   ResetCount
         stz   AutomaticResetFlag
         stz   LowWaterResetFlag
         pea   ^ResettingMsg
         pea   ResettingMsg
         _WriteCString
         jsr   RestartPlaybackTool
         bcc   NetworkPrefillToolRestarted

         jsr   PrintToolRestartError
         brl   NetworkCleanExit

NetworkPrefillToolRestarted
         brl   NetworkBeginPrefill

NetworkPrefillReady
         jsr   ResetSessionDiagnostics
         brl   InitialRingsReady

*-------------------------------------------------
* Text console and line input
*-------------------------------------------------

StartTextConsole
         pea   TextTool
         pea   $0000
         _LoadOneTool
         bcc   TextToolWasLoaded
         rts

TextToolWasLoaded
         lda   #1
         sta   TextToolLoaded

         _TextStartUp
         bcc   TextToolWasStarted
         rts

TextToolWasStarted
         lda   #1
         sta   TextToolActive

* Device type zero, device reference three is the
* standard console text device.  Initialise input 0
* and output 1 explicitly.

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

PromptHostAndPort
HostPromptAgain
         pea   ^HostPromptMsg
         pea   HostPromptMsg
         _WriteCString

         lda   #63
         ldx   #HostBuffer
         ldy   #^HostBuffer
         jsr   ReadTextLine
         bcc   HostLineReady
         rts

HostLineReady
         lda   HostBuffer
         and   #$00FF
         bne   HostValueReady

         jsr   CopyDefaultHost

HostValueReady
         pea   ^PortPromptMsg
         pea   PortPromptMsg
         _WriteCString

         lda   #5
         ldx   #PortBuffer
         ldy   #^PortBuffer
         jsr   ReadTextLine
         bcc   PortLineReady
         rts

PortLineReady
         lda   PortBuffer
         and   #$00FF
         bne   ParseEnteredPort

         lda   #DefaultPort
         sta   DestinationPort
         clc
         rts

ParseEnteredPort
         jsr   ParsePortNumber
         rts

* Blank host input selects the embedded P0.6.2 default.
* The prompt remains fully editable; a later release can
* replace this helper with a GS/OS preference file.

CopyDefaultHost
         sep   #$20
         mx    %10
         ldx   #$0000

CopyDefaultHostLoop
         lda   DefaultHostPString,x
         sta   HostBuffer,x
         inx
         cpx   #$000E
         bcc   CopyDefaultHostLoop

         rep   #$20
         mx    %00
         rts

* Entry: A=max length, X=buffer low, Y=bank.
* Output is a Pascal string with one-byte length.

ReadTextLine
         sta   InputMaxLength
         stx   InputStore+1
         stx   InputLengthStore+1

         sep   #$20
         mx    %10
         tya
         sta   InputStore+3
         sta   InputLengthStore+3
         rep   #$20
         mx    %00

         stz   InputLength

ReadTextChar
         pea   $0000
         pea   $0000
         _ReadChar
         pla
         and   #$007F
         cmp   #$000D
         beq   FinishTextLine
         cmp   #$001B
         beq   CancelTextLine
         cmp   #$0008
         beq   BackspaceTextLine
         cmp   #$007F
         beq   BackspaceTextLine
         cmp   #$0020
         bcc   ReadTextChar
         cmp   #$007F
         bcs   ReadTextChar

         ldx   InputLength
         cpx   InputMaxLength
         bcs   ReadTextChar

         sta   InputChar
         pha
         _WriteChar
         lda   InputChar

         ldx   InputLength
         inx
         sep   #$20
         mx    %10
InputStore
         sta   >$000000,x
         rep   #$20
         mx    %00
         inc   InputLength
         bra   ReadTextChar

BackspaceTextLine
         lda   InputLength
         beq   ReadTextChar
         dec   InputLength

         pea   $0008
         _WriteChar
         pea   $0020
         _WriteChar
         pea   $0008
         _WriteChar
         bra   ReadTextChar

CancelTextLine
         pea   ^CRLFMsg
         pea   CRLFMsg
         _WriteCString
         lda   #NetErrCancel
         sec
         rts

FinishTextLine
         sep   #$20
         mx    %10
         lda   InputLength
InputLengthStore
         sta   >$000000
         rep   #$20
         mx    %00

         pea   ^CRLFMsg
         pea   CRLFMsg
         _WriteCString
         clc
         rts

ParsePortNumber
         stz   ParsedPort
         lda   PortBuffer
         and   #$00FF
         sta   ParseLength
         ldy   #1

ParsePortDigit
         sep   #$20
         mx    %10
         lda   PortBuffer,y
         rep   #$20
         mx    %00
         and   #$00FF
         cmp   #$0030
         bcc   BadPortNumber
         cmp   #$003A
         bcs   BadPortNumber
         sec
         sbc   #$0030
         sta   ParseDigit

* Reject decimal overflow before multiplying by ten.

         lda   ParsedPort
         cmp   #6553
         bcc   PortMultiply
         bne   BadPortNumber
         lda   ParseDigit
         cmp   #6
         bcs   BadPortNumber

PortMultiply
         lda   ParsedPort
         asl
         sta   ParseTimesTwo

         lda   ParsedPort
         asl
         asl
         asl
         clc
         adc   ParseTimesTwo
         adc   ParseDigit
         sta   ParsedPort

         iny
         dec   ParseLength
         bne   ParsePortDigit

         lda   ParsedPort
         beq   BadPortNumber
         sta   DestinationPort
         clc
         rts

BadPortNumber
         lda   #NetErrInput
         sec
         rts

*-------------------------------------------------
* Convert the Pascal host prompt buffer to the
* null-terminated C string required by Marinetti.
*-------------------------------------------------

BuildHostCString
         lda   HostBuffer
         and   #$00FF
         beq   HostCStringInvalid
         cmp   #65
         bcs   HostCStringInvalid
         sta   HostCStringLength
         tax

         sep   #$20
         mx    %10
         lda   #$00
         sta   HostCString,x

HostCStringCopyLoop
         dex
         bmi   HostCStringCopied
         lda   HostBuffer+1,x
         sta   HostCString,x
         bra   HostCStringCopyLoop

HostCStringCopied
         rep   #$20
         mx    %00
         clc
         rts

HostCStringInvalid
         lda   #NetErrInput
         sec
         rts

*-------------------------------------------------
* Marinetti lifecycle, DNS, and TCP open
*-------------------------------------------------

StartMarinetti
         pea   MarinettiTool
         pea   MarinettiVer
         _LoadOneTool
         bcc   TCPToolWasLoaded
         rts

TCPToolWasLoaded
         lda   #1
         sta   TCPToolLoaded

         _TCPIPStartUp
         bcc   TCPToolWasStarted
         rts

TCPToolWasStarted
         lda   #1
         sta   TCPToolActive

         pha
         _TCPIPStatus
         pla
         bne   TCPStackActive

         lda   #NetErrInactive
         sec
         rts

TCPStackActive
         pha
         _TCPIPGetConnectStatus
         pla
         bne   TCPLinkActive

         lda   #NetErrInactive
         sec
         rts

TCPLinkActive
         clc
         rts

ResolveHost
* Follow Marinetti's documented Pascal-string ABI:
* validate the prompt pstring, convert numeric IP directly,
* otherwise start asynchronous DNS and poll it.

         pha
         pea   ^HostBuffer
         pea   HostBuffer
         _TCPIPValidateIPString
* STA and PLA do not alter carry.  Pull the 16-bit result
* before testing the tool-error carry; never PHP before a
* 16-bit PLA because PHP pushes only one byte.
         sta   NetToolError
         pla
         sta   NetTCPError
         bcc   ResolveValidateOkay
         brl   ResolveHostToolFailed
ResolveValidateOkay

         lda   NetTCPError
         beq   ResolveHostByDNS

         stz   ConvertRecord
         stz   ConvertRecord+2
         stz   ConvertRecord+4

         pea   ^ConvertRecord
         pea   ConvertRecord
         pea   ^HostBuffer
         pea   HostBuffer
         _TCPIPConvertIPToHex
         bcc   ResolveConvertOkay
         brl   ResolveHostToolFailed
ResolveConvertOkay

         lda   ConvertRecord
         sta   DestinationIP
         lda   ConvertRecord+2
         sta   DestinationIP+2
         clc
         rts

ResolveHostByDNS
         stz   DNRBuffer
         stz   DNRBuffer+2
         stz   DNRBuffer+4

         pea   ^HostBuffer
         pea   HostBuffer
         pea   ^DNRBuffer
         pea   DNRBuffer
         _TCPIPDNRNameToIP
         bcc   ResolveDNSStartOkay
         brl   ResolveHostToolFailed
ResolveDNSStartOkay

         jsr   ReadSystemTick
         lda   CurrentTick
         sta   DNSStartTick
         lda   CurrentTick+2
         sta   DNSStartTick+2

DNSRequestPending
         jsr   CheckEscapeOnly
         bcc   DNSNotCancelled

         pea   ^DNRBuffer
         pea   DNRBuffer
         _TCPIPCancelDNR
         lda   #NetErrCancel
         sec
         rts

DNSNotCancelled
         _TCPIPPoll
         lda   DNRBuffer
         cmp   #DNRPending
         bne   DNSRequestFinished

         jsr   ReadSystemTick
         lda   CurrentTick
         sec
         sbc   DNSStartTick
         sta   DNSElapsed
         lda   CurrentTick+2
         sbc   DNSStartTick+2
         bne   DNSRequestTimedOut
         lda   DNSElapsed
         cmp   #ConnectTimeout
         bcc   DNSRequestPending

DNSRequestTimedOut
         pea   ^DNRBuffer
         pea   DNRBuffer
         _TCPIPCancelDNR
         lda   #NetErrDNS
         sec
         rts

DNSRequestFinished
         cmp   #DNROkay
         bne   DNSRequestFailed

         lda   DNRBuffer+2
         sta   DestinationIP
         lda   DNRBuffer+4
         sta   DestinationIP+2
         clc
         rts

DNSRequestFailed
         lda   #NetErrDNS
         sec
         rts

ResolveHostToolFailed
         lda   NetToolError
         bne   ResolveHostReturnError
         lda   #NetErrDNS
ResolveHostReturnError
         sec
         rts

OpenNetworkStream
* TCPIPLogin(userID,destIP,port,TOS,TTL)
* Mirrors NetDisk: userid(), address, port,
* TOS 0, TTL 64.

         lda   HiddenRefreshActive
         bne   M3R22HSkipLoginMsg
         pea   ^LoginMsg
         pea   LoginMsg
         _WriteCString
M3R22HSkipLoginMsg

         pha
         lda   MasterID
         pha
         lda   DestinationIP+2
         pha
         lda   DestinationIP
         pha
         lda   DestinationPort
         pha
         pea   $0000
         pea   $0040
         _TCPIPLogin
* Preserve the tool carry while pulling the 16-bit IPID.
* PHP/PLA/PLP is invalid here: PHP pushes one byte while
* 16-bit PLA consumes two and corrupts both result and stack.
         sta   NetToolError
         pla
         sta   NetIPID
         bcc   NetworkLoginToolOkay
         brl   NetworkLoginToolFailed

NetworkLoginToolOkay
         lda   NetIPID
         bne   NetworkLoginOkay
         brl   NetworkLoginFailed

NetworkLoginOkay
         lda   HiddenRefreshActive
         bne   M3R22HSkipOpenMsg
         pea   ^OpenTCPMsg
         pea   OpenTCPMsg
         _WriteCString
M3R22HSkipOpenMsg

         pha
         lda   NetIPID
         pha
         _TCPIPOpenTCP
* Pull the 16-bit tcperr result before branching on carry.
         sta   NetToolError
         pla
         sta   NetTCPError
         bcc   NetworkOpenToolOkay
         brl   NetworkOpenToolFailed

NetworkOpenToolOkay
         lda   NetTCPError
         beq   NetworkOpenOkay
         brl   NetworkOpenFailed

NetworkOpenOkay
         lda   HiddenRefreshActive
         bne   M3R22HSkipSynMsg
         pea   ^SynWaitMsg
         pea   SynWaitMsg
         _WriteCString
M3R22HSkipSynMsg

         lda   #1
         sta   NetSocketOpen

* Record a hard 15-second connection deadline.  Marinetti's
* TCP open is asynchronous and may otherwise remain in SYN-SENT
* indefinitely when a host, firewall, or port does not answer.

         jsr   ReadSystemTick
         lda   CurrentTick
         sta   ConnectStartTick
         lda   CurrentTick+2
         sta   ConnectStartTick+2

WaitForTCPEstablished
         jsr   CheckEscapeOnly
         bcc   TCPConnectNotCancelled
         lda   #NetErrCancel
         sec
         rts

TCPConnectNotCancelled
         _TCPIPPoll
         jsr   GetTCPStatus
         bcc   NetworkStatusOkay
         brl   NetworkStatusFailed

NetworkStatusOkay
         lda   TCPStatusBuffer
         cmp   #TCPEstablished
         beq   TCPConnectionReady

* An active client should remain in SYN-SENT (or briefly
* SYN-RECEIVED) until it establishes.  Any closing state is
* a failed open; use Marinetti's ICMP/network error when one
* is available.

         cmp   #TCPSynSent
         beq   CheckTCPConnectTimeout
         cmp   #TCPSynRcvd
         beq   CheckTCPConnectTimeout
         brl   NetworkOpenStateFailed

CheckTCPConnectTimeout
         jsr   ReadSystemTick

         lda   CurrentTick
         sec
         sbc   ConnectStartTick
         sta   ConnectElapsed
         lda   CurrentTick+2
         sbc   ConnectStartTick+2
         bne   TCPConnectTimedOut

         lda   ConnectElapsed
         cmp   #ConnectTimeout
         bcc   WaitForTCPEstablished

TCPConnectTimedOut
         lda   #NetErrTimeout
         sec
         rts

NetworkOpenStateFailed
         lda   TCPStatusBuffer+2
         bne   NetworkOpenReturnError
         lda   #NetErrOpen
         bra   NetworkOpenReturnError

NetworkOpenFailed
* Preserve the actual Marinetti tcperr value as $FAxx.
* For example, $FA05 means tcperrNoResources.
         lda   NetTCPError
         and   #$00FF
         ora   #NetErrTCPBase

NetworkOpenReturnError
         sec
         rts

NetworkLoginFailed
         lda   #NetErrLogin
         sec
         rts

NetworkLoginToolFailed
         lda   NetToolError
         sec
         rts

NetworkOpenToolFailed
         lda   NetToolError
         sec
         rts

NetworkStatusFailed
         lda   #NetErrStatus
         sec
         rts

TCPConnectionReady
         clc
         rts

* Return the 32-bit Miscellaneous Tools tick counter in
* CurrentTick.  Sixty ticks equal one second.

ReadSystemTick
         pha
         pha
         _GetTick
         pla
         sta   CurrentTick
         pla
         sta   CurrentTick+2
         rts

GetTCPStatus
         pha
         lda   NetIPID
         pha
         pea   ^TCPStatusBuffer
         pea   TCPStatusBuffer
         _TCPIPStatusTCP
* Pull the 16-bit tcperr result; PLA preserves carry.
         sta   NetToolError
         pla
         sta   NetTCPError
         bcs   TCPStatusToolFailed

         lda   NetTCPError
         beq   TCPStatusOkay
         sec
         rts

TCPStatusToolFailed
         lda   NetToolError
         sec
         rts

TCPStatusOkay
         clc
         rts

*-------------------------------------------------
* Exact foreground TCP read
*
* Entry matches ReadWaveBytes: A=count, X=low,
* Y=bank.  TCP segment boundaries are arbitrary, so
* this routine accumulates until the requested count
* is complete.  It requests no more than srRcvQueued,
* avoiding Marinetti's partial-buffer/PUSH behavior.
*-------------------------------------------------

ReadNetworkBytes
         sta   NetRequestTotal
         sta   NetRemaining
         stx   NetReadPointer
         sty   NetReadPointer+2

* A reset may interrupt an arbitrary Marinetti segment.
* Preserve those already-received bytes so the next prefill
* resumes the same stereo frame instead of discarding an odd
* byte and reversing L/R alignment for the rest of the socket.

         lda   NetCarryBytes
         beq   NetworkReadLoop
         cmp   NetRemaining
         bcc   NetworkCarryValid
         beq   NetworkCarryValid
         stz   NetCarryBytes
         brl   NetworkReadLoop

NetworkCarryValid
         lda   NetReadPointer
         clc
         adc   NetCarryBytes
         sta   NetReadPointer
         lda   NetReadPointer+2
         adc   #0
         sta   NetReadPointer+2
         lda   NetRemaining
         sec
         sbc   NetCarryBytes
         sta   NetRemaining

NetworkReadLoop
         lda   NetRemaining
         bne   NetworkReadHasWork
         brl   NetworkReadComplete

NetworkReadHasWork
* M3R25B LIFE SUPPORT: when Paddle is active, do not spend CPU on
* keyboard soft-switch sampling inside the exact TCP polling loop.
* Every R24R Marinetti Poll/Status call remains present.
         lda   PumpRescueActive
         bne   NetworkReadNotCancelled
         jsr   CheckEscapeOnly
         bcc   NetworkReadNotCancelled

         lda   #ActionExit
         sta   NetworkAction
         stz   NetCarryBytes
         lda   #1
         sta   NetworkStopRequested
         lda   #NetErrCancel
         sec
         rts

NetworkReadNotCancelled
         _TCPIPPoll
         jsr   GetTCPStatus
         bcc   NetworkReadStatusOkay
         brl   NetworkReadStatusFailed

NetworkReadStatusOkay

* srRcvQueued is the longword at offset +8.
* Take available bytes immediately, but cap every
* M3R27B SERVICE SLICE: _TCPIPReadTCP is capped at 8192 bytes.
* Exact-read accumulation still commits one 16K producer quantum.

         lda   TCPStatusBuffer+10
         bne   NetworkReadCap8K

         lda   TCPStatusBuffer+8
         bne   TCPDataIsQueued
         brl   NoTCPDataQueued

TCPDataIsQueued
         cmp   NetRemaining
         bcc   NetworkReadQueuedWithinRemain
         lda   NetRemaining

NetworkReadQueuedWithinRemain
         cmp   #$2000
         bcc   NetworkReadLengthReady
         beq   NetworkReadLengthReady

NetworkReadCap8K
         lda   #$2000

NetworkReadLengthReady
         sta   NetReadLength

* M3R5R2 SAFETY: never ask one Marinetti _TCPIPReadTCP call to span a
* 64K bank boundary in the destination buffer.  ReadNetworkBytes remains
* exact: after the shorter call advances NetReadPointer into the next bank,
* the normal loop reads the rest of NetRemaining.
*
* If the low pointer is $0000, the next boundary is a full 64K away and
* the existing <=16K cap is already sufficient.

         lda   NetReadPointer
         beq   M3R5R2BankSpanReady

         eor   #$FFFF
         inc   a
         cmp   NetReadLength
         bcs   M3R5R2BankSpanReady
         sta   NetReadLength

M3R5R2BankSpanReady
         lda   NetReadLength
         pha
         lda   NetIPID
         pha
         pea   $0000

         lda   NetReadPointer+2
         pha
         lda   NetReadPointer
         pha

         pea   $0000
         lda   NetReadLength
         pha

         pea   ^TCPReadBuffer
         pea   TCPReadBuffer
         _TCPIPReadTCP
* Pull the 16-bit tcperr result; PLA preserves carry.
         sta   NetToolError
         pla
         sta   NetTCPError
         bcc   NetworkReadToolOkay
         brl   NetworkReadToolFailed

NetworkReadToolOkay
         lda   NetTCPError
         beq   NetworkReadLogicOkay
         brl   NetworkReadLogicFailed

NetworkReadLogicOkay

         lda   TCPReadBuffer+2
         bne   NetworkReadBadCount
         lda   TCPReadBuffer
         bne   NetworkReadHaveCount
         brl   NetworkReadLoop

NetworkReadHaveCount
         cmp   NetReadLength
         bcc   NetworkReadCountOkay
         beq   NetworkReadCountOkay

NetworkReadBadCount
         lda   #NetErrRead
         sec
         rts

NetworkReadCountOkay
         sta   NetReadCount

         lda   NetReadPointer
         clc
         adc   NetReadCount
         sta   NetReadPointer
         lda   NetReadPointer+2
         adc   #0
         sta   NetReadPointer+2

         lda   NetRemaining
         sec
         sbc   NetReadCount
         sta   NetRemaining
         brl   NetworkReadLoop

NoTCPDataQueued
* L3 direct-ring rule: never trigger a low-water reset in the middle of
* an exact TCP receive. A partial planar quantum cannot be safely rebased
* after Tool225/ring reset. While the socket remains established, keep
* polling until this exact read completes. Low-water is evaluated only
* after the complete producer quantum has been committed in PumpYield.

         lda   TCPStatusBuffer
         cmp   #TCPEstablished
         bne   NetworkReadClosed
         brl   NetworkReadLoop

NetworkReadClosed
         lda   #NetErrClosed
         sec
         rts

NetworkReadStatusFailed
         stz   NetCarryBytes
         lda   #NetErrStatus
         sec
         rts

NetworkReadToolFailed
         stz   NetCarryBytes
         lda   NetToolError
         sec
         rts

NetworkReadLogicFailed
         stz   NetCarryBytes
         lda   #NetErrRead
         sec
         rts

NetworkReadComplete
         stz   NetCarryBytes
         clc
         rts

SaveNetworkPartialChunk
         lda   NetRequestTotal
         sec
         sbc   NetRemaining
         sta   NetCarryBytes
         rts

CountNetworkReadCall
         inc   NetworkReadCalls
         bne   NetworkReadCallDone
         inc   NetworkReadCalls+2
NetworkReadCallDone
         rts

RecordNetworkReadCount
* NetReadCount is always a valid nonzero 16-bit result.

         lda   NetworkBytesTotal
         clc
         adc   NetReadCount
         sta   NetworkBytesTotal
         lda   NetworkBytesTotal+2
         adc   #0
         sta   NetworkBytesTotal+2

         lda   NetReadCount
         cmp   NetReadLength
         bcs   NetworkReadCountRecorded
         inc   NetworkPartialReads
         bne   NetworkReadCountRecorded
         inc   NetworkPartialReads+2

NetworkReadCountRecorded
         rts

CountNetworkNoDataPoll
         inc   NetworkNoDataPolls
         bne   NetworkNoDataPollDone
         inc   NetworkNoDataPolls+2
NetworkNoDataPollDone
         rts

UpdateNetworkQueueHighWater
* srRcvQueued is a 32-bit count at TCPStatusBuffer+8.

         lda   TCPStatusBuffer+10
         cmp   NetworkQueueHigh+2
         bcc   NetworkQueueHighDone
         bne   StoreNetworkQueueHigh
         lda   TCPStatusBuffer+8
         cmp   NetworkQueueHigh
         bcc   NetworkQueueHighDone
         beq   NetworkQueueHighDone

StoreNetworkQueueHigh
         lda   TCPStatusBuffer+8
         sta   NetworkQueueHigh
         lda   TCPStatusBuffer+10
         sta   NetworkQueueHigh+2

NetworkQueueHighDone
         rts

CheckEscapeOnly
         php
         sei
         sep   #$20
         mx    %10
         lda   >$E0C000
         bpl   EscapeNotPressed
         and   #$7F
         sta   PlaybackKey
         lda   >$E0C010
         lda   PlaybackKey
         cmp   #$1B
         beq   EscapeWasPressed

* L3R3 pending-control latch.  The exact 8K reader already samples the
* keyboard for ESC.  Preserve C/R/D here instead of discarding them
* after clearing $E0C010; the next safe producer boundary consumes the
* pending action exactly once.

         and   #$5F
         cmp   #$43
         bne   EscapeNotChange
         lda   #ActionChange
         sta   PendingNetworkAction
         bra   EscapeNotPressed

EscapeNotChange
         cmp   #$52
         bne   EscapeNotReset
         lda   #ActionReset
         sta   PendingNetworkAction
         bra   EscapeNotPressed

EscapeNotReset
         cmp   #$44
         bne   EscapeNotPressed
         lda   #ActionDiag
         sta   PendingNetworkAction

EscapeNotPressed
         plp
         mx    %00
         clc
         rts

EscapeWasPressed
         plp
         mx    %00
         sec
         rts

*-------------------------------------------------
* Playback-only network keys.  The direct keyboard
* latch is used so controls remain responsive while
* an exact 8K TCP read is waiting for more bytes.
*-------------------------------------------------

CheckNetworkControlKey
         jsr   CheckAutomaticRecovery
         bcc   NetworkControlCheckPending
         rts

NetworkControlCheckPending
         lda   PendingNetworkAction
         beq   NetworkControlCheckKeyboard
         stz   PendingNetworkAction

         cmp   #ActionExit
         bne   NetworkControlPendingNotExit
         lda   #ActionExit
         sta   NetworkAction
         sec
         rts

NetworkControlPendingNotExit
         cmp   #ActionChange
         bne   NetworkControlPendingNotChange
         lda   #ActionChange
         sta   NetworkAction
         sec
         rts

NetworkControlPendingNotChange
         cmp   #ActionReset
         bne   NetworkControlPendingNotReset
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

NetworkControlPendingNotReset
         cmp   #ActionDiag
         bne   NetworkControlCheckKeyboard
         lda   #ActionDiag
         sta   NetworkAction
         sec
         rts

NetworkControlCheckKeyboard
         php
         sei
         sep   #$20
         mx    %10
         lda   >$E0C000
         bmi   NetworkControlKeyAvailable
         brl   NetworkControlNotPressed

NetworkControlKeyAvailable
         and   #$7F
         sta   PlaybackKey
         lda   >$E0C010
         lda   PlaybackKey
         cmp   #$1B
         bne   NetworkControlNotExit
         brl   NetworkControlExit

NetworkControlNotExit
         and   #$5F
         cmp   #$43
         bne   NetworkControlNotChange
         brl   NetworkControlChange

NetworkControlNotChange
         cmp   #$52
         bne   NetworkControlNotReset
         brl   NetworkControlReset

NetworkControlNotReset
         cmp   #$44
         bne   NetworkControlNotPressed
         brl   NetworkControlDiag

NetworkControlNotPressed
         plp
         mx    %00

* M3R16L LEAN CONTROL: the direct latch above remains hot.  Throttle the
* expensive Event Manager fallback to EventPollLoops safe boundaries.
         lda   PlaybackEventPoll
         beq   M3R16LPollNetworkEvents
         dec   PlaybackEventPoll
         clc
         rts

M3R16LPollNetworkEvents
         lda   #EventPollLoops
         sta   PlaybackEventPoll

* L3R3 Event Manager fallback.  A GS/OS interrupt may already have
* moved the keystroke out of $E0C000 before the bounded producer
* reaches this safe boundary.  Drain key-down events here, outside
* the exact TCP receive loop, and translate the same ESC/C/R/D
* controls used by the direct latch path.

NetworkControlNextEvent
         pea   $0000
         pea   KeyDownMask
         pea   ^PlaybackEvent
         pea   PlaybackEvent
         _GetNextEvent
         pla
         beq   NetworkControlContinue

         lda   PlaybackEvent+2
         and   #$007F
         cmp   #$001B
         beq   NetworkControlQueueExit

         and   #$005F
         cmp   #$0043
         beq   NetworkControlQueueChange
         cmp   #$0052
         beq   NetworkControlQueueReset
         cmp   #$0044
         beq   NetworkControlQueueDiag
         bra   NetworkControlNextEvent

NetworkControlContinue
         clc
         rts

NetworkControlQueueExit
         lda   #ActionExit
         sta   NetworkAction
         sec
         rts

NetworkControlQueueChange
         lda   #ActionChange
         sta   NetworkAction
         sec
         rts

NetworkControlQueueReset
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

NetworkControlQueueDiag
         lda   #ActionDiag
         sta   NetworkAction
         sec
         rts

NetworkControlExit
         plp
         mx    %00
         lda   #ActionExit
         sta   NetworkAction
         sec
         rts

NetworkControlChange
         plp
         mx    %00
         lda   #ActionChange
         sta   NetworkAction
         sec
         rts

NetworkControlReset
         plp
         mx    %00
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

NetworkControlDiag
         plp
         mx    %00
         lda   #ActionDiag
         sta   NetworkAction
         sec
         rts

*-------------------------------------------------
* Clear both complete source rings to unsigned PCM
* silence before partial network prefill.
*-------------------------------------------------
ClearStereoRings
* M1 MONO DIRECT: both Tool225 descriptors reference the same physical
* ring, so clear it exactly once.
         lda   RingBytesHighSelected
         ldx   LeftRingPtr
         ldy   LeftRingPtr+2
         jsr   ClearOneRing
         rts


ClearOneRing
         sta   ClearSegments
         stx   ClearPointer
         sty   ClearPointer+2

ClearNextSegment
         lda   ClearPointer
         sta   ClearStore+1

         sep   #$20
         mx    %10
         lda   ClearPointer+2
         sta   ClearStore+3
         lda   #$80
         rep   #$10
         mx    %10
         ldx   #0

ClearSegmentLoop
ClearStore
         sta   >$000000,x
         inx
         bne   ClearSegmentLoop

         rep   #$20
         mx    %00
         inc   ClearPointer+2
         dec   ClearSegments
         bne   ClearNextSegment
         rts

*-------------------------------------------------
* Network/text shutdown.  Abort avoids leaving a
* live looping provider socket while the app exits.
*-------------------------------------------------

CloseNetworkSession
         lda   HiddenRefreshActive
         bne   M3R22HCloseKeepPlayback
         stz   PlaybackRunningFlag
M3R22HCloseKeepPlayback

         lda   NetIPID
         beq   NetworkSessionClosed

         lda   NetSocketOpen
         beq   NetworkSocketNotOpen

         pha
         lda   NetIPID
         pha
         _TCPIPAbortTCP
         pla
         stz   NetSocketOpen

NetworkSocketNotOpen
         lda   NetIPID
         pha
         _TCPIPLogout
         stz   NetIPID

NetworkSessionClosed
         stz   NetSocketOpen
         clc
         rts

ShutNetworkFrontend
         jsr   CloseNetworkSession

         lda   TCPToolActive
         beq   TCPToolNotActive
         _TCPIPShutDown
         stz   TCPToolActive

TCPToolNotActive
         lda   TCPToolLoaded
         beq   TCPToolNotLoaded
         pea   MarinettiTool
         _UnloadOneTool
         stz   TCPToolLoaded

TCPToolNotLoaded
         lda   TextToolActive
         beq   TextToolNotActive
         _TextShutDown
         stz   TextToolActive

TextToolNotActive
         lda   TextToolLoaded
         beq   TextToolNotLoaded
         pea   TextTool
         _UnloadOneTool
         stz   TextToolLoaded

TextToolNotLoaded
         clc
         rts

*-------------------------------------------------
*-------------------------------------------------
* StartSelectorTools
*
* StartUpTools loads and starts the Standard File
* dependency set.  Because the input record uses a
* pointer reference, the returned long is a pointer
* and must be passed unchanged to ShutDownTools.
*-------------------------------------------------

StartSelectorTools
         pha
         pha

         lda   MemoryID
         pha

         pea   $0000
         pea   ^SelectorStartStop
         pea   SelectorStartStop

         _StartUpTools

         sta   SelectorToolError

* PLA changes N and Z but preserves carry, so collect
* the long result before doing anything to the stack.
* A PHP here would insert a one-byte status value in
* front of this four-byte result and corrupt it.

         pla
         sta   SelectorToolsHandle

         pla
         sta   SelectorToolsHandle+2

         bcc   SelectorToolsStarted

         lda   SelectorToolError
         bne   SelectorStartErrorReady

         lda   #$FA0A

SelectorStartErrorReady
         sec
         rts

SelectorToolsStarted
         _InitCursor
         clc
         rts

*-------------------------------------------------
* CheckPlaybackStop
*
* Poll the IIgs keyboard latch directly first.  An
* interrupt may already have moved the key into the
* Event Manager queue, so periodically drain queued
* key-down events as a reliable fallback.  The
* toolbox call is throttled to keep the producer hot
* loop inexpensive on a stock 2.8 MHz machine.
*
* Return:
*
* carry clear = continue playback
* carry set   = a network action or file ESC
*-------------------------------------------------

CheckPlaybackStop
         lda   NetworkModeFlag
         beq   PlaybackCheckKeyboard

         jsr   CheckAutomaticRecovery
         bcc   PlaybackCheckKeyboard
         rts

PlaybackCheckKeyboard
         php
         sei
         sep   #$20
         mx    %10

         lda   >$E0C000
         bmi   PlaybackKeyAvailable
         brl   NoPlaybackStop

PlaybackKeyAvailable
         and   #$7F
         sta   PlaybackKey

         lda   >$E0C010
         lda   PlaybackKey
         cmp   #$1B
         bne   PlaybackNotExitKey
         brl   PlaybackExitRequested

PlaybackNotExitKey
         and   #$5F
         cmp   #$43
         bne   PlaybackNotChangeKey
         brl   PlaybackChangeRequested

PlaybackNotChangeKey
         cmp   #$52
         bne   PlaybackNotResetKey
         brl   PlaybackResetRequested

PlaybackNotResetKey
         cmp   #$44
         bne   NoPlaybackStop
         brl   PlaybackDiagRequested

NoPlaybackStop
         plp
         mx    %00

         lda   NetworkModeFlag
         bne   NetworkPlaybackContinues
         brl   CheckDesktopPlaybackEvents

NetworkPlaybackContinues
         clc
         rts

PlaybackExitRequested
         plp
         mx    %00
         lda   NetworkModeFlag
         bne   PlaybackNetworkExit
         brl   PlaybackStopFromQueue

PlaybackNetworkExit
         lda   #ActionExit
         sta   NetworkAction
         sec
         rts

PlaybackChangeRequested
         plp
         mx    %00
         lda   NetworkModeFlag
         bne   PlaybackNetworkChange
         brl   PlaybackContinuesNow

PlaybackNetworkChange
         lda   #ActionChange
         sta   NetworkAction
         sec
         rts

PlaybackResetRequested
         plp
         mx    %00
         lda   NetworkModeFlag
         bne   PlaybackNetworkReset
         brl   PlaybackContinuesNow

PlaybackNetworkReset
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         stz   LowWaterResetFlag
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

PlaybackDiagRequested
         plp
         mx    %00
         lda   NetworkModeFlag
         bne   PlaybackNetworkDiag
         brl   PlaybackContinuesNow

PlaybackNetworkDiag
         lda   #ActionDiag
         sta   NetworkAction
         sec
         rts

CheckDesktopPlaybackEvents
         lda   PlaybackEventPoll
         beq   PollPlaybackEvents

         dec   PlaybackEventPoll
         beq   PollPlaybackEvents
         clc
         rts

PollPlaybackEvents
         lda   #EventPollLoops
         sta   PlaybackEventPoll

NextPlaybackEvent
         pea   $0000
         pea   KeyDownMask
         pea   ^PlaybackEvent
         pea   PlaybackEvent
         _GetNextEvent
         pla
         beq   PlaybackContinuesNow

         lda   PlaybackEvent+2
         and   #$007F
         cmp   #$001B
         beq   PlaybackStopFromQueue

* Consume other queued key-down events during
* playback, matching the direct-latch behavior.

         bra   NextPlaybackEvent

PlaybackContinuesNow
         clc
         rts

PlaybackStopFromQueue
         sec
         rts

*-------------------------------------------------
* StopSelectorTools
*-------------------------------------------------

StopSelectorTools
         lda   SelectorToolsHandle
         ora   SelectorToolsHandle+2
         beq   SelectorToolsAlreadyStopped

* The StartUpTools input used refType $0000, so its
* returned reference is also a pointer.  Pass that
* exact pointer back with the matching descriptor.

         pea   $0000

         lda   SelectorToolsHandle+2
         pha

         lda   SelectorToolsHandle
         pha

         _ShutDownTools

         php
         sta   SelectorToolError

         stz   SelectorToolsHandle
         stz   SelectorToolsHandle+2

         plp
         bcc   SelectorToolsStoppedOK

         lda   SelectorToolError
         sec
         rts

SelectorToolsAlreadyStopped
SelectorToolsStoppedOK
         clc
         rts

*-------------------------------------------------
* SelectWaveFile
*
* SFGetFile2 returns:
*
* good       at SFReply+0
* full path  as a Class 1 output string
*
* SFPathBuffer+0 is bufferSize.
* SFPathBuffer+2 is a Class 1 input string that
* can be passed directly to GS/OS calls.
*-------------------------------------------------

SelectWaveFile
         stz   SFReply
         stz   SFReply+2
         stz   SFReply+4
         stz   SFReply+6

         lda   #512
         sta   SFNameBuffer
         sta   SFPathBuffer

         stz   SFNameBuffer+2
         stz   SFPathBuffer+2

         pea   120
         pea   43
         pea   $0000

         pea   ^SelectPrompt
         pea   SelectPrompt

         pea   $0000
         pea   $0000

         pea   $0000
         pea   $0000

         pea   ^SFReply
         pea   SFReply

         _SFGetFile2

         lda   SFReply
         beq   SelectWaveCancelled

         clc
         rts

SelectWaveCancelled
         sec
         rts

*-------------------------------------------------
* OpenAndParseWave
*
* Opens the Standard File-selected pathname.
* On success the GS/OS file mark is positioned at
* the first interleaved sample in the data chunk.
*-------------------------------------------------

OpenAndParseWave
         stz   FoundFmtFlag
         stz   WaveOpenFlag
         stz   WaveDataSize
         stz   WaveDataSize+2
         stz   ChunkSize
         stz   ChunkSize+2
         stz   ChunkPad
         stz   SkipRemaining
         stz   SkipRemaining+2
         stz   WaveHeader
         stz   WaveHeader+2
         stz   WaveHeader+4
         stz   WaveHeader+6
         stz   WaveHeader+8
         stz   WaveHeader+10

         jsl   GSOS
         dw    OpenCall
         adrl  WaveOpenPB
         bcc   WaveOpened

         rts

WaveOpened
         lda   #1
         sta   WaveOpenFlag

         lda   WaveOpenPB+2
         sta   WaveEOFPB+2
         sta   WaveReadPB+2
         sta   WaveSetMarkPB+2
         sta   WaveClosePB+2

* Explicitly reset the newly opened file mark to
* absolute byte zero before reading RIFF.

         jsl   GSOS
         dw    SetMarkCall
         adrl  WaveSetMarkPB
         bcc   WaveMarkReset

         brl   ParseWaveFailed

WaveMarkReset
         jsl   GSOS
         dw    GetEOFCall
         adrl  WaveEOFPB
         bcc   WaveEOFReady

         brl   ParseWaveFailed

WaveEOFReady
         lda   WaveEOFPB+4
         sta   WaveFileSize

         lda   WaveEOFPB+6
         sta   WaveFileSize+2

* Read RIFF size and WAVE signature.

         lda   #12
         ldx   #WaveHeader
         ldy   #^WaveHeader
         jsr   ReadWaveBytes
         bcc   WaveHeaderRead

         brl   ParseWaveFailed

WaveHeaderRead
         lda   WaveHeader
         cmp   #$4952
         bne   BadRiffWave

         lda   WaveHeader+2
         cmp   #$4646
         bne   BadRiffWave

         lda   WaveHeader+8
         cmp   #$4157
         bne   BadRiffWave

         lda   WaveHeader+10
         cmp   #$4556
         beq   ChunkLoop

BadRiffWave
         lda   #$FA01
         brl   ParseWaveFailed

*-------------------------------------------------
* RIFF chunk loop.
*-------------------------------------------------

ChunkLoop
         lda   #8
         ldx   #ChunkHeader
         ldy   #^ChunkHeader
         jsr   ReadWaveBytes
         bcc   ChunkHeaderRead

         brl   ParseWaveFailed

ChunkHeaderRead
         lda   ChunkHeader+4
         sta   ChunkSize

         lda   ChunkHeader+6
         sta   ChunkSize+2

* Is this "fmt "?

         lda   ChunkHeader
         cmp   #$6D66
         bne   CheckDataChunk

         lda   ChunkHeader+2
         cmp   #$2074
         beq   ParseFmtChunk

* Is this "data"?

CheckDataChunk
         lda   ChunkHeader
         cmp   #$6164
         bne   SkipUnknownChunk

         lda   ChunkHeader+2
         cmp   #$6174
         bne   SkipUnknownChunk

         brl   ParseDataChunk

* Skip unknown RIFF chunks including the required
* pad byte after odd-sized chunks.

SkipUnknownChunk
         jsr   SetSkipFromChunk
         jsr   SkipWaveBytes
         bcc   UnknownChunkSkipped

         brl   ParseWaveFailed

UnknownChunkSkipped
         brl   ChunkLoop

*-------------------------------------------------
* Parse and validate the first sixteen fmt bytes.
* Extra fmt bytes are skipped.
*-------------------------------------------------

ParseFmtChunk
         lda   ChunkSize+2
         bne   FmtSizeReady

         lda   ChunkSize
         cmp   #16
         bcs   FmtSizeReady

         lda   #$FA02
         brl   ParseWaveFailed

FmtSizeReady
         lda   ChunkSize
         and   #1
         sta   ChunkPad

         lda   #16
         ldx   #FmtBuffer
         ldy   #^FmtBuffer
         jsr   ReadWaveBytes
         bcc   FmtRead

         brl   ParseWaveFailed

FmtRead
         lda   FmtBuffer
         cmp   #1
         bne   UnsupportedFmt

         lda   FmtBuffer+2
         cmp   #1
         bne   UnsupportedFmt

* Read but deliberately ignore both 32-bit rate
* fields.  Two NOPs preserve each former two-byte
* conditional branch, keeping all later addresses
* identical to the proven P0.13 binary layout.

         lda   FmtBuffer+4
         cmp   #$55D5
         bne   UnsupportedFmt

         lda   FmtBuffer+6
         bne   UnsupportedFmt

         lda   FmtBuffer+8
         cmp   #$55D5
         bne   UnsupportedFmt

         lda   FmtBuffer+10
         bne   UnsupportedFmt

         lda   FmtBuffer+12
         cmp   #1
         bne   UnsupportedFmt

         lda   FmtBuffer+14
         cmp   #8
         beq   FmtSupported

UnsupportedFmt
         lda   #$FA02
         brl   ParseWaveFailed

FmtSupported
         lda   #1
         sta   FoundFmtFlag

* Skip remaining fmt bytes and any odd pad byte.

         lda   ChunkSize
         sec
         sbc   #16
         sta   SkipRemaining

         lda   ChunkSize+2
         sbc   #0
         sta   SkipRemaining+2

         lda   ChunkPad
         beq   FmtSkipReady

         inc   SkipRemaining
         bne   FmtSkipReady

         inc   SkipRemaining+2

FmtSkipReady
         jsr   SkipWaveBytes
         bcc   FmtChunkDone

         brl   ParseWaveFailed

FmtChunkDone
         brl   ChunkLoop

*-------------------------------------------------
* Validate data chunk and leave the file open at
* its first sample.
*-------------------------------------------------

ParseDataChunk
         lda   FoundFmtFlag
         bne   DataHasFormat

         lda   #$FA02
         brl   ParseWaveFailed

DataHasFormat
         lda   ChunkSize
         sta   WaveDataSize

         lda   ChunkSize+2
         sta   WaveDataSize+2

* Require at least 131072 interleaved bytes.

         cmp   #MinDataHigh
         bcs   DataLongEnough

         lda   #$FA03
         brl   ParseWaveFailed

* Each 256-sample channel block consumes 512 WAV
* bytes.  Requiring exact alignment keeps the ring
* producer and end-of-stream accounting exact.

DataLongEnough
         lda   WaveDataSize
         and   #$00FF
         beq   WaveParseSuccess

         lda   #$FA04
         brl   ParseWaveFailed

WaveParseSuccess
         clc
         rts

ParseWaveFailed
         sta   SavedFileError
         jsr   CloseWaveFile
         lda   SavedFileError
         sec
         rts

*-------------------------------------------------
* ReadWaveBytes
*
* Entry:
*
* A = request count, 1 through 8192
* X = buffer low word
* Y = buffer bank word
*
* Return:
*
* carry clear = exact read completed
* carry set   = GS/OS or $FA05 error
*-------------------------------------------------

ReadWaveBytes
         sta   WaveReadPB+8
         stz   WaveReadPB+10

         stx   WaveReadPB+4
         sty   WaveReadPB+6

         stz   WaveReadPB+12
         stz   WaveReadPB+14

         jsl   GSOS
         dw    ReadCall
         adrl  WaveReadPB
         bcc   WaveReadReturned

         rts

WaveReadReturned
         lda   WaveReadPB+14
         bne   WaveReadShort

         lda   WaveReadPB+12
         cmp   WaveReadPB+8
         beq   WaveReadExact

WaveReadShort
         lda   #$FA05
         sec
         rts

WaveReadExact
         clc
         rts

*-------------------------------------------------
* SetSkipFromChunk
*
* SkipRemaining = ChunkSize rounded to even.
*-------------------------------------------------

SetSkipFromChunk
         lda   ChunkSize
         sta   SkipRemaining

         lda   ChunkSize+2
         sta   SkipRemaining+2

         lda   ChunkSize
         and   #1
         beq   SkipSizeReady

         inc   SkipRemaining
         bne   SkipSizeReady

         inc   SkipRemaining+2

SkipSizeReady
         rts

*-------------------------------------------------
* SkipWaveBytes
*
* Reads and discards SkipRemaining bytes in chunks
* of at most 8192 bytes.
*-------------------------------------------------

SkipWaveBytes
         lda   SkipRemaining
         ora   SkipRemaining+2
         beq   SkipComplete

         lda   SkipRemaining+2
         bne   SkipFullBuffer

         lda   SkipRemaining
         cmp   #InterleaveMax
         bcs   SkipFullBuffer

         sta   SkipRequest
         bra   SkipReadNow

SkipFullBuffer
         lda   #InterleaveMax
         sta   SkipRequest

SkipReadNow
         lda   SkipRequest
         ldx   #InterleaveBuffer
         ldy   #^InterleaveBuffer
         jsr   ReadWaveBytes
         bcc   SkipReadDone

         rts

SkipReadDone
         lda   SkipRemaining
         sec
         sbc   SkipRequest
         sta   SkipRemaining

         lda   SkipRemaining+2
         sbc   #0
         sta   SkipRemaining+2

         bra   SkipWaveBytes

SkipComplete
         clc
         rts

*-------------------------------------------------
* AllocateStereoRings
*-------------------------------------------------
AllocateStereoRings
         jsr   ReleaseAllRings

* M1 MONO DIRECT: allocate ONE physical ring and expose that same
* system-memory ring to both Tool225 output descriptors.  Tool225
* still owns two independent playback cursors/oscillator pairs, so
* the producer uses ConsumedMin before overwriting shared data.
* This removes the second 512K allocation and all foreground
* sample duplication while keeping dual-mono physical output.

         lda   #$0008
         sta   RingBytesHighSelected

         lda   #$0800
         sta   RingBlocksSelected

         lda   #$0007
         sta   RingBankMask

         lda   #128
         sta   InitialChunksSelected

* RightHandle MUST remain zero.  Only LeftHandle owns/disposes the
* shared Memory Manager allocation.

         stz   RightHandle
         stz   RightHandle+2
         stz   RightRingPtr
         stz   RightRingPtr+2

         jsr   AllocateOneRing
         bcc   MonoSharedRingAllocated
         rts

MonoSharedRingAllocated
         jsr   CommitWorkToLeft

* Alias the right runtime pointer and right Tool225 descriptor pointer
* to the left allocation.  Do NOT alias the handle or it would be
* disposed twice by ReleaseAllRings.

         lda   LeftRingPtr
         sta   RightRingPtr
         sta   RightRingPointer

         lda   LeftRingPtr+2
         sta   RightRingPtr+2
         sta   RightRingPointer+2

         stz   RightRingLength
         stz   LeftRingLength

         lda   RingBytesHighSelected
         sta   RightRingLength+2
         sta   LeftRingLength+2

         clc
         rts


AllocateSelectedStereoRings
         jsr   AllocateOneRing
         bcc   LeftRingAllocated

         rts

LeftRingAllocated
         jsr   CommitWorkToLeft

         jsr   AllocateOneRing
         bcc   RightRingAllocated

         sta   SavedFileError
         jsr   ReleaseAllRings
         lda   SavedFileError
         sec
         rts

RightRingAllocated
         jsr   CommitWorkToRight

         clc
         rts

AllocateOneRing
         stz   WorkHandle
         stz   WorkHandle+2
         stz   WorkDataPtr
         stz   WorkDataPtr+2

* Reserve the four-byte result.

         pha
         pha

* Allocate the currently selected 256K or 512K size.

         lda   RingBytesHighSelected
         pha
         pea   RingBytesLow

         lda   MemoryID
         pha

         pea   AttrLocked

         pea   $0000
         pea   $0000

         _NewHandle
         bcc   OneRingAllocated

         sta   SavedFileError
         pla
         pla

         lda   SavedFileError
         bne   RingAllocationErrorReady

         lda   #$FA06

RingAllocationErrorReady
         sec
         rts

OneRingAllocated
         pla
         sta   WorkHandle

         pla
         sta   WorkHandle+2

         jsr   DerefWorkHandle

         lda   WorkDataPtr
         ora   WorkDataPtr+2
         bne   RingPointerReady

         lda   #$FA07
         jsr   ReleaseWorkRing
         sec
         rts

RingPointerReady
         clc
         rts

DerefWorkHandle
         phd

         ldx   WorkHandle+2
         lda   WorkHandle

         phx
         pha

         tsc
         tcd

         lda   [1]
         sta   WorkDataPtr

         ldy   #2
         lda   [1],y
         sta   WorkDataPtr+2

         pla
         plx
         pld
         rts

CommitWorkToLeft
         lda   WorkHandle
         sta   LeftHandle

         lda   WorkHandle+2
         sta   LeftHandle+2

         lda   WorkDataPtr
         sta   LeftRingPtr
         sta   LeftRingPointer

         lda   WorkDataPtr+2
         sta   LeftRingPtr+2
         sta   LeftRingPointer+2

         stz   WorkHandle
         stz   WorkHandle+2
         stz   WorkDataPtr
         stz   WorkDataPtr+2
         rts

CommitWorkToRight
         lda   WorkHandle
         sta   RightHandle

         lda   WorkHandle+2
         sta   RightHandle+2

         lda   WorkDataPtr
         sta   RightRingPtr
         sta   RightRingPointer

         lda   WorkDataPtr+2
         sta   RightRingPtr+2
         sta   RightRingPointer+2

         stz   WorkHandle
         stz   WorkHandle+2
         stz   WorkDataPtr
         stz   WorkDataPtr+2
         rts

*-------------------------------------------------
* FillInitialRings
*
* M3R15H true-22K mono uses 16K producer quanta. Network startup
* intentionally stops two quanta / 32K short of the physical ring end.
*-------------------------------------------------

FillInitialRings
         stz   ProducedBlocks
         stz   ProducedBlocks+2

         lda   InitialChunksSelected
         sta   InitialChunks

InitialFillLoop
         lda   #ChunkBlocks
         sta   BlocksToRead

         jsr   ReadNextWaveChunk
         bcc   InitialChunkReady

         rts

InitialChunkReady
         lda   ProducedBlocks
         clc
         adc   #ChunkBlocks
         sta   ProducedBlocks

         lda   ProducedBlocks+2
         adc   #0
         sta   ProducedBlocks+2

         dec   InitialChunks
         bne   InitialFillLoop

         clc
         rts

*-------------------------------------------------
* ReadNextWaveChunk
*
* Reads the profile wire bytes for BlocksToRead,
* sanitizes native-DOC $00 values, and separates
* them into the current locations in both rings.
*-------------------------------------------------
ReadNextWaveChunk

* M3R14N TRUE 22K MONO - UP-TO-16K ALIGNED COMMIT + RING SAFETY.
*
* The provider still emits the same chronological 16K cadence groups.
* The healthy request cap is 16384 bytes.  Initial prefill uses the same
* 16K producer quantum.  Once playback is running, select the largest
* complete 256-byte block count already queued, capped at 64 blocks / 16K.
*
* Example at low water:
*   srRcvQueued = $1828 = 6184 bytes
*   commit       = $1800 = 6144 bytes = 24 blocks
*   leave        = $0028 = 40 bytes in TCP for the next call
*
* No foreground byte carry is required: incomplete sub-block bytes remain
* in Marinetti/TCP until enough data exists to form another 256-byte block.
* BlocksToRead is updated to the actual aligned block count, so the common
* caller advances ProducedBlocks by exactly the audio made playable.
*
* This decouples:
*   Marinetti request cap        = 16384 bytes
*   provider cadence            = 16384 chronological bytes
*   ring commit granularity     = 256 bytes / 1 block
*   normal high-throughput read = up to 16384 bytes / 64 blocks

         lda   NetworkModeFlag
         bne   M3R4NetworkPlayback
         brl   M3R4UseRequestedBlocks

M3R4NetworkPlayback
* M3R15H network prefill uses the 16K quantum but stops 32K short of full for warm handoff.

         lda   PlaybackRunningFlag
         bne   M3R4PlaybackActive
         brl   M3R4UseRequestedBlocks

M3R4PlaybackActive
* M3R36 PREFILL-LIKE PLAYBACK: request the same exact 16K producer quantum
* used during FillInitialRings.  Do not shrink the commit to the amount
* momentarily queued in TCP.  ReadNetworkBytes still accumulates this exact
* quantum as two <=8K TCPIPReadTCP slices and remains bank-safe.
         lda   #ChunkBlocks
         sta   BlocksToRead
         brl   M3R4UseRequestedBlocks

M3R4WaitForFullBlock
         _TCPIPPoll
         jsr   GetTCPStatus
         bcc   M3R4StatusOkay

         lda   #NetErrStatus
         sec
         rts

M3R4StatusOkay
M3R18GSelectorStatusReady
         lda   TCPStatusBuffer
         cmp   #TCPEstablished
         beq   M3R4SocketOpen

         lda   #NetErrClosed
         sec
         rts

M3R4SocketOpen
* Any nonzero high word is safely capped at the generated 64-block / 16K cap.

         lda   TCPStatusBuffer+10
         bne   M3R4CapAt32

* floor(srRcvQueued / 256) is the high byte of the low word.

         lda   TCPStatusBuffer+8
         xba
         and   #$00FF
         beq   M3R4WaitForFullBlock
         cmp   #ChunkBlocks
         bcc   M3R4BlocksSelected

M3R4CapAt32
         lda   #ChunkBlocks

M3R4BlocksSelected
         sta   BlocksToRead

* M3R5R2 SAFETY: a partial aligned commit must never straddle the
* physical end of the locked ring handle.  ProducedBlocks is monotonic,
* but the destination is circular.  Limit this operation to the number
* of complete 256-byte blocks remaining before the logical ring wraps.
*
* The next producer operation recomputes the destination at ring block 0,
* so no Marinetti write can run beyond the allocated handle.

         lda   ProducedBlocks
         and   #$07FF
         sta   RingOffset

         lda   #$0800
         sec
         sbc   RingOffset
         cmp   BlocksToRead
         bcs   M3R5R2RingSpanOkay
         sta   BlocksToRead

M3R5R2RingSpanOkay

M3R4UseRequestedBlocks
* RequestBytes = BlocksToRead * 256.  ReadNetworkBytes performs exact
* accumulation for the selected aligned amount.  M3R14N permits a 16K
* single call when it is queued and bank-safe; the existing bank-edge guard
* splits only when the destination would cross a 64K boundary.

         lda   BlocksToRead
         xba
         sta   RequestBytes
         sta   ChannelBytes

         lda   ProducedBlocks
         and   #$00FF
         xba
         sta   RingOffset

         lda   ProducedBlocks
         xba
         and   RingBankMask
         sta   RingBankOffset

         lda   LeftRingPtr
         clc
         adc   RingOffset
         sta   LeftChunkPtr

         lda   LeftRingPtr+2
         adc   RingBankOffset
         sta   LeftChunkPtr+2

* Keep logical right pointer coherent for diagnostics.  There is one
* physical mono ring and one chronological write destination.

         lda   LeftChunkPtr
         sta   RightChunkPtr
         lda   LeftChunkPtr+2
         sta   RightChunkPtr+2

         lda   NetworkModeFlag
         beq   M3R4MonoFileFallback

         lda   RequestBytes
         ldx   LeftChunkPtr
         ldy   LeftChunkPtr+2
         jsr   ReadNetworkBytes
         rts

M3R4MonoFileFallback
         lda   RequestBytes
         ldx   LeftChunkPtr
         ldy   LeftChunkPtr+2
         jsr   ReadWaveBytes
         rts

*-------------------------------------------------
* PatchRingCounterReads
*
* M3 starts one legacy circular ring on oscillator 0. Only counter 0
* is live. Mirror it into both logical consumer fields so existing
* producer lead/skew diagnostics remain valid.
*-------------------------------------------------

PatchRingCounterReads
         lda   RingStatusPtr
         clc
         adc   #RightLowOff
         sta   RightLowRead+1

         lda   RingStatusPtr+2
         adc   #0
         jsr   StoreRightLowBank

         lda   RingStatusPtr
         clc
         adc   #RightHighOff
         sta   RightHighRead+1

         lda   RingStatusPtr+2
         adc   #0
         jsr   StoreRightHighBank

         rts

StoreRightLowBank
         sep   #$20
         mx    %10
         sta   RightLowRead+3
         rep   #$20
         mx    %00
         rts

StoreRightHighBank
         sep   #$20
         mx    %10
         sta   RightHighRead+3
         rep   #$20
         mx    %00
         rts

*-------------------------------------------------
* ReadRingCounters
*-------------------------------------------------

ReadRingCounters
         php
         sei

RightLowRead
         lda   >$000000
         sta   ConsumedMin
         sta   ConsumedMax

RightHighRead
         lda   >$000000
         sta   ConsumedMin+2
         sta   ConsumedMax+2

         plp
         rts


*-------------------------------------------------
* Patch and read Tool225 P0.9B phase diagnostics
*-------------------------------------------------

PatchPhaseDiagnosticReads
         lda   PhaseStatusPtr
         clc
         adc   #PhasePollOff
         sta   PhasePollRead+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhasePollBank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseFaultCountOff
         sta   PhaseFaultCountRead+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseFaultCountBank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseFaultFlagsOff
         sta   PhaseFaultFlagsRead+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseFaultFlagsBank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseCurrentOff
         sta   PhaseCurrentRead+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseCurrentBank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseStreak01Off
         sta   PhaseStreak01Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseStreak01Bank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseStreak23Off
         sta   PhaseStreak23Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseStreak23Bank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseMax01Off
         sta   PhaseMax01Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseMax01Bank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseMax23Off
         sta   PhaseMax23Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseMax23Bank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseSample01Off
         sta   PhaseSample01Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseSample01Bank

         lda   PhaseStatusPtr
         clc
         adc   #PhaseSample23Off
         sta   PhaseSample23Read+1
         lda   PhaseStatusPtr+2
         adc   #0
         jsr   StorePhaseSample23Bank
         rts

StorePhasePollBank
         sep   #$20
         sta   PhasePollRead+3
         rep   #$20
         rts
StorePhaseFaultCountBank
         sep   #$20
         sta   PhaseFaultCountRead+3
         rep   #$20
         rts
StorePhaseFaultFlagsBank
         sep   #$20
         sta   PhaseFaultFlagsRead+3
         rep   #$20
         rts
StorePhaseCurrentBank
         sep   #$20
         sta   PhaseCurrentRead+3
         rep   #$20
         rts
StorePhaseStreak01Bank
         sep   #$20
         sta   PhaseStreak01Read+3
         rep   #$20
         rts
StorePhaseStreak23Bank
         sep   #$20
         sta   PhaseStreak23Read+3
         rep   #$20
         rts
StorePhaseMax01Bank
         sep   #$20
         sta   PhaseMax01Read+3
         rep   #$20
         rts
StorePhaseMax23Bank
         sep   #$20
         sta   PhaseMax23Read+3
         rep   #$20
         rts
StorePhaseSample01Bank
         sep   #$20
         sta   PhaseSample01Read+3
         rep   #$20
         rts
StorePhaseSample23Bank
         sep   #$20
         sta   PhaseSample23Read+3
         rep   #$20
         rts

ReadPhaseDiagnostics
         lda   PhaseStatusPtr
         ora   PhaseStatusPtr+2
         bne   ReadPhasePointerReady
         rts

ReadPhasePointerReady
         php
         sei
PhasePollRead
         lda   >$000000
         sta   PhasePollCount
PhaseFaultCountRead
         lda   >$000000
         sta   PhaseFaultCount
PhaseFaultFlagsRead
         lda   >$000000
         sta   PhaseFaultFlags
PhaseCurrentRead
         lda   >$000000
         sta   PhaseCurrentFlags
PhaseStreak01Read
         lda   >$000000
         sta   PhaseStreak01
PhaseStreak23Read
         lda   >$000000
         sta   PhaseStreak23
PhaseMax01Read
         lda   >$000000
         sta   PhaseMax01
PhaseMax23Read
         lda   >$000000
         sta   PhaseMax23
PhaseSample01Read
         lda   >$000000
         sta   PhaseSample01
PhaseSample23Read
         lda   >$000000
         sta   PhaseSample23
         plp
         rts

*-------------------------------------------------
* Lightweight session diagnostics
*
* Counters are sampled only in foreground code.  The hot
* loop updates minimum producer lead and maximum L/R ring
* counter skew without console I/O.  D prints a snapshot;
* R, C, and connection loss print the last snapshot after
* Tool225 has been stopped.
*-------------------------------------------------

ResetProducerDiagnostics
         stz   NetworkBytesTotal
         stz   NetworkBytesTotal+2
         stz   NetworkReadCalls
         stz   NetworkReadCalls+2
         stz   NetworkPartialReads
         stz   NetworkPartialReads+2
         stz   NetworkNoDataPolls
         stz   NetworkNoDataPolls+2
         stz   NetworkQueueHigh
         stz   NetworkQueueHigh+2
         stz   PumpBurstCurrent
         stz   PumpBurstLast
         stz   PumpBurstMax
         stz   PumpQuantaTotal
         stz   PumpQuantaTotal+2
         stz   PumpStopReason
         stz   PumpRescueActive
         lda   #1
         sta   HiddenRefreshArmed
         stz   HiddenRefreshActive
         stz   HiddenRefreshReportPending
         stz   PumpQueueStart
         stz   PumpQueueStart+2
         stz   PumpQueueLast
         stz   PumpQueueLast+2
         stz   PumpBytesCurrent
         stz   PumpBytesCurrent+2
         stz   PumpBytesLast
         stz   PumpBytesLast+2
         stz   PumpBytesMax
         stz   PumpBytesMax+2
         stz   PumpRescueCount
         stz   PumpRescueQuanta
         stz   SnapshotPumpRescueCount
         stz   SnapshotPumpRescueQuanta
         stz   SnapshotNetworkBytes
         stz   SnapshotNetworkBytes+2
         stz   SnapshotNetworkReadCalls
         stz   SnapshotNetworkReadCalls+2
         stz   SnapshotNetworkPartialReads
         stz   SnapshotNetworkPartialReads+2
         stz   SnapshotNetworkNoDataPolls
         stz   SnapshotNetworkNoDataPolls+2
         stz   SnapshotNetworkQueueHigh
         stz   SnapshotNetworkQueueHigh+2
         stz   SnapshotElapsedTicks
         stz   SnapshotElapsedTicks+2
         stz   SnapshotElapsedSeconds
         stz   SnapshotElapsedSeconds+2
         stz   SnapshotAverageBytes
         stz   SnapshotAverageBytes+2
         stz   SnapshotBytesPerSecond
         stz   SnapshotBytesPerSecond+2
         stz   SnapshotKbitPerSecond
         stz   SnapshotKbitPerSecond+2
         stz   SnapshotPumpBurstCurrent
         stz   SnapshotPumpBurstLast
         stz   SnapshotPumpBurstMax
         stz   SnapshotPumpQuantaTotal
         stz   SnapshotPumpQuantaTotal+2
         stz   SnapshotPumpStopReason
         stz   SnapshotPumpQueueStart
         stz   SnapshotPumpQueueStart+2
         stz   SnapshotPumpQueueLast
         stz   SnapshotPumpQueueLast+2
         stz   SnapshotPumpBytesCurrent
         stz   SnapshotPumpBytesCurrent+2
         stz   SnapshotPumpBytesLast
         stz   SnapshotPumpBytesLast+2
         stz   SnapshotPumpBytesMax
         stz   SnapshotPumpBytesMax+2
         jsr   ReadSystemTick
         lda   CurrentTick
         sta   ProducerStartTick
         lda   CurrentTick+2
         sta   ProducerStartTick+2
         rts

ResetSessionDiagnostics
         stz   SessionMaxSkew
         stz   AutoLowLeadCount
         stz   AutoResetPending
         stz   AutomaticResetFlag
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         lda   #$FFFF
         sta   SessionMinLead
         stz   LastLeadBlocks
         stz   LastSkewBlocks
         stz   SnapshotProduced
         stz   SnapshotProduced+2
         stz   SnapshotRight
         stz   SnapshotRight+2
         stz   SnapshotLeft
         stz   SnapshotLeft+2
         stz   SnapshotPhasePoll
         stz   SnapshotPhaseFaultCount
         stz   SnapshotPhaseFaultFlags
         stz   SnapshotPhaseCurrentFlags
         stz   SnapshotPhaseStreak01
         stz   SnapshotPhaseStreak23
         stz   SnapshotPhaseMax01
         stz   SnapshotPhaseMax23
         stz   SnapshotPhaseSample01
         stz   SnapshotPhaseSample23
         rts


UpdateProducerLead
* Minimal hot-path producer lead calculation. Full skew,
* min/max, phase, and rate diagnostics are computed only
* by explicit snapshots / stop paths.

         lda   ProducedBlocks
         sec
         sbc   ConsumedMax
         sta   DiagTemp
         lda   ProducedBlocks+2
         sbc   ConsumedMax+2
         bcc   LeanLeadZero
         beq   LeanLeadLow
         lda   #$FFFF
         sta   LastLeadBlocks
         rts

LeanLeadLow
         lda   DiagTemp
         sta   LastLeadBlocks
         rts

LeanLeadZero
         stz   LastLeadBlocks
         rts


UpdateDiagnostics
* Absolute 32-bit difference between channel counters.

         lda   RightConsumed+2
         cmp   LeftConsumed+2
         bcc   DiagLeftGreater
         bne   DiagRightGreater
         lda   RightConsumed
         cmp   LeftConsumed
         bcc   DiagLeftGreater

DiagRightGreater
         lda   RightConsumed
         sec
         sbc   LeftConsumed
         sta   DiagTemp
         lda   RightConsumed+2
         sbc   LeftConsumed+2
         sta   DiagTemp+2
         bra   DiagSkewReady

DiagLeftGreater
         lda   LeftConsumed
         sec
         sbc   RightConsumed
         sta   DiagTemp
         lda   LeftConsumed+2
         sbc   RightConsumed+2
         sta   DiagTemp+2

DiagSkewReady
         lda   DiagTemp+2
         beq   DiagSkewLow
         lda   #$FFFF
         bra   DiagSkewStore

DiagSkewLow
         lda   DiagTemp

DiagSkewStore
         sta   LastSkewBlocks
         cmp   SessionMaxSkew
         bcc   DiagLeadCalculate
         beq   DiagLeadCalculate
         sta   SessionMaxSkew

DiagLeadCalculate
* Producer lead is ProducedBlocks-ConsumedMax.  Saturate
* to a word for compact display while retaining 32-bit
* source counters in the snapshot.

         lda   ProducedBlocks
         sec
         sbc   ConsumedMax
         sta   DiagTemp
         lda   ProducedBlocks+2
         sbc   ConsumedMax+2
         sta   DiagTemp+2
         bcc   DiagLeadZero

         lda   DiagTemp+2
         beq   DiagLeadLow
         lda   #$FFFF
         bra   DiagLeadStore

DiagLeadLow
         lda   DiagTemp
         bra   DiagLeadStore

DiagLeadZero
         lda   #$0000

DiagLeadStore
         sta   LastLeadBlocks
         cmp   SessionMinLead
         bcs   DiagUpdateDone
         sta   SessionMinLead

DiagUpdateDone
         rts

CaptureDiagnostics
         lda   NetIPID
         beq   CaptureSkipTCPRefresh

         _TCPIPPoll
         jsr   GetTCPStatus

CaptureSkipTCPRefresh
         lda   PlaybackRunningFlag
         beq   CaptureWithoutPlayback
         lda   RingStatusPtr
         ora   RingStatusPtr+2
         beq   CaptureWithoutPlayback

         jsr   ReadRingCounters
* M3R16L snapshot-only diagnostic mirrors.  The hot ring-counter reader
* intentionally maintains only ConsumedMin/ConsumedMax.
         lda   ConsumedMin
         sta   RightConsumed
         sta   LeftConsumed
         lda   ConsumedMin+2
         sta   RightConsumed+2
         sta   LeftConsumed+2
         jsr   UpdateDiagnostics
         bra   CaptureCountersReady

CaptureWithoutPlayback
         stz   RightConsumed
         stz   RightConsumed+2
         stz   LeftConsumed
         stz   LeftConsumed+2
         stz   ConsumedMin
         stz   ConsumedMin+2
         stz   ConsumedMax
         stz   ConsumedMax+2
         stz   LastLeadBlocks
         stz   LastSkewBlocks

CaptureCountersReady
         jsr   ReadPhaseDiagnostics

         lda   ProducedBlocks
         sta   SnapshotProduced
         lda   ProducedBlocks+2
         sta   SnapshotProduced+2
         lda   RightConsumed
         sta   SnapshotRight
         lda   RightConsumed+2
         sta   SnapshotRight+2
         lda   LeftConsumed
         sta   SnapshotLeft
         lda   LeftConsumed+2
         sta   SnapshotLeft+2
         lda   LastLeadBlocks
         sta   SnapshotLead
         lda   LastSkewBlocks
         sta   SnapshotSkew
         lda   SessionMinLead
         cmp   #$FFFF
         bne   CaptureMinLeadReady
         lda   #$0000

CaptureMinLeadReady
         sta   SnapshotMinLead
         lda   SessionMaxSkew
         sta   SnapshotMaxSkew
         lda   TCPStatusBuffer
         sta   SnapshotTCPState
         lda   TCPStatusBuffer+8
         sta   SnapshotQueued
         lda   TCPStatusBuffer+10
         sta   SnapshotQueued+2
         lda   PhasePollCount
         sta   SnapshotPhasePoll
         lda   PhaseFaultCount
         sta   SnapshotPhaseFaultCount
         lda   PhaseFaultFlags
         sta   SnapshotPhaseFaultFlags
         lda   PhaseCurrentFlags
         sta   SnapshotPhaseCurrentFlags
         lda   PhaseStreak01
         sta   SnapshotPhaseStreak01
         lda   PhaseStreak23
         sta   SnapshotPhaseStreak23
         lda   PhaseMax01
         sta   SnapshotPhaseMax01
         lda   PhaseMax23
         sta   SnapshotPhaseMax23
         lda   PhaseSample01
         sta   SnapshotPhaseSample01
         lda   PhaseSample23
         sta   SnapshotPhaseSample23

         lda   NetworkBytesTotal
         sta   SnapshotNetworkBytes
         lda   NetworkBytesTotal+2
         sta   SnapshotNetworkBytes+2
         lda   NetworkReadCalls
         sta   SnapshotNetworkReadCalls
         lda   NetworkReadCalls+2
         sta   SnapshotNetworkReadCalls+2
         lda   NetworkPartialReads
         sta   SnapshotNetworkPartialReads
         lda   NetworkPartialReads+2
         sta   SnapshotNetworkPartialReads+2
         lda   NetworkNoDataPolls
         sta   SnapshotNetworkNoDataPolls
         lda   NetworkNoDataPolls+2
         sta   SnapshotNetworkNoDataPolls+2
         lda   NetworkQueueHigh
         sta   SnapshotNetworkQueueHigh
         lda   NetworkQueueHigh+2
         sta   SnapshotNetworkQueueHigh+2
         lda   PumpBurstCurrent
         sta   SnapshotPumpBurstCurrent
         lda   PumpBurstLast
         sta   SnapshotPumpBurstLast
         lda   PumpBurstMax
         sta   SnapshotPumpBurstMax
         lda   PumpQuantaTotal
         sta   SnapshotPumpQuantaTotal
         lda   PumpQuantaTotal+2
         sta   SnapshotPumpQuantaTotal+2
         lda   PumpStopReason
         sta   SnapshotPumpStopReason
         lda   PumpQueueStart
         sta   SnapshotPumpQueueStart
         lda   PumpQueueStart+2
         sta   SnapshotPumpQueueStart+2
         lda   PumpQueueLast
         sta   SnapshotPumpQueueLast
         lda   PumpQueueLast+2
         sta   SnapshotPumpQueueLast+2
         lda   PumpBytesCurrent
         sta   SnapshotPumpBytesCurrent
         lda   PumpBytesCurrent+2
         sta   SnapshotPumpBytesCurrent+2
         lda   PumpBytesLast
         sta   SnapshotPumpBytesLast
         lda   PumpBytesLast+2
         sta   SnapshotPumpBytesLast+2
         lda   PumpBytesMax
         sta   SnapshotPumpBytesMax
         lda   PumpBytesMax+2
         sta   SnapshotPumpBytesMax+2
         lda   PumpRescueCount
         sta   SnapshotPumpRescueCount
         lda   PumpRescueQuanta
         sta   SnapshotPumpRescueQuanta

         jsr   ReadSystemTick
         lda   CurrentTick
         sec
         sbc   ProducerStartTick
         sta   SnapshotElapsedTicks
         lda   CurrentTick+2
         sbc   ProducerStartTick+2
         sta   SnapshotElapsedTicks+2
         jsr   ComputeProducerDerivedDiagnostics
         rts

ComputeProducerDerivedDiagnostics
* Snapshot-only arithmetic.  No division occurs in the
* producer or TCP receive hot paths.

         stz   SnapshotElapsedSeconds
         stz   SnapshotElapsedSeconds+2
         stz   SnapshotAverageBytes
         stz   SnapshotAverageBytes+2
         stz   SnapshotBytesPerSecond
         stz   SnapshotBytesPerSecond+2
         stz   SnapshotKbitPerSecond
         stz   SnapshotKbitPerSecond+2

* Average bytes returned by each _TCPIPReadTCP call.

         lda   SnapshotNetworkReadCalls
         ora   SnapshotNetworkReadCalls+2
         beq   ProducerAverageReady
         lda   SnapshotNetworkBytes
         sta   DivideDividend
         lda   SnapshotNetworkBytes+2
         sta   DivideDividend+2
         lda   SnapshotNetworkReadCalls
         sta   DivideDivisor
         lda   SnapshotNetworkReadCalls+2
         sta   DivideDivisor+2
         jsr   DivideUnsigned32
         lda   DivideQuotient
         sta   SnapshotAverageBytes
         lda   DivideQuotient+2
         sta   SnapshotAverageBytes+2

ProducerAverageReady
* Convert 60 Hz elapsed ticks to whole seconds.

         lda   SnapshotElapsedTicks
         sta   DivideDividend
         lda   SnapshotElapsedTicks+2
         sta   DivideDividend+2
         lda   #60
         sta   DivideDivisor
         stz   DivideDivisor+2
         jsr   DivideUnsigned32
         lda   DivideQuotient
         sta   SnapshotElapsedSeconds
         lda   DivideQuotient+2
         sta   SnapshotElapsedSeconds+2
         ora   SnapshotElapsedSeconds
         beq   ProducerRatesReady

* Measured bytes/sec = total network bytes / whole seconds.

         lda   SnapshotNetworkBytes
         sta   DivideDividend
         lda   SnapshotNetworkBytes+2
         sta   DivideDividend+2
         lda   SnapshotElapsedSeconds
         sta   DivideDivisor
         lda   SnapshotElapsedSeconds+2
         sta   DivideDivisor+2
         jsr   DivideUnsigned32
         lda   DivideQuotient
         sta   SnapshotBytesPerSecond
         lda   DivideQuotient+2
         sta   SnapshotBytesPerSecond+2

* Integer kbit/sec = bytes/sec * 8 / 1000.  The Uthernet
* path is far below the 32-bit overflow point for this shift.

         lda   SnapshotBytesPerSecond
         sta   DivideDividend
         lda   SnapshotBytesPerSecond+2
         sta   DivideDividend+2
         asl   DivideDividend
         rol   DivideDividend+2
         asl   DivideDividend
         rol   DivideDividend+2
         asl   DivideDividend
         rol   DivideDividend+2
         lda   #1000
         sta   DivideDivisor
         stz   DivideDivisor+2
         jsr   DivideUnsigned32
         lda   DivideQuotient
         sta   SnapshotKbitPerSecond
         lda   DivideQuotient+2
         sta   SnapshotKbitPerSecond+2

ProducerRatesReady
         rts

DivideUnsigned32
* Unsigned 32/32 restoring division.
* Input:  DivideDividend / DivideDivisor
* Output: DivideQuotient, DivideRemainder
* A zero divisor returns a zero quotient and remainder.

         stz   DivideQuotient
         stz   DivideQuotient+2
         stz   DivideRemainder
         stz   DivideRemainder+2
         lda   DivideDivisor
         ora   DivideDivisor+2
         beq   DivideUnsignedDone
         lda   #32
         sta   DivideLoopCount

DivideUnsignedLoop
         asl   DivideDividend
         rol   DivideDividend+2
         rol   DivideRemainder
         rol   DivideRemainder+2
         asl   DivideQuotient
         rol   DivideQuotient+2

         lda   DivideRemainder+2
         cmp   DivideDivisor+2
         bcc   DivideUnsignedNext
         bne   DivideUnsignedSubtract
         lda   DivideRemainder
         cmp   DivideDivisor
         bcc   DivideUnsignedNext

DivideUnsignedSubtract
         lda   DivideRemainder
         sec
         sbc   DivideDivisor
         sta   DivideRemainder
         lda   DivideRemainder+2
         sbc   DivideDivisor+2
         sta   DivideRemainder+2
         inc   DivideQuotient

DivideUnsignedNext
         dec   DivideLoopCount
         bne   DivideUnsignedLoop

DivideUnsignedDone
         rts

PrintInputError
         sta   LastNetworkError
         pea   ^InputErrorLineMsg
         pea   InputErrorLineMsg
         _WriteCString
         lda   LastNetworkError
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

PrintConnectionError
         sta   LastNetworkError
         pea   ^ConnectionErrorLineMsg
         pea   ConnectionErrorLineMsg
         _WriteCString
         lda   LastNetworkError
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

PrintStreamEnded
         pea   ^StreamEndedMsg
         pea   StreamEndedMsg
         _WriteCString
         lda   LastNetworkError
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

PrintDiagnosticsSnapshot
         pea   ^DiagProducedMsg
         pea   DiagProducedMsg
         _WriteCString
         lda   SnapshotProduced+2
         jsr   WriteHexWord
         lda   SnapshotProduced
         jsr   WriteHexWord

         pea   ^DiagRightMsg
         pea   DiagRightMsg
         _WriteCString
         lda   SnapshotRight+2
         jsr   WriteHexWord
         lda   SnapshotRight
         jsr   WriteHexWord

         pea   ^DiagLeftMsg
         pea   DiagLeftMsg
         _WriteCString
         lda   SnapshotLeft+2
         jsr   WriteHexWord
         lda   SnapshotLeft
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagLeadMsg
         pea   DiagLeadMsg
         _WriteCString
         lda   SnapshotLead
         jsr   WriteHexWord

         pea   ^DiagMinMsg
         pea   DiagMinMsg
         _WriteCString
         lda   SnapshotMinLead
         jsr   WriteHexWord

         jsr   WriteCRLF

         pea   ^DiagTCPMsg
         pea   DiagTCPMsg
         _WriteCString
         lda   SnapshotTCPState
         jsr   WriteHexWord

         pea   ^DiagQueueMsg
         pea   DiagQueueMsg
         _WriteCString
         lda   SnapshotQueued+2
         jsr   WriteHexWord
         lda   SnapshotQueued
         jsr   WriteHexWord

         pea   ^DiagResetMsg
         pea   DiagResetMsg
         _WriteCString
         lda   ResetCount
         jsr   WriteHexWord

         pea   ^DiagAutoMsg
         pea   DiagAutoMsg
         _WriteCString
         lda   AutoResetCount
         jsr   WriteHexWord

         pea   ^DiagLowWaterMsg
         pea   DiagLowWaterMsg
         _WriteCString
         lda   LowWaterResetCount
         jsr   WriteHexWord

         pea   ^DiagLowLeadMsg
         pea   DiagLowLeadMsg
         _WriteCString
         lda   LowWaterLead
         jsr   WriteHexWord

         pea   ^DiagDisconnectMsg
         pea   DiagDisconnectMsg
         _WriteCString
         lda   DisconnectCount
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagNetBytesMsg
         pea   DiagNetBytesMsg
         _WriteCString
         lda   SnapshotNetworkBytes+2
         jsr   WriteHexWord
         lda   SnapshotNetworkBytes
         jsr   WriteHexWord

         pea   ^DiagReadCallsMsg
         pea   DiagReadCallsMsg
         _WriteCString
         lda   SnapshotNetworkReadCalls+2
         jsr   WriteHexWord
         lda   SnapshotNetworkReadCalls
         jsr   WriteHexWord

         pea   ^DiagPartialMsg
         pea   DiagPartialMsg
         _WriteCString
         lda   SnapshotNetworkPartialReads+2
         jsr   WriteHexWord
         lda   SnapshotNetworkPartialReads
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagNoDataMsg
         pea   DiagNoDataMsg
         _WriteCString
         lda   SnapshotNetworkNoDataPolls+2
         jsr   WriteHexWord
         lda   SnapshotNetworkNoDataPolls
         jsr   WriteHexWord

         pea   ^DiagQueueMaxMsg
         pea   DiagQueueMaxMsg
         _WriteCString
         lda   SnapshotNetworkQueueHigh+2
         jsr   WriteHexWord
         lda   SnapshotNetworkQueueHigh
         jsr   WriteHexWord

         pea   ^DiagTicksMsg
         pea   DiagTicksMsg
         _WriteCString
         lda   SnapshotElapsedTicks+2
         jsr   WriteHexWord
         lda   SnapshotElapsedTicks
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagAverageMsg
         pea   DiagAverageMsg
         _WriteCString
         lda   SnapshotAverageBytes+2
         jsr   WriteHexWord
         lda   SnapshotAverageBytes
         jsr   WriteHexWord

         pea   ^DiagBytesPerSecondMsg
         pea   DiagBytesPerSecondMsg
         _WriteCString
         lda   SnapshotBytesPerSecond+2
         jsr   WriteHexWord
         lda   SnapshotBytesPerSecond
         jsr   WriteHexWord

         pea   ^DiagKbitPerSecondMsg
         pea   DiagKbitPerSecondMsg
         _WriteCString
         lda   SnapshotKbitPerSecond+2
         jsr   WriteHexWord
         lda   SnapshotKbitPerSecond
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagBurstMsg
         pea   DiagBurstMsg
         _WriteCString
         lda   SnapshotPumpBurstCurrent
         jsr   WriteHexWord

         pea   ^DiagBurstLastMsg
         pea   DiagBurstLastMsg
         _WriteCString
         lda   SnapshotPumpBurstLast
         jsr   WriteHexWord

         pea   ^DiagBurstMaxMsg
         pea   DiagBurstMaxMsg
         _WriteCString
         lda   SnapshotPumpBurstMax
         jsr   WriteHexWord

         pea   ^DiagQuantaMsg
         pea   DiagQuantaMsg
         _WriteCString
         lda   SnapshotPumpQuantaTotal+2
         jsr   WriteHexWord
         lda   SnapshotPumpQuantaTotal
         jsr   WriteHexWord

         pea   ^DiagRescueMsg
         pea   DiagRescueMsg
         _WriteCString
         lda   SnapshotPumpRescueCount
         jsr   WriteHexWord

         pea   ^DiagRescueQuantaMsg
         pea   DiagRescueQuantaMsg
         _WriteCString
         lda   SnapshotPumpRescueQuanta
         jsr   WriteHexWord
         jsr   WriteCRLF
         jsr   PrintPaddleStateLine

         pea   ^DiagM3WhyMsg
         pea   DiagM3WhyMsg
         _WriteCString
         lda   SnapshotPumpStopReason
         jsr   WriteHexWord

         pea   ^DiagM3Q0Msg
         pea   DiagM3Q0Msg
         _WriteCString
         lda   SnapshotPumpQueueStart+2
         jsr   WriteHexWord
         lda   SnapshotPumpQueueStart
         jsr   WriteHexWord

         pea   ^DiagM3Q1Msg
         pea   DiagM3Q1Msg
         _WriteCString
         lda   SnapshotPumpQueueLast+2
         jsr   WriteHexWord
         lda   SnapshotPumpQueueLast
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagM3BytesCurMsg
         pea   DiagM3BytesCurMsg
         _WriteCString
         lda   SnapshotPumpBytesCurrent+2
         jsr   WriteHexWord
         lda   SnapshotPumpBytesCurrent
         jsr   WriteHexWord

         pea   ^DiagM3BytesLastMsg
         pea   DiagM3BytesLastMsg
         _WriteCString
         lda   SnapshotPumpBytesLast+2
         jsr   WriteHexWord
         lda   SnapshotPumpBytesLast
         jsr   WriteHexWord

         pea   ^DiagM3BytesMaxMsg
         pea   DiagM3BytesMaxMsg
         _WriteCString
         lda   SnapshotPumpBytesMax+2
         jsr   WriteHexWord
         lda   SnapshotPumpBytesMax
         jsr   WriteHexWord
         jsr   WriteCRLF

         pea   ^DiagM3FreeMsg
         pea   DiagM3FreeMsg
         _WriteCString
         lda   FreeBlocks+2
         jsr   WriteHexWord
         lda   FreeBlocks
         jsr   WriteHexWord

         pea   ^DiagM3BlocksMsg
         pea   DiagM3BlocksMsg
         _WriteCString
         lda   BlocksToRead
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

WriteCRLF
         pea   ^CRLFMsg
         pea   CRLFMsg
         _WriteCString
         rts

WriteHexWord
         sta   HexValue

         lda   HexValue
         and   #$F000
         xba
         lsr
         lsr
         lsr
         lsr
         jsr   WriteHexNibble

         lda   HexValue
         and   #$0F00
         xba
         jsr   WriteHexNibble

         lda   HexValue
         and   #$00F0
         lsr
         lsr
         lsr
         lsr
         jsr   WriteHexNibble

         lda   HexValue
         and   #$000F
         jsr   WriteHexNibble
         rts

WriteHexNibble
         and   #$000F
         cmp   #$000A
         bcc   WriteHexNumeric
         clc
         adc   #$0037
         bra   WriteHexOutput

WriteHexNumeric
         clc
         adc   #$0030

WriteHexOutput
         pha
         _WriteChar
         rts



*-------------------------------------------------
* M3R23W warm-provider TCP restream (client side remains ring-safe).
* Safe-boundary only; Tool225 and ring state remain live.
*-------------------------------------------------
M3R22HHiddenRefresh
         stz   HiddenRefreshArmed
         inc   HiddenRefreshCount
         lda   LastLeadBlocks
         sta   HiddenRefreshLastLead
         stz   NetCarryBytes
         lda   #1
         sta   HiddenRefreshActive

         jsr   CloseNetworkSession
         jsr   OpenNetworkStream
         bcc   M3R22HHiddenRefreshOkay

         sta   LastNetworkError
         inc   HiddenRefreshFailCount
         stz   HiddenRefreshActive
         lda   LastNetworkError
         sec
         rts

M3R22HHiddenRefreshOkay
         inc   HiddenRefreshSuccessCount
         stz   HiddenRefreshActive
         lda   #1
         sta   HiddenRefreshReportPending
         clc
         rts

PrintHiddenRefreshStateLine
         pea   ^HiddenRefreshCountMsg
         pea   HiddenRefreshCountMsg
         _WriteCString
         lda   HiddenRefreshCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshOkayMsg
         pea   HiddenRefreshOkayMsg
         _WriteCString
         lda   HiddenRefreshSuccessCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshFailMsg
         pea   HiddenRefreshFailMsg
         _WriteCString
         lda   HiddenRefreshFailCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshHardMsg
         pea   HiddenRefreshHardMsg
         _WriteCString
         lda   LowWaterResetCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshLeadMsg
         pea   HiddenRefreshLeadMsg
         _WriteCString
         lda   HiddenRefreshLastLead
         jsr   WriteHexWord

         pea   ^HiddenRefreshArmedMsg
         pea   HiddenRefreshArmedMsg
         _WriteCString
         lda   HiddenRefreshArmed
         jsr   WriteHexWord

         pea   ^HiddenRefreshRearmMsg
         pea   HiddenRefreshRearmMsg
         _WriteCString
         lda   HiddenRefreshRearmCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshSocketMsg
         pea   HiddenRefreshSocketMsg
         _WriteCString
         lda   HiddenRefreshSocketCount
         jsr   WriteHexWord

         pea   ^HiddenRefreshReasonMsg
         pea   HiddenRefreshReasonMsg
         _WriteCString
         lda   HiddenRefreshReason
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

*-------------------------------------------------
* M3R21F compact FULL PADDLE controller state.
* Display-only: explicit D or after playback has stopped on hard low water.
*-------------------------------------------------
PrintPaddleStateLine
         pea   ^PaddleStateInMsg
         pea   PaddleStateInMsg
         _WriteCString
         lda   PaddleEnterCount
         jsr   WriteHexWord

         pea   ^PaddleStateOutMsg
         pea   PaddleStateOutMsg
         _WriteCString
         lda   PaddleExitCount
         jsr   WriteHexWord

         pea   ^PaddleStateEnterMsg
         pea   PaddleStateEnterMsg
         _WriteCString
         lda   PaddleLastEnterLead
         jsr   WriteHexWord

         pea   ^PaddleStateExitMsg
         pea   PaddleStateExitMsg
         _WriteCString
         lda   PaddleLastExitLead
         jsr   WriteHexWord

         pea   ^PaddleStateActiveMsg
         pea   PaddleStateActiveMsg
         _WriteCString
         lda   PumpRescueActive
         jsr   WriteHexWord

         pea   ^PaddleStateQueueMsg
         pea   PaddleStateQueueMsg
         _WriteCString
         lda   SnapshotQueued+2
         jsr   WriteHexWord
         lda   SnapshotQueued
         jsr   WriteHexWord
         jsr   WriteCRLF
         jsr   PrintHiddenRefreshStateLine
         rts

*-------------------------------------------------
* Stock-speed network low-water recovery
*
* Unlike the experimental phase watchdog, this guard is
* enabled in both builds.  A live producer lead of 64 blocks
* or fewer is captured and routed through the proven R-style
* Tool225 recycle/rebuffer path before the ring reaches zero.
*-------------------------------------------------

CheckLowWaterRecovery
         lda   NetworkModeFlag
         beq   LowWaterContinue
         lda   PlaybackRunningFlag
         beq   LowWaterContinue
         lda   LowWaterResetFlag
         bne   LowWaterRequest

         lda   LastLeadBlocks
         cmp   #NetworkLowLead+1
         bcs   LowWaterContinue
         sta   LowWaterLead
         lda   #1
         sta   LowWaterResetFlag
         stz   AutomaticResetFlag

LowWaterRequest
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

LowWaterContinue
         clc
         rts

*-------------------------------------------------
* Optional automatic recovery watchdog
*
* LEAN EXPERIMENT: AutoRecoverEnabled=0 so phase/skew
* observation is not executed in the playback hot path.
* Low-water recovery remains enabled.
*
* The normal EtherStream225 build compiles this code
* with AutoRecoverEnabled=0.  EtherStrAuto enables it.
* It requests the exact normal R-style engine recycle when:
*
* - Tool225 P0.9B latches duplicate-pair 0/1 or 2/3,
* - logical channel counters differ by two blocks,
* - producer lead remains at or below 16 blocks for
*   eight consecutive foreground observations.
*
* Physical pair faults are captured before Tool225 is
* shut down so D-style diagnostics identify which pair
* triggered the automatic recovery.
*
* P0.6.2C-L3R3 retains the P0.6.2B no-timed-reset behavior.
* A healthy stream may now run indefinitely without an
* artificial 30-minute Tool225 recycle and rebuffer.
*-------------------------------------------------

CheckAutomaticRecovery
* M3R16L LEAN WATCHDOG.  True-22K immediate mono has one physical ring
* consumer and uses PumpYield low-water rescue/reset as its safety authority.
* Prepared-stereo phase/skew diagnostics remain available on explicit D/stop
* snapshots but are not polled continuously in the live M3 hot path.
         lda   NetworkModeFlag
         beq   M3R16LLegacyAutoRecovery
         lda   PlaybackRunningFlag
         beq   M3R16LLegacyAutoRecovery
         clc
         rts

M3R16LLegacyAutoRecovery
* Never run the watchdog while establishing, prefilling,
* stopped at the endpoint prompt, or in file-player mode.
* In particular, LastLeadBlocks is intentionally zero until
* prepared playback has started; testing it during prefill
* would cause the experimental build to reset repeatedly.

         lda   #AutoRecoverEnabled
         bne   AutoRecoveryModeEnabled
         clc
         rts

AutoRecoveryModeEnabled
         lda   NetworkModeFlag
         bne   AutoRecoveryNetworkReady
         brl   AutoRecoveryContinue

AutoRecoveryNetworkReady
         lda   PlaybackRunningFlag
         bne   AutoRecoveryActive
         brl   AutoRecoveryContinue

AutoRecoveryActive
         jsr   ReadPhaseDiagnostics
         lda   PhaseFaultFlags
         beq   AutoCheckPending

         sta   PhaseTriggerFlags
         lda   #1
         sta   PhaseResetFlag
         brl   AutoRecoveryLatch

AutoCheckPending
         lda   AutoResetPending
         beq   AutoCheckSkew
         brl   AutoRecoveryRequest

AutoCheckSkew
         stz   PhaseResetFlag
         stz   PhaseTriggerFlags
         lda   LastSkewBlocks
         cmp   #AutoSkewLimit
         bcc   AutoCheckLead
         brl   AutoRecoveryLatch

AutoCheckLead

         lda   LastLeadBlocks
         cmp   #AutoLowLeadLimit+1
         bcs   AutoLeadHealthy

         inc   AutoLowLeadCount
         lda   AutoLowLeadCount
         cmp   #AutoLowLeadLoops
         bcc   AutoWatchdogHealthy
         brl   AutoRecoveryLatch

AutoLeadHealthy
         stz   AutoLowLeadCount

AutoWatchdogHealthy
         brl   AutoRecoveryContinue

AutoRecoveryLatch
         lda   #1
         sta   AutoResetPending

AutoRecoveryRequest
         stz   AutoResetPending
         stz   AutoLowLeadCount
         lda   #1
         sta   AutomaticResetFlag
         stz   LowWaterResetFlag
         lda   #ActionReset
         sta   NetworkAction
         sec
         rts

AutoRecoveryContinue
         clc
         rts

*-------------------------------------------------
* Tool225 session repair
*
* A manual/automatic R operation fully shuts down and
* restarts Tool225 while keeping its code loaded.  This
* is stronger than Stop+Init and clears all tool-owned
* streaming/DOC state before the existing socket is
* prefetched again.  C and disconnect only do this when
* the preceding Stop call reported an error.
*-------------------------------------------------

*-------------------------------------------------
* StopPlaybackIRQLive
*
* Tool225 Stop must run with IRQs live so the DOC can
* complete its final interrupt-side quiescence. Preserve
* the caller status and return the Tool225 carry result.
* Cold lifecycle path only; no producer hot-path cost.
*-------------------------------------------------
StopPlaybackIRQLive
         php
         cli
         _PCM225Stop
         bcc   StopPlaybackIRQOkay
         plp
         sec
         rts

StopPlaybackIRQOkay
         plp
         clc
         rts

RepairPlaybackToolIfNeeded
         lda   PlaybackStopError
         bne   RestartPlaybackTool
         clc
         rts

RestartPlaybackTool
         stz   PlaybackRunningFlag
         stz   PlaybackStopError

         lda   PlaybackToolActive
         beq   PlaybackToolNeedsStart

         _PCM225ShutDown
         bcc   PlaybackToolWasShutDown
         rts

PlaybackToolWasShutDown
         stz   PlaybackToolActive

PlaybackToolNeedsStart
         lda   PlaybackToolLoaded
         bne   PlaybackToolCodeReady

         pea   $00E1
         pea   $0000
         _LoadOneTool
         bcc   PlaybackToolReloaded
         rts

PlaybackToolReloaded
         lda   #1
         sta   PlaybackToolLoaded

PlaybackToolCodeReady
         pea   $E1AD
         _PCM225StartUp
         bcc   PlaybackToolRestartOkay
         rts

PlaybackToolRestartOkay
         lda   #1
         sta   PlaybackToolActive
         clc
         rts

PrintToolRestartError
         sta   LastNetworkError
         pea   ^ToolRestartErrorMsg
         pea   ToolRestartErrorMsg
         _WriteCString
         lda   LastNetworkError
         jsr   WriteHexWord
         jsr   WriteCRLF
         rts

*-------------------------------------------------
* Close and release
*-------------------------------------------------

CloseWaveFile
         lda   WaveOpenFlag
         beq   WaveAlreadyClosed

         jsl   GSOS
         dw    CloseCall
         adrl  WaveClosePB

         stz   WaveOpenFlag

WaveAlreadyClosed
         rts

ReleaseWorkRing
         lda   WorkHandle
         ora   WorkHandle+2
         beq   WorkRingReleased

         lda   WorkHandle+2
         pha

         lda   WorkHandle
         pha

         _DisposeHandle

         stz   WorkHandle
         stz   WorkHandle+2
         stz   WorkDataPtr
         stz   WorkDataPtr+2

WorkRingReleased
         rts
ReleaseLeftRing
         lda   LeftHandle
         ora   LeftHandle+2
         beq   M3R5R2SharedRingNoHandle

         lda   LeftHandle+2
         pha

         lda   LeftHandle
         pha

         _DisposeHandle

         stz   LeftHandle
         stz   LeftHandle+2

M3R5R2SharedRingNoHandle
* The right-side runtime/descriptor pointers are aliases of the one left
* allocation in shared-mono mode.  Clear both logical views whenever the
* owner handle is released (or is already absent) so teardown cannot leave
* a dangling alias for launcher/toolbox code to observe after MM shutdown.

         stz   LeftRingPtr
         stz   LeftRingPtr+2
         stz   RightRingPtr
         stz   RightRingPtr+2

         stz   LeftRingPointer
         stz   LeftRingPointer+2
         stz   RightRingPointer
         stz   RightRingPointer+2

LeftRingReleased
         rts


ReleaseRightRing
         lda   RightHandle
         ora   RightHandle+2
         beq   RightRingReleased

         lda   RightHandle+2
         pha

         lda   RightHandle
         pha

         _DisposeHandle

         stz   RightHandle
         stz   RightHandle+2
         stz   RightRingPtr
         stz   RightRingPtr+2

RightRingReleased
         rts

ReleaseAllRings
         jsr   ReleaseWorkRing
         jsr   ReleaseLeftRing
         jsr   ReleaseRightRing
         rts

ShutPlaybackTool
         lda   PlaybackToolActive
         beq   PlaybackToolNotActive

         lda   PlaybackRunningFlag
         beq   PlaybackToolAlreadyQuiet

         jsr   StopPlaybackIRQLive
         stz   PlaybackRunningFlag

PlaybackToolAlreadyQuiet
         _PCM225ShutDown
         stz   PlaybackToolActive

PlaybackToolNotActive
* Do not immediately unload Tool225 after ShutDown.
* Its interrupt hooks are not yet proven quiescent at
* this boundary. Leave the code resident for correctness.
PlaybackToolAlreadyStopped
         clc
         rts

ShutMemory
         lda   MMStartedFlag
         beq   MemoryAlreadyStopped

         lda   MasterID
         pha
         _MMShutDown

         stz   MMStartedFlag

MemoryAlreadyStopped
         lda   TLStartedFlag
         beq   ToolLocatorAlreadyStopped

         _TLShutDown
         stz   TLStartedFlag

ToolLocatorAlreadyStopped
         rts

*-------------------------------------------------
* Error cleanup
*-------------------------------------------------

FailAfterStream
         sta   SavedError
         stx   SavedMsgBank
         sty   SavedMsgAddr

         jsr   ShutPlaybackTool

         jsr   CloseWaveFile
         jsr   ReleaseAllRings
         jsr   StopSelectorTools
         jsr   ShutNetworkFrontend
         jsr   ShutMemory

         lda   SavedError
         ldx   SavedMsgBank
         ldy   SavedMsgAddr
         brl   FatalError

FailAfterTool
         sta   SavedError
         stx   SavedMsgBank
         sty   SavedMsgAddr

         jsr   ShutPlaybackTool

         jsr   CloseWaveFile
         jsr   ReleaseAllRings
         jsr   StopSelectorTools
         jsr   ShutNetworkFrontend
         jsr   ShutMemory

         lda   SavedError
         ldx   SavedMsgBank
         ldy   SavedMsgAddr
         brl   FatalError

FailAfterMemory
         sta   SavedError
         stx   SavedMsgBank
         sty   SavedMsgAddr

         jsr   ShutPlaybackTool
         jsr   CloseWaveFile
         jsr   ReleaseAllRings
         jsr   StopSelectorTools
         jsr   ShutNetworkFrontend
         jsr   ShutMemory

         lda   SavedError
         ldx   SavedMsgBank
         ldy   SavedMsgAddr

FatalError
         pha
         phx
         phy
         _SysFailMgr

QuitReturned3
         bra   QuitReturned3
*-------------------------------------------------
* Ring descriptors
*-------------------------------------------------

RightRingStream
RightRingPointer
         adrl  $00000000

RightRingLength
         adrl  $00040000
         dw    ToneFreq
         dfb   $80
         dfb   $00
         dfb   $02
         dfb   $FF
         dfb   DOCRight
         dfb   $FF
         dfb   DOCLeft

* Retained but unused by the M3 22K-mono network path.

LeftRingStream
LeftRingPointer
         adrl  $00000000

LeftRingLength
         adrl  $00040000
         dw    ToneFreq
         dfb   $80
         dfb   $02
         dfb   $02
         dfb   $FF
         dfb   DOCLeft
         dfb   $FF
         dfb   DOCLeft


*-------------------------------------------------
* GS/OS path and parameter blocks
*-------------------------------------------------

WaveOpenPB
         dw    3
         dw    $0000
         adrl  SFPathBuffer+2
         dw    $0001

WaveEOFPB
         dw    2
         dw    $0000
         adrl  $00000000

WaveReadPB
         dw    4
         dw    $0000
         adrl  $00000000
         adrl  $00000000
         adrl  $00000000

WaveSetMarkPB
         dw    3
         dw    $0000
         dw    $0000
         adrl  $00000000

WaveClosePB
         dw    1
         dw    $0000

QuitPB
         dw    0

*-------------------------------------------------
*-------------------------------------------------
* Standard File reply record and buffers
*-------------------------------------------------

SFReply
         dw    $0000
         dw    $0000
         adrl  $00000000
         dw    $0000
         adrl  SFNameBuffer
         dw    $0000
         adrl  SFPathBuffer

SFNameBuffer
         dw    512
         dw    $0000
         ds    508

SFPathBuffer
         dw    512
         dw    $0000
         ds    508

SelectPrompt
         dfb   SelectPromptEnd-SelectPromptText
SelectPromptText
         asc   'Select stereo WAV (ESC stops playback)'
SelectPromptEnd

*-------------------------------------------------
* StartStop record for Standard File dependencies
*-------------------------------------------------

SelectorStartStop
         dw    $0000
         dw    $C080
         dw    $0000
         adrl  $00000000
         dw    14

         dw    $0003
         dw    $0300

         dw    $0004
         dw    $0301

         dw    $0006
         dw    $0300

         dw    $000E
         dw    $0301

         dw    $000F
         dw    $0301

         dw    $0010
         dw    $0301

         dw    $0012
         dw    $0301

         dw    $0014
         dw    $0301

         dw    $0015
         dw    $0301

         dw    $0016
         dw    $0300

         dw    $0017
         dw    $0301

         dw    $001B
         dw    $0301

         dw    $001C
         dw    $0301

         dw    $001E
         dw    $0100

* Runtime variables
*-------------------------------------------------

MMStartedFlag
         ds    2

TLStartedFlag
         ds    2

PlaybackToolActive
         ds    2

PlaybackToolLoaded
         ds    2

MasterID
         ds    2

MemoryID
         ds    2

SelectorToolsHandle
         ds    4

SelectorToolError
         ds    2

WaveOpenFlag
         ds    2

FoundFmtFlag
         ds    2

WorkHandle
         ds    4

WorkDataPtr
         ds    4

LeftHandle
         ds    4

LeftRingPtr
         ds    4

RightHandle
         ds    4

RightRingPtr
         ds    4

RingBytesHighSelected
         ds    2

RingBlocksSelected
         ds    2

RingBankMask
         ds    2

InitialChunksSelected
         ds    2

WaveFileSize
         ds    4

WaveDataSize
         ds    4

ChunkSize
         ds    4

SkipRemaining
         ds    4

ChunkPad
         ds    2

SkipRequest
         ds    2

RingStatusPtr
         ds    4

PhaseStatusPtr
         ds    4

PhasePollCount
         ds    2
PhaseFaultCount
         ds    2
PhaseFaultFlags
         ds    2
PhaseCurrentFlags
         ds    2
PhaseStreak01
         ds    2
PhaseStreak23
         ds    2
PhaseMax01
         ds    2
PhaseMax23
         ds    2
PhaseSample01
         ds    2
PhaseSample23
         ds    2

RightConsumed
         ds    4

LeftConsumed
         ds    4

ConsumedMin
         ds    4

ConsumedMax
         ds    4

ProducedBlocks
         ds    4

TotalBlocks
         ds    4

RemainingBlocks
         ds    4

FreeBlocks
         ds    4

BlocksToRead
         ds    2

RequestBytes
         ds    2

ChannelBytes
         ds    2

RingOffset
         ds    2

RingBankOffset
         ds    2

LeftChunkPtr
         ds    4

RightChunkPtr
         ds    4

InitialChunks
         ds    2

SavedFileError
         ds    2

SavedError
         ds    2

SavedMsgBank
         ds    2

SavedMsgAddr
         ds    2

PlaybackKey
         ds    2

PlaybackEventPoll
         ds    2

PlaybackEvent
         ds    16


*-------------------------------------------------
* EthernetStreamer runtime state
*-------------------------------------------------

NetworkModeFlag       ds    2
TextToolLoaded        ds    2
TextToolActive        ds    2
TCPToolLoaded         ds    2
TCPToolActive         ds    2
NetIPID               ds    2
NetSocketOpen         ds    2
PlaybackRunningFlag   ds    2
NetworkStopRequested   ds    2
NetworkAction          ds    2
PendingNetworkAction   ds    2
LastNetworkError       ds    2
ResetCount             ds    2
DisconnectCount        ds    2
AutoResetCount         ds    2
LowWaterResetCount     ds    2
LowWaterResetFlag      ds    2
LowWaterLead           ds    2
AutoLowLeadCount       ds    2
AutoResetPending       ds    2
AutomaticResetFlag     ds    2
PhaseResetFlag         ds    2
PhaseTriggerFlags      ds    2
PlaybackStopError      ds    2
SessionMinLead         ds    2
SessionMaxSkew         ds    2
LastLeadBlocks         ds    2
LastSkewBlocks         ds    2
DiagTemp               ds    4
NetworkBytesTotal      ds    4
NetworkReadCalls       ds    4
NetworkPartialReads    ds    4
NetworkNoDataPolls     ds    4
NetworkQueueHigh       ds    4
ProducerStartTick      ds    4
PumpBurstCurrent       ds    2
PumpBurstLast          ds    2
PumpBurstMax           ds    2
PumpQuantaTotal        ds    4
PumpStopReason         ds    2
PumpQueueStart         ds    4
PumpQueueLast          ds    4
PumpBytesCurrent       ds    4
PumpBytesLast          ds    4
PumpBytesMax           ds    4
PumpRescueActive       ds    2
PumpRescueCount        ds    2
PumpRescueQuanta       ds    2
PaddleEnterCount       ds    2
PaddleExitCount        ds    2
PaddleLastEnterLead    ds    2
PaddleLastExitLead     ds    2
HiddenRefreshActive    ds    2
HiddenRefreshArmed     ds    2
HiddenRefreshReportPending ds 2
HiddenRefreshCount     ds    2
HiddenRefreshSuccessCount ds 2
HiddenRefreshFailCount ds    2
HiddenRefreshLastLead  ds    2
HiddenRefreshReason    ds    2
HiddenRefreshRearmCount ds  2
HiddenRefreshSocketCount ds 2
SnapshotProduced       ds    4
SnapshotRight          ds    4
SnapshotLeft           ds    4
SnapshotLead           ds    2
SnapshotSkew           ds    2
SnapshotMinLead        ds    2
SnapshotMaxSkew        ds    2
SnapshotTCPState       ds    2
SnapshotQueued         ds    4
SnapshotNetworkBytes   ds    4
SnapshotNetworkReadCalls ds  4
SnapshotNetworkPartialReads ds 4
SnapshotNetworkNoDataPolls ds 4
SnapshotNetworkQueueHigh ds 4
SnapshotElapsedTicks   ds    4
SnapshotElapsedSeconds ds    4
SnapshotAverageBytes   ds    4
SnapshotBytesPerSecond ds    4
SnapshotKbitPerSecond ds     4
SnapshotPumpBurstCurrent ds  2
SnapshotPumpBurstLast  ds    2
SnapshotPumpBurstMax   ds    2
SnapshotPumpQuantaTotal ds   4
SnapshotPumpStopReason ds    2
SnapshotPumpQueueStart ds    4
SnapshotPumpQueueLast  ds    4
SnapshotPumpBytesCurrent ds  4
SnapshotPumpBytesLast ds     4
SnapshotPumpBytesMax ds      4
SnapshotPumpRescueCount ds   2
SnapshotPumpRescueQuanta ds  2
SnapshotPhasePoll      ds    2
SnapshotPhaseFaultCount ds   2
SnapshotPhaseFaultFlags ds   2
SnapshotPhaseCurrentFlags ds 2
SnapshotPhaseStreak01  ds    2
SnapshotPhaseStreak23  ds    2
SnapshotPhaseMax01     ds    2
SnapshotPhaseMax23     ds    2
SnapshotPhaseSample01  ds    2
SnapshotPhaseSample23  ds    2
DivideDividend         ds    4
DivideDivisor          ds    4
DivideQuotient         ds    4
DivideRemainder        ds    4
DivideLoopCount        ds    2
HexValue               ds    2
DestinationPort       ds    2
DestinationIP         ds    4
NetToolError          ds    2
NetTCPError           ds    2
ConnectStartTick      ds    4
CurrentTick           ds    4
ConnectElapsed        ds    2
DNSStartTick          ds    4
DNSElapsed            ds    2
HostCStringLength     ds    2
NetRequestTotal       ds    2
NetCarryBytes         ds    2
NetRemaining          ds    2
NetReadLength         ds    2
NetReadCount          ds    2
NetReadPointer        ds    4
InputMaxLength        ds    2
InputLength           ds    2
InputChar             ds    2
ParsedPort            ds    2
ParseLength           ds    2
ParseDigit            ds    2
ParseTimesTwo         ds    2
ClearSegments         ds    2
ClearPointer          ds    4

ConvertRecord
         ds    6

DNRBuffer
         ds    6

TCPStatusBuffer
         ds    22

TCPReadBuffer
         ds    14

HostBuffer
         ds    65

HostCString
         ds    65

PortBuffer
         ds    7

DefaultHostPString
         str   '192.168.5.235'

*-------------------------------------------------
* Parse buffers
*-------------------------------------------------

WaveHeader
         ds    12

ChunkHeader
         ds    8

FmtBuffer
         ds    16


*-------------------------------------------------
* EthernetStreamer console strings (C strings)
*-------------------------------------------------

BannerMsg
         asc   'ES M3R36A 22M512'
         dfb   $0D,$0A
         asc   'Tool225 raw TCP player'
         dfb   $0D,$0A
         asc   'ESC exit, C endpoint, R reset, D diag'
         dfb   $0D,$0A,$0D,$0A,$00
EndpointPromptMsg
         asc   'Choose an endpoint; ESC exits.'
         dfb   $0D,$0A,$00
HostPromptMsg
         asc   'Server IP or DNS name [192.168.5.235]: '
         dfb   $00
PortPromptMsg
         asc   'TCP port [22510]: '
         dfb   $00
ResolvingMsg
         asc   'Resolving host...'
         dfb   $0D,$0A,$00
ConnectingMsg
         asc   'Connecting with Marinetti...'
         dfb   $0D,$0A,$00
LoginMsg
         asc   '  TCPIPLogin...'
         dfb   $0D,$0A,$00
OpenTCPMsg
         asc   '  TCPIPOpenTCP...'
         dfb   $0D,$0A,$00
SynWaitMsg
         asc   '  Waiting for TCP SYN...'
         dfb   $0D,$0A,$00
ConnectedMsg
         asc   'TCP connection established.'
         dfb   $0D,$0A,$00
BufferingMsg
         asc   'Buffering 512K mono ring...'
         dfb   $0D,$0A,$00
PlayingMsg
         asc   'Playing: ESC exit, C endpoint, R reset, D diag.'
         dfb   $0D,$0A,$00
CRLFMsg
         dfb   $0D,$0A,$00
ResettingMsg
         asc   'Resetting Tool225 and rebuffering...'
         dfb   $0D,$0A,$00
AutoResettingMsg
         asc   'Automatic Tool225 recovery and rebuffer...'
         dfb   $0D,$0A,$00
PhaseResettingMsg
         asc   'DOC pair phase fault flags=$'
         dfb   $00
LowWaterResettingMsg
         asc   'Network low-water rebuffer at lead=$'
         dfb   $00
LowWaterReconnectMsg
         asc   'SpikeGuard: reopening TCP before rebuffer...'
         dfb   $0D,$0A,$00
PaddleStateInMsg
         asc   'Paddle in=$'
         dfb   $00
PaddleStateOutMsg
         asc   ' out=$'
         dfb   $00
PaddleStateEnterMsg
         asc   ' enter=$'
         dfb   $00
PaddleStateExitMsg
         asc   ' exit=$'
         dfb   $00
PaddleStateActiveMsg
         asc   ' act=$'
         dfb   $00
PaddleStateQueueMsg
         asc   ' q=$'
         dfb   $00
HiddenRefreshCountMsg
         asc   'Restream n=$'
         dfb   $00
HiddenRefreshOkayMsg
         asc   ' ok=$'
         dfb   $00
HiddenRefreshFailMsg
         asc   ' fail=$'
         dfb   $00
HiddenRefreshHardMsg
         asc   ' hard=$'
         dfb   $00
HiddenRefreshLeadMsg
         asc   ' lead=$'
         dfb   $00
HiddenRefreshArmedMsg
         asc   ' arm=$'
         dfb   $00
HiddenRefreshRearmMsg
         asc   ' rearm=$'
         dfb   $00
HiddenRefreshSocketMsg
         asc   ' sock=$'
         dfb   $00
HiddenRefreshReasonMsg
         asc   ' why=$'
         dfb   $00
ChangingEndpointMsg
         asc   'Playback stopped; choosing another endpoint.'
         dfb   $0D,$0A,$00
InputErrorLineMsg
         asc   'Input rejected: $'
         dfb   $00
ConnectionErrorLineMsg
         asc   'Connection attempt failed: $'
         dfb   $00
StopWarningMsg
         asc   'Tool225 stop warning; recovering: $'
         dfb   $00
ToolRestartErrorMsg
         asc   'Tool225 restart failed; exiting: $'
         dfb   $00
StreamEndedMsg
         asc   'TCP stream ended; returning to endpoint prompt: $'
         dfb   $00
DiagProducedMsg
         asc   'Diag P=$'
         dfb   $00
DiagRightMsg
         asc   ' R=$'
         dfb   $00
DiagLeftMsg
         asc   ' L=$'
         dfb   $00
DiagLeadMsg
         asc   '  lead=$'
         dfb   $00
DiagMinMsg
         asc   ' min=$'
         dfb   $00
DiagSkewMsg
         asc   ' skew=$'
         dfb   $00
DiagMaxMsg
         asc   ' max=$'
         dfb   $00
DiagTCPMsg
         asc   '  tcp=$'
         dfb   $00
DiagQueueMsg
         asc   ' queued=$'
         dfb   $00
DiagResetMsg
         asc   ' resets=$'
         dfb   $00
DiagAutoMsg
         asc   ' auto=$'
         dfb   $00
DiagLowWaterMsg
         asc   ' low=$'
         dfb   $00
DiagLowLeadMsg
         asc   ' at=$'
         dfb   $00
DiagDisconnectMsg
         asc   ' drops=$'
         dfb   $00
DiagNetBytesMsg
         asc   'Net bytes=$'
         dfb   $00
DiagReadCallsMsg
         asc   ' calls=$'
         dfb   $00
DiagPartialMsg
         asc   ' partial=$'
         dfb   $00
DiagNoDataMsg
         asc   'No-data=$'
         dfb   $00
DiagQueueMaxMsg
         asc   ' qmax=$'
         dfb   $00
DiagTicksMsg
         asc   ' ticks60=$'
         dfb   $00
DiagAverageMsg
         asc   'Avg/call=$'
         dfb   $00
DiagBytesPerSecondMsg
         asc   ' B/s=$'
         dfb   $00
DiagKbitPerSecondMsg
         asc   ' kbit/s=$'
         dfb   $00
DiagBurstMsg
         asc   'Pump cur=$'
         dfb   $00
DiagBurstLastMsg
         asc   ' last=$'
         dfb   $00
DiagBurstMaxMsg
         asc   ' max=$'
         dfb   $00
DiagQuantaMsg
         asc   ' quanta=$'
         dfb   $00
DiagRescueMsg
         asc   ' rescue=$'
         dfb   $00
DiagRescueQuantaMsg
         asc   ' rq=$'
         dfb   $00
DiagM3WhyMsg
         asc   '  why=$'
         dfb   $00
DiagM3Q0Msg
         asc   ' q0=$'
         dfb   $00
DiagM3Q1Msg
         asc   ' q1=$'
         dfb   $00
DiagM3BytesCurMsg
         asc   '  bytes cur=$'
         dfb   $00
DiagM3BytesLastMsg
         asc   ' last=$'
         dfb   $00
DiagM3BytesMaxMsg
         asc   ' max=$'
         dfb   $00
DiagM3FreeMsg
         asc   '  free=$'
         dfb   $00
DiagM3BlocksMsg
         asc   ' blocks=$'
         dfb   $00

DiagPhaseMsg
         asc   '  phase=$'
         dfb   $00
DiagPhaseNowMsg
         asc   ' now=$'
         dfb   $00
DiagPhaseFaultsMsg
         asc   ' faults=$'
         dfb   $00
DiagPhasePollsMsg
         asc   ' polls=$'
         dfb   $00
DiagPair01Msg
         asc   '  pair01=$'
         dfb   $00
DiagPair23Msg
         asc   ' pair23=$'
         dfb   $00
DiagStreak01Msg
         asc   '  s01=$'
         dfb   $00
DiagStreak23Msg
         asc   ' s23=$'
         dfb   $00
DiagPhaseMaxMsg
         asc   ' max=$'
         dfb   $00

*-------------------------------------------------
* Error strings
*-------------------------------------------------

NetworkStartErrMsg
         str   'Text console startup failed: $'

NetworkInputErrMsg
         str   'Invalid host or TCP port: $'

MarinettiErrMsg
         str   'Marinetti is unavailable or offline: $'

ResolveErrMsg
         str   'Host name resolution failed: $'

ConnectErrMsg
         str   'TCP connection failed: $'

ConnectTimeoutErrMsg
         str   'TCP connection timed out after 15 seconds: $'

NetworkReadErrMsg
         str   'Raw TCP stream read failed: $'

WaveErrMsg
         str   'Could not parse selected WAV: $'

SelectorStartErrMsg
         str   'Desktop tool startup failed: $'

SelectorShutErrMsg
         str   'Desktop tool shutdown failed: $'

MemoryErrMsg
         str   'Could not allocate WAV rings: $'

ReadErrMsg
         str   'WAV ring file read failed: $'

LoadErrMsg
         str   'Cannot load Tool 225: $'

StartErrMsg
         str   'Tool 225 startup failed: $'

InitErrMsg
         str   'Stream initialization failed: $'

StatusErrMsg
         str   'Ring status pointer failed: $'
PhaseStatusErrMsg
         str   'Tool 225 phase status pointer failed: $'

RightSubmitErrMsg
         str   'Right WAV ring submission failed: $'

LeftSubmitErrMsg
         str   'Left WAV ring submission failed: $'

StartPreparedErrMsg
         str   'Prepared WAV ring startup failed: $'

UnderrunErrMsg
         str   'Network/file ring underrun: $'

StopErrMsg
         str   'WAV ring shutdown failed: $'

ShutErrMsg
         str   'Tool 225 shutdown failed: $'

*-------------------------------------------------
* Foreground interleaved read and skip buffer.
*-------------------------------------------------

InterleaveBuffer
         ds    InterleaveMax

* END
