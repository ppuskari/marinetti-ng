 LST OFF
*=================================================
*
* I.CALLS.S - Miscellaneous tool calls
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
* 2006.06.03 AJR - Close TCP debug file when TCP debugging is turned off
*
*=================================================
 REL
 mx 0

*-------------------------------------------------
* Calls not needing disk/ipid access.
*-------------------------------------------------

 USE 4/RJBUTIL.MACS
 USE 4/LOCATOR.MACS
 USE 4/LOAD.MACS
 USE 4/INT.MACS
 USE 4/RESOURCE.MACS
 USE 4/MEM.MACS
 USE 4/TCPIP.MACS
 USE ../EQUATES/BUILD.EQU ;Build stuff, version etc.
 USE ../EQUATES/I.EQU ;My personal stuff
 USE ../EQUATES/TCPIP.EQU ;Application stuff

 EXT CASC2HEXIP,HEX2CASCIP,AMIACTIVE,MYDP,MYTOOLSETNUMBER ;INIT
 EXT CONNECTMETHOD,LINKFLAG,IPTOCLASS,PASC2HEXIP,HEX2PASCIP

 EXT DUMPLINKLAYER,LOADLINKLAYER,MODULEPATHNAME ;DISPATCH
 EXT LINKCONFIGURE,MODULELIST,BuildModuleList,LINKMODULEINFO
 EXT SystemTriggers

 EXT ERRORTABLE,IPSENDDATAGRAM ;IP

 EXT DNSIPMAIN,DNSIPAUX,DEBUGHEX,DEBUGTCP ;PREFS
 EXT IPUSERSLICE,IPRUNQFREQ,IPRUNQSLICE,TCPUSERSLICE
 EXT CONNECTMSGFLAG,USERNAME,PASSWORD,HOSTNAME
 EXT ALIVEFLAG,ALIVEMINUTES,BOOTCONNECTFLAG

 EXT PtrToPtr,PtrToPtrNeg

 EXT TCPCLOSEDEBUGFILE

 DUM 1 ;Tool call stack on entry
RTLROM ADR 0
RTLCALLER ADR 0
RAWSTACKEDPARMS
 DEND

*-------------------------------------------------
* Tool exit procs
*-------------------------------------------------

NOTACTIVE16 LDY #16
 BRA NOACTIVE
NOTACTIVE14 LDY #14
 BRA NOACTIVE
NOTACTIVE12 LDY #12
 BRA NOACTIVE
NOTACTIVE10 LDY #10
 BRA NOACTIVE
NOTACTIVE8 LDY #8
 BRA NOACTIVE
NOTACTIVE6 LDY #6
 BRA NOACTIVE
NOTACTIVE4 LDY #4
 BRA NOACTIVE
NOTACTIVE2 LDY #2
NOACTIVE LDX #terrTCPIPNOTACTIVE&terrmask

STRIPTOOLEXIT CMP #1 ;A=error (moves to X before ToStrip), Y=bytes
 BCC :STRIP
 ORA >MYTOOLSETNUMBER
:STRIP TAX
 JML ToStrip

NOTACTIVE0 LDA #terrTCPIPNOTACTIVE&terrmask
TOOLEXIT CMP #1 ;A=error
 BCC :RTL
 ORA >MYTOOLSETNUMBER
:RTL RTL

*-------------------------------------------------
* _TCPIPGetConnectStatus():flag  $0936
*-------------------------------------------------

TCPIPGetConnectStatus ENT
 DBGMSG TCPIPGetConnectStatus
 LDA >LINKFLAG
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPGetErrorTable():errtableptr  $0A36
*-------------------------------------------------

TCPIPGetErrorTable ENT
 DBGMSG TCPIPGetErrorTable
 LDA #ERRORTABLE
 STA RAWSTACKEDPARMS,S
 LDA #^ERRORTABLE
 STA RAWSTACKEDPARMS+2,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPConvertIPCToHex(cvtRecPtr,ddipcstring)
*-------------------------------------------------

TCPIPConvertIPCToHex ENT
 DBGMSG TCPIPConvertIPCToHex
 PHS 2+1
 LDA 4+2+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+4+2+RAWSTACKEDPARMS,S
 PHA
 JSL CASC2HEXIP
 TSC
 PHD
 TCD
 LDA 1
 STA [17]
 LDA 1+2
 LDY #2
 STA [17],Y
 INY
 INY
 LDA 5
 STA [17],Y
 PLD
 PLS 2+1
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #8
 JML ToStrip

*-------------------------------------------------
* _TCPIPConvertIPToHex(cvtRecPtr,ddipstring)
*-------------------------------------------------

