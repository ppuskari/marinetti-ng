 LST OFF
 REL
 mx 0

*=================================================
*
* Telnet - Apple IIgs Telnet application
*
* Copyright (C) 1998-2002 Richard Bennett
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*
*=================================================
*
* 2002.09.02 RJBF - Initial release as open source
* 2002.10.20 AJR - Add check for tcpsCLOSED
* 2003.05.17 AJR - Output :TITLE for non-DNR connection
*
*=================================================

debug = 0
buffering = 0

 USE 4/RJBUTIL.MACS
 USE 4/LOCATOR.MACS
 USE 4/MISC.MACS
 USE 4/MEM.MACS
 USE 4/INT.MACS
 USE 4/TEXT.MACS
 USE 4/EVENT.MACS
 USE 4/DESK.MACS
 USE 4/TCPIP.MACS
 do DEBUG
 USE 4/TCPIPX.MACS
 fin

 USE ../../MARINETTI/EQUATES/TCPIP.EQU

 DUM 0
TMPHANDLE ADRL 0
TMPTR ADRL 0
 DEND

*

INIT BRL STARTUP

*

* 203,2,193,124 ;destip = Oz Email
* 203,108,7,77 ;www.ozemail.com.au (for Web server)
* 192,80,63,5 ;delphi.com (for telnet)
* 199,93,4,68 ;delphi.com (for telnet)
* 203,12,97,2 ;zip.com.au (for DNR)
* 203,12,97,1 ;zipper.zip.com.au

DESTIP DFB 203,12,97,1
DESTPORT DA 23 ;destport. telnet=23, http=80, dnr=53

TELNET
 ~TCPIPPoll
 PEA 0
 ~TCPIPLongVersion
 BCS :VERR
 PHL #:TV
 _VersionString
 ~WriteString #:VSTR
 ~WriteLine #:TV

 do debug
 JSR SHOWDEBUG
 fin

:TOP JSR PRMENU
:LOOP JSR GETCHAR
 CMP #'a'
 BCC :OK
 CMP #'z'+1
 BCS :OK
 AND #$5F
:OK LDX #0
]L1 LDY :TBL,X
 BEQ :LOOP
 CMP :TBL,X
 BEQ :GOTIT
 INX
 INX
 INX
 INX
 BRA ]L1
:GOTIT JSR (:TBL+2,X)
 BRA :TOP

:VERR PLS 1+2
 SEC
 RTS

:VERSION DA 0

:VSTR STR 'Using TCP/IP v'
:TV DS 1+9

:TBL DA 'T',OPENTELNET
 DA 'Q',:QUIT
 DA 'C',CONNECT
 DA 'D',DISCONNECT
 DA 'R',RECONNECT
 do buffering
 DA 'B',BUFFERTOGGLE
 fin
 do debug
 DA 'Z',TCPDEBUGTOGGLE
 fin
 DA 0

:QUIT PLA
 RTS

MYID DA 0

*-------------------------------------------------

RECONNECT ~WriteLine #:STR1
 ~TCPIPReconnect #SHOWPSTRING
 JMP PRERROR

:STR1 STR 'Reconnecting.'

*-------------------------------------------------

CONNECT ~WriteLine #:STR1
 ~TCPIPConnect #SHOWPSTRING
 PHP
 PHA
 ~TCPIPGetAuthMessage MYID
 PHS 2
 LDA 4+1+2,S
 PHA
 LDA 2+4+1,S
 PHA
 _GetHandleSize
 LDA 1,S
 ORA 1+2,S
 BEQ :DONE2
 LDA 5,S
 STA TMPHANDLE
 LDA 5+2,S
 STA TMPHANDLE+2
 LDY #2
 LDA [TMPHANDLE],Y
 PHA
 LDA [TMPHANDLE]
 PHA
 PEA 0
 LDA 7,S
 PHA
 _TextWriteBlock
 ~WriteLine #NULL
:DONE2 PLS 2
 _DisposeHandle
 PLA
 PLP
 BCC :SHOWIP
 JMP PRERROR
:SHOWIP JMP SHOWIP

:STR1 STR 'Starting connection.'

NULL DFB 0

*-------------------------------------------------

DISCONNECT ~WriteLine #:STR1
 ~TCPIPDisconnect #1;#SHOWPSTRING
 JMP PRERROR

