 LST OFF
*=================================================
*
* I.ICMP.S - ICMP manager for Marinetti
*
* Copyright (C) 1997-2001 Richard Bennett
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
* 2000.08.12 RJB - Initial release as open source
* 2002.02.16 RJB - ICMPSEND was using even length checksum calculation when
*                  there could be odd length packets. Fixed.
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/MEM.MACS
 USE ../Equates/BUILD.EQU
 USE ../Equates/I.EQU
 USE ../Equates/TCPIP.EQU

 EXT CHECKSUM16EVEN,CHECKSUM16,IPOPENUSER,IPCLOSEUSER,GETTICK
 EXT OPENUSERBYIPID

 EXT WRITEDATAGRAM,CLOSEDATAGRAM

 EXT SENDIPHEADER

 EXT ERRORTABLE

 EXT ADDTOQUEUE

 EXT IPID,MYDP

 EXT SETSTATEL

* ENTs in this module
*
* ICMPSEND(ipkeyblock:longword,len:integer,msgptr:longword);

 DUM 4
isPTR ADRL 0
isLEN DA 0
isKEYBLOCK ADRL 0
 DEND

ICMPSEND ENT ; ICMPSEND(ipkeyblock:longword,len:integer,msgptr:longword);
 DBGMSG ICMPSEND(ipkeyblock,len,ptr)

* Copy shit in

 LDA isPTR,S
 STA ICMPPTR
 LDA isPTR+2,S
 STA ICMPPTR+2
 LDA isLEN,S
 STA ICMPLEN

* Calculate ICMP checksum

 LDY #ic_cksum
 LDA #0
 STA [ICMPPTR],Y
 LXA ICMPPTR
 LDY ICMPLEN
 JSL CHECKSUM16 ;could be odd/even
 EOR #-1
 LDY #ic_cksum
 STA [ICMPPTR],Y

* Send the IP header

 LDA isKEYBLOCK+2,S
 PHA
 LDA 2+isKEYBLOCK,S
 PHA
 PEA protocolICMP
 PEI ICMPLEN
 JSL SENDIPHEADER ;sends IP header and opens packet

* Send ICMP message

 PHD

 PZL ICMPPTR
 PEI ICMPLEN
 LDA >MYDP
 TCD
 JSL WRITEDATAGRAM

* End it all

 JSL CLOSEDATAGRAM

 PLD

*
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

*-------------------------------------------------
* ICMPIN - Low level ICMP datagram handler
*          Called with handle in TMPHANDLE, must be purged before return.
*          TMPTR also points to it, IPHEADERLEN is header length.
*          On return, SEC=no user interaction required, CLC=possible user dgm
*          Assume no user open!
*          See Comer/Stevens, vol II, p130.
*-------------------------------------------------

ICMPIN ENT ;Called from I.IP, same bank.
 DBGMSG ICMPIN

 PHB
 PHK
 PLB

 INCR ERRORTABLE+tcpDGMSICMP

* First do the checksum

 LDY #ip_len
 LDA [TMPTR],Y
 XBA
 SEC
 SBC IPHEADERLEN
 CMP #4
 BCC :BAD
 TAY
 LDA TMPTR
 CLC
 ADC IPHEADERLEN
 TAX
 LDA TMPTR+2
 ADC #0
 JSL CHECKSUM16 ;must be even, but could be odd as error
 ; should really test "oddness" before checksum
 EOR #-1
 BEQ :CKOK
:BAD INCR ERRORTABLE+tcpDGMSICMPBAD
 BRA :PURGENOACTION

:CKOK LDY IPHEADERLEN
 LDA [TMPTR],Y
 AND #$FF
 CMP #ictmax
 BCC :ICMPOK
 JSR INVALID
 BRA :PURGENOACTION

:ICMPOK ASL
 TAX
 JSR (:ICMPTBL,X)
 PLB
 RTL

:PURGENOACTION JSR PURGETMPHANDLE
 PLB
 SEC
 RTL

:ICMPTBL DA ECHOREPLY ;0
 DA INVALID
 DA INVALID
 DA DESTUNREACH ;3
 DA SRCQ ;4
 DA REDIRECT ;5
 DA INVALID
 DA INVALID
 DA ECHORQ ;8
 DA USERINVALID
 DA USERINVALID
 DA TIMEX ;11
 DA PARAMP ;12
 DA TIMERQ ;13
 DA TIMERP ;14
 DA INVALID ;INFORQ ;15
 DA INVALID ;INFORP ;16
 DA MASKRQ ;17
 DA MASKRP ;18

SRCQ ;brk 0
 DBGMSG SRCQ
REDIRECT ;brk 0
 DBGMSG REDIRECT
PARAMP ;brk 0
 DBGMSG PARAMP
TIMERQ ;brk 0
 DBGMSG TIMERQ
