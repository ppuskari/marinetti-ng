 LST OFF
*=================================================
*
* I.UDP.S - UDP manager
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
* 2005.07.10 RJB - Initial release as open source
* 2012.03.25 AJR - Fixed stack imbalance in UDPSYNTAX [3496764]
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

 EXT SENDIPHEADER,SENDIPDATA,CLOSEIP

*-------------------------------------------------
* USER RECORD is valid - DP is my DP, USERPTR is valid
*-------------------------------------------------

UDPSEND ENT
 DBGMSG UDPSEND(len,ptr)
 PHB
 PHK
 PLB

* Copy in vars

 LDA 5,S
 STA UDPPTR
 LDA 5+2,S
 STA UDPPTR+2

* Build UDP header

 LDA 9,S
 STA UDPLEN ;data length
 CLC
 ADC #8 ;header + data length
 XBA
 STA :UDPLEN

 LDY #uwSourcePort
 LDA [USERPTR],Y
 XBA
 STA :SRCPORT

 LDY #uwDestPort
 LDA [USERPTR],Y
 XBA
 STA :DESTPORT

* Calculate checksum - first do the raw data

 STZ :UDPCHECKSUM

 PEA 0 ;little endian - normal

 CLC

 LDA UDPLEN
 BEQ :DONEDATA
 TAY
 LSR
 BCC :DATALOOP
 CLC
 DEY
 LDA [UDPPTR],Y ;Add in pad byte
 AND #$00FF
 XBA
 STA 1,S ;
 TYA
 BEQ :DONEDATA
:DATALOOP DEY
 DEY
 LDA [UDPPTR],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE :DATALOOP
:DONEDATA

* Add in UDP header

 LDX #6
]L1 LDA :UDPHEADER,X
 XBA
 ADC 1,S
 STA 1,S
 DEX
 DEX
 BPL ]L1

* Add in pseudo header

 LDA MYIPADDRESS
 XBA
 ADC 1,S
 STA 1,S

 LDA MYIPADDRESS+2
 XBA
 ADC 1,S
 STA 1,S

 LDY #uwDestIP
 LDA [USERPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDY #uwDestIP+2
 LDA [USERPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDA #protocolUDP
 ADC 1,S
 STA 1,S

 LDA :UDPLEN
 XBA
 ADC 1,S
 ADC #0

 XBA
]L1 EOR #-1
 BEQ ]L1
 STA :UDPCHECKSUM

 PLS

* Send IP header

 PZL USERPTR ;ipkeyblock
 PEA protocolUDP
 LDA :UDPLEN
 XBA
 PHA
 JSL SENDIPHEADER ;open driver then sends IP header

* Send UDP header

 PHLW #:UDPHEADER;#8
 JSL SENDIPDATA

* Send UDP data

 PZL UDPPTR
 PEI UDPLEN
 JSL SENDIPDATA

* End it all

 JSL CLOSEIP

 PLA
 STA 5,S
 PLA
 STA 5,S
 PLA
 PLB
 RTL

:UDPHEADER
:SRCPORT DDB 0
:DESTPORT DDB 0
:UDPLEN DDB 0
:UDPCHECKSUM DDB 0

*-------------------------------------------------
* UDPSYNTAX - Called with TMPHANDLE/TMPTR as IP packet
*-------------------------------------------------

UDPSYNTAX ENT
 DBGMSG UDPSYNTAX

* First the checksum

 LDA TMPTR ;Point to UDP start...
 CLC
 ADC IPHEADERLEN
 STA UDPPTR
 LDA TMPTR+2
 ADC #0
 STA UDPPTR+2

* Start with UDP data and UDP header

 LDY #u_cksum
 LDA [UDPPTR],Y
 BEQ :CKSUMOK

 PEA 0 ;little endian - normal

 CLC

 LDY #u_len
 LDA [UDPPTR],Y
 BEQ :DONEDATA
 XBA
 TAY
 ROR
 BCC :DATALOOP
 CLC
 DEY
 LDA [UDPPTR],Y ;Add in pad byte
 AND #$FF
 XBA
 STA 1,S ;
 TYA
 BEQ :DONEDATA
:DATALOOP DEY
 DEY
 LDA [UDPPTR],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE :DATALOOP
:DONEDATA

* Add in pseudo header

 LDY #ip_src
 LDA [TMPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDY #ip_src+2
 LDA [TMPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDY #ip_dst
 LDA [TMPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDY #ip_dst+2
 LDA [TMPTR],Y
 XBA
 ADC 1,S
 STA 1,S

 LDA #protocolUDP
 ADC 1,S
 STA 1,S

 LDY #u_len
 LDA [UDPPTR],Y
 XBA
 ADC 1,S
 ADC #0
 STA 1,S

 PLA

 EOR #-1
 BEQ :CKSUMOK ;Check if checksum OK
 EOR #-1
 BEQ :CKSUMOK ;Check if was 0-->65535 fiddle

 SEC
 RTL

:CKSUMOK
 CLC
 RTL

 SAV I.UDP.L

 END