:STR1 STR 'Terminating connection.'

*-------------------------------------------------

SHOWIP ~WriteString #IPSTR1
SHOWJUSTIP PHS
 ~TCPIPGetMyIPAddress
 LDA 1,S
 STA :IP
 LDA 1+2,S
 STA :IP+2
 _TCPIPConvertIPToClass
 PLW :CLASS

 LXA :IP
 JSR PRIP

 do debug
 LDA :IP
 AND #$FF
 PHA
 PHL #:IPSTR2+3
 PEA 2
 _Int2Hex
 LDA :IP+1
 AND #$FF
 PHA
 PHL #:IPSTR2+6
 PEA 2
 _Int2Hex
 LDA :IP+2
 AND #$FF
 PHA
 PHL #:IPSTR2+9
 PEA 2
 _Int2Hex
 LDA :IP+3
 AND #$FF
 PHA
 PHL #:IPSTR2+12
 PEA 2
 _Int2Hex
 LDA :CLASS
 ORA #$40
 INC
 SEP $20
 STA :IPSTR2+22
 REP $20
 ~WriteLine #:IPSTR2
 else
 ~WriteLine #NULL
 fin
 RTS

:IP ADRL 0
:CLASS DA 0

:PSTR DS 1
:CSTR DS 15+1

 do debug
:IPSTR2 STR ' (00 00 00 00, class=x)'
 fin

IPSTR1 STR 'My current IP address is '

*-------------------------------------------------

IPID DA 0

OPENTELNET
 STZ ECHOFLAG
 ~TCPIPGetConnectStatus
 PLA
 BNE :OPENOK
 RTS
:OPENOK ~WriteLine #:PROMPT
 JSR INPUTLINE
 BCS :RTS
 LDA LINELEN
 BNE :INPUTOK
:RTS RTS
:INPUTOK
 ~TCPIPMangleDomainName #$F800;#LINELEN
 PLA
 BNE :GOTPORT
 LDA #23
:GOTPORT STA DESTPORT

 ~TCPIPValidateIPString #LINELEN
 PLA
 BEQ :DNR
 ~TCPIPConvertIPToHex #:CVTREC;#LINELEN
 LXA :CVTREC
 STXA :DNRIPADDRESS
 BRL :DOLOGIN

:DNR ~WriteString #:TRYING
 ~WriteString #LINELEN
 ~WriteString #:TRYDOTS

 ~TCPIPDNRNameToIP #LINELEN;#:DNRBUFF

:DNRLOOP SEP $20
 LDA >$E0C000
 REP $20
 BPL :SKIPDNRKBD
 ~ReadChar #0
 PLA
 AND #$7F
 CMP #$1B
 BNE :SKIPDNRKBD
 ~WriteLine #:NOSTR
 RTS
:SKIPDNRKBD

 ~TCPIPPoll
 LDA :DNRSTATUS
 BEQ :DNRLOOP

 DEC
 BEQ :DNROK

 DEC
 BEQ :DNRTIMEOUT

 ~WriteLine #NODNSSTR
 RTS

:DNRTIMEOUT ~WriteLine #DNSTIMEOUT
 RTS

:DNROK ~WriteLine #FOUND

 do debug
 ~WriteString #:TITLE0
 LXA :DNRIPADDRESS
 JSR PRIP
 ~WriteLine #NULL
 fin

*-------------------------------------------------
* Log me in
*-------------------------------------------------

:DOLOGIN
 ~WriteLine #:TITLE

 ~TCPIPLogin MYID;:DNRIPADDRESS;DESTPORT;#0;#64
 PLW IPID

 STZ PARSETELNETFLAG

*-------------------------------------------------
* Open it
*-------------------------------------------------

 ~TCPIPOpenTCP IPID
 PLS

 do buffering
 LDA BUFFERFLAG
 BEQ :SKIPFILEO
 JSL $E100A8
 DA $2002
 ADRL :DESTROYFILE
 JSL $E100A8
 DA $2001
 ADRL :CREATEFILE
 JSL $E100A8
 DA $2010
 ADRL :OPENFILE
 BCC :OPENFOK
:OPENFOK LDA :OPENFILE+2
 STA :WRITEFILE+2
 STA :CLOSEFILE+2