TCPIPConvertIPToHex ENT
 DBGMSG TCPIPConvertIPToHex
 PHS 2+1
 LDA 4+2+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+4+2+RAWSTACKEDPARMS,S
 PHA
 JSL PASC2HEXIP
 TSC
 PHD
 TCD
 LDA 1
 STA [17]
 LDA 1+2
 LDY #2
 STA [17],Y
 INY
 INY
 LDA 5
 STA [17],Y
 PLD
 PLS 2+1
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #8
 JML ToStrip

*-------------------------------------------------
* _TCPIPConvertIPToASCII(ipaddress,ddpstring,flags):strlen  $0E36
*-------------------------------------------------

TCPIPConvertIPToASCII ENT
 DBGMSG TCPIPConvertIPToASCII
 PHS
 LDA 2+RAWSTACKEDPARMS,S
 PHA
 LDA 2+2+RAWSTACKEDPARMS+6+2,S
 PHA
 LDA 2+2+2+RAWSTACKEDPARMS+6,S
 PHA
 LDA 2+2+2+2+RAWSTACKEDPARMS+2+2,S
 PHA
 LDA 2+2+2+2+2+RAWSTACKEDPARMS+2,S
 PHA
 JSL HEX2PASCIP ;(flags:int,ip:lw,pstringptr:lw):len:integer;
 PLA
 STA RAWSTACKEDPARMS+10,S
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #10
 JML ToStrip

*-------------------------------------------------
* _TCPIPConvertIPToCASCII(ipaddress,ddcstring,flags):strlen  $5836
*-------------------------------------------------

TCPIPConvertIPToCASCII ENT
 DBGMSG TCPIPConvertIPToCASCII
 PHS
 LDA 2+RAWSTACKEDPARMS,S
 PHA
 LDA 2+2+RAWSTACKEDPARMS+6+2,S
 PHA
 LDA 2+2+2+RAWSTACKEDPARMS+6,S
 PHA
 LDA 2+2+2+2+RAWSTACKEDPARMS+2+2,S
 PHA
 LDA 2+2+2+2+2+RAWSTACKEDPARMS+2,S
 PHA
 JSL HEX2CASCIP ;(flags:int,ip:lw,cstringptr:lw):len:integer;
 PLA
 STA RAWSTACKEDPARMS+10,S
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #10
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetMyIPAddress():ipaddress  $0F36
*-------------------------------------------------

TCPIPGetMyIPAddress ENT
 DBGMSG TCPIPGetMyIPAddress
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 LDA >LINKFLAG
 BEQ :NOTCONNECTED
 PHD
 LDA >MYDP
 TCD
 LDA MYIPADDRESS
 STA 2+RAWSTACKEDPARMS,S
 LDA MYIPADDRESS+2
 STA 2+RAWSTACKEDPARMS+2,S
 PLD
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

:NOTCONNECTED LDA #0
 STA RAWSTACKEDPARMS,S
 STA RAWSTACKEDPARMS+2,S
 LDA #terrNOCONNECTION&terrmask
 JMP TOOLEXIT

*-------------------------------------------------
* _TCPIPGetConnectMethod():method  $1036
*-------------------------------------------------

TCPIPGetConnectMethod ENT
 DBGMSG TCPIPGetConnectMethod
 LDA >CONNECTMETHOD
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetConnectMethod(method)  $1136
*-------------------------------------------------

TCPIPSetConnectMethod ENT
 DBGMSG TCPIPSetConnectMethod

 LDA >AMIACTIVE
 BEQL NOTACTIVE2

 LDA >LINKFLAG
 BNE :LINKUP

 LDA RAWSTACKEDPARMS,S
 CMP >CONNECTMETHOD
 BEQ :OK

 JSL DUMPLINKLAYER

 LDA RAWSTACKEDPARMS,S
 JSL LOADLINKLAYER
 BCS :ERR ;A = error

 LDA RAWSTACKEDPARMS,S
 STA >CONNECTMETHOD

:OK LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

:LINKUP LDA #terrCONNECTED&terrmask
:ERR LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetMTU():mtu  $1436
*-------------------------------------------------

TCPIPGetMTU ENT
 DBGMSG TCPIPGetMTU
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 PHD
 LDA >MYDP
 TCD
 LDA MTU
 STA 2+RAWSTACKEDPARMS,S
 PLD
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPGetDNS():DNSRecPtr  $1C36
*-------------------------------------------------

TCPIPGetDNS ENT
 DBGMSG TCPIPGetDNS
 TSC
 PHD
 TCD
 LDA >DNSIPMAIN
 STA [7]
 LDY #2
 LDA >DNSIPMAIN+2
 STA [7],Y
 INY
 INY
 LDA >DNSIPAUX
 STA [7],Y
 INY
 INY
 LDA >DNSIPAUX+2
 STA [7],Y
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetDNS(DNSRecPtr)  $1D36
*-------------------------------------------------

