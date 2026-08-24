 LST OFF
 REL
 mx 0

*=================================================
*
* I.TCP.S - Main TCP handling code for Marinetti
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
* 2005.01.12 RJB - Fixed stack imbalance in incoming SYN error handler 1084053
* 2006.06.03 AJR - Added ability to send TCP tracing output to disk
* 2006.06.20 AJR - Fixed PROCESSTHIS? Sequence check 226053
* 2006.06.22 AJR - Expanded TCP tracing output
* 2006.07.02 AJR - Fixed TCPRead memory overrun 426999
* 2006.10.01 AJR - Split out I.TCP.DEBUG because filled Merlin's editor memory
* 2008.01.20 AJR - Improve handling of TCPWrite buffer full 1608920
* 2008.01.28 AJR - Improve error handling 1881079
*
*=================================================
* ENTries in this module:
*
* TCPOPEN, TCPREAD, TCPWRITE, TCPCLOSE, TCPABORT, TCPSTATUS
* SEGMENTARRIVES, TCPPOLLTIMERS, TCPCONNECTIONS, TCPSYNTAX
* TCPTOSSUNCLAIMED, TCPCLOSEDEBUGFILE

 USE 4/RJBUTIL.MACS
 USE 4/MISC.MACS
 USE 4/TEXT.MACS
 USE 4/INT.MACS
 USE 4/MEM.MACS
 USE 4/TCPIP.MACS
 USE ../EQUATES/BUILD.EQU
 USE ../EQUATES/I.EQU
 USE ../EQUATES/TCPIP.EQU

 EXT MYID,GETTICK,IPID

 EXT SENDIPHEADER,SENDIPDATA,CLOSEIP,ERRORTABLE

 EXT DEBUGTCP

 EXT GETNEXTINQUEUE

 EXT TCPMAXSEGSEND,TCPMAXSEGRECEIVE,TCPRECEIVEWINDOW

 EXT NEWQUEUE,DESTROYQUEUE,ADDTOHANDLE,READFROMHANDLE,COPYFROMHANDLE
 EXT INSERTDATAINTOHANDLE,GETHANDLESIZE,ADDTOQUEUE,FINDINQUEUE
 EXT RIPFROMQUEUE,TIMERVALID?,QUEUESIZE

*-------------------------------------------------
* SEGMENT XMT/RCV CALLS
*
* USER RECORD is valid - DP is my DP, USERPTR is valid
*-------------------------------------------------

* Locks TCPHANDLE, sends it as SND_NXT and unlocks

SENDSEG DBGMSG SENDSEG
 LDY #uwRCV_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 LDY #uwSND_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 LOCK TCPHANDLE
 LDY #8
 LDA [TCPHANDLE],Y
 PHA
 LDY #2
 LDA [TCPHANDLE],Y
 PHA
 LDA [TCPHANDLE]
 PHA

* Check for FIN - is it in the sequence data?

 LDY #uwTCP_ForceFIN
 LDA [USERPTR],Y
 BEQ :NOFIN

;Only send a FIN if the sequence number of the
;FIN is the byte after the data in this segment.
;SEQ + length  = FIN

 LDY #uwSND_NXT
 LDA [USERPTR],Y
 CLC
 LDY #8
 ADC [TCPHANDLE],Y
 TAX
 LDY #uwSND_NXT+2
 LDA [USERPTR],Y
 LDY #8+2
 ADC [TCPHANDLE],Y

 LDY #uwTCP_FINSEQ+2
 CMP [USERPTR],Y
 BNE :NOFIN
 TXA
 DEY
 DEY
 CMP [USERPTR],Y
 BNE :NOFIN

 PEA TCPF_ACK+TCPF_FIN

 LDA #1
 STA :SENTFIN

 LDA 7,S
 BEQ :NODATAFIN
 TCPD 'sending <ACK><FIN>+segment data'
 BRA :JOIN

:NODATAFIN TCPD 'sending <ACK><FIN>'
 BRA :JOIN

:NOFIN PEA TCPF_ACK

 STZ :SENTFIN

 LDA 7,S
 BEQ :NODATA
 TCPD 'sending <ACK>+segment data'
 BRA :JOIN

:NODATA TCPD 'sending <ACK>'

:JOIN

* Test for push in sequence

 LDY #uwTCPPushOutFlag
 LDA [USERPTR],Y
 BEQ :SKIPUSH

 LDY #uwTCPPushOutSEQ ;  PUSHSEQ - SEGSEQ < LEN    ---> Push me
 LDA [USERPTR],Y
 SEC
 SBC 9,S
 TAX
 INY
 INY
 LDA [USERPTR],Y
 SBC 9+2,S
 BMI :SKIPUSH ;should never be, push has passed by already
 BNE :SKIPUSH ;should never be, is too big a buffer
 TXA
 CMP 7,S
 BCS :SKIPUSH
 PLA
 ORA #TCPF_PSH
 PHA
:SKIPUSH

* OK, show debug stuff and send it on it's way.

 TCPDLEN

 TCPDSEQ
 JSL TCPSENDDGM ;(ack;L,seq;L,len;W,ptr;L,flags;W)

 UNLOCK TCPHANDLE

 LDY #uwTCP_ACKPending
 LDA #0
 STA [USERPTR],Y

 ROR :SENTFIN

 RTS

:SENTFIN DA 0

SEND_SYN DBGMSG SEND_SYN ;XA = SEQ (sequence number to use)
 PEA 0 ;ack
 PEA 0
 PHXA ;seq
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_SYN ;flags
 TCPD 'sending just <SYN>'
 TCPDSEQ
 JSL TCPSENDDGM
 RTS

SEND_SYNACK DBGMSG SEND_SYNACK ;XA = SEQ (sequence number to use)
 LDY #uwRCV_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 LDY #uwSND_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_SYN+TCPF_ACK ;flags
 TCPD 'sending just <SYN><ACK>'
 TCPDSEQ
 JSL TCPSENDDGM
 RTS

SEND_RST DBGMSG SEND_RST ;XA = SEQ (sequence number to use)
 PEA 0 ;ack
 PEA 0
 PHXA ;seq
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_RST ;flags
 TCPD 'sending just <RST>'
 TCPDSEQ
 JSL TCPSENDDGM
 RTS

SEND_ACK DBGMSG SEND_ACK ;RCV_NXT = ACK, SND_NXT = SEQ
 LDY #uwRCV_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 LDY #uwSND_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_ACK ;flags
 TCPD 'sending just <ACK>'
 TCPDSEQ
 JSL TCPSENDDGM
 RTS

TCPSENDDGM DBGMSG TCPSENDDGM(ack,seq,len,ptr,flags)
 PHB
 PHK
 PLB

* Copy in vars

 LDA 5,S
 AND #%0011_1111
 SEP $20
 STA :FLAGS
 REP $20

 LDA 7,S
 STA TCPPTR
 LDA 7+2,S
 STA TCPPTR+2

 LDA 13,S
 XBA
 STA :SEQNUM+2
 LDA 13+2,S
 XBA
 STA :SEQNUM

 LDA 17,S
 XBA
 STA :ACKNUM+2
 LDA 17+2,S
 XBA
 STA :ACKNUM

 LDA 11,S
 STA TCPLEN

* Build TCP pseudo header

 CLC
 ADC #20
 XBA
 STA :TCPLEN

 LDA MYIPADDRESS
 STA :SRCIP
 LDA MYIPADDRESS+2
 STA :SRCIP+2

 LDY #uwDestIP
 LDA [USERPTR],Y
 STA :DESTIP
 INY
 INY
 LDA [USERPTR],Y
 STA :DESTIP+2

* Build TCP header

 LDY #uwSourcePort
 LDA [USERPTR],Y
 XBA
 STA :SRCPORT

 LDY #uwDestPort
 LDA [USERPTR],Y
 XBA
 STA :DESTPORT

 LDY #uwRCV_WND
 LDA [USERPTR],Y
 XBA
 STA :WINDOW

 STZ :TCPCHECKSUM

* Calculate checksum - first do the raw data

 PEA 0 ;little endian - normal

 CLC
 LDA TCPLEN
 BEQ :DONEDATA
 TAY
 ROR
 BCC :DATALOOP
 DEY
 LDA [TCPPTR],Y ;Add in pad byte
 XBA
 AND #$FF00
 STA 1,S ;
 TYA
 CLC
 BEQ :DONEDATA
:DATALOOP DEY
 DEY
 LDA [TCPPTR],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE :DATALOOP
:DONEDATA

* Add in TCP pseudo header and header

 LDX #12+20-2
]L1 LDA :PSEUDOHEADER,X
 XBA
 ADC 1,S
 STA 1,S
 DEX
 DEX
 BPL ]L1

 ADC #0

 XBA
 EOR #-1
 STA :TCPCHECKSUM

 PLS

* debug stuff

 do TCPDEBUG
 LDA >DEBUGTCP
 BEQ :SKIPASC
 JSR TCPRINT
 ASC ' wind size=',00
 LDA :WINDOW
 XBA
 JSR TCPSHORT
 JSR TCPRINT
 HEX 0D00
:SKIPASC
 fin

* Send IP header

 PZL USERPTR ;ipkeyblock
 PEA protocolTCP
 LDA :TCPLEN
 XBA
 PHA
 JSL SENDIPHEADER ;open driver then sends IP header

* Send TCP header

 PHLW #:TCPHEADER;#20
 JSL SENDIPDATA

* Send TCP data

 LDA TCPLEN
 BEQ :SKIPDATA
 PZL TCPPTR
 PHA
 JSL SENDIPDATA
:SKIPDATA

* End it all

 JSL CLOSEIP

 PLA
 STA 15,S
 PLA
 STA 15,S
 PLS 6
 PLB
 RTL

:PSEUDOHEADER
:SRCIP ADRL 0
:DESTIP ADRL 0
 DFB 0
:PTCL DFB protocolTCP
:TCPLEN DDB 0

:TCPHEADER
:SRCPORT DDB 0
:DESTPORT DDB 0
:SEQNUM ADRL 0
:ACKNUM ADRL 0
:OFFSET DFB 5*$10 ;First four bits = 5
:FLAGS DFB 0
:WINDOW DDB 0
:TCPCHECKSUM DDB 0
:URGENTPTR DDB 0
:TCPOPTIONS

*-------------------------------------------------
* TCP LOGIC
*-------------------------------------------------

INSUFFICIENT LDA #tcperrNoResources
 BRA SETERRORPLBRTL

CONCLOSING LDA #tcperrConClosing
 BRA SETERRORPLBRTL

BADCONNECTION LDA #tcperrBadConnection
 BRA SETERRORPLBRTL

NOERROR LDA #tcperrOK
SETERRORPLBRTL LDY #uwTCP_ErrCode
 STA [USERPTR],Y
 PLB
 RTL

*-------------------------------------------------
* TCPACCEPT - Already checked whether its a server and in LISTEN state
*-------------------------------------------------

TCPACCEPT ENT
 DBGMSG TCPACCEPT

 PHB
 PHK
 PLB

; TCPD 'TCP_ACCEPT'

* See if there are any pending

 PHS 2
 LDY #uwTCP_ChildList+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETNEXTINQUEUE ;Removes it
 PLS
 PLA
 PLB
 RTL

*-------------------------------------------------
* TCPOPEN
*-------------------------------------------------

TCPOPEN ENT
 DBGMSG TCPOPEN

 PHB
 PHK
 PLB

 TCPD 'TCP_OPEN'

 LDY #uwTCP_State
 LDA [USERPTR],Y
; CMP #tcpsLISTEN
; BEQ :LISTENING
 CMP #tcpsCLOSED
 BEQ :OPENIT
 LDA #tcperrConExists
 BRA SETERRORPLBRTL

;:LISTENING

; LDY #uwTCP_Active
; LDA [USERPTR],Y
; BNE :OPENIT

; JMP NOERROR

:OPENIT

* Zero out work area

 SEP $20
 LDA #0
 LDY #uwTCPVarStart
]L1 STA [USERPTR],Y
 INY
 CPY #uwTCPVarEnd
 BCC ]L1
 REP $20

* Save old user stuff

 LDY #uwIP_TTL
 LDA [USERPTR],Y
 PHA
 LDA #%00111100 ;1 minute
 STA [USERPTR],Y
 LDY #uwTCP_SaveTTL
 PLA
 STA [USERPTR],Y

 LDY #uwIP_TOS
 LDA [USERPTR],Y
 PHA
 LDA #0 ;all normal
 STA [USERPTR],Y
 LDY #uwTCP_SaveTOS
 PLA
 STA [USERPTR],Y