:SKIPFILEO
 fin

*-------------------------------------------------
* Spin until open
*-------------------------------------------------

:OPENLOOP ~TCPIPPoll

 SEP $20
 LDA >$E0C000
 REP $20
 BPL :SKIP1
 ~ReadChar #0
 PLA
 AND #$7F
 CMP #$1B
 BEQL :ABORT
:SKIP1
 ~TCPIPStatusTCP IPID;#:SRBUFF
 PLA
 BNE :TCPTERR
 LDA :SRBUFF+srState
 CMP #tcpsESTABLISHED
 BEQ :NOWOPEN
 CMP #tcpsCLOSED
 BNE :OPENLOOP

 LDA :SRBUFF+srNetworkError
 JSR PRNWERROR
 BRL :QUIT

:TCPTERR JSR PRTCPTERR
 BRL :QUIT

:NOWOPEN

*-------------------------------------------------
* Main loop
*-------------------------------------------------

:TELNETLOOP ~TCPIPPoll

 ~TCPIPStatusTCP IPID;#:SRBUFF
 PLS
 LDA :SRBUFF+srState
 CMP #tcpsCLOSEWAIT
 BEQL :CLOSE
 CMP #tcpsCLOSED
 BEQL :QUIT
 CMP #tcpsTIMEWAIT
 BEQL :QUIT

 SEP $20
 LDA >$E0C000
 REP $20
 BPLL :SKIP
 ~ReadChar #0
 PLA
 AND #$7F
 CMP #$1B
 BEQL :CLOSE

 TAX
 SEP $20
 LDA >$E0C025
 REP $20
 BPL :KEY

 do debug
 CPX #'Z' ;'Z'
 BEQL :DEBUG
 CPX #'z'
 BEQL :DEBUG
 fin
 CPX #'E'
 BEQL :ECHO
 CPX #'e'
 BEQL :ECHO
 do debug
 CPX #2
 BEQ :BRK
 CPX #'#'
 BEQL :QUITNOCLOSE
 fin

:KEY TXA

:STICK PHA

 PHA
 JSL SENDCHARVIATCP

 LDA ECHOFLAG
 BEQ :SKIPECHO
 LDA 1,S
 PHA
 _WriteChar
:SKIPECHO

 PLA
 CMP #$0D
 BNE :SKIP
 LDA #$0A
 BRA :STICK

 do debug
:BRK brk 0
 fin

:SKIP
 JSR :CHECKRECEIVED
 BRL :TELNETLOOP

:ABORT ~TCPIPAbortTCP IPID
 PLS
 BRA :LOGOUT

:CLOSE JSR :CHECKRECEIVED

 ~TCPIPCloseTCP IPID
 PLS

 STZ :LOOPCNT
]L1 INC :LOOPCNT
 BEQ :LOGOUT ;Something bad has happened
 JSR :CHECKRECEIVED
 ~TCPIPPoll
 ~TCPIPStatusTCP IPID;#:SRBUFF
 PLS
 BCS :LOGOUT ;Something bad has happened
 LDA :SRBUFF+srState
 BEQ :LOGOUT ;tcpsCLOSED
 CMP #tcpsTIMEWAIT
 BNE ]L1

 BRA :LOGOUT

:LOOPCNT DA 0

*-------------------------------------------------
* CLOSE and QUIT
*-------------------------------------------------

:QUIT ~WriteLine #NULL
 ~TCPIPCloseTCP IPID
 PLS
 ~WriteLine #:CLOSING
:LOGOUT
 STZ :LOOPCNT
]L1 INC :LOOPCNT
 BEQ :QUITNOCLOSE ;Something bad has happened
 ~TCPIPPoll
 ~TCPIPLogout IPID
 BCC :QUITNOCLOSE ;Clean logout
 CMP #terrSOCKETOPEN
 BEQ ]L1 ;Wait for Clean logout while socket is open
  ; otherwise something bad has happened
:QUITNOCLOSE

 do buffering
 LDA BUFFERFLAG
 BEQ :NOCLOSE
 JSL $E100A8
 DA $2014
 ADRL :CLOSEFILE
:NOCLOSE
 fin

 RTS

 do debug
:DEBUG JSR TCPDEBUGTOGGLE
 BRL :TELNETLOOP
 fin

