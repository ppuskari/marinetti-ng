 LST OFF
*=================================================
*
* I.QLIB.S - Memory and queue managememnt subroutines
*
* Copyright (C) 1997-2002 Richard Bennett
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
* 2002.01.14 RJB - Initial release as open source
* 2002.09.01 RJBF - Added Handle bounds checking code to PtrToPtr
* 2002.10.20 AJR - Fix FindHandle usage
* 2002.11.11 AJR - AddToHandle will skip PtrToPtr if length = 0
* 2003.07.28 AJR - Correct bug with skipping nil handles
* 2005.07.17 AJR - Improve FindHandle error checking & general code style
* 2008.01.28 AJR - Improve error handling 1881079
* 2008.02.04 AJR - Fix pointer addition bug in CopyFromHandle 1885692
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE 4/MISC.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

 EXT MYID,GETTICK

* NEWQUEUE():masterhandle

NEWQUEUE ENT
 DBGMSG NEWQUEUE
 ~NewHandle #4;>MYID;#$0018;#0
 PLA
 STA QHANDLE
 STA 6,S
 PLA
 STA QHANDLE+2
 STA 6,S
 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2
 LDA #0
 STA [QPTR]
 STA [QPTR],Y
 RTL

* DESTROYQUEUE(masterhandle)

DESTROYQUEUE ENT
 DBGMSG DESTROYQUEUE
 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2
 LOCK QHANDLE
 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2
 LDY #2
:LOOP LDA [QPTR],Y
 BEQ :DONE
 PHY
 PHA
 DEY
 DEY
 LDA [QPTR],Y
 PHA
 _DisposeHandle
 PLY
 INY
 INY
 INY
 INY
 BRA :LOOP
:DONE UNLOCK QHANDLE
 PZL QHANDLE
 _DisposeHandle
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

* INSERTQUEUE(index,handle,master)
* OUT: Carry set if error during SetHandleSize, else clear

INSERTQUEUE ENT
 DBGMSG INSERTQUEUE(index,handle,master)
 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2

 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2
 LDA 12,S
 ASL
 ASL
 PHA ;index to the entry to insert

 LDY #8
 LDA [QHANDLE],Y
 PHA ;save a copy of old length
 CLC
 ADC #4
 PEA 0
 PHA
 PZL QHANDLE
 _SetHandleSize
 BCS :ERR

 LDA 1,S
 DEC
 CLC
 ADC [QHANDLE]
 TAX
 LDY #2
 LDA [QHANDLE],Y
 ADC #0
 PHXA ;from

 LDA 1,S
 CLC
 ADC #4
 TAX
 LDA 1+2,S
 ADC #0
 PHA ;to
 PHX

 LDA 9,S
 SEC
 SBC 11,S
 PEA 0
 PHA ;length

 JSL PtrToPtrNeg

 PLS ;old length

 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2

 PLY
 LDA 8,S
 STA [QPTR],Y
 INY
 INY
 LDA 8+2,S
 STA [QPTR],Y
 CLC

:ERR PHB
 PLA
 STA 9,S
 PLA
 STA 9,S
 PLS 3
 PLB
 RTL

* ADDTOQUEUE(handle,masterhandle)
* OUT: Carry set if error during SetHandleSize, else clear

ADDTOQUEUE ENT
 DBGMSG ADDTOQUEUE
 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2
 LDY #8
 LDA [QHANDLE],Y
 PHA ;save a copy
 CLC
 ADC #4
 PEA 0
 PHA
 PZL QHANDLE
 _SetHandleSize
 BCS :ERR

 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2

 PLY
 PHY
 LDA #0
 STA [QPTR],Y
 INY
 INY
 STA [QPTR],Y
 PLY
 DEY
 DEY
 DEY
 DEY
 LDA 8,S
 STA [QPTR],Y
 INY
 INY
 LDA 8+2,S
 STA [QPTR],Y
 CLC
:ERR PHB
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLA
 PLA
 PLB
 RTL

* QUEUESIZE(masterhandle):count:word

QUEUESIZE ENT
 DBGMSG QUEUESIZE
 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2
 LDY #8
 LDA [QHANDLE],Y
 LSR
 LSR
 DEC
 STA 8,S
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

