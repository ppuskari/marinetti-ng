 LST OFF
*=================================================
*
* I.DNR.S - Domain Name Resolver
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
* 2005.07.17 AJR - Integrate I.PATCH
* 2008.01.28 AJR - Improve error handling 1881079
*
*=================================================
 REL
 mx 0

 USE 4/MEM.MACS
 USE 4/TCPIP.MACS
 USE 4/RJBUTIL.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

 EXT AMIACTIVE,LINKFLAG,MYDP,MYID
 EXT NOTACTIVE8,STRIPTOOLEXIT,NOTACTIVE4

 EXT PtrToPtr,ADDTOQUEUE,FINDINQUEUE,TIMERVALID?,NEWTIMER
 EXT RIPFROMQUEUE,NEWQUEUE,DESTROYQUEUE

 EXT DNSIPMAIN,DNSIPAUX

 DUM 1 ;Tool call stack on entry
RTLROM ADR 0
RTLCALLER ADR 0
RAWSTACKEDPARMS
 DEND

 DUM 0
dnsmID DDB 0
dnsmFLAGS DDB 0
dnsmQUESTIONS DDB 0
dnsmANSWERS DDB 0
dnsmAUTH DDB 0
dnsmADD DDB 0
dnsml
 DEND

 DS 1 ;Move TCPIPDNRNameToIP off segment boundary

*-------------------------------------------------
* _TCPIPDNRNameToIP(nameptr,dnrBuffPtr)  $2136
*-------------------------------------------------

TCPIPDNRNameToIP ENT
 DBGMSG TCPIPDNRNameToIP
 LDA >AMIACTIVE
 BNE :ACTIVE
 JML NOTACTIVE8
:ACTIVE LDA >LINKFLAG
 BEQL :NOTCONNECTED

 JSR GETFIRSTSERVER
 BCSL :NOSERVERS

 PHB
 PHK
 PLB
 PHD
 LDA >MYDP
 TCD

* First set up tables

 LDA #%0_0000_0_0_1_0_000_0000
 XBA
 STA UDPDNSFLAGS
 LDA #$0100
 STA UDPDNSQ ;1 question
 STZ UDPDNSA ;0 answers

 ~NewHandle #DNRlen;>MYID;#$0018;#0
 PLXA TMPHANDLE
 DEREF TMPHANDLE;TMPTR

 LDY #DNRtype
 LDA #0 ;NameToIP
 STA [TMPTR],Y

 LDA 2+1+RAWSTACKEDPARMS,S
 LDY #DNRbuffptr
 STA [TMPTR],Y
 STA TMPTR1
 LDA 2+1+RAWSTACKEDPARMS+2,S
 INY
 INY
 STA [TMPTR],Y
 STA TMPTR1+2
 LDA #DNR_Pending
 STA [TMPTR1] ;Tell user we're pending

 LDA 2+1+RAWSTACKEDPARMS+4+2,S ;Copy pstring to my buffer
 STA TMPTR1+2
 PHA
 LDA 2+2+1+RAWSTACKEDPARMS+4,S
 STA TMPTR1
 PHA
 PHL #QUERYDATA
 PEA 0
 LDA [TMPTR1]
 AND #$FF
 INC
 PHA
 JSL PtrToPtr

 JSR GETFIRSTSERVER
 STX :SERVER
 STA :SERVER+2
 TYA
 LDY #DNRserver
 STA [TMPTR],Y

 LDA >DNSTIMER
 JSL NEWTIMER
 LDY #DNRtimer+2
 STA [TMPTR],Y
 TXA
 DEY
 DEY
 STA [TMPTR],Y

 LDA >DNSRETRIES
 LDY #DNRcount
 STA [TMPTR],Y

 PZL TMPHANDLE ;Destroyed by reentrancy

 PHS
 PHW >MYID
 PHL :SERVER
 PEA 53 ;DNS port
 PEA 0 ;TOS
 PEA 64 ;TTL
 _TCPIPLogin

 PLX

 PLL TMPHANDLE
 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2

 TXA ;ipid
 STA UDPIPID
 LDY #DNRipid
 STA [TMPTR],Y

 PZL TMPHANDLE
 PZL DNRHANDLE ;Ready to add to queue

* Build first UDP packet

 LDA QUERYDATA
 AND #$FF
 BEQ :ROOTLEVEL

 INC
 STA :PSTRLENGTHP1

 SEP $20

 STZ :LABELLENGTH
 LDY #0 ;Last count offset
 LDX #1 ;Flowing index
 BRA :FIRSTLOOP