:ECHO LDA ECHOFLAG
 EOR #$8000
 STA ECHOFLAG
 BRL :TELNETLOOP

:CHECKRECEIVED ~TCPIPPoll

 ~TCPIPReadTCP IPID;#0;#:BUFFER;#100;#:RRBUFF
 PLA
 BCS :NONE
 BNE :NONE

 LDA :RRBUFF+rrBuffCount
 BEQ :NONE

 PHA

 LDX #0
]L1 LDA :BUFFER,X
 PHX
 JSR PARSETELNET
 BCS :SKIPP
 PHA
 _WriteChar
:SKIPP PLX
 INX
 TXA
 CMP 1,S
 BCC ]L1

 PLA

 do buffering
 LDX BUFFERFLAG
 BEQ :NOWRITE
 STA :WRITELEN
 JSL $E100A8
 DA $2013
 ADRL :WRITEFILE
:NOWRITE
 fin

:NONE RTS

:SRBUFF DS srlen

:RRBUFF DS rrlen

:BUFFER DS 100

:CVTREC ADRL 0
 DA 0

 do debug
:TITLE0 STR 'Resulting IP address is: '
:TITLE STR 'Opening connection. [OA-E for echo, ESC to close, OA-Z for debug]'
 else
:TITLE STR 'Opening connection. [OA-E for echo, ESC to close]'
 fin

:PROMPT STR 'Telnet to where?  (enter domain name)'

:TRYING STR 'Looking up '
:TRYDOTS STR '...'

:NOSTR DFB 0

:DNRBUFF
:DNRstatus DA 0
:DNRIPaddress ADRL 0

:CLOSING STR 'Closing connection.'

 do buffering

:DESTROYFILE DA 1
 ADRL :FILE

:CREATEFILE DA 4
 ADRL :FILE
 DA $C3,4
 ADRL 0

:OPENFILE DA 3,0
 ADRL :FILE
 DA %11

:CLOSEFILE DA 1,0

:WRITEFILE DA 4,0
 ADRL :BUFFER
:WRITELEN ADRL 0
 ADRL 0

:FILE STRL ':RAM5:Telnet.buffer'
 fin

NODNSSTR STR 'not found.'
DNSTIMEOUT STR 'timed out.'
FOUND STR 'found.'

ECHOFLAG DA 0

SENDCHARVIATCP PHB
 PLX
 PLY
 PLA
 STA :TCHAR
 PHY
 PHX
 PLB
 ~TCPIPWriteTCP IPID;#:TCHAR;#1;#1;#0
 PLS
 RTL

:TCHAR DA 0

*-------------------------------------------------

 do debug
SHOWDEBUG ~TCPIPGetDebugTCP
 PLA
 BEQ SHOWDBGOFF
 BRA SHOWDBGON

TCPDEBUGTOGGLE
 ~TCPIPGetDebugTCP
 PLA
 BEQ SETDEBUGON
SETDEBUGOFF ~TCPIPSetDebugTCP #0
SHOWDBGOFF ~WriteLine #DBGOFFSTR
 RTS
SETDEBUGON ~TCPIPSetDebugTCP #$8000
SHOWDBGON ~WriteLine #DBGONSTR
 RTS

DBGOFFSTR STR 'TCP debug off.'
DBGONSTR STR 'TCP debug on.'
 fin

*-------------------------------------------------

 do buffering
BUFFERTOGGLE LDA BUFFERFLAG
 EOR #1
 STA BUFFERFLAG
SHOWbuffering LDA BUFFERFLAG
 BEQ :OFF
 ~WriteLine #:BUFFON
:OFF RTS

:BUFFON STR 'buffering to :RAM5:Telnet.buffer'

BUFFERFLAG DA 0
 fin

*-------------------------------------------------

PARSETELNET AND #$FF
 LDX PARSETELNETFLAG
 BNE :ALREADY
 CMP #$FF
 BEQ :IAC
 CLC
 RTS
:IAC LDA #:PARSER-1
 STA PARSETELNETFLAG
:NO SEC
 RTS
:ALREADY PHX
 RTS
:PARSER CMP #240
 BCC :INVALID
 AND #$0F
 ASL
 TAX
 JMP (:TBL,X)