* Set default send and receive max seg sizes

 LDY #uwTCPMaxSendSeg
 LDA >TCPMAXSEGSEND
 STA [USERPTR],Y

 LDY #uwTCPMaxReceiveSeg
 LDA >TCPMAXSEGRECEIVE
 STA [USERPTR],Y

 LDY #uwRCV_WND
 LDA >TCPRECEIVEWINDOW
 STA [USERPTR],Y

* Set timer values

 LDY #uwTCP_rt_timer
 LDA #RT_TIME
 STA [USERPTR],Y
 LDY #uwTCP_2MSL_timer
 LDA #MSLX2_TIME
 STA [USERPTR],Y

* Set up data queues

 PHS 2
 JSL NEWQUEUE
 PLA
 LDY #uwTCPDataInQ
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y

 ~NewHandle #0;>MYID;#$0008;#0
 PLA
 LDY #uwTCPDataIn
 STA [USERPTR],Y
 PLA
 INY
 INY
 STA [USERPTR],Y

 ~NewHandle #0;>MYID;#$0008;#0
 PLA
 LDY #uwTCPDataOut
 STA [USERPTR],Y
 PLA
 INY
 INY
 STA [USERPTR],Y

* Bump open count

 INC TCPCONNECTIONS

* Active or passive?

 LDY #uwTCP_Server
 LDA tcCONNECTIONTYPE
 STA [USERPTR],Y
 BEQ :ACTIVE

* Passive (server) - initialise incoming (child) ipid list.

 PHS 2
 JSL NEWQUEUE ;This is a list of long IPIDs, not really a
 PLA ;queue of handles, so don't DESTROYQUEUE on it.
 LDY #uwTCP_ChildList
 STA [USERPTR],Y
 PLA
 INY
 INY
 STA [USERPTR],Y

 LDA #tcpsLISTEN
 JSR SETSTATE

 JMP NOERROR

:ACTIVE

* Initial send sequence number

 ~ReadTimeHex
 LDA 0,S
 AND #$FF00 ;Get seconds in high byte
 STA 4,S ;Save it somewhere
 LDA >$E100DC ;Heartbeat low byte provides 1/60 resolution
 ;and is continuously incremented. Gets reset
;on boot, but seconds/minutes make sure
;the sequence number doesn't get duplicated
;for at least 24 hours. 1/60 resolution
;provides unique sequence numbers for
;open/close/open sequences less than a second
;apart.
 AND #$FF
 ORA 4,S
 LDY #uwISS ;Initial sequence number
 STA [USERPTR],Y
 INY
 INY
 LDA 2,S ;Minutes and hours.
 STA [USERPTR],Y
 PLS 4

* Send SYN segment

 LDY #uwISS
 JSR GETVAR
 LDY #uwSND_NXT ;make it the next one
 JSR SETVAR

 LDY SKIPSYNFLAG
 BNE :SKIPSYN

 JSR SEND_SYN ;Send initial SYN (XA=seqnum)

:SKIPSYN

 LDY #uwISS
 JSR GETVAR
 LDY #uwSND_UNA
 JSR SETVAR
 INXA
 LDY #uwSND_NXT ;next one is ISS+1
 JSR SETVAR

 LDA #tcpsSYNSENT ;waiting for SYN reply
 JSR SETSTATE

 LDY #uwTCP_TimerState
 LDA #TCPT_SYN
 STA [USERPTR],Y

 JSR SETREXMITIMER ;set new timer

 JMP NOERROR

SKIPSYNFLAG DA 0

*-------------------------------------------------
* TCPWRITE
*-------------------------------------------------

TCPWRITE ENT
 DBGMSG TCPWRITE
 PHB
 PHK
 PLB

; TCPD 'TCP_WRITE'

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JMP (:TBL,X)

:TBL DA BADCONNECTION ;CLOSED
 DA :badstate ;LISTEN
 DA :QUEUEIT ;SYNSENT
 DA :QUEUEIT ;SYNRCVD
 DA :QUEUEIT ;ESTABLISHED
 DA CONCLOSING ;FINWAIT1
 DA CONCLOSING ;FINWAIT2
 DA :QUEUEIT ;CLOSEWAIT
 DA CONCLOSING ;LASTACK
 DA CONCLOSING ;CLOSING
 DA CONCLOSING ;TIMEWAIT

:badstate brk 0
 DBGMSG 'Bad state'
 DBGMSG 'Not written'
 DBGMSG 'yet!'
 bra *

:QUEUEIT PZL tcDATABUFFER
 PZL tcDATALENGTH
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL AddToHandle
 BCSL INSUFFICIENT ;If can't add to queue, report error

 PHS 2
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GetHandleSize ;Get size of queued data

 LDA 1,S
 ORA 1+2,S
 BEQ :OUTPL2 ;If nothing to send, then just exit...

* Do push stuff

 LDA tcPUSHFLAG
 BEQ :SKIPUSH

 LDY #uwTCPPushOutFlag
 STA [USERPTR],Y

 LDA 1,S ;Subtract one, to make it last byte in buffer
 SEC
 SBC #1
 STA 1,S
 LDA 1+2,S
 SBC #0
 STA 1+2,S

 LDY #uwSND_UNA ;Add it to the UNA
 LDA [USERPTR],Y
 CLC
 ADC 1,S
 LDY #uwTCPPushOutSEQ
 STA [USERPTR],Y
 LDY #uwSND_UNA+2
 LDA [USERPTR],Y
 ADC 1+2,S
 LDY #uwTCPPushOutSEQ+2
 STA [USERPTR],Y
:SKIPUSH

* Set timers and exit.

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsSYNSENT ;Still haven't got SYN.
 BEQ :SKIPTIMER

 LDA #TCPT_DATA
 LDY #uwTCP_TimerState
 STA [USERPTR],Y

 JSR SETIMERNOW ;set new timer to NOW!

:SKIPTIMER

:OUTPL2 PLS 2

 PLB
 RTL

*-------------------------------------------------
* TCPREAD
*-------------------------------------------------

TCPREAD ENT
 DBGMSG TCPREAD

 PHB
 PHK
 PLB

 LDY #rrlen-2
 LDA #0
]L1 STA [tcRESPONSEBUFFPTR],Y
 DEY
 DEY
 BPL ]L1

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX

 do TCPDEBUG
 PHX
 TCPSAY 'TCPREAD:'
 LDA 1,S
 TAX
 LDA STATEINDEX,X
 JSR DUMPSTRING
 LDY #uwDestIP
 LDA [USERPTR],Y
 XBA
 PHA
 INY
 INY
 LDA [USERPTR],Y
 XBA
 PHA
 PHL #IPSTR+1
 PEA 8
 _Long2Hex
 LDA #IPSTR
 JSR DUMPSTRING
 LDY #uwDestPort
 LDA [USERPTR],Y
 PHA
 PHL #PORTSTR+1
 PEA 4
 _Int2Hex
 LDA #PORTSTR
 JSR DUMPSTRING
 PLX
 fin

 JMP (:TBL,X)

:TBL DA BADCONNECTION ;CLOSED
 DA INSUFFICIENT ;LISTEN
 DA INSUFFICIENT ;SYNSENT
 DA INSUFFICIENT ;SYNRCVD
 DA :CHECKQUEUE ;ESTABLISHED
 DA :CHECKQUEUE ;FINWAIT1
 DA :CHECKQUEUE ;FINWAIT2
 DA :ANYLEFT ;CLOSEWAIT
 DA :CONCLOSING ;LASTACK
 DA :CONCLOSING ;CLOSING
 DA :CONCLOSING ;TIMEWAIT

:CONCLOSING
 TCPSAY ' conclosing - should not return data here?'
 PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 PLA
 STA :WORKLEN
 PLA
 STA :WORKLEN+2
 ORA :WORKLEN
 BEQ :NODATA
 TCPSAY ' - data!!!',0d
 JMP CONCLOSING
:NODATA
 TCPSAY ' - no data',0d
 JMP CONCLOSING

:ANYLEFT PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 PLA
 STA :WORKLEN
 PLA
 STA :WORKLEN+2
 ORA :WORKLEN
 BNE :SOMEDATA
 JSR :NORETURN
 JMP CONCLOSING

:CHECKQUEUE PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 PLA
 STA :WORKLEN
 PLA
 STA :WORKLEN+2
 ORA :WORKLEN
 BNE :SOMEDATA
:NOTHING JSR :NORETURN
 JMP NOERROR
:SOMEDATA

 do TCPDEBUG
 TCPSAY ' handlesize: '
 LDA :WORKLEN+2
 LDX :WORKLEN
 JSR TCPLONG
 fin

* Set up buffers

 LDA tcDATALENGTH ;Is the user's buffer big enough for something?
 STA TCPLEN
 LDA tcDATALENGTH+2
 STA TCPLEN+2
 ORA TCPLEN
 BEQ :NOTHING

* If looking for a delimiter, then do so!

 LDA tcDELIMITSTRING
 ORA tcDELIMITSTRING+2
 BNEL LOOKFORDELIMIT

* :WORKLEN is data in me, TCPLEN is size of callers buffer

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSEWAIT
* BEQ :IMPLYPUSH
 BNE :CHKPUSH
 LDA :WORKLEN+2
 LDX :WORKLEN
 BRA :IMPLIEDPUSH
:CHKPUSH
 LDY #uwTCPPushInFlag
 LDA [USERPTR],Y
 BEQ :NOPUSH

 LDY #uwTCPPushInOffset
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y

:IMPLIEDPUSH
 CMP TCPLEN+2 ;if less than buffer size, use it instead
 BCC :USEPUSH
 BNE :FILLBUFF
 CPX TCPLEN
 BCS :FILLBUFF
:USEPUSH STA :WORKLEN+2
 STX :WORKLEN
:IMPLYPUSH LDA #1
 BRA :PUSHME

:FILLBUFF LDA TCPLEN
 STA :WORKLEN
 LDA TCPLEN+2
 STA :WORKLEN+2
 LDA #0

:PUSHME LDY #rrPushFlag
 STA [tcRESPONSEBUFFPTR],Y
 BRA :SUCKDATA

:NOPUSH LDA #0
 LDY #rrPushFlag
 STA [tcRESPONSEBUFFPTR],Y

* OK, can we fill the buffer

 LDX TCPLEN
 LDA TCPLEN+2
 CMP :WORKLEN+2
 BCC :USETCPLEN ;fill the buffer (ie. use his size)
 BNE :RESIDUE? ;can't fill it, check if closewait ie. no more
 CPX :WORKLEN
 BCC :USETCPLEN
 BEQ :USETCPLEN

:RESIDUE? LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSEWAIT ;FIN was received, so return what I have.
 BNEL :NOTHING
 BRA :SUCKDATA ;Use what we have to give

:USETCPLEN STX :WORKLEN
 STA :WORKLEN+2

* OK, getting (:WORKLEN) data into the buffer

:SUCKDATA PHS 2
 LDA :WORKLEN+2
 PHA
 LDA :WORKLEN
 PHA
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL ReadFromHandle

 TCPSAY ' returning '
 LDA tcBUFFTYPE
 BEQ :PTR
 DEC
 BEQ :HANDLE

:NEWHANDLE LDY #rrBuffHandle
 PLA
 STA [tcRESPONSEBUFFPTR],Y
 TAX
 INY
 INY
 PLA
 STA [tcRESPONSEBUFFPTR],Y
 PHS 2
 PHA
 PHX
 LDY #uwUserID
 LDA [USERPTR],Y
 STA 5,S
 _SetHandleID
 PLS
 TCPSAY ' new Handle',0d
 BRL :GOTDATA

:HANDLE PHL :WORKLEN
 PZL tcDATABUFFER
 _SetHandleSize
 LDA 3,S
 PHA
 LDA 3,S
 PHA
 PZL tcDATABUFFER
 PHL :WORKLEN
 _HandToHand
 _DisposeHandle
 TCPSAY ' user Handle',0d
 BRA :GOTDATA

:PTR LDA 3,S
 PHA
 LDA 3,S
 PHA
 PZL tcDATABUFFER
 PHL :WORKLEN
 _HandToPtr
 _DisposeHandle
 TCPSAY ' PTR',0d

* OK, filled the buffer, set up generic output stuff

:GOTDATA LDY #rrBuffCount
 LDA :WORKLEN
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 LDA :WORKLEN+2
 STA [tcRESPONSEBUFFPTR],Y

 PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 LDY #rrMoreFlag
 PLA
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 PLA
 STA [tcRESPONSEBUFFPTR],Y

 LDY #rrUrgentFlag
 LDA #0
 STA [tcRESPONSEBUFFPTR],Y ;urgent