:LABELLOOP INC :LABELLENGTH
:FIRSTLOOP LDA QUERYDATA,X
 CMP #'.'
 BNE :NEXT

:GOTDOT LDA :LABELLENGTH
 STA QUERYDATA,Y
 STZ :LABELLENGTH
 TXY
 INX
 CPX :PSTRLENGTHP1
 BNE :FIRSTLOOP
 BRA :DONEDOT

:NEXT INX
 CPX :PSTRLENGTHP1
 BNE :LABELLOOP
 LDA :LABELLENGTH
 INC
 STA QUERYDATA,Y

:DONEDOT STZ QUERYDATA,X
 REP $20
 INX
 BRA :GOTINDEX

:ROOTLEVEL LDX #1 ;Index past null byte

:GOTINDEX LDA #$0100 ;Type = 1
 STA QUERYDATA,X
 STA QUERYDATA+2,X ;Class = 1 (Internet address)

 TXA ;Length of labels
 CLC
 ADC #2+2+12 ;Type + class + header
 STA UDPLENGTH

* Fill in final fields

 LDY #DNRdatagraml
 LDA UDPLENGTH
 STA [TMPTR],Y

 PHL #UDPDATA
 LDA TMPTR
 CLC
 ADC #DNRdatagram
 TAX
 LDA TMPTR+2
 ADC #0
 PHA
 PHX
 PEA 0
 PHW UDPLENGTH
 JSL PtrToPtr

* Send it!

 ~TCPIPSendUDP UDPIPID;#UDPDATA;UDPLENGTH

* OK, add it and exit

 JSL ADDTOQUEUE ;We now have a new entry
 BCS :BUFFERFULL

 INC DNRSPENDING

*

 PLD
 PLB
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #8
 JML ToStrip

:BUFFERFULL LDA #terrBUFFERTOOSMALL&terrmask
 LDY #8
 JML STRIPTOOLEXIT

:NOSERVERS LDA #terrNODNSERVERS&terrmask
 LDY #8
 JML STRIPTOOLEXIT

:NOTCONNECTED LDA #terrNOCONNECTION&terrmask
 LDY #8
 JML STRIPTOOLEXIT

:SERVER ADRL 0

:PSTRLENGTHP1 DA 0
:LABELLENGTH DS 1

UDPLENGTH DA 0

UDPDATA
UDPIPID DA 0
UDPDNSFLAGS DDB %0_0000_0_0_1_0_000_0000
UDPDNSQ DDB 1 ;1 question
UDPDNSA DDB 0 ;0 answer RRs
 DDB 0 ;0 authority RRs
 DDB 0 ;0 additional RRs
QUERYDATA DS 1+255+1+4 ;Maximum name is 255 chars plus length byte
;...plus ending null byte for root level, plus
;...four bytes for query type and class.

*-------------------------------------------------
* PollDNR - MYDP is set
*-------------------------------------------------

PollDNR ENT
 DBGMSG PollDNR
 PHB
 PHK
 PLB
*
 PEA 0 ;Scan through the pending list starting at 0

:TOPLOOP PHS 2
 LDA 5,S
 PHA
 PZL DNRHANDLE
 JSL FINDINQUEUE

 LDA 1,S
 STA TMPHANDLE
 ORA 1+2,S
 BEQL :NOMORE3W
 LDA 1+2,S
 STA TMPHANDLE+2

 DEREF TMPHANDLE;TMPTR

 PHS 2
 LDY #DNRipid
 LDA [TMPTR],Y
 PHA
 PEA protocolUDP
 PEA $C000
 _TCPIPGetNextDatagram

 LDA 1,S
 STA TMPHANDLE
 ORA 1+2,S
 BEQL :NORESPONSE
 LDA 1+2,S
 STA TMPHANDLE+2

 DEREF TMPHANDLE;TMPTR

 DBGMSG udppkt

 LDY #dnsmFLAGS
 LDA [TMPTR],Y
 XBA
 AND #%1000_0000_0000_1111
 BPLL :DUMPIT ;Is my query. Weird. Toss it.
 AND #%0000_0000_0000_1111
 BEQ :REPLYOK

:NOENTRY _DisposeHandle
 PLL TMPHANDLE
 DEREF TMPHANDLE;TMPTR ;record handle
 LDA #DNR_NoDNSEntry
 BRL :DNRCOMPLETE

