 LST OFF
 REL
 MX %00 ;Long X, A
 XC
 XC
*=================================================
*
* CRYPTO.TOOL.S - Crypto tool set
*
* Copyright (C) 2002 by Andrew Roughan
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*
*=================================================
*
* Changelog:
* 2002-04-03 AJR - Initial Implementation of tool (desCipher)
* 2002-07-02 AJR - Implemented desAddParity for MS-CHAP
* 2002-08-25 AJR - Release version 1.0 Tool129
*
*=================================================

 USE 4/LOCATOR.MACS
 USE DESP.DP

false = $0000
true = $8000

Tool MAC
 LDX #]1 ; load tool call #
 JSL $E10000 ; go to dispatcher
 <<<
ToBusyStrip EQU $E10180 ;X = error, Y = bytes to strip
ToStrip EQU $E10184 ;X = error, Y = bytes to strip
INCBUSY EQU $E10064
DECBUSY EQU $E10068

CryptoToolNum EQU 129

*-------------------------------------------------
* DES Tool Jump Table
*-------------------------------------------------

JUMPSTART
 ADRL JUMPEND-JUMPSTART/4
 ADRL MyBootInit-1
 ADRL MyStartup-1
 ADRL MyShutDown-1
 ADRL MyVersion-1
 ADRL MyReset-1
 ADRL MyStatus-1
 ADRL NotImp-1
 ADRL NotImp-1
 ADRL DESCipher-1
 ADRL DESAddParity-1
JUMPEND


NotImp
 TXA
 XBA ;Move tool set # to MSB for error
 ORA #$00FF ;$FF in LSB as error code
 SEC
 RTL

*-------------------------------------------------
*MyVersion
*-------------------------------------------------

* MyVersionStack
VerRTL1 EQU 1
VerRTL2 EQU VerRTL1+3
VerNum EQU VerRTL2+3

MyVersion
 LDA #$100 ;Version 1.0
 STA VerNum,S
MyBootInit
MyReset
 LDA #0
 CLC
 RTL

*-------------------------------------------------
* MyStatus
*-------------------------------------------------

* MyStatusStack
StaRTL1 EQU 1
StaRTL2 EQU StaRTL1+3
ActiveFlag EQU StaRTL2+3 ;Indication of whether tool is active or not

MyStatus
 LDY #true ;Assume that we are active
* Technote #73 says that on entry WAP value is in YA
* and that If WAP is non zero then we are active
* Since we have setup our WAP to be a DP, then Y=0 and A!=0
 CMP #0
 BNE :Active
 LDY #false
:Active TYA
 STA ActiveFlag,S
 LDA #0
 CLC
 RTL

*-------------------------------------------------
* MyStartup
*-------------------------------------------------

* MyStartupStack
SupRTL1 EQU 1
SupRTL2 EQU SupRTL1+3
ZPToUse EQU SupRTL2+3 ;Bank 0 starting address for DP space

* SetWAPStack
%ToolNum EQU 5

MyStartup
 LDA ZPToUse,S ;Get callers value for DP
 TAY
 PEA $0000 ;System tool set
% PHX ;Tool set number and function number in X
 TXA
 AND #$00FF
 PHA
 PEA 0
 PHY ;DP
% LDA ToolNum,S
% AND #$00FF
% STA ToolNum,S
 _SetWAP ;Set our work area pointer

 LDA SupRTL2+1,S
 STA ZPToUse,S
 LDA SupRTL1+2,S
 STA ZPToUse-2,S
 LDA SupRTL1,S
 STA SupRTL1+2,S
 PLA
 LDA #0
 CLC
 RTL

*-------------------------------------------------
* MyShutdown
*-------------------------------------------------

MyShutdown
 CMP #0
 BEQ :OUT
 PEA $0000 ;System tool set
 TXA ;Tool set number and function number in X
 AND #$00FF ;Eliminate function number
 PHA ;Tell SetWAP which entry to clear
 PEA 0 ;zero the entry
 PEA 0
 _SetWAP

:OUT LDA #0
 CLC
 RTL

*-------------------------------------------------
* DESCipher
*-------------------------------------------------

* DESCipherStack
DESRTL1 EQU 1
DESRTL2 EQU DESRTL1+3
DESMode EQU DESRTL2+3 ;Encryption or Decryption mode (enc=0,dec=1)
Plaintext EQU DESMode+2 ;Pointer to input (8 bytes)
DESKey EQU Plaintext+4 ;Pointer to key (8 bytes)
Ciphertext EQU DESKey+4 ;Pointer to output (8 bytes)

DESCipher
 JSL INCBUSY
 PHD ;Save User's DP and Bank
 PHB
 PHK ;Setup our Bank
 PLB