:TBL DA :SE,:NOP,:DM,:BRK,:IP,:AO,:AYT,:EC,:EL
 DA :GA,:SB,:WILL,:WONT,:DO,:DONT,:NOTIAC

:DONTOPT ;option is in A, ignore it for this version
 PHA
 PEA 255 ;IAC
 JSL SENDCHARVIATCP
 PEA 254 ;DON'T
 JSL SENDCHARVIATCP
 JSL SENDCHARVIATCP ;Send the option
 BRA :FLAGGER

:WONTOPT ;option is in A, ignore it for this version
 PHA
 PEA 255 ;IAC
 JSL SENDCHARVIATCP
 PEA 252 ;DON'T
 JSL SENDCHARVIATCP
 JSL SENDCHARVIATCP ;Send the option


:SE
:NOP
:DM
:BRK
:IP
:AO
:AYT
:EC
:EL
:GA
:FLAGGER
:INVALID
 STZ PARSETELNETFLAG
 SEC
 RTS

:SB
 LDA #:FLAGGER-1
 STA PARSETELNETFLAG
 SEC
 RTS

:DO
:DONT
 LDA #:WONTOPT-1
 STA PARSETELNETFLAG
 SEC
 RTS

:WILL
:WONT
 LDA #:DONTOPT-1
 STA PARSETELNETFLAG
 SEC
 RTS

:NOTIAC LDA #255
 STZ PARSETELNETFLAG
 CLC
 RTS

PARSETELNETFLAG DA 0

*-------------------------------------------------

PRMENU ~WriteLine #:M1
 ~WriteLine #:M2
 ~WriteLine #:M3
 ~WriteString #:M4
 JSR SHOWJUSTIP
 ~WriteLine #:M5
 RTS

:M1 STR '---------- Marinetti Telnet 1.0.3 --'
:M2 STR '[T]elnet to location, [Q]uit'
:M3 STR '[C]onnect, [D]isconnect, [R]econnect'
:M4 STR 'IP='
:M5 STR '------------------------------------'

NOERROR LDA #0
PRERROR PHA
 EOR #0
 BEQ :OK
 PHA
 PHL #:STR+8
 PEA 4
 _Int2Hex
 ~WriteString #:STR

 LDX #0
]LOOP LDA :ERRTABLE,X
 BMI :NOTEXT
 CMP 1,S
 BEQ :GOTIT
 PHX
 LDA :ERRTABLE+2,X
 AND #$FF
 CLC
 ADC #3
 ADC 1,S
 TAX
 PLY
 BRA ]LOOP
:GOTIT PEA ^*
 TXA
 CLC
 ADC #:ERRTABLE+2
 PHA
 _WriteLine

:NOTEXT PLA
 RTS

:STR STR 'Error $xxxx. '

:OK ~WriteLine #:OKSTR
 PLA
 RTS

:OKSTR STR 'terrOK. (rc=0000)'

