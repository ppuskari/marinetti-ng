*=================================================
*
* I.TCP.DEBUG.S - TCP debugging code for Marinetti
*
* Copyright (C) 1997-2005 Richard Bennett-Forrest
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
* 2005.01.12 RJB - Initial release as open source
* 2006.10.01 AJR - Created I.TCP.DEBUG.S file from T.TCP (buffer full)
*
*=================================================

 do TCPDEBUG
DUMPLINE

 do TCPTOBUFFER.TCPTODISK

 JSR DUMPSTRING
 LDA #:CRSTR
 JSR DUMPSTRING
 RTS
:CRSTR DFB 1,13

 else

 pea ^*
 pha
 _WriteLine
 rts

 fin

DUMPCHAR

 do TCPTOBUFFER.TCPTODISK

 SEP $20
 STA :CHAR
 REP $20
 LDA #:THECHAR
 JSR DUMPSTRING
 RTS

:THECHAR DFB 1
:CHAR DS 1

 else

 PHA
 _WriteChar
 RTS

 fin

DUMPSTRING

 do TCPTOBUFFER

 STA :STRINGPTR+1
 LDA TCPDEBUGHANDLE
 ORA TCPDEBUGHANDLE+2
 BEQ :ALLOC
 CMP #$CCCC
 BNE :GOTIT
:ALLOC ~NewHandle #$10000;>MYID;#$C01C;#0
 PLXA TCPDEBUGHANDLE
 PHD
 PHA
 PHX
 TSC
 TCD
 LDA [1]
 TAX
 LDY #2
 LDA [1],Y
 STXA :TCPDEBUGPTR
 STXA 1
 LDY #0
 LDA #$0D0D
]L1 STA [1],Y
 INY
 INY
 BNE ]L1
 PLY
 PLY
 PLD
:GOTIT
 SEP $20
 LDA :TCPDEBUGPTR+2
 STA :MOD+1
 REP $20
 LDX :STRINGPTR+1
 INX
 LDY :TCPDEBUGPTR
:STRINGPTR LDA: 0
 AND #$FF
 BEQ :RTS
 PHA
 DEC
 PHB
:MOD MVN *,0
 PLB
 PLA
 CLC
 ADC :TCPDEBUGPTR
 STA :TCPDEBUGPTR
:RTS RTS

:TCPDEBUGPTR ADRL 0

 else

 do TCPTODISK

 STA :MOD+1
 INC
 STA :ADDRESS
:MOD LDA: 0
 AND #$FF
 STA :LENGTH
 JSL $E100A8
 DA $2001
 ADRL :CREATE
 JSL $E100A8
 DA $2010
 ADRL :OPEN
 BCS :SKIPREFS
 LDA :OPEN+2
 STA :WRITE+2
 STA FLUSH+2
 STA CLOSE+2
:SKIPREFS JSL $E100A8
 DA $2013
 ADRL :WRITE
:DONE RTS

:CREATE DA 4
 ADRL :PATHNAME
 DA $C3,4
 ADRL 0

:WRITE DA 4,0
:ADDRESS ADRL *
:LENGTH ADRL 0,0

:OPEN DA 3,0
 ADRL :PATHNAME
 DA %11

:PATHNAME STRL ':RAM5:TCP.trace'

FLUSH DA 1,0
CLOSE DA 1,0

 else

 pea ^*
 pha
 _WriteString
 rts

 fin

 fin

 fin