TCPIPSetDNS ENT
 DBGMSG TCPIPSetDNS
 TSC
 PHD
 TCD
 LDA [7]
 STA >DNSIPMAIN
 LDY #2
 LDA [7],Y
 STA >DNSIPMAIN+2
 INY
 INY
 LDA [7],Y
 STA >DNSIPAUX
 INY
 INY
 LDA [7],Y
 STA >DNSIPAUX+2
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetTuningTable(tuneptr)  $1E36
*-------------------------------------------------

TCPIPGetTuningTable ENT
 DBGMSG TCPIPGetTuningTable
 LDA RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+RAWSTACKEDPARMS,S
 PHA
 TEMPDPON
 LDA #10 ;length of table
 STA [0]
 LDY #2
 LDA >IPUSERSLICE
 STA [0],Y
 INY
 INY
 LDA >IPRUNQFREQ
 STA [0],Y
 INY
 INY
 LDA >IPRUNQSLICE
 STA [0],Y
 INY
 INY
 LDA >TCPUSERSLICE
 STA [0],Y
 TEMPDPOFF
 PLS 2
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetTuningTable(tuneptr)  $1F36
*-------------------------------------------------

TCPIPSetTuningTable ENT
 DBGMSG TCPIPSetTuningTable
 LDA RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+RAWSTACKEDPARMS,S
 PHA
 TEMPDPON
 LDA [0]
 CMP #10
 BNE :BADLEN

 LDY #2
 LDA [0],Y
 BEQ :ERR1
 CMP #10+1
 BCS :ERR1
 STA >IPUSERSLICE
:ERR1
 INY
 INY
 LDA [0],Y
 STA >IPRUNQFREQ

 INY
 INY
 LDA [0],Y
 BEQ :ERR2
 CMP #10+1
 BCS :ERR2
 STA >IPRUNQSLICE
:ERR2
 INY
 INY
 LDA [0],Y
 BEQ :ERR3
 CMP #10+1
 BCS :ERR3
 STA >TCPUSERSLICE
:ERR3
 TEMPDPOFF
 PLS 2
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

:BADLEN TEMPDPOFF
 PLS
 LDA #terrBADTUNETABLELEN
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSetMyIPAddress(ipaddress)  $3836
*-------------------------------------------------

TCPIPSetMyIPAddress ENT
 DBGMSG TCPIPSetMyIPAddress
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHD
 LDA >MYDP
 TCD
 LDA 2+RAWSTACKEDPARMS,S
 STA MYIPADDRESS
 LDA 2+RAWSTACKEDPARMS+2,S
 STA MYIPADDRESS+2
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetDP():DP  $3936
*-------------------------------------------------

TCPIPGetDP ENT
 DBGMSG TCPIPGetDP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 LDA >MYDP
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPGetDebugHex():flag  $3A36
*-------------------------------------------------

TCPIPGetDebugHex ENT
 DBGMSG TCPIPGetDebugHex
 LDA >DEBUGHEX
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetDebugHex():flag  $3B36
*-------------------------------------------------

TCPIPSetDebugHex ENT
 DBGMSG TCPIPSetDebugHex
 LDA RAWSTACKEDPARMS,S
 STA >DEBUGHEX
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetDebugTCP():flag  $3C36
*-------------------------------------------------

TCPIPGetDebugTCP ENT
 DBGMSG TCPIPGetDebugTCP
 LDA >DEBUGTCP
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetDebugTCP(flag)  $3D36
*-------------------------------------------------

TCPIPSetDebugTCP ENT
 DBGMSG TCPIPSetDebugTCP
 LDA RAWSTACKEDPARMS,S
 STA >DEBUGTCP
 BNE :SKIPCLOSE ;When debugging is turned off, close the file
 JSL TCPCLOSEDEBUGFILE
:SKIPCLOSE
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

*-------------------------------------------------
* _TCPIPSendIPDatagram(dgmptr)  $4036
*-------------------------------------------------

TCPIPSendIPDatagram ENT
 DBGMSG TCPIPSendIPDatagram
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 LDA >LINKFLAG
 BEQ :NONETWORK
 LDA RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+RAWSTACKEDPARMS,S
 PHA
 JSL IPSENDDATAGRAM ;(dgmptr:longword)
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip
:NONETWORK LDA #terrNOCONNECTION&terrmask
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPConvertIPToClass(ipaddress):class  $4136
*-------------------------------------------------