FINDINQUEUE ENT ;Doesn't remove entry!
 DBGMSG FINDINQUEUE(entry,masterhandle):handle
 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2
 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2
 LDA 8,S
 ASL
 ASL
 LDY #8
 CMP [QHANDLE],Y
 BCC :OK
 LDA #0
 STA 10,S
 BRA :OUT
:OK TAY
 LDA [QPTR],Y
 STA 10,S
 INY
 INY
 LDA [QPTR],Y
:OUT STA 10+2,S
 PHB
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 RTL

GETNEXTINQUEUE ENT ;Removes entry!
 DBGMSG GETNEXTINQUEUE(masterhandle):handle

 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2

 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2

 LDA [QPTR] ;Get the first entry
 STA 8,S
 LDA [QPTR],Y
 STA 8+2,S
 ORA 8,S
 BEQ :OUT ;None

 LDY #8
 LDA [QHANDLE],Y
 PHA

 LDY #6
]L1 LDA [QPTR],Y
 TAX
 DEY
 DEY
 LDA [QPTR],Y
 PHA
 DEY
 DEY
 TXA
 STA [QPTR],Y
 DEY
 DEY
 PLA
 STA [QPTR],Y
 TYA
 CLC
 ADC #8
 TAY
 CMP 1,S
 BCC ]L1

 PLS

 PEA 0
 LDY #8
 LDA [QHANDLE],Y
 SEC
 SBC #4
 PHA
 PZL QHANDLE
 _SetHandleSize

:OUT PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

RIPFROMQUEUE ENT ;Removes entry!
 DBGMSG RIPFROMQUEUE(index,masterhandle):handle

 LDA 4,S
 STA QHANDLE
 LDA 4+2,S
 STA QHANDLE+2

 LDA [QHANDLE]
 STA QPTR
 LDY #2
 LDA [QHANDLE],Y
 STA QPTR+2

 LDA 8,S
 ASL
 ASL
 PHA ;offset to entry

 TAY
 LDA [QPTR],Y
 STA 12,S
 INY
 INY
 LDA [QPTR],Y
 STA 12+2,S

 PHS 2

 LDA QPTR
 CLC
 ADC 5,S
 TAX
 LDA QPTR+2
 ADC #0
 PHA
 PHX ;from

 TXA
 CLC
 ADC #4
 STA 5,S
 LDA 1+2,S
 ADC #0
 STA 5+2,S ;to

 LDY #8
 LDA [QHANDLE],Y
 SEC
 SBC #4
 SBC 9,S
 PEA 0
 PHA

 JSL PtrToPtr

 PLS

 PEA 0
 LDY #8
 LDA [QHANDLE],Y
 SEC
 SBC #4
 PHA
 PZL QHANDLE
 _SetHandleSize

:OUT PHB
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 RTL

*-------------------------------------------------
* Memory management subroutines
*-------------------------------------------------

* IN:  longword  POINTER
*      longword  LENGTH
*      longword  HANDLE TO ADD TO
* OUT: Carry set if error during SetHandleSize, else clear

AddToHandle ENT
 DBGMSG AddToH(ptr,len,hnd) ;DP-> 4=hnd 8=len 12=ptr
 LDA 8,S
 ORA 8+2,S
 CLC
 BEQ :NODATA
 TSC
 PHD
 TCD
 PHS 2
 PZL 4
 JSL GETHANDLESIZE
 LDA 1,S
 CLC
 ADC 8
 TAX
 LDA 1+2,S
 ADC 8+2
 PHXA
 PZL 4
 _SetHandleSize
 BCS :ERR
 PZL 12
 LDA [4]
 CLC
 ADC 5,S
 TAX
 LDY #2
 LDA [4],Y
 ADC 5+2,S
 PHXA
 PZL 8
 JSL PtrToPtr
 CLC

:ERR PLS 2
 PLD
:NODATA PHB
 PLA
 STA 11,S
 PLA
 STA 11,S
 PLS 4
 PLB
 RTL

* IN:  longword  FROM
*      longword  TO
*      longword  LENGTH

debugPtrToPtr = 1 ;Turn on handle trashing check code
debugBreak = 0 ;BRK = 1, SysFail = 0