:ERRTABLE DA 1+]t0
 STR 'terrBADIPID ;Bad IPID for this request'
 DA 2+]t0
 STR 'terrNOCONNECTION ;Not connected to the network'
 DA 3+]t0
 STR 'terrNORECONDATA ;No reconnect data'
 DA 4+]t0
 STR 'terrLINKERROR ;Problem with the link layer'
 DA 5+]t0
 STR 'terrSCRIPTFAILED ;The script failed / timed out'
 DA 6+]t0
 STR 'terrCONNECTED ;Not while connected to the network'
 DA 7+]t0
 STR 'terrSOCKETOPEN ;Cannot complete - socket still open'
 DA 8+]t0
 STR 'terrINITNOTFOUND ;The Marinetti init is not loaded'
 DA 9+]t0
 STR 'terrVERSIONMISMATCH ;The init and tool set have different versions'
 DA $A+]t0
 STR 'terrBADTUNETABLELEN ;Tune table length in Marinetti 3.0 must be 10'
 DA $B+]t0
 STR 'terrIPIDTABLEFULL ;Marinetti cannot handle any more ipids'
 DA $C+]t0
 STR 'terrNOICMPQUEUED ;No ICMP datagrams in the queue'
 DA $D+]t0
 STR 'terrLOGINSPENDING ;There are still ipids logged in'
 DA $E+]t0
 STR 'terrTCPIPNOTACTIVE ;Not active - probably in P8 mode'
 DA $F+]t0
 STR 'terrDNRNOTFOUND ;No DNR to load from disk'
 DA $10+]t0
 STR 'terrDNRBUSY ;DNR is currently busy - try again later'
 DA $11+]t0
 STR 'terrNOLINKLAYER ;Unable to load link layer module'
 DA $12+]t0
 STR 'terrBADLINKLAYER ;Not a link layer module'
 DA $13+]t0
 STR 'terrENJOYCOKE ;But not so close to the keyboard'
 DA $14+]t0
 STR &terrNORECONSUPPRT ;This module doesn't support reconnect&
 DA $15+]t0
 STR 'terrABORTEDSCRIPT ;The user aborted the connect/disconnect script'
 DA $16+]t0
 STR 'terrBADUSERPASS ;Invalid username and/or password'
 DA $17+]t0
 STR 'terrBADPARAMETER ;Invalid parameter for this call'
 DA $18+]t0
 STR 'terrBADENVIRONMENT ;No desktop or tools not started'
 DA $19+]t0
 STR 'terrNOINCOMING ;There is no pending incoming request'
 DA $1A+]t0
 STR 'terrLINKBUSY ;Modem or interface is busy'
 DA $1B+]t0
 STR 'terrNOLINKINTERFACE ;No dial tone or similar'
 DA $1C+]t0
 STR 'terrNOLINKRESPONSE ;No modem answer or similar'
 DA $1D+]t0
 STR 'terrNODNRPENDING ;No such entry in DNR list'
 DA $1E+]t0
 STR 'terrBADALIVEMINUTES ;Minutes value is invalid'
 DA $1F+]t0
 STR 'terrBUFFERTOOSMALL ;Buffer is too small'
 DA -1

PRNWERROR PHA
 EOR #0
 BPL :UNKNOWN
 PHA
 PHL #:STR+16
 PEA 4
 _Int2Hex
 ~WriteString #:STR

 LDX #0
]LOOP LDA ICMPCODES,X
 BEQ :NOTEXT
 CMP 1,S
 BEQ :GOTIT
 PHX
 LDA ICMPCODES+2,X
 AND #$FF
 CLC
 ADC #3
 ADC 1,S
 TAX
 PLY
 BRA ]LOOP
:GOTIT PEA ^*
 TXA
 CLC
 ADC #ICMPCODES+2
 PHA
 _WriteLine

 PLS
 RTS

:UNKNOWN ~WriteLine #:UNSTR
 PLS
 RTS

:NOTEXT ~WriteLine #:NOTBL
 PLS
 RTS

:STR STR 'Network error $xxxx. '
:NOTBL STR 'Unknown'
:UNSTR STR 'Unknown connection failure.'

ICMPCODES DA $8000
 STR 'Network unreachable'
 DA $8001
 STR 'Host unreachable'
 DA $8002
 STR 'Protocol unreachable'
 DA $8003
 STR 'Port unreachable'
 DA $8004
 STR 'Fragmentation needed but DF bit set'
 DA $8005
 STR 'Source route failed'
 DA $8006
 STR 'Destination network unknown'
 DA $8007
 STR 'Destination host unknown'
 DA $8009
 STR 'Destination network administratively prohibited'
 DA $800A
 STR 'Destination host administratively prohibited'
 DA $800B
 STR 'Network unreachable for TOS'
 DA $800C
 STR 'Host unreachable for TOS'
 DA 0

PRTCPTERR PHA
 PHA
 PHL #:STR+8
 PEA 4
 _Int2Hex
 ~WriteString #:STR

 LDX #0
]LOOP LDA TCPTERRCODES,X
 BMI :NOTEXT
 CMP 1,S
 BEQ :GOTIT
 PHX
 LDA TCPTERRCODES+2,X
 AND #$FF
 CLC
 ADC #3
 ADC 1,S
 TAX
 PLY
 BRA ]LOOP
:GOTIT PEA ^*
 TXA
 CLC
 ADC #TCPTERRCODES+2
 PHA
 _WriteLine

 PLS
 RTS

:NOTEXT ~WriteLine #:NOTBL
 PLS
 RTS

:STR STR 'Error $xxxx. '

:NOTBL STR 'Unknown error'