TCPIPConvertIPToClass ENT
 DBGMSG TCPIPConvertIPToClass
 PHS
 LDA 2+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+2+RAWSTACKEDPARMS,S
 PHA
 JSL IPTOCLASS
 PLA
 STA RAWSTACKEDPARMS+4,S
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetConnectMsgFlag():conMsgFlag  $4236
*-------------------------------------------------

TCPIPGetConnectMsgFlag ENT
 DBGMSG TCPIPGetConnectMsgFlag
 LDA >CONNECTMSGFLAG
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetConnectMsgFlag(conMsgFlag)  $4336
*-------------------------------------------------

TCPIPSetConnectMsgFlag ENT
 DBGMSG TCPIPSetConnectMsgFlag
 LDA RAWSTACKEDPARMS,S
 STA >CONNECTMSGFLAG
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetUsername(unBuffPtr)  $4436
*-------------------------------------------------

TCPIPGetUsername ENT
 DBGMSG TCPIPGetUsername(unBuffPtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA >USERNAME
 TAY
 TAX
]L1 LDA >USERNAME,X
 STA [RAWSTACKEDPARMS],Y
 DEX
 DEY
 BPL ]L1
 REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetUsername(usernamePtr)  $4536
*-------------------------------------------------

TCPIPSetUsername ENT
 DBGMSG TCPIPSetUsername(usernamePtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA [RAWSTACKEDPARMS]
 CMP #50+1
 BCC :LENOK
 LDA #50
:LENOK STA >USERNAME
 EOR #0
 BEQ :DONE
 TAY
 TAX
]L1 LDA [RAWSTACKEDPARMS],Y
 STA >USERNAME,X
 DEX
 DEY
 BNE ]L1
:DONE REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetPassword(pwBuffPtr)  $4636
*-------------------------------------------------

TCPIPGetPassword ENT
 DBGMSG TCPIPGetPassword(pwBuffPtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA >PASSWORD
 TAY
 TAX
]L1 LDA >PASSWORD,X
 STA [RAWSTACKEDPARMS],Y
 DEX
 DEY
 BPL ]L1
 REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetPassword(passwordPtr)  $4736
*-------------------------------------------------

TCPIPSetPassword ENT
 DBGMSG TCPIPSetPassword(passwordPtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA [RAWSTACKEDPARMS]
 CMP #50+1
 BCC :LENOK
 LDA #50
:LENOK STA >PASSWORD
 EOR #0
 BEQ :DONE
 TAY
 TAX
]L1 LDA [RAWSTACKEDPARMS],Y
 STA >PASSWORD,X
 DEX
 DEY
 BNE ]L1
:DONE REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPValidateIPCString(cstringPtr):validFlag  $1536
*-------------------------------------------------

TCPIPValidateIPCString ENT
 DBGMSG TCPIPValidateIPCString(cstringPtr):validFlag
 TSC
 PHD
 TCD
 SEP $30
 LDY #0
 TYX
]L1 LDA [RAWSTACKEDPARMS],Y
 BEQ :TERM
 CMP #','
 BEQ :TERM
 CMP #':'
 BEQ :TERM
 CMP #'.'
 BEQ :DOT
 CMP #'0'
 BCC :NO
 CMP #'9'+1
 BCS :NO
 BRA :NEXT
:DOT INX
:NEXT INY
 BNE ]L1
 BRA :NO
:TERM DEY
 LDA [RAWSTACKEDPARMS],Y ;was there numeric after the last dot?
 CMP #'.'
 BEQ :NO
 REP $30
 CPX #3 ;Must be 3 dots
 BNE :NO
 CPY #15+1 ;"xxx.xxx.xxx.xxx" is maximum length
 BCS :NO
 PHS 2+1
 PZL RAWSTACKEDPARMS
 JSL CASC2HEXIP
 PLS 2+1
 BCS :NO
:OK REP $30
 LDA #true
:OUT STA RAWSTACKEDPARMS+4
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip
:NO REP $30
 LDA #false
 BRA :OUT

*-------------------------------------------------
* _TCPIPValidateIPString(pstringPtr):validFlag  $4836
*-------------------------------------------------

TCPIPValidateIPString ENT
 DBGMSG TCPIPValidateIPString(pstringPtr):validFlag
 TSC
 PHD
 TCD
 SEP $30
 LDA [RAWSTACKEDPARMS],Y
 INC
 PHA
 LDY #1 ;string index
 LDX #0 ;byte counter
]L1 LDA [RAWSTACKEDPARMS],Y
 CMP #','
 BEQ :TERM
 CMP #':'
 BEQ :TERM
 CMP #'.'
 BEQ :DOT
 CMP #'0'
 BCC :NO
 CMP #'9'+1
 BCS :NO
 BRA :NEXT