PtrToPtr ENT

 DBGMSG PtrToPtr
 TSC
 PHD
 TCD

 do debugPtrToPtr

* Make some space

 PHS 2+2
 PHD
 TSC
 TCD

 DUM 1
 DS 2 ;D
:dbghandle ADRL 0
:dbgend ADRL 0
 DS 2+3 ;D+RTL
:dbglen ADRL 0
:dbgto ADRL 0
:dbgfrom ADRL 0
 DEND

* Make sure the LENGTH is completely within the original handle

 PHS 2 ;get the handle
 PZL :dbgfrom
 _FindHandle
 LDX #1
 BCSL :FINDHANDLEERR
 LDA 1,S
 ORA 1+2,S
 BEQL :NOHANDLE
 PLL :dbghandle

 LDA [:dbghandle] ;deref and calculate handle end+1
 LDY #8
 CLC
 ADC [:dbghandle],Y
 STA :dbgend
 LDY #2
 LDA [:dbghandle],Y
 LDY #8+2
 ADC [:dbghandle],Y
 STA :dbgend+2

 LDA :dbgfrom ;see if over
 CLC
 ADC :dbglen
 TAX
 LDA :dbgfrom+2
 ADC :dbglen+2
 CMP :dbgend+2
 BCC :FROMOK
 BEQ :FROMOK
 TXA
 CMP :dbgend
 BEQ :FROMOK
 LDX #2
 BCC :FROMOK

 do debugBreak
 BRL :DEBUGBRK
 else
 TXA
 PHA
* PEA $DEAD
 PHL #:FROMSTR4
 _SysFailMgr
:FROMSTR4 STR 'MAR:PtrToPtr found original handle with length outside handle boundaries $'
 fin
* BCS :FAIL
:FROMOK

* Make sure the LENGTH is completely within the destination handle

 PHS 2 ;get the handle
 PZL :dbgto
 _FindHandle
 LDX #3
 BCSL :FINDHANDLEERR
 LDA 1,S
 ORA 1+2,S
 BEQL :NOHANDLE
 PLL :dbghandle

 LDA [:dbghandle] ;deref and calculate handle end+1
 LDY #8
 CLC
 ADC [:dbghandle],Y
 STA :dbgend
 LDY #2
 LDA [:dbghandle],Y
 LDY #8+2
 ADC [:dbghandle],Y
 STA :dbgend+2

 LDA :dbgto ;see if over
 CLC
 ADC :dbglen
 TAX
 LDA :dbgto+2
 ADC :dbglen+2
 CMP :dbgend+2
 BEQL :LENOK
 BCCL :LENOK
 TXA
 CMP :dbgend
 BEQL :LENOK
 BCCL :LENOK
 LDX #4
:FAIL
 do debugBreak
 BRL :DEBUGBRK
 else
 TXA
 PHA
* PEA $DEAD
 PHL #:FROMSTR
 _SysFailMgr
:FROMSTR STR 'MAR:PtrToPtr tried to copy outside handle boundaries $'
 fin

:NOHANDLE
 do debugBreak
 BRL :DEBUGBRK
 else
 TXA
 PHA
* PEA $DEAD
 PHL #:FROMSTR2
 _SysFailMgr
:FROMSTR2 STR 'MAR:PtrToPtr: FindHandle returned no handle $'
 fin

:FINDHANDLEERR
 do debugBreak
 BRL :DEBUGBRK
 else
 PHA ;Toolbox Error code
 TXA ;Position in the code from where call failed
 CLC
 ADC #$2030 ;Hex to Asc + space
 STAL :POSFLAG
 PHL #:FROMSTR3
 _SysFailMgr
:FROMSTR3 DFB ]FROMSTR3LEN ;STR
 ASC 'MAR:PtrToPtr: FindHandle'
:POSFLAG HEX 0000
 ASC 'returned error $'
]FROMSTR3LEN = *-:FROMSTR3-1
 fin

:LENOK

* OK, clean up

 PLD
 PLS 2+2
 BRA :CONTINUE