TCPTERRCODES DA 0
 STR 'tcperrOK'
 DA 1
 STR 'tcperrDeafDestPort'
 DA 2
 STR 'tcperrHostReset'
 DA 3
 STR 'tcperrConExists ;"connection already exists"'
 DA 4
 STR 'tcperrConIllegal ;"connection illegal for this process"'
 DA 5
 STR 'tcperrNoResources ;"insufficient resources"'
 DA 6
 STR 'tcperrNoSocket ;"foreign socket unspecified"'
 DA 7
 STR 'tcperrBadPrec ;"precedence not allowed"'
 DA 8
 STR 'tcperrBadSec ;"security/compartment not allowed"'
 DA 9
 STR 'tcperrBadConnection ;"connection does not exist"'
 DA 10
 STR 'tcperrConClosing ;"connection closing"'
 DA 11
 STR 'tcperrClosing ;"closing"'
 DA 12
 STR 'tcperrConReset ;"connection reset"'
 DA 13
 STR 'tcperrUserTimeout ;"connection aborted due to user timeout"'
 DA 14
 STR 'tcperrConRefused ;"connection refused"'
 DA -1

PRIP PHS
 PHXA
 PHL #:PSTR
 PEA 0
 _TCPIPConvertIPToASCII
 PLA
 ~WriteString #:PSTR
 RTS

:PSTR DS 1+15

*-------------------------------------------------
* SHOWPSTRING called by connect/disconnect/reconnect
*-------------------------------------------------

SHOWPSTRING LDA 4+2,S
 PHA
 LDA 2+4,S
 PHA
 _WriteLine
 PHB
 PLA
 STA 3,S
 PLA
 STA 3,S
 PLB
 RTL

*-------------------------------------------------
* Startup stuff
*-------------------------------------------------

STARTUP PHK
 PLB
 ~MMStartUp
 PLW MYID
 _MTStartUp
 _TextStartUp
 ~SetOutPutDevice #1;#3
 ~SetInGlobals #$7F;#0
 ~SetOutGlobals #$7F;#0
 _IMStartUp
 ~LoadOneTool #$36;#$300
 BCS :NOGK
 _TCPIPStartup
 BCS :NOGK
 JSR TELNET
 BRA :DOWN
:NOGK ~WriteLine #:NOGKSTR
 ~ReadChar #0
 PLA
:DOWN _TCPIPShutdown
 _IMShutDown
 _TextShutDown
 _MTShutDown
 ~MMShutDown MYID
 JSL $E100A8
 DA $2029
 ADRL :QUIT
 BRA *
:QUIT DA 2
 ADRL 0
 DA 0

:NOGKSTR STR 'Marinetti 3.0 is not installed.'

*-------------------------------------------------

LINELEN DS 1
LINE DS 80

INPUTLINE LDA LINELEN
 BEQ :LINECOPIED
 ~WriteString #LINELEN
:LINECOPIED
:TOP JSR GETCHAR
 CMP #$0D
 BEQ :CR
 CMP #$1B
 BEQ :ESC
 CMP #$08
 BEQ :BS
 CMP #$7F
 BEQ :BS
 CMP #'X'-$40
 BEQ :CTLX
 CMP #$20
 BCC :GOBEEP
 SEP $10
 LDX LINELEN
 CPX #80
 REP $10
 BCS :GOBEEP
 SEP $20
 STA LINE,X
 INC LINELEN
 REP $20
 PHA
 _WriteChar
 BRA :TOP
:BS SEP $20
 LDA LINELEN
 REP $20
 BEQ :GOBEEP
 JSR :FORCEBS
 BRA :TOP
:GOBEEP _SysBeep
 BRA :TOP
:CTLX SEP $20
 LDA LINELEN
 REP $20
 BEQ :TOP
 JSR :FORCEBS
 BRA :CTLX
:CR CLC
 HEX 24
:ESC SEC
 PHP
 ~WriteLine #NULL
 PLP
 RTS
:FORCEBS SEP $20
 DEC LINELEN
 REP $20
 ~WriteString #:BSSTR
 RTS

:BSSTR DFB 3,8,$20,8

GETCHAR ~TCPIPPoll
 SEP $20
 LDA >$E0C000
 REP $20
 BPL GETCHAR
 ~ReadChar #0
 PLA
 AND #$7F
 RTS

 SAV TELNET.L

 END