:DOT INX
:NEXT INY
 TYA
 CMP 1,S
 BCC ]L1
:TERM DEY
 LDA [RAWSTACKEDPARMS],Y ;was there numeric after the last dot?
 CMP #'.'
 BEQ :NO
 REP $30
 CPX #3 ;Must be 3 dots
 BNE :NO
 CPY #15+1 ;"xxx.xxx.xxx.xxx" is maximum length
 BCS :NO
 PHS 2+1
 PZL RAWSTACKEDPARMS
 JSL PASC2HEXIP
 PLS 2+1
 BCS :NO
:OK SEP $30
 PLA
 REP $30
 LDA #true
:OUT STA RAWSTACKEDPARMS+4
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip
:NO SEP $30
 PLA
 REP $30
 LDA #false
 BRA :OUT

*-------------------------------------------------
* _TCPIPGetLinkVariables():variablesPtr  $4A36
*-------------------------------------------------

TCPIPGetLinkVariables ENT
 DBGMSG TCPIPGetLinkVariables():variablesPtr
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 PHD
 LDA >MYDP
 TCD
 LDA LINKVARIABLESPTR
 STA 2+RAWSTACKEDPARMS,S
 LDA LINKVARIABLESPTR+2
 STA 2+RAWSTACKEDPARMS+2,S
 PLD
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPGetLinkLayer(linkInfoBlkPtr)  $5436
*-------------------------------------------------

TCPIPGetLinkLayer ENT
 DBGMSG TCPIPGetLinkLayer(linkInfoBlkPtr)
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 LDA >LINKFLAG
 BEQ :NOTCONNECTED
 PHD
 LDA >MYDP
 TCD
 LDA 2+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+2+RAWSTACKEDPARMS,S
 PHA
 JSL LINKMODULEINFO
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

:NOTCONNECTED LDA #terrNOCONNECTION&terrmask
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPEditLinkConfig(connectHandle,disconnectHandle)  $4B36
*-------------------------------------------------

TCPIPEditLinkConfig ENT
 DBGMSG TCPIPEditLinkConfig(connectHandle,disconnectHandle)

 LDA >AMIACTIVE
 BEQL NOTACTIVE8

 PHD
 LDA >MYDP
 TCD

* Make sure tools are started

 LDX #0
]L1 LDA >:TOOLTBL,X
 BEQ :TOOLSOK
 PHX
 PEA 0
 ORA #$0600 ;_xxxxStatus
 TAX
 JSL $E10000
 PLA
 BCS :NOTSTARTED
 BEQ :NOTSTARTED
 PLX
 INX
 INX
 BRA ]L1
:TOOLSOK

* Make sure the link layer module is loaded

 LDA >CONNECTMETHOD
 JSL LOADLINKLAYER
 BCS :ERR ;A = error

* Call it

 LDA 2+RAWSTACKEDPARMS+4+2,S
 PHA
 LDA 2+2+RAWSTACKEDPARMS+4,S
 PHA
 LDA 2+2+2+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+2+2+2+RAWSTACKEDPARMS,S
 PHA
 JSL LINKCONFIGURE

 LDA #terrOK
:ERR PLD
 LDY #8
 JMP STRIPTOOLEXIT

:NOTSTARTED PLX
 LDA #terrBADENVIRONMENT&terrmask
 BRA :ERR

:TOOLTBL DA 1 ;Tool Locator
 DA 2 ;Memory Manager
 DA 3 ;Miscellaneous Toolset
 DA 4 ;Quickdraw II
 DA 5 ;Event Manager
 DA 11 ;Integer Math Toolset
 DA 12 ;Text Toolset
 DA 14 ;Window Manager
 DA 15 ;Menu Manager
 DA 16 ;Control Manager
 DA 17 ;System Loader
 DA 18 ;Quickdraw II Auxilliary
 DA 20 ;LineEdit Toolset
 DA 21 ;Dialog Manager
 DA 22 ;Scrap Manager
 DA 30 ;Resource Manager
 DA 0

*-------------------------------------------------
* _TCPIPGetModuleNames():moduleListPtr  $4C36
*-------------------------------------------------

TCPIPGetModuleNames ENT
 DBGMSG TCPIPGetModuleNames():moduleListPtr  $4C36
 LDA #MODULELIST
 STA RAWSTACKEDPARMS,S
 LDA #^MODULELIST
 STA RAWSTACKEDPARMS+2,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPRebuildModuleList  $4D36 RESTRICTED
*-------------------------------------------------

TCPIPRebuildModuleList ENT
 DBGMSG TCPIPRebuildModuleList ;$4D36 RESTRICTED
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 JSL BuildModuleList
 JMP TOOLEXIT