:DEBUGBRK
 BRK 0
 PLD
 PLS 2+2
 JMP :DONE
 EMBED 'MAR:PtrToPtr'
 EMBED 'Bad copy sizes'
 EMBED 'X= source code'
 EMBED 'location indicator'

:CONTINUE

 fin

 LDA 4+2
 BEQ :LESS64K

:ABOVE64K LDY #0
:BANKLOOP LDA [12],Y
 STA [8],Y
 INY
 INY
 BNE :BANKLOOP
 INC 12+2
 INC 8+2
 DEC 4+2
 BNE :BANKLOOP

:LESS64K LDA 4
 BEQ :DONE ;None
 DEC
 BEQ :ONEBYTE
 DEC
 BEQ :TWOBYTES

* A straight copy loop of two bytes in 8 bit mode is 2 cycles slower than
* this MVN routine! But just to add speed, the custom branches above make
* things even faster!

 LDA #0 ;Make sure both blocks are inside banks
 CLC
 SBC 4
 CMP 8
 BCC :BYTES
 CMP 12
 BCC :BYTES
 LDA 12+2 ;To bank
 XBA
 ORA 8+2 ;From bank
 STA >:MOD+1
 LDX 12
 LDY 8
 LDA 4
 DEC
 PHB
:MOD MVN 0,0
 PLB
 BRA :DONE

:BYTES

 SEP $20 ;Have to do bytes, because it cross banks!
 LDY #0
:COPYLOOP LDA [12],Y
 STA [8],Y
 INY
 CPY 4
 BNE :COPYLOOP
 REP $20
 BRA :DONE

:TWOBYTES LDA [12]
 STA [8]
 BRA :DONE

:ONEBYTE SEP $20
 LDA [12]
 STA [8]
 REP $20

:DONE PLD
 PHB
 PLA
 STA 11,S
 PLA
 STA 11,S
 PLS 2+2
 PLB
 RTL

* IN:  longword  FROM (last location)
*      longword  TO (last location)
*      longword  LENGTH

PtrToPtrNeg ENT
 DBGMSG PtrToPtrNeg
 TSC
 PHD
 TCD
:LOOP LDA 4
 ORA 4+2
 BEQ :DONE
 SEP $20
 LDA [12]
 STA [8]
 REP $20
 DECR 12
 DECR 8
 DECR 4
 BRA :LOOP
:DONE PLD
 PHB
 PLA
 STA 11,S
 PLA
 STA 11,S
 PLS 4
 PLB
 RTL

* IN: longword - space for returned handle
*     longword - length
*     longword - master handle
*
* Deletes the read data...

 DUM 6
RFH_HANDLE ADRL 0
RFH_LENGTH ADRL 0
RFH_SPACE ADRL 0
 DEND

ReadFromHandle ENT
 DBGMSG ReadFromHandle(length,master):handle
 PHD
 TSC
 TCD

* Make sure length is OK... Adjust if not

 LDY #8+2 ;More than 64K left?
 LDA [RFH_HANDLE],Y
 CMP RFH_LENGTH+2
 BCC :BADLEN
 BNE :LENOK
 DEY
 DEY
 LDA [RFH_HANDLE],Y
 CMP RFH_LENGTH
 BCS :LENOK
:BADLEN LDY #8+2
 LDA [RFH_HANDLE],Y
 STA RFH_LENGTH+2
 DEY
 DEY
 LDA [RFH_HANDLE],Y
 STA RFH_LENGTH
:LENOK

* Make new handle to hold the data

 PHS 2
 PEI RFH_LENGTH+2
 PEI RFH_LENGTH
 LDY #6
 LDA [RFH_HANDLE],Y ;UserID
 PHA
 DEY
 DEY
 LDA [RFH_HANDLE],Y ;attributes
 AND #%0000_0000_0001_1100
 PHA
 PHS 2
 _NewHandle
 PLA
 STA RFH_SPACE
 PLA
 STA RFH_SPACE+2

* Copy the data to it

 LOCK RFH_HANDLE
 LOCK RFH_SPACE ;don't lock in _NewHandle, so we're in high mem

 LDY #2 ;From
 LDA [RFH_HANDLE],Y
 PHA
 LDA [RFH_HANDLE]
 PHA

 LDA [RFH_SPACE],Y ;To
 PHA
 LDA [RFH_SPACE]
 PHA

 PEI RFH_LENGTH+2 ;Length
 PEI RFH_LENGTH

 JSL PtrToPtr

 UNLOCK RFH_SPACE