* Finally, update the push offset

*  ...the offset will always be equal to or greater than the data just copied.

 LDY #uwTCPPushInFlag
 LDA [USERPTR],Y ;Pending push?
 BEQ :DONEOUT

 LDY #uwTCPPushInOffset
 LDA [USERPTR],Y
 SEC
 SBC :WORKLEN
 TAX
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 SBC :WORKLEN+2
 STA [USERPTR],Y
 DEY
 DEY
 ORA [USERPTR],Y
 BNE :PUSHSTILLVALID
 LDY #uwTCPPushInFlag
 STA [USERPTR],Y

:PUSHSTILLVALID

:DONEOUT LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSEWAIT
 BNE :OUT
 JMP CONCLOSING
:OUT JMP NOERROR

:NORETURN LDA #0
 LDY #rrBuffCount
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 STA [tcRESPONSEBUFFPTR],Y ;+2

 LDY #rrBuffHandle
 STA [tcRESPONSEBUFFPTR],Y ;handle
 INY
 INY
 STA [tcRESPONSEBUFFPTR],Y ;+2

 LDY #rrPushFlag
 STA [tcRESPONSEBUFFPTR],Y ;push

 LDY #rrUrgentFlag
 STA [tcRESPONSEBUFFPTR],Y ;urgent

 LDY #rrMoreFlag
 LDA :WORKLEN
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 LDA :WORKLEN+2
 STA [tcRESPONSEBUFFPTR],Y

 TCPSAY ' - no data returned',0d

 RTS

:WORKLEN ADRL 0

*-------------------------------------------------
* LOOKFORDELIMIT
*-------------------------------------------------

LOOKFORDELIMIT DBGMSG LOOKFORDELIMIT

 DBGMSG LOOKFORDELIMIT

* Parse off bit flag

 LDA tcDELIMITSTRING+2
 AND #$8000
 STA :STRIPFLAG

* First find length of delimiter and bump pointer to actual string

 LDA [tcDELIMITSTRING]
 AND #$FF
 STA :STRINGLEN
 INCR tcDELIMITSTRING

* Find length of received data

 PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 PLXA :RECEIVESIZE

* Would a delimiter fit in the receive buffer?

 LDA :RECEIVESIZE+2
 BNE :DELIMFIT
 LDA :STRINGLEN
 CMP :RECEIVESIZE
 BEQ :DELIMFIT
 BCSL :NOLINE
:DELIMFIT

* Get last index into buffer to search for delimit

 LDA :RECEIVESIZE
 SEC
 SBC :STRINGLEN
 STA :INDEX
 LDA :RECEIVESIZE
 SBC #0
 STA :INDEX+2

* Start plowing through buffer for delimiter

 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 STA TMPHANDLE+2
 DEY
 DEY
 LDA [USERPTR],Y
 STA TMPHANDLE
 LDA [TMPHANDLE]
 STA TMPTR
 STA :RECEIVEPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 STA :RECEIVEPTR+2

 LDA TMPTR
 CLC
 ADC :INDEX
 STA :LASTPTR
 LDA TMPTR+2
 ADC :INDEX+2
 STA :LASTPTR+2

* Check this character

:SCANLOOP

 SEP $20
 LDY :STRINGLEN
 DEY
]L1 LDA [TMPTR],Y
 CMP [tcDELIMITSTRING],Y
 BNEL :NOMATCH
 DEY
 BPL ]L1
 REP $20

* Match! Work out how much data to remove. First calculate our index.

 LDA TMPTR
 SEC
 SBC :RECEIVEPTR
 TAX
 LDA TMPTR+2
 SBC :RECEIVEPTR+2
 STXA :INDEX
 LDY :STRIPFLAG
 BEQ :NOSTRIP1
 PHA
 TXA
 CLC
 ADC :STRINGLEN
 TAX
 PLA
 ADC #0
:NOSTRIP1 STXA :RETURNSIZE ;Now have length of data to return

 CMP tcDATALENGTH+2
 BCC :WILLFIT
 BNE :NOFIT
 CPX tcDATALENGTH
 BCC :WILLFIT
 BEQ :WILLFIT
:NOFIT LDY #rlrBuffSize+2
 STA [tcRESPONSEBUFFPTR],Y
 TXA
 DEY
 DEY
 STA [tcRESPONSEBUFFPTR],Y
 JSR :SETMOREFLAG
 LDA #terrBUFFERTOOSMALL&terrmask
 PLB
 RTL

:WILLFIT

* Will fit, so grab the data from Marinetti

 PHS 2
 PHXA ;size
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL ReadFromHandle ;ReadFromHandle(length,master):handle
;handle is on stack

 LDY #rlrIsDataFlag
 LDA #true
 STA [tcRESPONSEBUFFPTR],Y

 LDA tcBUFFTYPE
 BEQ :PTR
 DEC
 BEQ :HANDLE

:NEWHANDLE LDY #rlrBuffHandle
 PLA
 STA [tcRESPONSEBUFFPTR],Y
 TAX
 INY
 INY
 PLA
 STA [tcRESPONSEBUFFPTR],Y
 PHS 2
 PHA
 PHX
 LDY #uwUserID
 LDA [USERPTR],Y
 STA 5,S
 _SetHandleID
 PLS
 BRL :GOTDATA

:HANDLE PHL :RETURNSIZE
 PZL tcDATABUFFER
 _SetHandleSize
 LDA 3,S
 PHA
 LDA 3,S
 PHA
 PZL tcDATABUFFER
 PHL :RETURNSIZE
 _HandToHand
 _DisposeHandle
 BRA :GOTDATA

:PTR LDA 3,S
 PHA
 LDA 3,S
 PHA
 PZL tcDATABUFFER
 PHL :RETURNSIZE
 _HandToPtr
 _DisposeHandle

:GOTDATA

* OK, user has the data, no all left is to rip out delimiter if he didn't
* take it.

 LDY :STRIPFLAG
 BNE :NOSTRIPPED

 PHS 2
 PEA 0
 LDA :STRINGLEN
 PHA
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL ReadFromHandle ;ReadFromHandle(length,master):handle
 _DisposeHandle ;Fuck it off
:NOSTRIPPED

 LDY #rlrBuffCount
 LDA :RETURNSIZE
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 LDA :RETURNSIZE+2
 STA [tcRESPONSEBUFFPTR],Y
 LDY #rlrBuffSize
 LDA :RETURNSIZE
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 LDA :RETURNSIZE+2
 STA [tcRESPONSEBUFFPTR],Y

 BRA :EXITOK

* No match -- iterate

:NOMATCH REP $20
 INCR TMPTR
 LDA TMPTR
 CMP :LASTPTR
 BNEL :SCANLOOP
 LDA TMPTR+2
 CMP :LASTPTR+2
 BNEL :SCANLOOP

* Exit code

:EXITOK
:NOLINE JSR :SETMOREFLAG
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 PLB
 RTL

:SETMOREFLAG LDA :RECEIVESIZE ;If data in buffer at least, set rrMoreFlag
 ORA :RECEIVESIZE+2
 BEQ :NOMORE
 LDA #true
 LDY #rlrMoreFlag
 STA [tcRESPONSEBUFFPTR],Y
:NOMORE RTS

:STRIPFLAG DA 0 ;hi bit is flag
:STRINGLEN DA 0
:RECEIVESIZE ADRL 0 ;Marinetti's received data size
:INDEX ADRL 0 ;Last index in buffer to search
; and when found, actual index.
:LASTPTR ADRL 0 ;Pointer to last in buffer
:RECEIVEPTR ADRL 0 ;Pointer to start of buffer
:RETURNSIZE ADRL 0 ;Actual size of data to return

*-------------------------------------------------
* TCPCLOSE
*-------------------------------------------------

TCPCLOSE ENT
 DBGMSG TCPCLOSE

 PHB
 PHK
 PLB

 TCPD 'TCP_CLOSE'

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JMP (:TBL,X)

:TBL DA BADCONNECTION ;CLOSED
 DA :CLOSEOUT ;LISTEN
 DA :CLOSEOUT ;SYNSENT
 DA :SYNRCVD ;SYNRCVD
 DA :ESTABLISHED ;ESTABLISHED
 DA CONCLOSING ;FINWAIT1
 DA CONCLOSING ;FINWAIT2
 DA :CLOSEWAIT ;CLOSEWAIT
 DA CONCLOSING ;LASTACK
 DA CONCLOSING ;CLOSING
 DA CONCLOSING ;TIMEWAIT

:CLOSEOUT LDA #tcpsCLOSED
 JSR SETSTATE
 JMP NOERROR

:ESTABLISHED LDA #tcpsFINWAIT1
 JSR SETSTATE
 JSR MARKANDQUEUEFIN
 JSR SETIMERNOW
 JMP NOERROR

:SYNRCVD JSR GETOUTSIZE
 BNE :NOFINWAIT1
 JSR MARKANDQUEUEFIN
 JSR SETIMERNOW
 LDA #tcpsFINWAIT1
 JSR SETSTATE
:NOFINWAIT1 JMP NOERROR

:CLOSEWAIT JSR MARKANDQUEUEFIN
 JSR SETIMERNOW
 LDA #tcpsCLOSING
 JSR SETSTATE
 JMP NOERROR

*-------------------------------------------------
* TCPABORT
*-------------------------------------------------

TCPABORT ENT
 DBGMSG TCPABORT

 PHB
 PHK
 PLB

 TCPD 'TCP_ABORT'

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JMP (:TBL,X)

:TBL DA BADCONNECTION ;CLOSED
 DA :CLOSEOUT ;LISTEN
 DA :CLOSEOUT ;SYNSENT
 DA :RESET ;SYNRCVD
 DA :RESET ;ESTABLISHED
 DA :RESET ;FINWAIT1
 DA :RESET ;FINWAIT2
 DA :RESET ;CLOSEWAIT
 DA :CLOSEOUTOK ;LASTACK
 DA :CLOSEOUTOK ;CLOSING
 DA :CLOSEOUTOK ;TIMEWAIT

:RESET LDY #uwSND_NXT
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 JSR SEND_RST
:CLOSEOUT LDA #tcpsCLOSED
 JSR SETSTATE
 LDA #tcperrConReset
 JMP SETERRORPLBRTL

:CLOSEOUTOK LDA #tcpsCLOSED
 JSR SETSTATE
 JMP NOERROR

*-------------------------------------------------
* SUBROUTINES
*-------------------------------------------------

TCPOPTIONS DBGMSG TCPOPTIONS ;Checks for option list. Assumes BUILDPOINTERS.
 LDY #tcp_offset
 LDA [TCPHEADER],Y
 LSR
 LSR
 LSR
 LSR
 AND #$F
 ASL
 ASL
 CMP #21
 BCC :NONE ;any options after TCP header?
 PHA ;offset to data (after options)
 LDY #20
:TOPLOOP LDA [TCPHEADER],Y ;start scanning
 AND #$FF
 BEQ :DONE
 CMP #1
 BEQ :NOP
 CMP #2
 BEQ :MAXSEG
:NOP INY
:NEXT TYA
 CMP 1,S
 BCC :TOPLOOP
:DONE PLS
:NONE RTS
:MAXSEG INY
 INY
 PHY
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_SYN
 BEQ :NOMAX ;invalid if not SYN set
 PLY
 PHY
 LDA [TCPHEADER],Y
 XBA
 BEQ :NOMAX ;Cannot be zero
 LDY #uwTCPMaxSendSeg
 STA [USERPTR],Y
:NOMAX PLY
 INY
 INY
 BRA :NEXT

* in:  TCPINHANDLE is raw segment locked down
* out: TCPIPHEADER - pointer to IP header
*      TCPHEADER   - pointer to TCP header
*      TCPDATA     - pointer to TCP data
*      TCPDATALEN  - length of TCP data (word)

BUILDPOINTERS DBGMSG BUILDPOINTERS

 LDA [TCPINHANDLE]
 STA TCPIPHEADER
 LDY #2
 LDA [TCPINHANDLE],Y
 STA TCPIPHEADER+2

 LDA [TCPIPHEADER] ;IP header len in longwords
 AND #$0F
 ASL ;words
 ASL ;bytes
 CLC
 ADC TCPIPHEADER
 STA TCPHEADER
 LDA TCPIPHEADER+2
 ADC #0
 STA TCPHEADER+2

 LDY #tcp_offset
 LDA [TCPHEADER],Y
 LSR
 LSR
 LSR
 LSR
 AND #$F
 ASL
 ASL
 CLC
 ADC TCPHEADER
 STA TCPDATA
 LDA TCPHEADER+2
 ADC #0
 STA TCPDATA+2

 LDA TCPDATA
 SEC
 SBC TCPIPHEADER
 PHA
 LDY #ip_len
 LDA [TCPIPHEADER],Y
 XBA
 SEC
 SBC 1,S
 STA TCPDATALEN
 PLS

 RTS