*-------------------------------------------------
* _TCPIPGetHostName(hnBuffPtr)  $5136
*-------------------------------------------------

TCPIPGetHostName ENT
 DBGMSG TCPIPGetHostName(hnBuffPtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA >HOSTNAME
 TAY
 TAX
]L1 LDA >HOSTNAME,X
 STA [RAWSTACKEDPARMS],Y
 DEX
 DEY
 BPL ]L1
 REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPSetHostName(hostnamePtr)  $5236
*-------------------------------------------------

TCPIPSetHostName ENT
 DBGMSG TCPIPSetHostName(hostnamePtr)
 TSC
 PHD
 TCD
 SEP $30
 LDA [RAWSTACKEDPARMS]
 CMP #30+1
 BCC :LENOK
 LDA #30
:LENOK STA >HOSTNAME
 TAY
 TAX
]L1 LDA [RAWSTACKEDPARMS],Y
 STA >HOSTNAME,X
 DEX
 DEY
 BNE ]L1
 REP $30
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

*-------------------------------------------------
* _TCPIPPtrToPtr(from,to,len)  $5536
*-------------------------------------------------

TCPIPPtrToPtr ENT
 DBGMSG TCPIPPtrToPtr(from,to,len)
 LDA RAWSTACKEDPARMS+8+2,S
 PHA
 LDA 2+RAWSTACKEDPARMS+8,S
 PHA
 LDA 4+RAWSTACKEDPARMS+4+2,S
 PHA
 LDA 2+4+RAWSTACKEDPARMS+4,S
 PHA
 LDA 4+4+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+4+4+RAWSTACKEDPARMS,S
 PHA
 JSL PtrToPtr
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4*3
 JML ToStrip

*-------------------------------------------------
* _TCPIPPtrToPtrNeg(from,to,len)  $5636
*-------------------------------------------------

TCPIPPtrToPtrNeg ENT
 DBGMSG TCPIPPtrToPtrNeg(from,to,len)
 LDA RAWSTACKEDPARMS+8+2,S
 PHA
 LDA 2+RAWSTACKEDPARMS+8,S
 PHA
 LDA 4+RAWSTACKEDPARMS+4+2,S
 PHA
 LDA 2+4+RAWSTACKEDPARMS+4,S
 PHA
 LDA 4+4+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+4+4+RAWSTACKEDPARMS,S
 PHA
 JSL PtrToPtrNeg
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4*3
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetAuthMessage(userid):authMsgHandle  $5736
*-------------------------------------------------

TCPIPGetAuthMessage ENT
 DBGMSG TCPIPGetAuthMessage(userid):authMsgHandle
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHD
 LDA >MYDP
 TCD
 PZL AUTHMSGHANDLE
 PHS 2
 LDY #8+2
 LDA [AUTHMSGHANDLE],Y
 PHA
 DEY
 DEY
 LDA [AUTHMSGHANDLE],Y
 PHA
 LDA 4+4+4+2+RAWSTACKEDPARMS,S
 PHA
 PEA $0008
 PHL #0
 _NewHandle
 LDA 1+2,S
 TAY
 STA 4+4+2+RAWSTACKEDPARMS+2+2,S
 LDA 1,S
 TAX
 STA 4+4+2+RAWSTACKEDPARMS+2,S
 PHS 2
 PHY
 PHX
 _GetHandleSize
 _HandToHand
 PLD
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

*-------------------------------------------------
* _TCPIPMangleDomainName(flags,dnPstrinPtr):port  $5936
*-------------------------------------------------

mfRemovePort = %1000_0000_0000_0000
mfTranslatePCT = %0100_0000_0000_0000
mfLowerCase = %0010_0000_0000_0000
mfDelIllegal = %0001_0000_0000_0000
mfStripHigh = %0000_1000_0000_0000

TCPIPMangleDomainName ENT
 DBGMSG TCPIPMangleDomainName(flags,dnPstrinPtr):port
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD

* Set up
 LDA [1+RAWSTACKEDPARMS]
 AND #$FF
 STA :STRLEN
 STZ :PORT
 STZ :PORTINDEX

* Do port stuff

 LDA #:PARSEPORT
 JSR :SCAN
 LDA :PORTINDEX
 BEQ :NOPORT
 LDA :STRLEN
 SEC
 SBC :PORTINDEX
 BEQ :CHOPPORT ;Comma was at the very end
 TAY
 LDA 1+RAWSTACKEDPARMS
 SEC
 ADC :PORTINDEX
 TAX
 LDA 1+RAWSTACKEDPARMS+2
 ADC #0
 PHS 2
 PHA
 PHX
 PHY
 PEA 0
 _Dec2Long
 PLX
 PLA
 BNE :CHOPPORT
 STX :PORT
