 LST OFF
*=================================================
*
* I.FRAG.S - IP Fragmentation manager
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
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

 EXT MYID

 EXT LINKSENDPACKET

 EXT PtrToPtr

 EXT CHECKSUM16EVEN

 EXT ERRORTABLE

StartIPOut ENT
 DBGMSG StartIPOut
 ~NewHandle #$10000;>MYID;#$C01C;#0
 PLA
 STA >WORKBUFFHANDLE
 STA TMPHANDLE
 PLA
 STA >WORKBUFFHANDLE+2
 STA TMPHANDLE+2
 LDA [TMPHANDLE]
 STA WORKBUFFPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA WORKBUFFPTR+2
 do INITBUFFCC
 XBA
 ORA WORKBUFFPTR+2
 STA >:MOD+1
 LDA #$CCCC
 STA [WORKBUFFPTR]
 LDX #0
 LDY #2
 LDA #$FFFE-1
 PHB
:MOD MVN 0,0
 PLB
 fin
 RTL

ShutIPOut ENT
 DBGMSG ShutIPOut
 PHL >WORKBUFFHANDLE
 _DisposeHandle
 do INITDPCC
 LDA #$CCCC
 STA WORKBUFFPTR
 STA WORKBUFFPTR+2
 fin
 RTL

WORKBUFFHANDLE ADRL 0

*-------------------------------------------------
* ALL THESE REQUIRE MYDP TO BE SET
*-------------------------------------------------

OPENDATAGRAM ENT
 DBGMSG OPENDATAGRAM
 LDA #0
 STA WORKBUFFINDEX
 RTL

WRITEDATAGRAM ENT
 DBGMSG WRITEDATAGRAM
 LDA FRAME+2+2,S ;Address of data
 PHA
 LDA 2+FRAME+2,S
 PHA
 PEI WORKBUFFPTR+2
 PEI WORKBUFFINDEX
 LDA 4+4+FRAME,S ;Length
 PEA 0
 PHA
 CLC
 ADC WORKBUFFINDEX
 STA WORKBUFFINDEX
 JSL PtrToPtr
 PHB
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLS
 PLB
 RTL

CLOSEDATAGRAM ENT
 DBGMSG CLOSEDATAGRAM

 PHB
 PHK
 PLB

* OK, first calculate length of header

 LDA [WORKBUFFPTR]
 AND #$0F
 ASL
 ASL
 STA :IPHEADERLEN

* Length of actual data

 LDA WORKBUFFINDEX
 SEC
 SBC :IPHEADERLEN
 STA :DATALEN

* Start of first fragment

 STZ :FRAGOFFSET
 LSR :LASTFLAG

* Top of fragment loop

:NEXTFRAGMENT

* How much data should I send?

 LDA MTU ;This is maximum
 SEC
 SBC :IPHEADERLEN ;...leaves number of data bytes
 AND #$FFF8 ;...round to 8 bytes = total data bytes
 STA :SENDLEN
 CMP :DATALEN ;Is send length less than data left?
 BCC :MOREFRAGS ;Yep.

* Last fragment

 LDA :DATALEN
 STA :SENDLEN
% SEC
 ROR :LASTFLAG
 LDA :FRAGOFFSET
 BRA :JOINSIZE
:MOREFRAGS LDA :FRAGOFFSET
 ORA #%0010_0000_0000_0000
:JOINSIZE

* Doctor the new header

 LDY #ip_fragoff
 XBA
 STA [WORKBUFFPTR],Y

 LDA :IPHEADERLEN
 CLC
 ADC :SENDLEN
 XBA
 LDY #ip_len
 STA [WORKBUFFPTR],Y

* All sends go through here

:SENDLAST

* New checksum

 LDY #ip_cksum
 LDA #0
% XBA
 STA [WORKBUFFPTR],Y

 LDX WORKBUFFPTR
 LDA WORKBUFFPTR+2
 LDY :IPHEADERLEN
 JSL CHECKSUM16EVEN ;on header, so always even
 EOR #-1
 LDY #ip_cksum
 STA [WORKBUFFPTR],Y

 PZL WORKBUFFPTR
 LDA :IPHEADERLEN
 CLC
 ADC :SENDLEN
 PHA
 JSL LINKSENDPACKET

* Was this send a fragment? If so, bump the fragment send count.

 LDY #ip_fragoff
 LDA [WORKBUFFPTR],Y
 BEQ :SKIPFRAGINC ;If MF (more fragments) or offset non-zero
 INCR ERRORTABLE+tcpDGMSOFRAGMENTS ;Transmitting a fragment
:SKIPFRAGINC

 BIT :LASTFLAG
 BMI :DONE

* Update data left

 LDA :DATALEN
 SEC
 SBC :SENDLEN
 STA :DATALEN

* Update offset

 LDA :FRAGOFFSET
 ASL
 ASL
 ASL
 CLC
 ADC :SENDLEN
 LSR
 LSR
 LSR
 STA :FRAGOFFSET

* Move data down

 PEI WORKBUFFPTR+2
 LDA :IPHEADERLEN
 CLC
 ADC :SENDLEN
 PHA

 PEI WORKBUFFPTR+2
 PHW :IPHEADERLEN

 PEA 0
 PHW :DATALEN

 JSL PtrToPtr

 BRL :NEXTFRAGMENT

:DONE

* Was the last send a fragemnt? If so, increment the fact that we had to
* fragment this datagram.

 LDY #ip_fragoff
 LDA [WORKBUFFPTR],Y
 BEQ :SKIPFRAGGED ;If MF (more fragments) or offset non-zero
 INCR ERRORTABLE+tcpDGMSFRAGMENTED ;Transmitting a fragment
:SKIPFRAGGED

 PLB
 RTL

:IPHEADERLEN DA 0 ;Length of IP header
:DATALEN DA 0 ;Length of data left to send
:FRAGOFFSET DA 0 ;Offset into real datagram for this fragment
:SENDLEN DA 0 ;How much data to send in this fragment
:LASTFLAG DA 0 ;0=no, 8000=yes

 SAV I.FRAG.L

 END