GETVAR DBGMSG GETVAR
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 DEY
 DEY
 RTS

SETVAR DBGMSG SETVAR
 PHA
 TXA
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y
 DEY
 DEY
 RTS

* SETSTATEL - A=new state
*
* Must have my direct page set as well as an open user entry

SETSTATEL ENT ;Called from another module
 DBGMSG SETSTATEL
 PHB
 PHK
 PLB
 JSR SETSTATE
 PLB
 RTL

SETSTATE DBGMSG SETSTATE

 LDY #uwTCP_State
 STA [USERPTR],Y
 PHA

 PHS 2
 JSL GETTICK
 LDY #uwTCP_StateTick
 PLA
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y

 PLA
 CMP #tcpsCLOSED
 BEQ :HANDLECLOSE

 CMP #tcpsTIMEWAIT
 BEQ :HANDLETIMEWAIT

 RTS

:HANDLETIMEWAIT DBGMSG :HANDLETIMEWAIT

 PEA 0
 PEA 0
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 _SetHandleSize

 TCPSAY 'TIMEWAIT:STARTING 2MSL TIMER',0D

 JMP SET2MSLTIMER

:HANDLECLOSE DBGMSG :HANDLECLOSE

 do TCPDEBUG
 LDA >DEBUGTCP
 BEQL :SKIPASC
 TCPSAY 'SETSTATE:Closing connection',0D
 TCPSAY ' src: '
 LDA MYIPADDRESS
 XBA
 PHA
 LDA MYIPADDRESS+2
 XBA
 PHA
 PHL #IPSTR+1
 PEA 8
 _Long2Hex
 LDA #IPSTR
 JSR DUMPSTRING

 LDY #uwSourcePort
 LDA [USERPTR],Y
 PHA
 PHL #PORTSTR+1
 PEA 4
 _Int2Hex
 LDA #PORTSTR
 JSR DUMPSTRING

 TCPSAY ' dest: '
 LDY #uwDestIP
 LDA [USERPTR],Y
 XBA
 PHA
 INY
 INY
 LDA [USERPTR],Y
 XBA
 PHA
 PHL #IPSTR+1
 PEA 8
 _Long2Hex
 LDA #IPSTR
 JSR DUMPSTRING

 LDY #uwDestPort
 LDA [USERPTR],Y
 PHA
 PHL #PORTSTR+1
 PEA 4
 _Int2Hex
 LDA #PORTSTR
 JSR DUMPSTRING
:SKIPASC
 fin

 DEC TCPCONNECTIONS

* Restore old user stuff

 LDY #uwTCP_SaveTOS
 LDA [USERPTR],Y
 LDY #uwIP_TOS
 STA [USERPTR],Y

 LDY #uwTCP_SaveTTL
 LDA [USERPTR],Y
 LDY #uwIP_TTL
 STA [USERPTR],Y

* If server, delete all pendings

 LDY #uwTCP_Server
 LDA [USERPTR],Y ;server?
 BEQ :SKIPSERVER

 DBGMSG DELETESVRHANDLES

 LDY #uwTCP_ChildList+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 _DisposeHandle ;This SHOULD be empty

 DBGMSG SERVERDONE

:SKIPSERVER

* Delete handles

 LDY #uwTCPDataInQ+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL DESTROYQUEUE

 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 _DisposeHandle

 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 _DisposeHandle

 LDY #uwTCP_ForceFIN
 LDA #0
 STA [USERPTR],Y

 LDY #uwTCP_TimerState
 LDA #TCPT_OFF
 STA [USERPTR],Y

 TCPSAY 'CLOSED:CONNECTION CLOSED',0D

 RTS

GETOUTSIZE DBGMSG GETOUTSIZE
 PHS 2 ;Size of output data
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 PLX
 PLA
 CMP #0
 BNE :RTS
 CPX #0
:RTS RTS

*-------------------------------------------------
* TCPSTATUS
*-------------------------------------------------

TCPSTATUS ENT
 DBGMSG TCPSTATUS

 PHB
 PHK
 PLB

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 PHP

 LDY #uwDestIP+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 LDY #srDestIP
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 PLA
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwDestPort
 LDA [USERPTR],Y
 LDY #srDestPort
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwTCP_State
 LDA [USERPTR],Y
 LDY #srState
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwTCP_ICMPError
 LDA [USERPTR],Y
 LDY #srNetworkError
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwTCP_Server
 LDA [USERPTR],Y
 LDY #srConnectType
 STA [tcRESPONSEBUFFPTR],Y
 CMP #0
 BEQ :ACTIVE

 PHS
 LDY #uwTCP_ChildList+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL QUEUESIZE
 PLA
:ACTIVE LDY #srAcceptCount
 STA [tcRESPONSEBUFFPTR],Y

 PLP
 BEQ :ISCLOSED ;If closed, these queues don't exist...

 LDY #uwTCPDataOut
 LDA [USERPTR],Y
 STA TCPHANDLE
 INY
 INY
 LDA [USERPTR],Y
 STA TCPHANDLE+2
 LDY #8
 LDA [TCPHANDLE],Y
 TAX
 INY
 INY
 LDA [TCPHANDLE],Y
 LDY #srSndQueued+2
 STA [tcRESPONSEBUFFPTR],Y
 DEY
 DEY
 TXA
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwTCPDataIn
 LDA [USERPTR],Y
 STA TCPHANDLE
 INY
 INY
 LDA [USERPTR],Y
 STA TCPHANDLE+2
 LDY #8
 LDA [TCPHANDLE],Y
 TAX
 INY
 INY
 LDA [TCPHANDLE],Y
 LDY #srRcvQueued+2
 STA [tcRESPONSEBUFFPTR],Y
 DEY
 DEY
 TXA
 STA [tcRESPONSEBUFFPTR],Y

 PLB
 RTL

:ISCLOSED

 LDA #0
 LDY #srSndQueued+2
 STA [tcRESPONSEBUFFPTR],Y
 DEY
 DEY
 STA [tcRESPONSEBUFFPTR],Y
 LDY #srRcvQueued+2
 STA [tcRESPONSEBUFFPTR],Y
 DEY
 DEY
 STA [tcRESPONSEBUFFPTR],Y
 PLB
 RTL

*-------------------------------------------------
* MAIN INCOMING LOGIC - RFC 793, P65
*-------------------------------------------------

SEGMENTARRIVES ENT
 DBGMSG SEGMENTARRIVES(segmenthandle)
 PHB
 PHK
 PLB
 PLX
 PLY
 PLL TCPINHANDLE
 PHY
 PHX

 LOCK TCPINHANDLE
 JSR BUILDPOINTERS ;set everything up for main logic
 TCPSAY 'SEGMENTARRIVES:'
 TCPDRCV

* 1. INITIAL

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:INITIALTBL,X)
 BCSL :DONE

:NEXTSEGMENT

 LDY #tcp_window
 LDA [TCPHEADER],Y
 XBA
 LDY #uwSND_WND
 STA [USERPTR],Y ;Save his window

* 2. RST

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:RSTTBL,X)
 BCSL :DONE

* 3. SECURITY/PRECEDENCE
;not written

* 4. SYN

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:SYNTBL,X)
 BCS :DONE

* 5. ACK - if ACK off, drop and return

 LDY #tcp_code
 LDA [TCPHEADER],Y
 BIT #TCPF_ACK
 BEQ :DISCARD
 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:ACKTBL,X)
 BCS :DONE

* 6. URG

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:URGTBL,X)
 BCS :DONE

* 7. DATA

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:DATATBL,X)
 BCS :DONE

* 8. FIN

 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_FIN
 BEQ :SKIPFIN

 LDA #tcperrConClosing
 LDY #uwTCP_ErrCode
 STA [USERPTR],Y

 LDY #uwRCV_NXT
 JSR GETVAR
 INXA
 JSR SETVAR

 JSR SEND_ACK ;Must send now, because if this segment
;includes an ACK for my FIN, then both
;FINs are received, and the next routine will
;switch to TIMEWAIT, turning off the ACKPending
;timer, causing it never to be sent.

 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 JSR (:FINTBL,X)

:SKIPFIN

 JSR POLLPURGE

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 BEQ :DONE

 JSR CHECKCACHE
 BCCL :NEXTSEGMENT

:DONE PLB
 RTL

:DISCARD JSR POLLPURGE
 BRA :DONE

:INITIALTBL DA INITIAL_CLOSED
 DA INITIAL_LISTEN
 DA INITIAL_SYNSENT
 DA INITIAL_SYNRCVD
 DA INITIAL_ESTABLISHED
 DA INITIAL_FINWAIT1
 DA INITIAL_FINWAIT2
 DA INITIAL_CLOSEWAIT
 DA INITIAL_LASTACK
 DA INITIAL_CLOSING
 DA INITIAL_TIMEWAIT

:RSTTBL DA NEVER
 DA RST_LISTEN
 DA RST_SYNSENT ;dummy
 DA RST_SYNRCVD
 DA RST_ESTABLISHED
 DA RST_FINWAIT1
 DA RST_FINWAIT2
 DA RST_CLOSEWAIT
 DA RST_LASTACK
 DA RST_CLOSING
 DA RST_TIMEWAIT

:SYNTBL DA NEVER
 DA NEVER ;SYN-LISTEN
 DA SYN_SYNSENT ;dummy
 DA SYN_SYNRCVD
 DA SYN_ESTABLISHED
 DA SYN_FINWAIT1
 DA SYN_FINWAIT2
 DA SYN_CLOSEWAIT
 DA SYN_LASTACK
 DA SYN_CLOSING
 DA SYN_TIMEWAIT

:ACKTBL DA NEVER
 DA NEVER
 DA ACK_SYNSENT ;dummy
 DA ACK_SYNRCVD
 DA ACK_ESTABLISHED
 DA ACK_FINWAIT1
 DA ACK_FINWAIT2
 DA ACK_CLOSEWAIT
 DA ACK_LASTACK
 DA ACK_CLOSING
 DA ACK_TIMEWAIT

:URGTBL DA NEVER ;CLOSED
 DA NEVER ;LISTEN
 DA URG_SYNSENT ;fiddle - switches to ESTABLISHED
 DA NEVER ;SYNRCVD
 DA URG_ESTABLISHED
 DA URG_FINWAIT1
 DA URG_FINWAIT2
 DA URG_CLOSEWAIT
 DA URG_LASTACK
 DA URG_CLOSING
 DA URG_TIMEWAIT

:DATATBL DA NEVER ;CLOSED
 DA NEVER ;LISTEN
 DA NEVER ;SYNSENT
 DA NEVER ;SYNRCVD
 DA DATA_ESTABLISHED
 DA DATA_FINWAIT1
 DA DATA_FINWAIT2
 DA DATA_CLOSEWAIT
 DA DATA_LASTACK
 DA DATA_CLOSING
 DA DATA_TIMEWAIT

:FINTBL DA NEVER
 DA NEVER
 DA NEVER
 DA FIN_SYNRCVD
 DA FIN_ESTABLISHED
 DA FIN_FINWAIT1
 DA FIN_FINWAIT2
 DA FIN_CLOSEWAIT
 DA FIN_LASTACK
 DA FIN_CLOSING
 DA FIN_TIMEWAIT

NEVER DBGMSG NEVER
 brk 0
 DBGMSG 'never called'
 DBGMSG 'X=STATE*2'
 DBGMSG 'RTS to STEP'
 BRA *

*-------------------------------------------------
* INITIAL_* routines
*-------------------------------------------------

INITIAL_TIMEWAIT DBGMSG INITIAL_TIMEWAIT
INITIAL_SYNRCVD DBGMSG INITIAL_SYNRCVD
INITIAL_ESTABLISHED DBGMSG INITIAL_ESTABLISHED
INITIAL_FINWAIT1 DBGMSG INITIAL_FINWAIT1
INITIAL_FINWAIT2 DBGMSG INITIAL_FINWAIT2
INITIAL_CLOSEWAIT DBGMSG INITIAL_CLOSEWAIT
INITIAL_CLOSING DBGMSG INITIAL_CLOSING
INITIAL_LASTACK DBGMSG INITIAL_LASTACK
* 1.
 JSR PROCESSTHIS? ;p69
 BCS :DONE
 JSR TCPOPTIONS ;This segment is valid, so perform options!
 CLC