:REPLYOK ;This is a reply. Scan datagram for IP address

 INY
 INY
 INY
 INY
 LDA [TMPTR],Y ;Number of answers
 BEQ :NOENTRY

 LDY #dnsml
 JSR SKIPLABEL ;skip over the question name
 INY ;skip over the question type and code
 INY
 INY
 INY
;now scanning answer
 JSR SKIPLABEL ;skip over the answer name

 LDA [TMPTR],Y ;Find the type
 XBA
 CMP #1
 BEQL :A_TYPE
 CMP #5
 BEQ :CNAME_TYPE
 BRA :NOENTRY

:CNAME_TYPE TYA ;CNAME record is an alias
 CLC
 ADC #8+2 ;skip type, class, ttl, rdlength
 TAY ;pointer to actual name

 DBGMSG canonical

* Copy alias to work buffer and make it a name

 LXA #QUERYDATA
 STXA TMPTR1

 TYA
 CLC
 ADC TMPTR
 STA TMPTR
 LDA TMPTR+2
 ADC #0
 STA TMPTR+2

 LDX #0 ;initialise length

:NEXTLABEL LDA [TMPTR] ;length of this label
 AND #$FF
 BEQ :GOTENDX
 AND #$C0
 BEQ :DOLABEL
 LDA [TMPTR]
 XBA
 AND #$3FFF
 CLC
 ADC [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 BRA :NEXTLABEL

:DOLABEL LDA [TMPTR]
 AND #$FF
 TAY ;x=length of (length+label)

 SEP $20

]L2 LDA [TMPTR],Y
 STA [TMPTR1],Y
 DEY
 BNE ]L2
 LDA #'.'
 STA [TMPTR1]

 REP $20

 LDA [TMPTR] ;get label length
 AND #$FF
 PHA

 TXA ;bump name length
 SEC
 ADC 1,S
 TAX

 LDA 1,S ;bump datagram pointer
 SEC
 ADC TMPTR
 STA TMPTR
 LDA TMPTR+2
 ADC #0
 STA TMPTR+2

 LDA 1,S ;bump QUERYDATA pointer to accept next label
 SEC
 ADC TMPTR1
 STA TMPTR1
 LDA TMPTR1+2
 ADC #0
 STA TMPTR1+2

 PLS

 BRA :NEXTLABEL

:GOTENDX DEX
 SEP $10
 STX QUERYDATA
 REP $10

* Call Marinetti as a new DNR entry

 PHL #QUERYDATA ;pointer to pstring

 LDA 9,S
 STA TMPHANDLE ;handle to pending entry
 LDA 9+2,S
 STA TMPHANDLE+2
 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 LDY #DNRbuffptr
 LDA [TMPTR],Y
 TAX
 INY
 INY
 LDA [TMPTR],Y
 PHA ;pointer to pending entry
 PHX

 PHA ;pointer to pending entry
 PHX
 _TCPIPCancelDNR ;Cancel it -- purges current entry handle

 _TCPIPDNRNameToIP ;...and start a new one

 _DisposeHandle ;dump the datagram

 PLS 2 ;the entry handle which no longer exists

 BRL :SAMEINQUEUE ;the index to this entry now contains a
;different entry, so handle this index
;again.

:A_TYPE TYA ;this is the type offset
 CLC
 ADC #8 ;skip type(2), class(2), ttl(4)
 TAY
 LDA [TMPTR],Y
 XBA
 CMP #4 ;IP address is 4 bytes long
 BNEL :NOENTRY
 INY
 INY ;now pointing to IP address
 LDA [TMPTR],Y
 STA :IPADDRESS
 INY
 INY
 LDA [TMPTR],Y
 STA :IPADDRESS+2

:GOTIT _DisposeHandle ;ok, dumped the datagram, now go back and
;report it to the caller
 PLL TMPHANDLE
 DEREF TMPHANDLE;TMPTR

 LDY #DNRbuffptr
 LDA [TMPTR],Y
 STA TMPTR1
 INY
 INY
 LDA [TMPTR],Y
 STA TMPTR1+2
 LDY #DNRIPaddress
 LDA :IPADDRESS
 STA [TMPTR1],Y
 INY
 INY
 LDA :IPADDRESS+2
 STA [TMPTR1],Y

 LDA #DNR_OK
 BRL :DNRCOMPLETE

:DUMPIT PZL TMPHANDLE
 _DisposeHandle