MASKRQ DBGMSG MASKRQ
 INCR ERRORTABLE+tcpDGMSICMPKERNEL
 JSR PURGETMPHANDLE
 SEC
 RTS

TIMERP ;brk 0
 DBGMSG TIMERP
MASKRP ;brk 0
 DBGMSG MASKRP
 INCR ERRORTABLE+tcpDGMSICMPUSER
 JSR PURGETMPHANDLE
 SEC
 RTS

PURGETMPHANDLE PZL TMPHANDLE
 _DisposeHandle
 RTS

USERINVALID INCR ERRORTABLE+tcpDGMSICMPUSER
INVALID INCR ERRORTABLE+tcpDGMSICMPBADTYPE
 JSR PURGETMPHANDLE
 SEC
 RTS

BADCODE INCR ERRORTABLE+tcpDGMSICMPBADCODE
 JSR PURGETMPHANDLE
 SEC
 RTS

ECHORQ INCR ERRORTABLE+tcpDGMSICMPKERNEL
 INCR ERRORTABLE+tcpDGMSICMPECHORQ
 LDA [TMPTR],Y
 AND #$FF00
 BNE BADCODE
 LDA #0
 STA [TMPTR],Y ;New type 0, code 0
 LDY #ip_len
 LDA [TMPTR],Y
 XBA
 SEC
 SBC IPHEADERLEN
 CMP #8
 BCC :BAD ;too short
 TAX
 LDY #ip_dst
 LDA [TMPTR],Y
 STA :uwDestIP
 INY
 INY
 LDA [TMPTR],Y
 STA :uwDestIP+2
 PEA ^:KEYBLOCK
 PEA :KEYBLOCK
 PHX
 PZL TMPTR
 JSL ICMPSEND
 JSR PURGETMPHANDLE
 SEC
 RTS
:BAD INCR ERRORTABLE+tcpDGMSICMPBAD
 JSR PURGETMPHANDLE
 SEC
 RTS

:KEYBLOCK
:uwUserID DA 0 ;dummy keyblock
:uwDestIP ADRL 0
:uwDestPort DA 0
:uwIP_TOS DA 0 ;00 TOS for system ICMP
:uwIP_TTL DA $FF ;FF TTL for system ICMP

ECHOREPLY INCR ERRORTABLE+tcpDGMSICMPUSER
 INCR ERRORTABLE+tcpDGMSICMPECHORP
 LDA [TMPTR],Y
 AND #$FF00
 BNEL BADCODE
 TYX
 LDY #ip_len
 LDA [TMPTR],Y
 XBA
 SEC
 SBC IPHEADERLEN
 CMP #8
 BCC :BAD
 TXA
 CLC
 ADC #IC_ECHO_ID
 TAY
 LDA [TMPTR],Y
 XBA
 TAX
 JSL OPENUSERBYIPID
 BCC ADDTOICMPQUEUE
 INCR ERRORTABLE+tcpDGMSICMPECHORPBADID
 JSR PURGETMPHANDLE
 SEC
 RTS

:BAD INCR ERRORTABLE+tcpDGMSICMPBAD
 JSR PURGETMPHANDLE
 SEC
 RTS

ADDTOICMPQUEUE PZL TMPHANDLE
 LDY #uwICMPQueue+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL ADDTOQUEUE
 CLC
 RTS

DESTUNREACH DBGMSG DESTUNREACH

 INCR ERRORTABLE+tcpDGMSICMPKERNEL

 LDA [TMPTR],Y
 AND #$FF00
 XBA
 CMP #13 ;codes 13 and above are to be ignore
 BCS :IGNORE

 STA :CODE ;save the code

 TYA
 CLC
 ADC #8 ;Skip over 8 byte ICMP(3,x) header
 TAY
 PHY ;Save offset to embedded IP header

 TYA
 CLC
 ADC #9
 TAY
 LDA [TMPTR],Y ;Get protocol
 AND #$FF
 STA :PROTOCOL

 PLY ;Restore offset to embedded IP header
 LDA [TMPTR],Y ;Get first word in embedded IP header
 AND #$F
 ASL
 ASL
 PHA ;Length of embedded IP header
 TYA
 CLC
 ADC 1,S
 TAY ;Offset to beginning to datagram data
 PLS
 LDA [TMPTR],Y
 XBA ;fix endian
 STA :SOURCEPORT
 INY
 INY
 LDA [TMPTR],Y
 XBA ;fix endian
 STA :DESTPORT

 LDA :PROTOCOL
 CMP #protocolUDP
 BEQ :HANDLEUDP
 CMP #protocolTCP
 BEQ :HANDLETCP

 JMP ADDTOICMPQUEUE ;Not me, let the user handle it

