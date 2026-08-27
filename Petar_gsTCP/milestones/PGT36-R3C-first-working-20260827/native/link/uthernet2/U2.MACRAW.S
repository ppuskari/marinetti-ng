*=================================================
*
* Uthernet II W5100 MACRAW lifecycle and record access
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*
*=================================================

* A low byte = command.  Wait until S0_CR clears, with a bounded software
* timeout.  This is a control-path routine; frame loops access the data port
* directly and do not pay these JSL costs.

PGTU2Command    ent
                rep   #$30
                and   #$00FF
                ldx   #W5S0CR
                jsl   PGTU2Write8
                lda   #$FFFF
                sta   PGTu2Timeout
PGTU2CmdWait    ldx   #W5S0CR
                jsl   PGTU2Read8
                beq   PGTU2CmdDone
                dec   PGTu2Timeout
                bne   PGTU2CmdWait
                sec
                rtl
PGTU2CmdDone    clc
                rtl

* Start socket 0 in MACRAW mode.  The caller must have selected/probed the
* slot and supplied a valid MAC address before DHCP begins.  No chip reset is
* performed, so a shared convention MAC address is preserved.

PGTU2StartRaw   ent
                rep   #$30
                lda   #W5CmdClose
                jsl   PGTU2Command
                bcs   PGTU2StartFail

                lda   #W5MemoryShared
                ldx   #W5RMSR
                jsl   PGTU2Write8
                lda   #W5MemoryShared
                ldx   #W5TMSR
                jsl   PGTU2Write8

                lda   #W5ModeMACRAW
                ldx   #W5S0MR
                jsl   PGTU2Write8
                lda   #W5CmdOpen
                jsl   PGTU2Command
                bcs   PGTU2StartFail

                lda   #$FFFF
                sta   PGTu2Timeout
PGTU2StartWait  ldx   #W5S0SR
                jsl   PGTU2Read8
                cmp   #W5SockMACRAW
                beq   PGTU2StartOK
                dec   PGTu2Timeout
                bne   PGTU2StartWait
PGTU2StartFail  lda   #W5CmdClose
                jsl   PGTU2Command
                sec
                rtl
PGTU2StartOK    clc
                rtl

PGTU2StopRaw    ent
                rep   #$30
                lda   #W5CmdClose
                jsl   PGTU2Command
                rtl

* Begin the next MACRAW record.
*
* Success: carry clear, A = Ethernet frame length, PGTu2RXPtr is the logical
* pointer of the first Ethernet byte, and the W5100 data register is positioned
* there.  Failure/no complete record: carry set, A = 0.
*
* The W5100's two-byte MACRAW length includes the prefix itself.  The prefix is
* read with an explicit 4 KiB boundary check because auto-increment wraps only
* at the end of the entire 8 KiB RX memory, not socket 0's assigned region.

PGTU2BeginRX    ent
                rep   #$30
                ldx   #W5S0RXSize
                jsl   PGTU2Read16
                sta   PGTu2RXAvail
                cmp   #2
                bcc   PGTU2NoRecord

                ldx   #W5S0RXRead
                jsl   PGTU2Read16
                sta   PGTu2RXPtr
                and   #W5S0MemoryMask
                clc
                adc   #W5S0RXBase
                tax
                jsl   PGTU2SetAddress

                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                sta   PGTu2RecordLen+1
                rep   #$20
                inc   PGTu2RXPtr
                lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                bne   PGTU2PrefixLow
                ldx   #W5S0RXBase
                jsl   PGTU2SetAddress
PGTU2PrefixLow  sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                sta   PGTu2RecordLen
                rep   #$20
                inc   PGTu2RXPtr
                lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                bne   PGTU2PrefixReady
                ldx   #W5S0RXBase
                jsl   PGTU2SetAddress
PGTU2PrefixReady

* Minimum record is prefix plus a 14-byte Ethernet header.  VLAN frames are
* outside P0, and a normal 1500-byte Ethernet payload yields at most 1516 bytes
* including prefix.

                lda   PGTu2RecordLen
                cmp   #16
                bcc   PGTU2BadRecord
                cmp   #1517
                bcs   PGTU2BadRecord
                cmp   PGTu2RXAvail
                beq   PGTU2RecordReady
                bcc   PGTU2RecordReady
                bra   PGTU2NoRecord

PGTU2RecordReady sec
                sbc   #2
                sta   PGTu2FrameLen
                sta   PGTu2Remain
                clc
                rtl

PGTU2BadRecord  lda   #W5CmdClose
                jsl   PGTU2Command
PGTU2NoRecord   lda   #0
                sec
                rtl

* Read one byte from the current frame.  Success returns a zero-extended byte
* in A with carry clear.  The W5100 auto-increment pointer is explicitly moved
* back to socket 0's RX base whenever the assigned 4 KiB boundary is crossed.

PGTU2ReadFrame8 ent
                rep   #$30
                lda   PGTu2Remain
                beq   PGTU2FrameEmpty
                sep   #$20
                ldy   #U2IDMData
                lda   [PGTu2IO],y
                sta   PGTu2Value
                rep   #$20
                inc   PGTu2RXPtr
                dec   PGTu2Remain
                lda   PGTu2Remain
                beq   PGTU2FrameByteOK
                lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                bne   PGTU2FrameByteOK
                inc   PGTu2WrapCount
                ldx   #W5S0RXBase
                jsl   PGTU2SetAddress
PGTU2FrameByteOK lda  PGTu2Value
                and   #$00FF
                clc
                rtl
PGTU2FrameEmpty lda   #0
                sec
                rtl