* Created new handle - now delete old data

 LDY #8
 LDA [RFH_HANDLE],Y ;How much left over?
 SEC
 SBC RFH_LENGTH
 TAX
 INY
 INY
 LDA [RFH_HANDLE],Y
 SBC RFH_LENGTH+2
 BNE :HEAPS

 CPX #0
 BEQ :NONE ;none left - empty handle

:HEAPS PHA ;Save ultimate size for later
 PHX

 PHS 4 ;Space for copy pointers

 PHA
 PHX

 LDA [RFH_HANDLE] ;Set copy pointers
 STA 5,S
 CLC
 ADC RFH_LENGTH
 STA 9,S
 LDY #2
 LDA [RFH_HANDLE],Y
 STA 5+2,S
 ADC RFH_LENGTH+2
 STA 9+2,S

 JSL PtrToPtr

 BRA :DONECOPY ;length is on stack

:NONE PHA ;zero
 PHX

:DONECOPY PZL RFH_HANDLE

 UNLOCK RFH_HANDLE

 _SetHandleSize

:OUT PLD

 PHB
 PLA
 STA 7,S
 PLA
 STA 7,S
 PLS 2
 PLB
 RTL

* IN: longword - space for returned handle
*     longword - offset
*         word - length
*     longword - master handle

 DUM 6
CFH_HANDLE ADRL 0
CFH_LENGTH DA 0
CFH_OFFSET ADRL 0
CFH_SPACE ADRL 0
 DEND

CopyFromHandle ENT
 DBGMSG CopyFromHandle
 PHD
 TSC
 TCD

* Zero length?

 LDA CFH_LENGTH
 ORA CFH_LENGTH+2
 BEQL :OUT

* Make sure length is inside handle... Adjust if not

 LDA CFH_OFFSET
 CLC
 ADC CFH_LENGTH
 TAX
 LDA CFH_OFFSET+2
 ADC #0
 PHA
 PHX

 LDY #8+2
 LDA 1+2,S
 CMP [CFH_HANDLE],Y
 BCC :LENOK
 BNE :CHOPIT
 DEY
 DEY
 LDA 1,S
 CMP [CFH_HANDLE],Y
 BCC :LENOK
 BEQ :LENOK

:CHOPIT ;Well, is the offset inside then?

 LDY #8+2
 LDA CFH_OFFSET+2
 CMP [CFH_HANDLE],Y
 BCC :OFFISIN
 BNE :NULLHANDLE
 DEY
 DEY
 LDA CFH_OFFSET
 CMP [CFH_HANDLE],Y
 BCC :OFFISIN

:NULLHANDLE PEA 0 ;space already on stack
 PEA 0
 LDY #6
 LDA [CFH_HANDLE],Y ;UserID
 PHA
 PEA 0
 PHS 2
 _NewHandle
 PLA
 STA CFH_SPACE
 PLA
 STA CFH_SPACE+2
 BRA :OUT

:OFFISIN LDY #8
 LDA [CFH_HANDLE],Y
 SEC
 SBC CFH_OFFSET
 STA CFH_LENGTH

:LENOK

* Make new handle to hold the data

 PEA 0 ;space already on stack
 PEI CFH_LENGTH
 LDY #6
 LDA [CFH_HANDLE],Y ;UserID
 PHA
 DEY
 DEY
 LDA [CFH_HANDLE],Y ;attributes
 AND #%0000_0000_0001_1100
 PHA
 PHS 2
 _NewHandle
 PLA
 STA CFH_SPACE
 PLA
 STA CFH_SPACE+2

* Copy the data to it

 LOCK CFH_HANDLE
 LOCK CFH_SPACE ;don't lock in _NewHandle, so we're in high mem

 LDA [CFH_HANDLE] ;From
 CLC
 ADC CFH_OFFSET
 TAX
 LDY #2
 LDA [CFH_HANDLE],Y
 ADC CFH_OFFSET+2
 PHA
 PHX

 LDA [CFH_SPACE],Y ;To
 PHA
 LDA [CFH_SPACE]
 PHA

 PEA 0 ;Length
 PEI CFH_LENGTH

 JSL PtrToPtr

 UNLOCK CFH_SPACE
 UNLOCK CFH_HANDLE