:DONE RTS

INITIAL_LISTEN DBGMSG INITIAL_LISTEN
 JSR TCPOPTIONS ;current, so do it

 LDY #tcp_code ;flags
 LDA [TCPHEADER],Y
 BIT #TCPF_RST
 BNEL :DISCARD
 BIT #TCPF_ACK
 BNEL :HANDLEACK ;NOT ALLOWED IN LISTEN STATE
 BIT #TCPF_SYN
 BEQL :DISCARD ;Nothing else, then discard

* Got a SYN -- wants to open a connection, so we need to create a new login
*              but this time make it non-server, as if we were initiaing it.

 PZL USERHANDLE
 PZL USERPTR

 PHS
 LDY #uwUserID
 LDA [USERPTR],Y
 PHA

 LDY #ip_src+2
 LDA [TCPIPHEADER],Y
 PHA
 DEY
 DEY
 LDA [TCPIPHEADER],Y
 PHA

 LDY #tcp_sport
 LDA [TCPHEADER],Y
 XBA
 PHA

 LDY #uwIP_TOS
 LDA [USERPTR],Y
 PHA
 LDY #uwIP_TTL
 LDA [USERPTR],Y
 PHA

 _TCPIPLogin ;USERPTR is trashed
 PLA ;also leaves IPID is location IPID. :-)
 BCSL :NOROOM ;reset it and exit...

 PHA ;a copy of the IPID for TCPIPopenTCP

 PHA
 LDY #tcp_dport ;This should be my port
 LDA [TCPHEADER],Y
 XBA
 PHA
 _TCPIPSetSourcePort

 INC SKIPSYNFLAG ;Make sure TCPIPOpenTCP doesn't actually send
;its SYN, because I want to do that.

 LDA 1,S ;IPID was pushed on stack above, use it
 PHA ;as space, and the IPID parm
 _TCPIPOpenTCP ;this sets up basically everything we need
 PLS ;...but leaves state as SYN_SENT.

 LDA #tcpsSYNRCVD ;We should still be LISTEN, and change
 JSR SETSTATE ;state lower down, but this is so the trace
;entry shows SYNRCVD and not SYNSENT.

 STZ SKIPSYNFLAG

* OK, we're all set. Now we need to add our IPID to the server's child list

 PLL TMPTR
 PLL TMPHANDLE ;Old user handle

 PHW >IPID ;Dummy queue entry
 PEA 0
 LDY #uwTCP_ChildList+2
 LDA [TMPTR],Y
 PHA
 DEY
 DEY
 LDA [TMPTR],Y
 PHA
 JSL ADDTOQUEUE ;Add it to the queue
 BCSL :NOROOM ;reset it and exit...

 UNLOCK TMPHANDLE ;Old user is now gone for this call

* OK, we're open, continue with incoming SYN handling