:NORESPONSE PLS 2 ;should check for ICMP errors too...

 PLL TMPHANDLE
 DEREF TMPHANDLE;TMPTR

 LDY #DNRtimer
 LDA [TMPTR],Y
 TAX
 INY
 INY
 LDA [TMPTR],Y
 JSL TIMERVALID?
 BCCL :NEXTINQUEUE ;No, so move on!

 LDY #DNRcount
 LDA [TMPTR],Y
 DEC
 BEQL :TIMEDOUT
 STA [TMPTR],Y

 LDA >DNSTIMER
 JSL NEWTIMER
 LDY #DNRtimer+2
 STA [TMPTR],Y
 DEY
 DEY
 TXA
 STA [TMPTR],Y

 PZL TMPHANDLE

 LDY #DNRipid
 LDA [TMPTR],Y
 PHA ;ready for destination change
 LDY #DNRserver
 LDA [TMPTR],Y
 JSR NEXTSERVER
 PHA
 PHX
 TYA
 LDY #DNRserver
 STA [TMPTR],Y
 PEA 53
 _TCPIPSetNewDestination

 PLL TMPHANDLE

 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 LDY #DNRipid
 LDA [TMPTR],Y
 PHA
 LDA TMPTR
 CLC
 ADC #DNRdatagram
 TAX
 LDA TMPTR+2
 PHA
 PHX
 LDY #DNRdatagraml
 LDA [TMPTR],Y
 PHA
 _TCPIPSendUDP
 BRA :NEXTINQUEUE

:TIMEDOUT LDA #DNR_Failed

:DNRCOMPLETE
 DBGMSG DNRCOMPLETE

 PHA ;error code

 LDY #DNRbuffptr
 LDA [TMPTR],Y
 STA TMPTR1
 INY
 INY
 LDA [TMPTR],Y
 STA TMPTR1+2

 PLA
 STA [TMPTR1]

 LDY #DNRipid
 LDA [TMPTR],Y
 PHA
 _TCPIPLogout

 DEC DNRSPENDING

 PHS 2
 LDA 5,S
 PHA
 PZL DNRHANDLE
 JSL RIPFROMQUEUE
 _DisposeHandle
 BRL :TOPLOOP ;Don't increment, because we've shifted down

:NEXTINQUEUE

 PLA
 INC
 PHA
 BRL :TOPLOOP

:SAMEINQUEUE

 LDA 1,S
 BRL :TOPLOOP

:NOMORE3W PLS 2
:NOMORE1W PLS

*

 PLB
 RTL

:IPADDRESS ADRL 0

SKIPLABEL DBGMSG SKIPLABEL ;Start at Y, ends after the entire name
 LDA [TMPTR],Y
 AND #$C0
 BEQ :LABELS
 INY
 INY
 RTS
:LABELS
]L1 LDA [TMPTR],Y ;Start of question - scanning labels
 AND #$FF
 BEQ :LASTLABEL
 PHA
 TYA
 SEC
 ADC 1,S
 TAY
 PLS
 BRA ]L1
:LASTLABEL INY
 RTS

*-------------------------------------------------
* GETFIRSTSERVER
*-------------------------------------------------

GETFIRSTSERVER DBGMSG GETFIRSTSERVER
GETMAINSERVER LDA >DNSIPMAIN
 ORA >DNSIPMAIN+2
 BEQ GETAUXSERVER
 LDA >DNSIPMAIN
 TAX
 LDA >DNSIPMAIN+2
 LDY #0
 CLC
 RTS
GETAUXSERVER LDA >DNSIPAUX
 ORA >DNSIPAUX+2
 BEQ NOSERVER
 LDA >DNSIPAUX
 TAX
 LDA >DNSIPAUX+2
 LDY #1
 CLC
 RTS
NOSERVER SEC
 RTS

*-------------------------------------------------
* NEXTSERVER - A is 0=primary,1=secondary. On exit XA is server, Y is new type.
*-------------------------------------------------

NEXTSERVER DBGMSG NEXTSERVER
 EOR #0
 BEQ :WASPRIMARY
:WASAUX LDA >DNSIPMAIN
 ORA >DNSIPMAIN+2
 BEQ GETAUXSERVER
 BRA GETMAINSERVER
:WASPRIMARY LDA >DNSIPAUX
 ORA >DNSIPAUX+2
 BNE GETAUXSERVER
 BRA GETMAINSERVER

*-------------------------------------------------
* KillDNR - MYDP is set
*-------------------------------------------------

KillDNR ENT
 DBGMSG KillDNR