* Technote #73 says that on entry WAP value is in YA
* In MyStartup we saved our DP into WAP
* Therefore our DP is in A

 TCD ;Switch in our DP

 LDA DESMode+3,S
 STA MODE
 LDA Plaintext+3,S
 STA TEMPDP
 LDA Plaintext+2+3,S
 STA TEMPDP+2
 LDA DESKey+3,S
 STA TEMPDP2
 LDA DESKey+2+3,S
 STA TEMPDP2+2

 LDY #6
]LOOP TYX
 LDA [TEMPDP],Y
 STA PTL,X
 LDA [TEMPDP2],Y
 STA KEYSTART,X
 DEY
 DEY
 BPL ]LOOP

 SEP #$30
 JSR INIT
 JSR DES
 REP #$30

 LDA Ciphertext+3,S
 STA TEMPDP
 LDA Ciphertext+2+3,S
 STA TEMPDP+2
 LDY #6
]LOOP TYX
 LDA PTL,X ;Copy result
 STA [TEMPDP],Y ; into output buffer
 DEY
 DEY
 BPL ]LOOP

 LDX #0 ;No error
 LDY #14 ;Remove all parms from stack

 PLB
 PLD ;Restore User's DP
 JML ToBusyStrip

*-------------------------------------------------
* DESAddParity
*
* During implementation of MS-CHAP from RFC2433 it
* became apparent that a routine to add Parity
* bits to a 56 bit key would be necessary.
*
* Calculating Odd Parity may not be necessary if it is ignored.
* However, as it was not much more work, I did it anyway.
*
* The following comments come directly from RFC2433:
*
* Note that the DES algorithm takes as input a 64-bit
* stream where the 8th, 16th, 24th, etc.  bits are
* parity bits ignored by the encrypting algorithm.
* Unless you write your own DES to accept 56-bit input
* without parity, you will need to insert the parity bits
* yourself.
*
* DES uses 56-bit keys, expanded to 64 bits by the insertion of parity
* bits.  After the parity of the key has been fixed, every
* eighth bit is a parity bit and the number of bits that are set (1)
* in each octet is odd; i.e., odd parity.  Note that many DES engines
* do not check parity, however, simply stripping the parity bits.
*
*-------------------------------------------------

*DESAddParityStack
AddRTL1 EQU 1
AddRTL2 EQU AddRTL1+3
PlainKey EQU AddRTL2+3 ;Pointer to input (7 bytes)
PaddedKey EQU PlainKey+4 ;Pointer to output (8 bytes)

DESAddParity
 JSL INCBUSY
 PHD ;Save User's DP and Bank
 PHB
 PHK ;Setup our Bank
 PLB

* Technote #73 says that on entry WAP value is in YA
* In MyStartup we saved our DP into WAP
* Therefore our DP is in A

 TCD ;Switch in our DP

 LDA PlainKey+3,S
 STA TEMPDP
 LDA PlainKey+2+3,S
 STA TEMPDP+2
 LDA PaddedKey+3,S
 STA TEMPDP2
 LDA PaddedKey+2+3,S
 STA TEMPDP2+2

* Move input to our DP for processing

 LDY #6
]LOOP TYX
 LDA [TEMPDP],Y
 STA PTL,X
 DEY
 DEY
 BPL ]LOOP

 MX %11 ;Short XA
 SEP #$30 ;Short M, X, Y

* Initialise counters
 LDY #8
 STY LOOPCT ;Number of output bytes to store on stack
 DEY ;7
 STY BCOUNT ;Number of bits to process before adding parity

 LDA #0 ;Intermediary data held in A
 STA HOLD ;Number of 1 bits in input

* Iterate through the input and add parity as we go
* Throughout this loop, X holds valid index into PTL
* A holds the result of Adding Parity
* Y is temporary storage
* As an output word is finished, it is pushed onto the stack
* When all processing is complete, the results are pulled from stack & stored

 TAX ;X starts at 0 and increments to LOOPCT-1 (7)

]LOOP2 LDY #8
 STY WCOUNT ;Number of bits to process per byte of input

]LOOP ASL PTL,X ;Move bit 7 into carry, (and 0 into bit 0)
 BCC :ROL
 INC HOLD ;Count number of 1 bits
:ROL ROL ;Move carry into bit 0, (and bit 7 into carry)
* count parity bit
 DEC BCOUNT
 BNE :KeepGoing
* Add Parity bit to output
 LSR HOLD ;even parity=carry clear, else set
 BCC :SET ;invert the carry flag
 CLC
 BRA :ROLPARITY
:SET SEC
:ROLPARITY ROL ;make result odd parity
* reset parity bit counter
 LDY #7
 STY BCOUNT ;Number of bits to process before adding parity
 LDY #0
 STY HOLD
* store output and set up for the next one
 PHA ;Place output bytes on stack (8 bytes)
 DEC LOOPCT ;Keep track of how many we've done
 BEQ :EXIT
 TYA ;Clear output A=(Y=0)
:KeepGoing
* count input bit
 DEC WCOUNT
* completed an input byte?
 BNE ]LOOP
* set up for the next input byte
 INX
 BRA ]LOOP2

:EXIT
* Save the result in the output pointer provided by user
 REP #$30 ;Long A, X, Y
 MX %00 ;Long XA

 LDY #6
]POPLOOP PLA ;Remove output bytes from stack (4x2=8)
 XBA ;Put in correct order for 16 bit store
* STA KEYSTART,Y
 STA [TEMPDP2],Y
 DEY
 DEY
 BPL ]POPLOOP

 LDX #0 ;No error
 LDY #8 ;Remove all parms from stack

 PLB
 PLD ;Restore User's DP
 JML ToBusyStrip

 USE DESP

 SAV CRYPTO.TOOL.L

 END