:CHOPPORT LDA 1+RAWSTACKEDPARMS+4
 AND #mfRemovePort
 BEQ :DONEPORT
 LDA :PORTINDEX
 SEP $20
 DEC
 STA [1+RAWSTACKEDPARMS]
 REP $20
:DONEPORT LDA :PORTINDEX ;either way, force scan to stop before port
 DEC
 STA :STRLEN
 BEQ :FINISHED
:NOPORT

* Translate % stuff

 LDA 1+RAWSTACKEDPARMS+4
 AND #mfTranslatePCT
 BEQ :DONEPCT
 LDA #:PCT
 JSR :SCAN
:DONEPCT

* Convert to lower case

 LDA 1+RAWSTACKEDPARMS+4
 AND #mfLowerCase
 BEQ :DONELC
 LDA #:LCASE
 JSR :SCAN
:DONELC

* Delete illegal characters

 LDA 1+RAWSTACKEDPARMS+4
 AND #mfDelIllegal
 BEQ :DONEILL
 LDA #:ILLEGAL
 JSR :SCAN
:DONEILL

* Strip high bit

 LDA 1+RAWSTACKEDPARMS+4
 AND #mfStripHigh
 BEQ :DONESTRIP
 LDA #:STRIP
 JSR :SCAN
:DONESTRIP

* Exit

:FINISHED LDA :PORT
 STA 1+RAWSTACKEDPARMS+4+2
 PLD
 PLB
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #6
 JML ToStrip

 mx %11
:PARSEPORT AND #$7F
 CMP #','
 BEQ :PORT?
 CMP #':'
 BEQ :PORT?
 CMP #';'
 BEQ :PORT?
 CLC
 RTS
:PORT? STY :PORTINDEX
 SEC
 RTS
 mx 0

 mx %11
:LCASE ROL
 PHP
 LSR
 CMP #'A'
 BCC :LCOK
 CMP #'Z'+1
 BCS :LCOK
 CLC
 ADC #$20
 ASL
 PLP
 ROR ;Carry is clear
 STA [1+RAWSTACKEDPARMS],Y
 RTS
:LCOK PLP
 CLC
 RTS
 mx 0

 mx %11
:STRIP AND #$7F
 STA [1+RAWSTACKEDPARMS],Y
 CLC
 RTS
 mx 0

 mx %11
:PCT AND #$7F
 CMP #'%'
 BEQ :GOTPCT
 CLC
 RTS
:GOTPCT LDA #:PCTHEX1
 STA :MOD+1
 LDA #>:PCTHEX1
 STA :MOD+1+1
 CLC
 RTS
:PCTHEX1 JSR :NIBBLE
 ASL
 ASL
 ASL
 ASL
 STA :HEX1
 LDA #:PCTHEX2
 STA :MOD+1
 LDA #>:PCTHEX2
 STA :MOD+1+1
 CLC
 RTS
:PCTHEX2 JSR :NIBBLE
 ORA :HEX1
 DEY
 DEY
 STA [1+RAWSTACKEDPARMS],Y ;store over "%"
 INY
 JSR :RIPPLE
 JSR :RIPPLE
 DEY
 LDA #:PCT
 STA :MOD+1
 LDA #>:PCT
 STA :MOD+1+1
 CLC
 RTS

:HEX1 DS 1

:NIBBLE AND #$7F
 CMP #'0'
 BCC :NIBERR
 CMP #'9'+1
 BCC :NUM
 CMP #'A'
 BCC :NIBERR
 CMP #'F'+1
 BCC :ALPHA
 CMP #'a'
 BCC :NIBERR
 CMP #'f'+1
 BCS :NIBERR
:ALPHA ADC #9
:NUM AND #$F
 RTS
:NIBERR LDA #0
 RTS

:RIPPLE PHY ;Must do entire string re embedded length
]L1 INY
 LDA [1+RAWSTACKEDPARMS],Y
 DEY
 STA [1+RAWSTACKEDPARMS],Y
 INY
 TYA
 CMP [1+RAWSTACKEDPARMS]
 BCC ]L1
 PLY
 DEC :STRLEN ;Decrement less port length
 LDA [1+RAWSTACKEDPARMS]
 DEC ;Decrement real length
 STA [1+RAWSTACKEDPARMS]
 RTS
 mx 0

 mx %11
:ILLEGAL AND #$7F
 CMP #'-'
 BEQ :LEG
 CMP #'.'
 BEQ :LEG
 CMP #'0'
 BCC :ILL
 CMP #'9'+1
 BCC :LEG
 CMP #'A'
 BCC :ILL
 CMP #'Z'+1
 BCC :LEG
 CMP #'a'
 BCC :ILL
 CMP #'z'+1
 BCC :LEG