* Set RCV.NXT to SEG.SEQ+1
*     IRS     to SEG.SEQ

 LDY #tcp_seq+2
 LDA [TCPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA
 LDY #uwIRS
 JSR SETVAR
 INXA
 LDY #uwRCV_NXT
 JSR SETVAR

* Initial send sequence number

;Was done inside TCPIPOpenTCP

* Send a SYN segment

 LDY #uwRCV_NXT ;ACK=RCV.NXT
 JSR GETVAR
 PHXA
 LDY #uwISS ;SEQ=ISS
 JSR GETVAR
 PHXA
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_SYN+TCPF_ACK ;flags
 TCPD 'sending <SYN><ACK>'
 TCPDSEQ
 JSL TCPSENDDGM

* SND.NXT = ISS+1
* SND.UNA = ISS

 LDY #uwISS
 JSR GETVAR
 LDY #uwSND_UNA
 JSR SETVAR
 INXA
 LDY #uwSND_NXT
 JSR SETVAR

% LDA #tcpsSYNRCVD ;This was already set above, even though
% JSR SETSTATE ;this is the RFC point to do it.

 LDY #uwTCP_TimerState
 LDA #TCPT_SYNACK
 STA [USERPTR],Y

 JSR SETREXMITIMER ;set new timer

; JSR POLLPURGE
 CLC ;Continue processing
 RTS

:NOROOM PLS 4 ;Trash the save USERHANDLE and USERPTR
:HANDLEACK PEA 0 ;ACK - IGNORED, NOT ACKING
 PEA 0
 LDY #tcp_ack ;SEQ
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 PEA 0 ;LEN
 PHS 2 ;PTR
 PEA TCPF_RST
 TCPD 'sending <RST>'
 TCPDSEQ
 JSL TCPSENDDGM
:DISCARD JMP POLLPURGE

* If <RST>, ignore, else send a <RST>.

INITIAL_CLOSED DBGMSG INITIAL_CLOSED
 LDY #tcp_code ;flags
 LDA [TCPHEADER],Y
 BIT #TCPF_RST
 BEQL :DISCARD
 BIT #TCPF_ACK ;If ACK, use that, else use zero
 BNE :GOTACK

:NOACK LDY #tcp_seq
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 LDA 1,S ;Use ACK of SEG.SEQ+SEG.LEN
 CLC
 ADC TCPDATALEN
 STA 1,S
 LDA 1+2,S
 ADC #0
 STA 1+2,S
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_RST+TCPF_ACK
 TCPD 'sending <RST>'
 TCPDSEQ
 JSL TCPSENDDGM
 BRA :DISCARD

:GOTACK PEA 0 ;ACK
 PEA 0
 LDY #tcp_ack ;Use SEQ of SEG.ACK
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 PEA 0 ;LEN
 PHS 2 ;PTR
 PEA TCPF_RST
 TCPD 'sending <RST>'
 TCPDSEQ
 JSL TCPSENDDGM
:DISCARD JMP POLLPURGE

INITIAL_SYNSENT DBGMSG INITIAL_SYNSENT

* Is there an PCK?

 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_ACK
 BEQL :SKIPACK

 LDY #tcp_ack ;get his ack number
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA

 LDY #uwSND_NXT ;same as my next?
 LDA [USERPTR],Y
 CMP 1,S
 BNE :RESETSYN
 INY
 INY
 LDA [USERPTR],Y
 CMP 1+2,S
 BNE :RESETSYN

 PLS 2

 BRA :ACKOK

* Not correct sequence number. Must be an older connection. Reset it.

:RESETSYN LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BEQ :RSTOK
 TCPSAY ' wrong sequence number - dropping segment.',0D
 JMP POLLPURGE

:RSTOK TCPSAY ' wrong sequence number, sending <RST>.',0D
 PLXA ;got the wrong sequence number
 JSR SEND_RST ;reset it
 JMP POLLPURGE

* ACK was supplied and OK. If RST, go CLOSED.

:ACKOK LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BEQ :SKIPACKRST
 TCPSAY ' is resetting me. Going CLOSED.',0D
 LDA #tcpsCLOSED
 JSR SETSTATE
 LDA #tcperrConReset
 LDY #uwTCP_ErrCode
 STA [USERPTR],Y
 JMP POLLPURGE

* No ACK supplied. If RST, just drop it.

:SKIPACK LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BEQ :SKIPACKRST
 JMP POLLPURGE

:SKIPACKRST

* Check security and precedence

;not written

* Big time! Check for SYN.

 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_SYN
 BEQ :NOSYN

 LDY #tcp_seq+2 ;get HIS seqnum
 LDA [TCPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA

 LDY #uwIRS
 JSR SETVAR ;Save his initial sequence number
 INXA
 LDY #uwRCV_NXT
 JSR SETVAR

 LDY #uwSND_UNA ;count the SYN as acknowledged
 JSR GETVAR
 INXA
 JSR SETVAR

; LDY #tcp_window
; LDA [TCPHEADER],Y
; XBA
; LDY #uwSND_WND
; STA [USERPTR],Y ;Save his initial window

* OK, we're connected. Change state to ESTABLISHED.
* Need to rejoin the ESTABLISHED code at DATA_ESTABLISHED, so dummy each
* step until URG_SYNSENT, the one before DATA_SYNSENT, then switch modes
* there.

% LDA #tcpsESTABLISHED
% JSR SETSTATE

 STZ POSOFFSET
 STZ POSLENGTH ;Dummy a INITIAL_ESTABLISHED call

* Send back acknowledgement once data has been extracted and UNA advanced.

 LDY #uwTCP_ACKPending
 LDA #-1
 STA [USERPTR],Y

 CLC
 RTS

:NOSYN JMP POLLPURGE

*-------------------------------------------------
* RST_* routines
*-------------------------------------------------

RST_LISTEN DBGMSG RST_LISTEN ;ignored
 SEC
 RTS

RST_SYNSENT DBGMSG RST_SYNSENT
 CLC
 RTS

RST_SYNRCVD DBGMSG RST_SYNRCVD
* 2.
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BEQ :SKIPRST
 JSR POLLPURGE
 LDY #uwTCP_Server
 LDA [USERPTR],Y
 BEQ :ACTIVE
 LDA #tcpsLISTEN
 JSR SETSTATE
 SEC
 RTS
:ACTIVE LDA #tcperrConRefused
 LDY #uwTCP_ErrCode
 STA [USERPTR],Y
 LDA #tcpsCLOSED
 JSR SETSTATE
 SEC
 RTS
:SKIPRST CLC
 RTS

RST_CLOSING DBGMSG RST_CLOSING
RST_LASTACK DBGMSG RST_LASTACK
RST_TIMEWAIT DBGMSG RST_TIMEWAIT
RST_FINWAIT1 DBGMSG RST_FINWAIT1
RST_FINWAIT2 DBGMSG RST_FINWAIT2
RST_CLOSEWAIT DBGMSG RST_CLOSEWAIT
RST_ESTABLISHED DBGMSG RST_ESTABLISHED
* 2.
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BEQ :SKIPRST
 JSR POLLPURGE
 LDA #tcpsCLOSED
 JSR SETSTATE
 LDA #tcperrConReset
 LDY #uwTCP_ErrCode
 STA [USERPTR],Y
 SEC
 RTS
:SKIPRST CLC
 RTS

*-------------------------------------------------
* SYN_* routines
*-------------------------------------------------

SYN_SYNSENT DBGMSG SYN_SYNSENT
 CLC
 RTS

* Spec says to RST when SYN received in SYN-RECEIVED, however, we have fallen
* through from INITIAL_LISTEN, so we do have a SYN, albeit out of our window.
* Ignore it and fall through to rest of processing.

SYN_SYNRCVD DBGMSG SYN_SYNRCVD
 CLC
 RTS

SYN_ESTABLISHED DBGMSG SYN_ESTABLISHED
SYN_FINWAIT1 DBGMSG SYN_FINWAIT1
SYN_FINWAIT2 DBGMSG SYN_FINWAIT2
SYN_CLOSEWAIT DBGMSG SYN_CLOSEWAIT
SYN_CLOSING DBGMSG SYN_CLOSING
SYN_LASTACK DBGMSG SYN_LASTACK
SYN_TIMEWAIT DBGMSG SYN_TIMEWAIT
* 4.
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_SYN
 BEQ :SKIPSYN
 LDY #tcp_ack+2
 LDA [TCPHEADER],Y
 XBA
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA
 JSR SEND_RST
 LDA #tcperrConReset
 LDY #uwTCP_ErrCode
 STA [USERPTR],Y
 JSR POLLPURGE
 LDA #tcpsCLOSED
 JSR SETSTATE
 SEC
 RTS
:SKIPSYN CLC
 RTS

*-------------------------------------------------
* ACK_* routines
*-------------------------------------------------

ACK_SYNSENT DBGMSG ACK_SYNSENT
 CLC
 RTS

ACK_SYNRCVD DBGMSG ACK_SYNRCVD
* 5. Check for ACK
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_ACK
 BEQ :DROPIT
 JSR BASICACK
 BCC :GOESTAB
 JSR SEND_RST
 JMP POLLPURGE
:DROPIT JMP POLLPURGE
:GOESTAB LDA #tcpsESTABLISHED
 JSR SETSTATE
 LDY #uwTCP_TimerState
 LDA #TCPT_DATA
 STA [USERPTR],Y
 CLC
 RTS

ACK_CLOSEWAIT DBGMSG ACK_CLOSEWAIT
ACK_ESTABLISHED DBGMSG ACK_ESTABLISHED
 JSR BASICACK
 BCS :DONE
:DONE RTS

ACK_FINWAIT1 DBGMSG ACK_FINWAIT1
 JSR BASICACK
 BCS :DONE
 LDY #uwTCP_MyFINACKed?
 LDA [USERPTR],Y
 BEQ :SKIPACK
 LDA #tcpsFINWAIT2
 JSR SETSTATE
 LDY #uwTCP_ForceFIN ;Don't send anymore FINs.
 LDA #0
 STA [USERPTR],Y
:SKIPACK CLC
:DONE RTS

ACK_FINWAIT2 DBGMSG ACK_FINWAIT2
 JSR BASICACK
 BCS :DONE
:DONE RTS

ACK_LASTACK DBGMSG ACK_LASTACK
 JSR BASICACK
 BCS :DONE
 LDY #uwTCP_MyFINACKed?
 LDA [USERPTR],Y
 BEQ :SKIPACK
 LDA #tcpsCLOSED
 JSR SETSTATE
 SEC
:DONE RTS
:SKIPACK JMP POLLPURGE

ACK_CLOSING DBGMSG ACK_CLOSING
 JSR BASICACK
 BCS :DONE
 LDY #uwTCP_MyFINACKed?
 LDA [USERPTR],Y
 BEQ :SKIPACK
 LDA #tcpsTIMEWAIT
 JSR SETSTATE
 CLC
:DONE RTS
:SKIPACK JMP POLLPURGE

ACK_TIMEWAIT DBGMSG ACK_TIMEWAIT
 JSR SEND_ACK
 JSR SET2MSLTIMER
 CLC
 RTS

*-------------------------------------------------
* URG_* routines
*-------------------------------------------------

URG_SYNSENT DBGMSG URG_SYNSENT
 LDA #tcpsESTABLISHED
 JSR SETSTATE
 LDY #uwTCP_TimerState
 LDA #TCPT_DATA
 STA [USERPTR],Y
 CLC
 RTS

URG_ESTABLISHED DBGMSG URG_ESTABLISHED
URG_FINWAIT1 DBGMSG URG_FINWAIT1
URG_FINWAIT2 DBGMSG URG_FINWAIT2
* 6. Check URG
 CLC
 RTS

URG_CLOSEWAIT DBGMSG URG_CLOSEWAIT
URG_CLOSING DBGMSG URG_CLOSING
URG_LASTACK DBGMSG URG_LASTACK
URG_TIMEWAIT DBGMSG URG_TIMEWAIT
 CLC
 RTS

*-------------------------------------------------
* DATA_* routines
*-------------------------------------------------

DATA_ESTABLISHED DBGMSG DATA_ESTABLISHED
DATA_FINWAIT1 DBGMSG DATA_FINWAIT1
DATA_FINWAIT2 DBGMSG DATA_FINWAIT2
 TCPSAY ' DATA_* -- adding to output buffer.',0D
 JSR HANDLEDATA
 BCC :DONE
 TCPSAY ' DATA_* -- error during HandleData - purging segment.',0D
 JMP POLLPURGE
:DONE RTS

DATA_CLOSEWAIT DBGMSG DATA_CLOSEWAIT
DATA_CLOSING DBGMSG DATA_CLOSING
DATA_LASTACK DBGMSG DATA_LASTACK
DATA_TIMEWAIT DBGMSG DATA_TIMEWAIT
 TCPSAY ' DATA_* -- ignoring (RFC793 pg 75).',0D
 CLC
 RTS

*-------------------------------------------------
* FIN_* routines
*-------------------------------------------------

FIN_SYNRCVD DBGMSG FIN_SYNRCVD
FIN_ESTABLISHED DBGMSG FIN_ESTABLISHED
 LDA #tcpsCLOSEWAIT
 JSR SETSTATE
 CLC
 RTS

FIN_FINWAIT1 DBGMSG FIN_FINWAIT1
 LDY #uwTCP_MyFINACKed?
 LDA [USERPTR],Y
 BEQ :GOCLOSING
 LDA #tcpsTIMEWAIT
 JSR SETSTATE
 CLC
 RTS
:GOCLOSING LDA #tcpsCLOSING
 JSR SETSTATE
 CLC
 RTS

FIN_FINWAIT2 DBGMSG FIN_FINWAIT2
 LDA #tcpsTIMEWAIT
 JSR SETSTATE
 CLC
 RTS

FIN_TIMEWAIT DBGMSG FIN_TIMEWAIT
 JSR SET2MSLTIMER
 CLC
 RTS

FIN_CLOSEWAIT DBGMSG FIN_CLOSEWAIT
FIN_CLOSING DBGMSG FIN_CLOSING
FIN_LASTACK DBGMSG FIN_LASTACK

*-------------------------------------------------
* Main logic subroutines
*-------------------------------------------------

CHECKCACHE DBGMSG CHECKCACHE

 TCPSAY ' check cache for delayed segments.',0D

 STZ FRAGINDEX ;Can use this, sort of the same thing. :-)

:NEXTSEG PHS 2
 PEI FRAGINDEX
 LDY #uwTCPDataInQ+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL FINDINQUEUE
 PLA
 STA TCPINHANDLE
 PLA
 STA TCPINHANDLE+2
 ORA TCPINHANDLE
 BEQ :NOMORE

 LOCK TCPINHANDLE

 JSR BUILDPOINTERS ;Set it all up for us to check

 PHS 3 ;space for reply
 LDY #tcp_seq ;wanted seq number
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 PEI TCPDATALEN ;length I have available
 LDY #uwRCV_NXT+2 ;receive window
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA ;Window start
 JSL POSCALC
 BCCL :GOTIT

 PLA ;get the flag
 BEQ :TOSSCACHESEG ;below, don't need it

 PLS 2 ;not yet...

 UNLOCK TCPINHANDLE

:SCANITERATE INC FRAGINDEX
 BRA :NEXTSEG

:NOMORE
 TCPSAY ' finished scanning cache.',0D
 SEC
 RTS

:TOSSCACHESEG DBGMSG :TOSSCACHESEG

% PLS 2

% PHS 2
 PEI FRAGINDEX
 LDY #uwTCPDataInQ+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL RIPFROMQUEUE ;Remove it from the queue...
 UNLOCK TCPINHANDLE ;...in TCPINHANDLE and on stack, take your pick.
 _DisposeHandle

 TCPSAY ' found old seg in cache - disposing.',0D

 INCREMENT >ERRORTABLE+tcpDGMSTCPOLD

 JMP :SCANITERATE

:GOTIT PHS 2
 PEI FRAGINDEX
 LDY #uwTCPDataInQ+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL RIPFROMQUEUE ;Remove it from the queue...
 PLS 2

 TCPSAY ' found next segment in local cache, adding to output buffer.',0D

 PLS ;flag from POSCALC
 PLW POSOFFSET ;offset from POSCALC
 PLW POSLENGTH ;length from POSCALC

 CLC
 RTS

POSOFFSET DA 0
POSLENGTH DA 0


HANDLEDATA DBGMSG HANDLEDATA

;Must go through here even if no data, so
;that push flags are handled.

* Add the data as received

 LDA POSOFFSET
 CLC
 ADC TCPDATA
 TAX
 LDA TCPDATA+2
 ADC #0
 PHA
 PHX
 PEA 0
 PHW POSLENGTH
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL AddToHandle
 BCS :ERR

* Bump total in count

 LDY #uwTCP_TotalIN
 LDA [USERPTR],Y
 CLC
 ADC POSLENGTH
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 ADC #0
 BCC :INCINOK
 LDA #-1
 DEY
 DEY
 STA [USERPTR],Y
 INY
 INY
:INCINOK STA [USERPTR],Y

* Bump next receive SEQ

 LDY #uwRCV_NXT
 LDA [USERPTR],Y
 CLC
 ADC POSLENGTH
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 ADC #0
 STA [USERPTR],Y

 LDA #-1
 LDY #uwTCP_ACKPending
 STA [USERPTR],Y

* Check for incoming push

 LDY #tcp_code ;flags
 LDA [TCPHEADER],Y
 AND #TCPF_PSH+TCPF_FIN ;FIN implies PSH
 BEQ :NOPSH
 PHS 2
 LDY #uwTCPDataIn+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 LDY #uwTCPPushInOffset
 PLA
 STA [USERPTR],Y
 INY
 INY
 PLA
 STA [USERPTR],Y
 LDA #1
 LDY #uwTCPPushInFlag
 STA [USERPTR],Y
:NOPSH

* adjust RCV_WND as appropriate to the current buffer availability (pg 74)
;not written

 CLC
:ERR RTS


PROCESSTHIS? DBGMSG PROCESSTHIS?

* OK, check out the data. Is it what I'm after? Empty segments must be in
* sequence to be actioned.

 LDA TCPDATALEN
 BNEL :CHECKWINDOW

 LDY #tcp_seq+2
 LDA [TCPHEADER],Y
 XBA
 LDY #uwRCV_NXT
 SEC
 SBC [USERPTR],Y
 TAX
 LDY #tcp_seq
 LDA [TCPHEADER],Y
 XBA
 LDY #uwRCV_NXT+2
 SBC [USERPTR],Y
 BMI :do_TOSSME1
 BNE :do_QUEUEIT
 TXA  ;faster way of doing CPX #0
 BEQ :continue
:do_QUEUEIT

* RSTs are processed if they are within the window (pg 37)
;not written

 TCPSAY ' PROCESSTHIS? -- no data, seq invalid.',0D
 BRA :QUEUEIT ;Seq > RCV.NXT
:do_TOSSME1 JMP :TOSSME1 ;Seq < RCV.NXT (retransmission?)
:continue   ;Seq = RCV.NXT
 TCPSAY ' PROCESSTHIS? -- no data, but seq is valid.',0D

 STZ POSOFFSET
 STZ POSLENGTH

 CLC
 RTS

:CHECKWINDOW

* If the RCV_WND is zero then no segments are acceptable, but special
* allowance should be made to accept valid ACKs, URGs and RSTs (pg 69)
;not written


 PHS 3 ;space for reply
 LDY #tcp_seq ;wanted seq number
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 PEI TCPDATALEN ;length I have available
 LDY #uwRCV_NXT+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA ;Window start
 JSL POSCALC
 BCCL :GOTNOWSEQ

 PLA ;get the flag
 BEQ :TOSSME ;below, don't need it

 PLS 2

:QUEUEIT ;add it to queue, not ready for it yet
 UNLOCK TCPINHANDLE
 PZL TCPINHANDLE
 LDY #uwTCPDataInQ+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL AddToQueue
% BCS :ERR ;(no need to do anything different)

 TCPSAY ' PROCESSTHIS? -- not required yet, adding to receive queue.',0D

 LDY #uwTCP_ACKPending
 LDA #-1
 STA [USERPTR],Y

 INCREMENT >ERRORTABLE+tcpDGMSTCPQUEUED

 SEC
 RTS

* Segment is duplicate or old.
*
*   1. If RST, toss segment and exit.
*   2. Send an ACK, telling where I am.

:TOSSME PLS 2
:TOSSME1 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_RST
 BNE :SKIPACK
 LDA #-1 ;Tell him the real SEQ before exiting.
 LDY #uwTCP_ACKPending
 STA [USERPTR],Y
:SKIPACK JSR POLLPURGE
 TCPSAY ' PROCESSTHIS? - disposing.',0D
 INCREMENT >ERRORTABLE+tcpDGMSTCPOLD
 SEC
 RTS

:GOTNOWSEQ TCPSAY ' PROCESSTHIS? -- correct segment',0D

:ADDTHISSEG ;three words from POSCALC are on the stack

 PLS ;flag from POSCALC
 PLW POSOFFSET ;offset from POSCALC
 PLW POSLENGTH ;length from POSCALC

 CLC
 RTS

* BASICACK - Standard ACK processing for most states

BASICACK DBGMSG BASICACK

 TCPSAY ' BASICACK -- processing incoming ACK.',0D

 LDY #tcp_ack+2
 LDA [TCPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA

 STX :ACK
 STA :ACK+2

 LDA :ACK ;Subtract to find which side I am
 SEC
 LDY #uwSND_UNA
 SBC [USERPTR],Y
 TAX
 LDA :ACK+2
 INY
 INY
 SBC [USERPTR],Y
 BCCL :OLDSEGMENT
; BMIL :OLDSEGMENT
 BNE :INWINDOW
 CPX #0
 BEQL :OLDSEGMENT

:INWINDOW ;xa contains length of data being ACKed...
 PHS 2
 PHA
 PHX

 do 0
* OK, so he's ACKing something more than I've had ACKed. Is it something that
* I am waiting on?   (If ACK=NXT or ACK<NXT then process, else dump it)

 LDA :ACK
 SEC
 LDY #uwSND_NXT
 SBC [USERPTR],Y
 TAX
 LDA :ACK+2
 INY
 INY
 SBC [USERPTR],Y
 BMI :DOACK
 BNE :BADACKPL4 ;way out of sequence (ahead of me)
 CPX #0
 BNE :BADACKPL4

:DOACK
 fin

* Is it ACKing my FIN as well? If so, take one byte off amount of data ACKed
* for the copy (but not the UNA).

 LDY #uwTCP_ForceFIN
 LDA [USERPTR],Y
 BEQ :SKIPFIN

 LDA :ACK
 SEC
 LDY #uwTCP_FINSEQ
 SBC [USERPTR],Y
 TAX
 INY
 INY
 LDA :ACK+2
 SBC [USERPTR],Y
 BMI :SKIPFIN ;No it doesn't

 LDA 1,S
 SEC
 SBC #1
 STA 1,S
 LDA 1+2,S
 SBC #0
 STA 1+2,S

 LDY #uwTCP_MyFINACKed?
 LDA #-1
 STA [USERPTR],Y
:SKIPFIN

* He's ACKing. Make sure all the ACK is actually pending.

 ;not written

* Finish the removal - add length to total out, then remove data from buffer

 LDY #uwTCP_TotalOUT
 LDA [USERPTR],Y
 CLC
 ADC 1,S
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 ADC 1+2,S
 BCC :INCOUTOK
 LDA #-1
 DEY
 DEY
 STA [USERPTR],Y
 INY
 INY
:INCOUTOK STA [USERPTR],Y

 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL ReadFromHandle ;If in SYN-SENT or SYN-RECEIVED, then he's
 _DisposeHandle ;ACKing my SYN, and the read will return an
;empty handle.

 TCPSAY ' BASICACK -- setting new SND.UNA (outgoing SEQ).',0D

 LDX :ACK
 LDA :ACK+2
 LDY #uwSND_UNA
 JSR SETVAR

* Check for outgoing push being ACKed

 LDY #uwTCPPushOutFlag
 LDA [USERPTR],Y
 BEQ :SKIPUSH

;PUSHSEQ - SNDUNA < 0   ---> Push is ACKed.

 LDY #uwTCPPushOutSEQ
 LDA [USERPTR],Y
 SEC
 LDY #uwSND_UNA
 SBC [USERPTR],Y
 TAX
 LDY #uwTCPPushOutSEQ+2
 LDA [USERPTR],Y
 LDY #uwSND_UNA+2
 SBC [USERPTR],Y
 BPL :SKIPUSH
 LDY #uwTCPPushOutFlag
 LDA #0
 STA [USERPTR],Y
:SKIPUSH

*

 CLC
 RTS

:GOTITPL4 PLS 4
:OLDSEGMENT
 CLC
 RTS

:BADACKPL4 PLS 4
 LDY #uwTCP_ACKPending
 LDA #-1
 STA [USERPTR],Y
 JMP POLLPURGE

:ACK ADRL 0

*-------------------------------------------------
* Timer checks
*-------------------------------------------------

* TCPPOLLTIMERS

TCPPOLLTIMERS ENT
 DBGMSG TCPPOLLTIMERS
 PHB
 PHK
 PLB
 LDY #uwTCP_TimerState
 LDA [USERPTR],Y
 TAX
 JSR (:TBL,X)
 PLB
 RTL

:TBL DA :OFF
 DA TIMER_SYN
 DA TIMER_DATA
 DA TIMER_2MSL
 DA TIMER_SYNACK

:OFF RTS

TIMER_SYN DBGMSG TIMER_SYN
 LDY #uwTCP_Timer ;See if we've timed out
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 JSL TIMERVALID?
 BCC :NOTYET
 TCPSAY 'TCPPOLLTIMERS:TIMER_SYN Valid',0D
 LDY #uwISS
 JSR GETVAR
 JSR SEND_SYN ;Send initial SYN (XA=seqnum)
 JSR SETREXMITIMER
:NOTYET RTS

TIMER_DATA DBGMSG TIMER_DATA

* Must we send something?

 LDY #uwTCP_ACKPending
 LDA [USERPTR],Y
 BNE :FORCESEND

* Are we allowed to send our window yet

 LDY #uwTCP_Timer ;See if we've timed out
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 JSL TIMERVALID?
 BCS :CHECKIT

 RTS

* Well, is there anything to do, now the timer has expired?
:CHECKIT
 TCPSAY 'TCPPOLLTIMERS:TIMER_DATA Valid',0D
 PHS 2
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 LDA 1,S
 ORA 1+2,S
 BNE :PL2FORCESEND
 PLS 2

* How about a fin?

 LDY #uwTCP_ForceFIN
 LDA [USERPTR],Y
 BNEL :FORCEFIN

 RTS

:PL2FORCESEND PLS 2

:FORCESEND

* Reset my sequence numbers to the last acknowledged byte

 LDY #uwSND_UNA
 JSR GETVAR
 LDY #uwSND_NXT
 JSR SETVAR

* Do I have a window?

 LDY #uwSND_WND
 LDA [USERPTR],Y
 BEQL :NOWINDOW

* See if there is data to send...

 PHS 2
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETHANDLESIZE
 LDA 1,S
 ORA 1+2,S
 BNE :SENDSOME

 PLS 2
 BRL :FORCEEMPTY

;* No data. Is there a FIN to send?

; LDY #uwTCP_ForceFIN
; LDA [USERPTR],Y
; BNEL :FORCEFIN
; RTS

:SENDSOME

* Work out how much I can send... DataOut size is still on stack...

 LDY #uwSND_WND ;how much can I send?
 LDA 1+2,S
 BNE :USEWND
 LDA 1,S
 CMP [USERPTR],Y
 BCC :USEA
 BEQ :USEA
:USEWND LDA [USERPTR],Y
:USEA
 STA TCPMAX ;length of data to send - split it into segs

* Now send all the data up to TCPMAX

 STZ TCPOFFSET ;start at beginning of buffer
 STZ TCPOFFSET+2
 STZ TCPCOUNT ;start with none

:NEXTSEND PHS 2
 PZL TCPOFFSET
 LDY #uwTCPMaxSendSeg
 LDA [USERPTR],Y
 CMP TCPMAX
 BCC :SENDTHIS
% BEQ :SENDTHIS
 LDA TCPMAX
:SENDTHIS PHA
 STA TCPTHISSEGLEN
 LDY #uwTCPDataOut+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL CopyFromHandle
 LDA 1,S
 STA TCPHANDLE
 LDA 1+2,S
 STA TCPHANDLE+2

 JSR SENDSEG ;Sends TCPHANDLE as SND_NXT
; carry flag indicates FIN was sent.

 LDY #uwSND_NXT ;Bump SEQ counter
 LDA [USERPTR],Y
 ADC TCPTHISSEGLEN
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 ADC #0
 STA [USERPTR],Y

 _DisposeHandle

 LDA TCPMAX ;Decrement temp send window size
 SEC
 SBC TCPTHISSEGLEN
 STA TCPMAX
 BEQ :DONESENDPL2

 LDA TCPCOUNT
 CLC
 ADC TCPTHISSEGLEN
 STA TCPCOUNT

 LDA TCPOFFSET
 CLC
 ADC TCPTHISSEGLEN
 STA TCPOFFSET
 LDA TCPOFFSET+2
 ADC #0
 STA TCPOFFSET+2

 BRA :NEXTSEND

:DONESENDPL2 PLS 2

 JMP SETREXMITIMER

:FORCEEMPTY
:FORCEFIN
:NOWINDOW ;zero window, send ACK to query when non-zero

* Reset my sequence numbers to the last acknowledged byte

 LDY #uwSND_UNA
 JSR GETVAR
 LDY #uwSND_NXT
 JSR SETVAR

* Send nothing which includes <ACK>+<FIN>

 LDA #DUMMYEMPTYHANDLE
 STA TCPHANDLE
 LDA #^DUMMYEMPTYHANDLE
 STA TCPHANDLE+2
 JSR SENDSEG ;Send an empty dummy segment

 LDY #uwSND_NXT ;Bump SEQ counter - SENDSEG sets carry if FIN
 LDA [USERPTR],Y
 ADC #0
 STA [USERPTR],Y
 INY
 INY
 LDA [USERPTR],Y
 ADC #0
 STA [USERPTR],Y

 JSR SETREXMITIMER ;In case there is a FIN being sent. If not,
;  then CHECKSEND will find no data to send
;  next time in, and exit. Dodgey, but works.
 RTS

DUMMYEMPTYHANDLE ADRL 0 ;pointer
 DA 0 ;attributes
 DA 0 ;userID
 ADRL 0 ;size
% ADRL 0 ;previous
% ADRL 0 ;next

TIMER_2MSL DBGMSG TIMER_2MSL
 LDY #uwTCP_Timer ;See if we've timed out
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 JSL TIMERVALID?
 BCC :NOTYET
 TCPSAY 'TCPPOLLTIMERS:TIMER_2MSL Valid',0D
 LDA #tcpsCLOSED
 JSR SETSTATE
:NOTYET RTS

TIMER_SYNACK DBGMSG TIMER_SYNACK
 LDY #uwTCP_Timer ;See if we've timed out
 LDA [USERPTR],Y
 TAX
 INY
 INY
 LDA [USERPTR],Y
 JSL TIMERVALID?
 BCCL :NOTYET
 TCPSAY 'TCPPOLLTIMERS:TIMER_SYNACK Valid',0D
 LDY #uwRCV_NXT ;ACK=RCV.NXT
 JSR GETVAR
 PHXA
 LDY #uwISS ;SEQ=ISS
 JSR GETVAR
 PHXA
 PEA 0 ;len
 PHS 2 ;ptr
 PEA TCPF_SYN+TCPF_ACK ;flags
 TCPD 'sending <SYN><ACK>'
 TCPDSEQ
 JSL TCPSENDDGM
 JSR SETREXMITIMER
:NOTYET RTS

*-------------------------------------------------
* Small work subroutines
*-------------------------------------------------

POLLPURGE DBGMSG POLLPURGE ;Discards the incoming segment
 UNLOCK TCPINHANDLE
 PZL TCPINHANDLE
 _DisposeHandle
 SEC
 RTS

SETIMERNOW DBGMSG SETIMERNOW
 PHS 2 ;set new rexmit timer
 JSL GETTICK
 PLA
 LDY #uwTCP_Timer
 STA [USERPTR],Y
 PLA
 INY
 INY
 STA [USERPTR],Y
 RTS

SETREXMITIMER DBGMSG SETREXMITIMER
 PHS 2 ;set new rexmit timer
 JSL GETTICK
 LDY #uwTCP_rt_timer
 PLA
 CLC
 ADC [USERPTR],Y
 TAX
 PLA
 ADC #0
 LDY #uwTCP_Timer+2
 STA [USERPTR],Y
 DEY
 DEY
 TXA
 STA [USERPTR],Y
 RTS

SET2MSLTIMER DBGMSG SET2MSLTIMER
 PHS 2 ;set new rexmit timer
 JSL GETTICK
 LDY #uwTCP_2MSL_timer
 PLA
 CLC
 ADC [USERPTR],Y
 TAX
 PLA
 ADC #0
 LDY #uwTCP_Timer+2
 STA [USERPTR],Y
 DEY
 DEY
 TXA
 STA [USERPTR],Y
 LDY #uwTCP_TimerState
 LDA #TCPT_2MSL
 STA [USERPTR],Y
 RTS

MARKANDQUEUEFIN DBGMSG MARKANDQUEUEFIN
 LDY #uwSND_NXT
 JSR GETVAR
 LDY #uwTCP_FINSEQ
 JSR SETVAR
 LDY #uwTCP_ForceFIN
 LDA #-1
 STA [USERPTR],Y
 RTS

*-------------------------------------------------
* TCP VARIABLES
*-------------------------------------------------

TCPCONNECTIONS ENT
 DA 0

*-------------------------------------------------
* Debug stuff
*-------------------------------------------------

 do TCPDEBUG
TCPDUMP LDA >DEBUGTCP
 BEQ :SKIPASC
 LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 LDA STATEINDEX,X
 JSR DUMPSTRING
 LDA MYIPADDRESS
 XBA
 PHA
 LDA MYIPADDRESS+2
 XBA
 PHA
 PHL #IPSTR+1
 PEA 8
 _Long2Hex
 LDA #IPSTR
 JSR DUMPSTRING
 LDY #uwSourcePort
 LDA [USERPTR],Y
 PHA
 PHL #PORTSTR+1
 PEA 4
 _Int2Hex
 LDA #PORTSTR
 JSR DUMPSTRING
:SKIPASC
 LDA 1,S
 INC
 STA 1,S
]L1 LDY #0
 LDA (1,S),Y
 AND #$FF
 BEQ :DONE
 TAX
 LDA >DEBUGTCP
 BEQ :SKIPW
 TXA
 JSR DUMPCHAR
:SKIPW
 LDA 1,S
 INC
 STA 1,S
 BRA ]L1
