 LST OFF
*=================================================
*
* I.LIB.S - Miscellaneous subroutines
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
* 2002.02.16 RJB - Initial coding and release as open source
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE ../Equates/BUILD.EQU
 USE ../Equates/I.EQU
 USE ../Equates/TCPIP.EQU

CHECKSUM16EVEN ENT ;XA = buff, Y = length in bytes (16 bit multiple)
 DBGMSG CHECKSUM16EVEN ;returns checksum big endian (flipped) in A
 PHXA
 TSC
 PHD
 TCD
 PEA 0 ;checksum
 CLC
]L1 DEY
 DEY
 LDA [1],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE ]L1
 PLA
 ADC #0
 XBA
 PLD
 PLXY
 RTL

* Calculate checksum odd and even (use CHECKSUM16 for faster even lengths)

CHECKSUM16 ENT ;XA = buff, Y = length in bytes (16 bit multiple)
 DBGMSG CHECKSUM16 ;returns checksum big endian (flipped) in A
 PHXA
 TSC
 PHD
 TCD
 PEA 0 ;checksum seed

 CPY #0
 BEQ :DONE ;anything to do?

 TYA
 ROR
 BCC :DATALOOP ;even?

 DEY ;odd!
 LDA [1],Y ;Add in pad byte
 XBA
 AND #$FF00
 STA 1,S ;save it

 TYA
 BEQ :DONE ;any more to do?

 CLC

:DATALOOP DEY
 DEY
 LDA [1],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE :DATALOOP
:DONE
 PLA
 ADC #0 ;add in final carry
 XBA ;endian
 PLD
 PLXY
 RTL

* NODPDEREF - Derefs handle in XA using the stack

NODPDEREF ENT
 DBGMSG NODPDEREF
 PHD
 PHA
 PHX
 TSC
 TCD
 LDA [1]
 TAX
 LDY #2
 LDA [1],Y
 PLY
 PLY
 PLD
 RTL

DELAYVBLS ENT ; Y = VBLs (60 = 1 second)
 DBGMSG DELAYVBLS
 PHP
 SEP $20
]L1 LDA >$E0C019
 BPL *-4
 LDA >$E0C019
 BMI *-4
 DEY
 BNE ]L1
 PLP
 RTL
 mx 0

GetTick ENT
 DBGMSG GetTick
 PHP
 SEI
 LDA >$E100DC
 STA 5,S
 LDA >$E100DC+2
 STA 5+2,S
 PLP
 RTL

 SAV I.LIB.L

 END