:ILL JSR :RIPPLE
:LEG CLC
 RTS
 mx 0

* Generic scan code

:SCAN STA :MOD+1
 SEP $30
 LDY #0
]L1 INY
 LDA [1+RAWSTACKEDPARMS],Y
:MOD JSR 0
 BCS :SCANOUT
 CPY :STRLEN
 BCC ]L1
:SCANOUT REP $30
 RTS

:STRLEN DA 0
:PORTINDEX DA 0
:PORT DA 0

*-------------------------------------------------
* _TCPIPGetAliveFlag():aliveFlag  $5A36
*-------------------------------------------------

TCPIPGetAliveFlag ENT
 DBGMSG TCPIPGetAliveFlag
 LDA >ALIVEFLAG
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetAliveFlag(aliveFlag)  $5B36
*-------------------------------------------------

TCPIPSetAliveFlag ENT
 DBGMSG TCPIPSetAliveFlag
 LDA >LINKFLAG
 BNE :CONNECTED
 LDA RAWSTACKEDPARMS,S
 STA >ALIVEFLAG
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:OUT LDY #2
 JML ToStrip
:CONNECTED LDX #terrCONNECTED&terrmask
 BRA :OUT

*-------------------------------------------------
* _TCPIPGetAliveMinutes():aliveMinutes  $5C36
*-------------------------------------------------

TCPIPGetAliveMinutes ENT
 DBGMSG TCPIPGetAliveMinutes
 LDA >ALIVEMINUTES
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetAliveMinutes(aliveMinutes)  $5D36
*-------------------------------------------------

TCPIPSetAliveMinutes ENT
 DBGMSG TCPIPSetAliveMinutes
 LDA >LINKFLAG
 BNE :CONNECTED
 LDA RAWSTACKEDPARMS,S
 BEQ :BADMINS
 CMP #1000
 BCS :BADMINS
 STA >ALIVEMINUTES
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:OUT LDY #2
 JML ToStrip
:BADMINS LDX #terrBADALIVEMINUTES&terrmask
 BRA :OUT
:CONNECTED LDX #terrCONNECTED&terrmask
 BRA :OUT

*-------------------------------------------------
* _TCPIPGetBootConnectFlag():bootConnectFlag  $5F36
*-------------------------------------------------

TCPIPGetBootConnectFlag ENT
 DBGMSG TCPIPGetBootConnectFlag
 LDA >BOOTCONNECTFLAG
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSetBootConnectFlag(bootConnectFlag)  $6036
*-------------------------------------------------

TCPIPSetBootConnectFlag ENT
 DBGMSG TCPIPSetBootConnectFlag
 LDA >LINKFLAG
 BNE :CONNECTED
 LDA RAWSTACKEDPARMS,S
 STA >BOOTCONNECTFLAG
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:OUT LDY #2
 JML ToStrip
:CONNECTED LDX #terrCONNECTED&terrmask
 BRA :OUT

*-------------------------------------------------
* _TCPIPGetSysEventTrigger(triggerNumber):triggerProcPtr  $6536
*-------------------------------------------------

TCPIPGetSysEventTrigger ENT
 DBGMSG TCPIPGetSysEventTrigger
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 LDA RAWSTACKEDPARMS,S
 CMP #strgCount+1
 BCS :BADTRIGGER
 DEC
 ASL
 TAX
 LDA >SystemTriggers,X
 STA RAWSTACKEDPARMS+2,S
 LDA >SystemTriggers+2,X
 STA RAWSTACKEDPARMS+2+2,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR LDY #2
 JMP STRIPTOOLEXIT
:BADTRIGGER LDA #terrBADTRIGGERNUM&terrmask
 BRA :ERR

*-------------------------------------------------
* _TCPIPSetSysEventTrigger(triggerNumber,triggerProcPtr)  $6636
*-------------------------------------------------

TCPIPSetSysEventTrigger ENT
 DBGMSG TCPIPSetSysEventTrigger
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 LDA RAWSTACKEDPARMS+4,S
 CMP #strgCount+1
 BCS :BADTRIGGER
 DEC
 ASL
 TAX
 LDA RAWSTACKEDPARMS,S
 STA >SystemTriggers,X
 LDA RAWSTACKEDPARMS+2,S
 STA >SystemTriggers+2,X
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR LDY #6
 JMP STRIPTOOLEXIT
:BADTRIGGER LDA #terrBADTRIGGERNUM&terrmask
 BRA :ERR

 SAV I.CALLS.L

 END