:DONE LDA >DEBUGTCP
 BEQ :SKIPW2
 LDA #:NUL
 JSR DUMPLINE
:SKIPW2
 RTS

:NUL DFB 0
IPSTR STR 'xxxxxxxx/'
PORTSTR STR 'xxxx:'

STATEINDEX DA PSTR_CLOSED
 DA PSTR_LISTEN
 DA PSTR_SYNSENT
 DA PSTR_SYNRCVD
 DA PSTR_ESTABLISHED
 DA PSTR_FINWAIT1
 DA PSTR_FINWAIT2
 DA PSTR_CLOSEWAIT
 DA PSTR_LASTACK
 DA PSTR_CLOSING
 DA PSTR_TIMEWAIT

PSTR_CLOSED STR 'CLOSED:'
PSTR_LISTEN STR 'LISTEN:'
PSTR_SYNSENT STR 'SYNSENT:'
PSTR_SYNRCVD STR 'SYNRCVD:'
PSTR_ESTABLISHED STR 'ESTABLISHED:'
PSTR_FINWAIT1 STR 'FINWAIT1:'
PSTR_FINWAIT2 STR 'FINWAIT2:'
PSTR_CLOSEWAIT STR 'CLOSEWAIT:'
PSTR_LASTACK STR 'LASTACK:'
PSTR_CLOSING STR 'CLOSING:'
PSTR_TIMEWAIT STR 'TIMEWAIT:'

