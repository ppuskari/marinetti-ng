*=================================================
*
* Petar_gsTCP internal direct-page ABI
*
* SPDX-License-Identifier: LGPL-2.1-or-later
*
*=================================================

* Checksum workspace.  PGTChecksum clobbers A/X/Y and requires 16-bit
* accumulator and index registers on entry and return.

PGTcsPtr        equ   $00             ; 24-bit source pointer (4-byte slot)
PGTcsLen        equ   $04             ; byte length
PGTcsSumLo      equ   $06             ; accumulator low word
PGTcsSumHi      equ   $08             ; accumulator carry word
PGTcsOddByte    equ   $0A             ; pending network high byte
PGTcsOddValid   equ   $0B             ; pending-byte valid/current byte

* Slot data-port pointer used by production bulk loops.  Keeping a pointer to
* the data register itself leaves Y available for the destination index and
* removes the save/change/restore sequence paid by the diagnostic byte API.

PGTu2Data       equ   $0C             ; 24-bit $E0/C0n7 data-port pointer

* Uthernet II workspace.

PGTu2IO         equ   $10             ; 24-bit slot I/O pointer
PGTu2Reg        equ   $14             ; W5100 register address
PGTu2Value      equ   $16             ; temporary value
PGTu2Value2     equ   $18             ; stable-read comparison
PGTu2Timeout    equ   $1A             ; bounded command/startup wait
PGTu2RXAvail    equ   $1C             ; bytes currently reported by W5100
PGTu2RXPtr      equ   $1E             ; logical socket RX pointer
PGTu2RecordLen  equ   $20             ; MACRAW record bytes including prefix
PGTu2FrameLen   equ   $22             ; Ethernet frame bytes
PGTu2Remain     equ   $24             ; unread bytes in current frame
PGTu2WrapCount  equ   $26             ; socket 0 RX boundary crossings
PGTu2TXPtr      equ   $28             ; 24-bit frame source pointer (4-byte slot)
PGTu2TXLen      equ   $2C             ; Ethernet frame byte count
PGTu2TXWrite    equ   $2E             ; logical socket TX write pointer
PGTu2TXRemain   equ   $30             ; bytes left to copy to the W5100
PGTu2TXWrapCount equ  $32             ; socket 0 TX boundary crossings
PGTu2BulkPtr    equ   $34             ; 24-bit contiguous destination pointer
PGTu2BulkLen    equ   $38             ; requested/current bytes to copy
PGTu2BulkCopied equ   $3A             ; bytes copied by the bulk operation
PGTu2BulkChunk  equ   $3C             ; current socket-boundary chunk

* Reserved for the core hot path.  Protocol modules must not place private
* direct-page variables below PGTdpPrivate.

PGTdpPrivate    equ   $40