:HANDLEUDP LDA :SOURCEPORT
 LDX :DESTPORT
 LDY #0 ;UDP
 JSL IPOPENUSER
 BCS :IGNORE ;No such port
 LDY #uwUDPError
 LDA :CODE
 ORA #$8000
 STA [USERPTR],Y
 PHS 2
 JSL GETTICK
 LDY #uwUDPErrorTick
 PLA
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y
 JSL IPCLOSEUSER
:IGNORE JSR PURGETMPHANDLE
 SEC
 RTS

:HANDLETCP LDA :SOURCEPORT
 LDX :DESTPORT
 LDY #1 ;TCP
 JSL IPOPENUSER
 BCS :IGNORE ;No such port
 PZL TMPHANDLE ;SETSTATEL may trash it!
 LDY #uwTCP_ICMPError
 LDA :CODE
 ORA #$8000
 STA [USERPTR],Y
 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 BEQ :TCPCLOSED
 LDA #tcpsCLOSED
 JSL SETSTATEL
:TCPCLOSED
 PLL TMPHANDLE
 JSL IPCLOSEUSER
 JSR PURGETMPHANDLE
 SEC
 RTS

:PROTOCOL DA 0
:SOURCEPORT DA 0
:DESTPORT DA 0
:CODE DA 0

TIMEX DBGMSG TIMEX

 INCR ERRORTABLE+tcpDGMSICMPKERNEL

 LDA [TMPTR],Y
 AND #$FF00
 XBA
 BEQ :TTLEXPIRED ;Didn't reach destination
 JSR PURGETMPHANDLE
 SEC
 RTS

:TTLEXPIRED TYA
 CLC
 ADC #8 ;Skip over 8 byte ICMP(12,0) header
 TAY
 PHY ;Save offset to embedded IP header

 TYA
 CLC
 ADC #9
 TAY
 LDA [TMPTR],Y ;Get protocol
 AND #$FF
 STA :PROTOCOL

 PLY ;Restore offset to embedded IP header
 LDA [TMPTR],Y ;Get first word in embedded IP header
 AND #$F
 ASL
 ASL
 PHA ;Length of embedded IP header
 TYA
 CLC
 ADC 1,S
 TAY ;Offset to beginning to datagram data
 PLS
 LDA [TMPTR],Y
 XBA ;fix endian
 STA :SOURCEPORT
 INY
 INY
 LDA [TMPTR],Y
 XBA ;fix endian
 STA :DESTPORT

 LDA :PROTOCOL
 CMP #protocolUDP
 BEQ :HANDLEUDP
 CMP #protocolTCP
 BEQ :HANDLETCP

 JMP ADDTOICMPQUEUE ;Not me, let the user handle it

:HANDLEUDP LDA :SOURCEPORT
 LDX :DESTPORT
 LDY #0 ;UDP
 JSL IPOPENUSER
 BCS :IGNORE ;No such port
 LDY #uwUDPError
 LDA #$8010
 STA [USERPTR],Y
 PHS 2
 JSL GETTICK
 LDY #uwUDPErrorTick
 PLA
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y
 JSL IPCLOSEUSER
:IGNORE JSR PURGETMPHANDLE
 SEC
 RTS

:HANDLETCP LDA :SOURCEPORT
 LDX :DESTPORT
 LDY #1 ;TCP
 JSL IPOPENUSER
 BCS :IGNORE ;No such port
 PHS 2 ;set new rexmit timer
 JSL GETTICK
 PLA
 LDY #uwTCP_Timer
 STA [USERPTR],Y
 PLA
 INY
 INY
 STA [USERPTR],Y
 JSL IPCLOSEUSER
 JSR PURGETMPHANDLE
 SEC
 RTS

:PROTOCOL DA 0
:SOURCEPORT DA 0
:DESTPORT DA 0

*-------------------------------------------------

 DUM 5
seSEQ DA 0
seKEYBLOCK ADRL 0
 DEND

ICMPSENDECHO ENT
 DBGMSG ICMPSENDECHO(keyblock:longword,seq:word)
 PHB
 PHK
 PLB
 LDA seSEQ,S
 XBA
 STA :SEQ
 LDA >IPID
 XBA
 STA :IPID
 STZ :CHECKSUM
 LXA #:ECHORQ
 LDY #8
 JSL CHECKSUM16EVEN
 EOR #-1
 STA :CHECKSUM
 LDA seKEYBLOCK+2,S
 PHA
 LDA 2+seKEYBLOCK,S
 PHA
 PEA protocolICMP
 PEA 8
 JSL SENDIPHEADER ;sends IP header
 PHD
 PHL #:ECHORQ
 PEA 8
 LDA >MYDP
 TCD
 JSL WRITEDATAGRAM
 JSL CLOSEDATAGRAM
 PLD
 PLA
 STA 5,S
 PLA
 STA 5,S
 PLS
 PLB
 RTL

:ECHORQ DFB 8,0
:CHECKSUM DDB 0
:IPID DDB 0
:SEQ DDB 0

 SAV I.ICMP.L

 END