SPININDEX DA 0
SPINASC ASC "/-\|"

TCPRINT PLA
 STA :MOD+1
]L1 INC :MOD+1
 JSR :MOD
 BEQ :DONE
 TAX
 LDA >DEBUGTCP
 BEQ ]L1
 CPX #$0D
 BNE :DOIT
 LDA #:NUL
 JSR DUMPLINE
 BRA ]L1
:DOIT TXA
 JSR DUMPCHAR
 BRA ]L1
:MOD LDA: 0
 AND #$FF
 RTS
:DONE LDA :MOD+1
 PHA
 RTS
:NUL DFB 0

TCPSHORT TAY
 LDA >DEBUGTCP
 BEQ :SKIPASC
 PHY
 PHL #:STR+1
 PEA 4
 _Int2Hex
 LDA #:STR
 JSR DUMPSTRING
:SKIPASC RTS
:STR STR 'xxxx'

TCPLONG TAY
 LDA >DEBUGTCP
 BEQ :SKIPASC
 PHY
 PHX
 PHL #:STR+1
 PEA 8
 _Long2Hex
 LDA #:STR
 JSR DUMPSTRING
:SKIPASC RTS
:STR STR 'xxxxxxxx'

DUMPRCV DBGMSG DUMPRCV
 LDA >DEBUGTCP
 BNE :doit
 RTS
:doit LDY #uwTCP_State
 LDA [USERPTR],Y
 ASL
 TAX
 LDA STATEINDEX,X
 JSR DUMPSTRING
 BRA DUMPRCV3
DUMPRCV2 DBGMSG DUMPRCV2
 LDA >DEBUGTCP
 BNE DUMPRCV3
 RTS
DUMPRCV3 LDY #ip_src+2
 LDA [TCPIPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPIPHEADER],Y
 XBA
 JSR TCPLONG
 JSR TCPRINT
 ASC '/',00
 LDY #tcp_sport
 LDA [TCPHEADER],Y
 XBA
 JSR TCPSHORT
 JSR TCPRINT
 ASC ':received, seq=',00
 LDY #tcp_seq+2
 LDA [TCPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA
 JSR TCPLONG
 JSR TCPRINT
 ASC ' ack=',00
 LDY #tcp_ack+2
 LDA [TCPHEADER],Y
 XBA
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA
 JSR TCPLONG
 JSR TCPRINT
 ASC ' wind size=',00
 LDY #tcp_window
 LDA [TCPHEADER],Y
 XBA
 JSR TCPSHORT
 LDY #tcp_code
 LDA [TCPHEADER],Y
 AND #TCPF_ALL
 BEQ :DONEFLAGS
 JSR DUMPFLAGS
:DONEFLAGS
 JSR TCPRINT
 ASC ', data length=',00
 LDA TCPDATALEN
 JSR TCPSHORT
 JSR TCPRINT
 HEX 0D00
:SKIPASC RTS

DUMPFLAGS PHA
 JSR TCPRINT
 HEX 0D
 ASC ' flags - ',00
 PLA
 BIT #TCPF_URG
 BEQ :SKIPURG
 PHA
 JSR TCPRINT
 ASC ' <URG>',00
 PLA
:SKIPURG
 BIT #TCPF_ACK
 BEQ :SKIPACK
 PHA
 JSR TCPRINT
 ASC ' <ACK>',00
 PLA
:SKIPACK
 BIT #TCPF_PSH
 BEQ :SKIPPSH
 PHA
 JSR TCPRINT
 ASC ' <PSH>',00
 PLA
:SKIPPSH
 BIT #TCPF_RST
 BEQ :SKIPRST
 PHA
 JSR TCPRINT
 ASC ' <RST>',00
 PLA
:SKIPRST
 BIT #TCPF_SYN
 BEQ :SKIPSYN
 PHA
 JSR TCPRINT
 ASC ' <SYN>',00
 PLA
:SKIPSYN
 BIT #TCPF_FIN
 BEQ :SKIPFIN
 PHA
 JSR TCPRINT
 ASC ' <FIN>',00
 PLA
:SKIPFIN
 RTS

DEBUGWAIT DBGMSG DEBUGWAIT
 do TCPTODISK ;skip waiting when outputting to disk
 else
 LDA >DEBUGTCP
 BEQ :SKIP
 LDA >$E0C060
 BMI *-4
 fin
:SKIP RTS
 fin

 DUM 6
PWINDOWPTR ADRL 0
PFROMCOUNT DA 0
PFROMPTR ADRL 0
PFLAG DA 0
POUTOFFSET DA 0
POUTLEN DA 0
 DEND

* POSCALC
*
*  PHS               ;length
*  PHS               ;offset into fromptr
*  PHS               ;flag if error... below window = 0, above window = 1
*  PHL  fromptr
*  PHW  fromcount
*  PHL  windowptr
*  JSL  POSCALC
*
* Take the fromptr/fromcount and return an offset into it and length, of
* what I can remove to add to the window.
*
* eg. window is at $1000
*     fromptr is $F00 for $200.
*     return is $100 for $100
*
* eg. window is at $1000
*     fromptr is $1000 for $200.
*     return is $1000 for $200.
*
* eg. window is at $1000
*     fromptr is $1100 for $200
*     return is error

POSCALC PHD
 TSC
 TCD

* First see if window is inside the from chunk, remembering wrap

 LDA PWINDOWPTR
 SEC
 SBC PFROMPTR
 TAX
 LDA PWINDOWPTR+2
 SBC PFROMPTR+2
 BMI :ABOVE
 BNE :BELOW
 CPX PFROMCOUNT
 BCS :BELOW

* It is, X is now count from FROM to WINDOW

 STX POUTOFFSET

 LDA PFROMCOUNT
 SEC
 SBC POUTOFFSET
 STA POUTLEN
 CLC
 BRA :OUT

:BELOW STZ PFLAG
 BRA :NOPE

:ABOVE LDA #1
 STA PFLAG

:NOPE SEC
:OUT PLD
 PHP
 PLA
 STA 9,S
 PLA
 STA 9,S
 PLS 3
 PLP
 RTL

*-------------------------------------------------
* TCPSYNTAX - Called with TMPHANDLE/TMPTR as IP segment
*-------------------------------------------------

TCPSYNTAX ENT
 DBGMSG TCPSYNTAX

 PHB
 PHK
 PLB

 LDA TMPHANDLE
 STA TCPINHANDLE
 LDA TMPHANDLE+2
 STA TCPINHANDLE+2

 JSR BUILDPOINTERS

* Build pseudo header

 LDA TCPDATA
 SEC
 SBC TCPHEADER
 CLC
 ADC TCPDATALEN
 XBA
 STA :TCPLEN

 LDY #ip_src
 LDA [TCPIPHEADER],Y
 STA :SRCIP
 INY
 INY
 LDA [TCPIPHEADER],Y
 STA :SRCIP+2

 LDY #ip_dst
 LDA [TCPIPHEADER],Y
 STA :DESTIP
 INY
 INY
 LDA [TCPIPHEADER],Y
 STA :DESTIP+2

* Calculate checksum - first do the raw data

 PEA 0 ;little endian - normal

 CLC
 LDA TCPDATALEN
 BEQ :DONEDATA
 TAY
 ROR
 BCC :DATALOOP
 DEY
 LDA [TCPDATA],Y ;Add in pad byte
 XBA
 AND #$FF00
 STA 1,S
 TYA
 CLC
 BEQ :DONEDATA
:DATALOOP DEY
 DEY
 LDA [TCPDATA],Y
 XBA
 ADC 1,S
 STA 1,S
 TYA
 BNE :DATALOOP
:DONEDATA

* Add in TCP header

 PHP

 LDA TCPDATA
 SEC
 SBC TCPHEADER
 TAY
 DEY
 DEY ;is a multiple of four, so pad not necessary

 PLP

]L1 LDA [TCPHEADER],Y
 XBA
 ADC 1,S
 STA 1,S
 DEY
 DEY
 BPL ]L1

* Add in TCP pseudo header

 LDX #12-2
]L1 LDA :PSEUDOHEADER,X
 XBA
 ADC 1,S
 STA 1,S
 DEX
 DEX
 BPL ]L1

 ADC #0

 PLX

% XBA
 EOR #-1
 BNE :ERROR

 CLC
 PLB
 RTL

:ERROR SEC
 PLB
 RTL

:PSEUDOHEADER
:SRCIP ADRL 0
:DESTIP ADRL 0
 DFB 0
:PTCL DFB protocolTCP
:TCPLEN DDB 0

*-------------------------------------------------
* Called by IP parser to handle unclaimed segments (CLOSED or no port)
* There is *NO* USERHANDLE active!
*-------------------------------------------------

TCPTOSSUNCLAIMED ENT
 DBGMSG TCPTOSSUNCLAIMED
 PHB
 PHK
 PLB

 LDA TMPHANDLE
 STA TCPINHANDLE
 LDA TMPHANDLE+2
 STA TCPINHANDLE+2
 JSR BUILDPOINTERS

 TCPDRCV2
 TCPSAY 'Unclaimed segment, resetting:',0D

 LDY #tcp_code ;flags
 LDA [TCPHEADER],Y
 BIT #TCPF_RST
 BNE :RTL ;Discard incoming RSTs
 BIT #TCPF_ACK
 BEQ :SEQ0

 PEA 0 ;ACK - IGNORED, NOT ACKING
 PEA 0
 LDY #tcp_ack ;SEQ
 LDA [TCPHEADER],Y
 XBA
 PHA
 INY
 INY
 LDA [TCPHEADER],Y
 XBA
 PHA
 PEA 0 ;LEN
 PHS 2 ;PTR
 PEA TCPF_RST
 TCPSAY 'sending <RST>'
 TCPDSEQ
 JSL TCPSENDDGM
:RTL PLB
 RTL

:SEQ0 CLC
 AND #TCPF_SYN
 BEQ :NOSYN
 SEC
:NOSYN LDY #tcp_seq+2
 LDA [TCPHEADER],Y
 XBA
 ADC TCPDATALEN
 TAX
 DEY
 DEY
 LDA [TCPHEADER],Y
 XBA
 ADC #0
 PHA ;ACK
 PHX
 PEA 0 ;SEQ
 PEA 0
 PEA 0 ;LEN
 PHS 2 ;PTR
 PEA TCPF_RST+TCPF_ACK
 TCPSAY 'sending <RST> <ACK>'
 TCPDSEQ
 JSL TCPSENDDGM
 PLB
 RTL

TCPCLOSEDEBUGFILE ENT
 do TCPTODISK
 LDA CLOSE+2
 BEQ :SKIP ;Don't try to close if it isn't open!
 JSL $E100A8
 DA $2014
 ADRL CLOSE
 STZ CLOSE+2
 fin
:SKIP RTL

 PUT I.TCP.DEBUG

 SAV I.TCP.L

 END