* Copy a contiguous span from the current MACRAW frame to IIgs memory.
*
* Input:
*   PGTu2BulkPtr = 24-bit destination
*   PGTu2BulkLen = byte count, no greater than PGTu2Remain
*
* The inner loop uses Y only as the destination index and PGTu2Data points
* directly at the auto-increment data port.  Socket 0's 4 KiB boundary is
* handled outside the byte loop.  Success returns carry clear and the bulk
* pointer advanced; an over-read request returns carry set without copying.

PGTU2CopyRXSpan ent
                rep   #$30
                stz   PGTu2BulkCopied
                lda   PGTu2BulkLen
                beq   PGTU2BulkDone
                cmp   PGTu2Remain
                bcc   PGTU2BulkStart
                beq   PGTU2BulkStart
                sec
                rtl

PGTU2BulkStart  lda   PGTu2RXPtr
                and   #W5S0MemoryMask
                eor   #W5S0MemoryMask
                inc
                sta   PGTu2BulkChunk
                cmp   PGTu2BulkLen
                bcc   PGTU2BulkChunkOK
                lda   PGTu2BulkLen
                sta   PGTu2BulkChunk
PGTU2BulkChunkOK
                ldx   PGTu2BulkChunk
                ldy   #0
                sep   #$20
PGTU2BulkLoop   lda   [PGTu2Data]
                sta   [PGTu2BulkPtr],y
                iny
                dex
                bne   PGTU2BulkLoop
                rep   #$20

                lda   PGTu2BulkPtr
                clc
                adc   PGTu2BulkChunk
                sta   PGTu2BulkPtr
                bcc   PGTU2BulkPtrOK
                inc   PGTu2BulkPtr+2
PGTU2BulkPtrOK  lda   PGTu2RXPtr
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
                bne   PGTU2BulkMore
                lda   PGTu2Remain
                beq   PGTU2BulkMore
                inc   PGTu2WrapCount
                ldx   #W5S0RXBase
                jsl   PGTU2SetAddress
PGTU2BulkMore   lda   PGTu2BulkLen
                bne   PGTU2BulkStart
PGTU2BulkDone   clc
                rtl

* Commit/release the current record after the frame dispatcher has consumed
* or skipped it.  This advances the logical pointer by any unread Ethernet
* bytes and issues exactly one RECV command.

PGTU2ReleaseRX  ent
                rep   #$30
                lda   PGTu2RXPtr
                clc
                adc   PGTu2Remain
                ldx   #W5S0RXRead
                jsl   PGTU2Write16
                stz   PGTu2Remain
                lda   #W5CmdRecv
                jsl   PGTU2Command
                rtl

* Send one complete Ethernet frame through socket 0 MACRAW.
*
* Input (current direct page):
*   PGTu2TXPtr = 24-bit pointer to the Ethernet destination MAC
*   PGTu2TXLen = frame bytes (14..1514)
*
* Success returns carry clear after SEND_OK.  Invalid length, unavailable TX
* space, command timeout or the W5100 TIMEOUT interrupt returns carry set.
* Both free-space and send completion waits are bounded so missing hardware or
* a disconnected cable cannot hang the IIgs.

PGTU2SendFrame  ent
                rep   #$30
                lda   PGTu2TXLen
                cmp   #14
                bcs   PGTU2SendMinOK
                brl   PGTU2SendFail
PGTU2SendMinOK  cmp   #1515
                bcc   PGTU2SendLengthOK
                brl   PGTU2SendFail
PGTU2SendLengthOK

                lda   #$FFFF
                sta   PGTu2Timeout
PGTU2SendFree   ldx   #W5S0TXFree
                jsl   PGTU2Read16
                cmp   PGTu2TXLen
                bcs   PGTU2SendSpace
                dec   PGTu2Timeout
                bne   PGTU2SendFree
                brl   PGTU2SendFail

PGTU2SendSpace  ldx   #W5S0TXWrite
                jsl   PGTU2Read16
                sta   PGTu2TXWrite
                and   #W5S0MemoryMask
                clc
                adc   #W5S0TXBase
                tax
                jsl   PGTU2SetAddress

                lda   PGTu2TXLen
                sta   PGTu2TXRemain
                ldy   #0
PGTU2SendCopy   sep   #$20
                lda   [PGTu2TXPtr],y
                phy
                pha
                ldy   #U2IDMData
                pla
                sta   [PGTu2IO],y
                ply
                rep   #$20
                iny
                inc   PGTu2TXWrite
                dec   PGTu2TXRemain
                beq   PGTU2SendCopied
                lda   PGTu2TXWrite
                and   #W5S0MemoryMask
                bne   PGTU2SendCopy
                inc   PGTu2TXWrapCount
                ldx   #W5S0TXBase
                jsl   PGTU2SetAddress
                bra   PGTU2SendCopy

PGTU2SendCopied lda   PGTu2TXWrite
                ldx   #W5S0TXWrite
                jsl   PGTU2Write16
                lda   #W5IRSendDone
                ldx   #W5S0IR
                jsl   PGTU2Write8
                lda   #W5CmdSend
                jsl   PGTU2Command
                bcs   PGTU2SendFail

                lda   #$FFFF
                sta   PGTu2Timeout
PGTU2SendWait   ldx   #W5S0IR
                jsl   PGTU2Read8
                bit   #W5IRTimeout
                bne   PGTU2SendTimedOut
                bit   #W5IRSendOK
                bne   PGTU2SendComplete
                dec   PGTu2Timeout
                bne   PGTU2SendWait
                bra   PGTU2SendFail

PGTU2SendComplete lda #W5IRSendOK
                ldx   #W5S0IR
                jsl   PGTU2Write8
                clc
                rtl
PGTU2SendTimedOut lda #W5IRTimeout
                ldx   #W5S0IR
                jsl   PGTU2Write8
PGTU2SendFail   sec
                rtl
