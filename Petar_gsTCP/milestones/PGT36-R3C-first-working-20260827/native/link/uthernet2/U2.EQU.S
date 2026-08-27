*=================================================
* Uthernet II / W5100 constants
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

U2SlotIO        equ   $C084           ; add slot * $10, use bank $E0
U2SlotMin       equ   1
U2SlotMax       equ   7

U2IDMMode       equ   0
U2IDMAddrHi     equ   1
U2IDMAddrLo     equ   2
U2IDMData       equ   3

W5MR            equ   $0000
W5GAR           equ   $0001
W5SUBR          equ   $0005
W5SHAR          equ   $0009
W5SIPR          equ   $000F
W5RTR           equ   $0017
W5RMSR          equ   $001A
W5TMSR          equ   $001B

W5MRIndirect    equ   $01
W5MRAutoInc     equ   $02
W5MRReset       equ   $80

W5S0MR          equ   $0400
W5S0CR          equ   $0401
W5S0IR          equ   $0402
W5S0SR          equ   $0403
W5S0TXFree      equ   $0420
W5S0TXWrite     equ   $0424
W5S0RXSize      equ   $0426
W5S0RXRead      equ   $0428

W5CmdOpen       equ   $01
W5CmdClose      equ   $10
W5CmdSend       equ   $20
W5CmdRecv       equ   $40

W5IRTimeout     equ   $08
W5IRSendOK      equ   $10
W5IRSendDone    equ   W5IRTimeout+W5IRSendOK

W5ModeMACRAW    equ   $04
W5SockMACRAW    equ   $42

W5MemoryShared  equ   $06             ; 4K, 2K, 1K, 1K
W5S0TXBase      equ   $4000
W5S0RXBase      equ   $6000
W5S0MemoryMask  equ   $0FFF