:LOOP LDA [DNRHANDLE]
 STA TMPTR
 LDY #2
 LDA [DNRHANDLE],Y
 STA TMPTR+2

 LDA [TMPTR]
 ORA [TMPTR],Y
 BEQ :ALLDONE

 LDA [TMPTR]
 STA TMPHANDLE
 LDA [TMPTR],Y
 STA TMPHANDLE+2

 LDA [TMPHANDLE]
 STA TMPTR
 LDA [TMPHANDLE],Y
 STA TMPTR+2

 LDY #DNRbuffptr+2
 LDA [TMPTR],Y
 PHA
 DEY
 DEY
 LDA [TMPTR],Y
 PHA
 _TCPIPCancelDNR

 BRA :LOOP

:ALLDONE

 do 0
 PHL #2
 PZL DNRCACHEHANDLE
 _SetHandleSize
 LDA [DNRCACHEHANDLE]
 STA TMPTR
 LDY #2
 LDA [DNRCACHEHANDLE],Y
 STA TMPTR+2
 LDA #0
 STA [TMPTR]
 fin

 STZ DNRSPENDING

 RTL

*-------------------------------------------------
* _TCPIPCancelDNR(buffPtr)  $2036
*-------------------------------------------------

TCPIPCancelDNR ENT
 DBGMSG TCPIPCanceDNR(buffPtr)
 LDA >AMIACTIVE
 BNE :ACTIVE
 JML NOTACTIVE4
:ACTIVE
 PHB
 PHK
 PLB

 PHD
 LDA >MYDP
 TCD

 PEA 0 ;Scan through the pending list starting at 0

:TOPLOOP PHS 2
 LDA 5,S
 PHA
 PZL DNRHANDLE
 JSL FINDINQUEUE

 LDA 1,S
 STA TMPHANDLE
 ORA 1+2,S
 BEQL :NOMORE3W
 LDA 1+2,S
 STA TMPHANDLE+2

 DEREF TMPHANDLE;TMPTR

 LDY #DNRbuffptr
 LDA [TMPTR],Y
 STA TMPTR1
 CMP 4+2+2+RAWSTACKEDPARMS,S
 BNE :NEXT
 INY
 INY
 LDA [TMPTR],Y
 STA TMPTR1+2
 CMP 4+2+2+RAWSTACKEDPARMS+2,S
 BNE :NEXT

* Got it

 LDA #DNR_Cancelled
 STA [TMPTR1]

 LDY #DNRipid
 LDA [TMPTR],Y
 PHA
 _TCPIPLogout

 DEC DNRSPENDING

% PHS 2 ;already 2 on stack
 LDA 5,S
 PHA
 PZL DNRHANDLE
 JSL RIPFROMQUEUE
 _DisposeHandle

 PLS

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:OUT PLD
 PLB
 LDY #4
 JML STRIPTOOLEXIT

:NEXT PLS 2
 PLA
 INC
 PHA
 BRA :TOPLOOP

:NOMORE3W PLS 2
 PLS
 LDA #terrNODNRPENDING&terrmask
 BRA :OUT

*-------------------------------------------------
* _TCPIPGetDNRTimeouts(dnrTimeoutBuffPtr)  $6736
*-------------------------------------------------

TCPIPGetDNRTimeouts ENT
 DBGMSG TCPIPGetDNRTimeouts(dnrTimeoutBuffPtr)
 TSC
 PHD
 TCD
 LDA >DNSRETRIES
 STA [RAWSTACKEDPARMS]
 LDA >DNSTIMER
 LDY #2
 LDA [RAWSTACKEDPARMS],Y
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetDNRTimeouts(dnrTimeoutBuffPtr)  $6836
*-------------------------------------------------

TCPIPSetDNRTimeouts ENT
 DBGMSG TCPIPSetDNRTimeouts(dnrTimeoutBuffPtr)
 TSC
 PHD
 TCD
 LDA [RAWSTACKEDPARMS]
 STA >DNSRETRIES
 LDY #2
 LDA [RAWSTACKEDPARMS],Y
 STA >DNSTIMER
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

DNSRETRIES DA 5 ;Try five times on each
DNSTIMER DA 120 ;Retry every 2 seconds

 SAV I.DNR.L

 END

* for reference

 DUM 0
DNRtype DA 0 ;0=NameToIP, 1=IPToName
DNRbuffptr ADRL 0 ;pointer to user's buffer
DNRserver DA 0 ;last sent is 0=primary, 1=secondary
DNRtimer ADRL 0 ;when to next send
DNRcount DA 0 ;resends left. 0=cancel
DNRipid DA 0 ;ipid of request
DNRdatagraml DA 0 ;length of datagram
DNRdatagram DS 12+1+255+1+2+2 ;See I.DNR.S
DNRlen
 DEND