:OUT PLD

 PHB
 PLA
 STA 9,S
 PLA
 STA 9,S
 PLA
 PLA
 PLA
 PLB
 RTL

GETHANDLESIZE ENT
 DBGMSG GETHANDLESIZE(handle):size
 PHD
 TSC
 TCD
 LDY #8
 LDA [6],Y
 STA 10
 INY
 INY
 LDA [6],Y
 STA 10+2
 PLD
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

* IN: longword - data pointer
*     longword - length
*     longword - offset
*     longword - handle
* OUT: Carry set if error during SetHandleSize, else clear

 DUM 6
INS_HANDLE ADRL 0
INS_OFFSET ADRL 0
INS_LENGTH ADRL 0
INS_BUFFER ADRL 0
 DEND

InsertDataIntoHandle ENT
 DBGMSG InsertDataIntoHandle
 PHD
 TSC
 TCD

* Make sure offset is OK

 LDY #8+2
 LDA INS_OFFSET+2
 CMP [INS_HANDLE],Y
 BCC :OFFOK
 BNE :BADOFF
 DEY
 DEY
 LDA INS_OFFSET
 CMP [INS_HANDLE],Y
 BCC :OFFOK
 BEQ :OFFOK

:BADOFF ;Offset is off the end of the handle - make EOF

 LDY #8
 LDA [INS_HANDLE],Y
 STA INS_OFFSET
 INY
 INY
 LDA [INS_HANDLE],Y
 STA INS_OFFSET+2

:OFFOK

* Now extend the handle by the length of the new data

 PHS 2
 PZL INS_HANDLE
 JSL GETHANDLESIZE
 LDA 1,S
 CLC
 ADC INS_LENGTH
 STA 1,S
 LDA 1+2,S
 ADC INS_LENGTH+2
 STA 1+2,S
 PZL INS_HANDLE
 _SetHandleSize
 BCS :ERR

* Now shift the data to make room

 LOCK INS_HANDLE

 LDA [INS_HANDLE] ;From: the offset
 CLC
 ADC INS_OFFSET
 TAX
 LDY #2
 LDA [INS_HANDLE],Y
 ADC INS_OFFSET+2
 PHA
 PHX

 LDA 1,S ;To: the offset + the length
 CLC
 ADC INS_LENGTH
 TAX
 LDA 3,S
 ADC INS_LENGTH+2
 PHA
 PHX

 PZL INS_LENGTH ;Length: the inserted length

 JSL PtrToPtr

* Now copy in the new data

 PZL INS_BUFFER ;From: the buffer

 LDA [INS_HANDLE] ;To: the offset
 CLC
 ADC INS_OFFSET
 TAX
 LDY #2
 LDA [INS_HANDLE],Y
 ADC INS_OFFSET+2
 PHA
 PHX

 PZL INS_LENGTH ;Length: the inserted length

 JSL PtrToPtr

 UNLOCK INS_HANDLE
 CLC
* Done.

:ERR PLD

 PHB
 PLA
 STA 15,S
 PLA
 STA 15,S
 PLS 6
 PLB
 RTL

*-------------------------------------------------
* NEWTIMER - A = increment from now. Exit XA is new timer.
*-------------------------------------------------

NEWTIMER ENT
 DBGMSG NEWTIMER
 PHA
 PHS 2
 JSL GETTICK
 PLA
 CLC
 ADC 3,S
 TAX
 PLA
 ADC #0
 PLY
 RTL

*-------------------------------------------------
* TIMERVALID? XA is timer value. Exit carry clear = valid, set = expired.
*-------------------------------------------------

TIMERVALID? ENT
 DBGMSG TIMERVALID?
 PHA
 PHX
 PHS 2
 JSL GETTICK
 PLA
 SEC
 SBC 3,S
 PLA
 SBC 3,S
 PLS 2
 RTL

 SAV I.QLIB.L


 END
