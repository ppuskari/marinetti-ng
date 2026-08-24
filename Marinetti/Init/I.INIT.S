 LST OFF
*=================================================
*
* I.INIT.S - Main code for TCPIP Init
*
* Copyright (C) 1997-2003 Richard Bennett-Forrest
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
* 2003.06.30 RJBF - Initial release as open source
* 2005.05.18 AJR - Fix usage of MYID in TCPIPLogin [1204455]
* 2005.07.17 AJR - Fixed stack imbalance in TCPIPStatusUDP [1183332]
* 2012.03.22 AJR - Fixed issues with PASC2HEX [3509349]
*
*=================================================
 REL
 mx 0

 USE 4/RJBUTIL.MACS
 USE 4/LOCATOR.MACS
 USE 4/MISC.MACS
 USE 4/MEM.MACS
 USE 4/DESK.MACS
 USE 4/LOAD.MACS
 USE 4/INT.MACS
 USE 4/EVENT.MACS
 USE 4/RESOURCE.MACS
 USE 4/TEXT.MACS
 USE 4/TCPIP.MACS
 USE ../EQUATES/BUILD.EQU ;Build stuff, version etc.
 USE ../EQUATES/I.EQU ;My personal stuff
 USE ../EQUATES/TCPIP.EQU ;Application stuff

 EXT DVRINIT,DVRSHUTDOWN,MODULELIST,BuildModuleList
 EXT LINKCONNECT,LINKRECONNECT,LINKDISCONNECT
 EXT DUMPLINKLAYER,LOADLINKLAYER,SHOWLINKVERSIONS
 EXT LINKRECONSTATUS

 EXT IPPOLL,IPPKTCOUNT,IPKILLPKTLIST
 EXT IPNEXTPACKET,ERRORTABLE

 EXT ICMPSENDECHO,ICMPSEND

 EXT PREFERENCES,PREFSLENGTH,DNSIPMAIN,CONNECTMETHOD
 EXT IPUSERSLICE,IPRUNQFREQ,IPRUNQSLICE,RECONVALID,RECONIPADDRESS
 EXT DNSIPAUX,CONNECTMSGFLAG,USERNAME,PASSWORD
 EXT ALIVEFLAG,ALIVEMINUTES

 EXT UDPSEND

 EXT NEWQUEUE,DESTROYQUEUE,GETNEXTINQUEUE,QUEUESIZE
 EXT FINDINQUEUE,RIPFROMQUEUE,PtrToPtr,TIMERVALID?

 EXT TCPOPEN,TCPWRITE,TCPREAD,TCPCLOSE,TCPABORT,TCPSTATUS
 EXT TCPCONNECTIONS,TCPPOLLTIMERS,SETSTATEL,TCPACCEPT

 EXT SENDIPC

 EXT GetTick

 EXT PollDNR,KillDNR

 EXT StartIPOut,ShutIPOut

 EXT TCPIPGetConnectStatus
 EXT TCPIPGetErrorTable
 EXT TCPIPConvertIPToHex
 EXT TCPIPConvertIPToASCII
 EXT TCPIPGetMyIPAddress
 EXT TCPIPGetConnectMethod
 EXT TCPIPSetConnectMethod
 EXT TCPIPGetMTU
 EXT TCPIPSetDNS
 EXT TCPIPGetDNS
 EXT TCPIPCancelDNR
 EXT TCPIPDNRNameToIP
 EXT TCPIPSetTuningTable
 EXT TCPIPGetTuningTable
 EXT TCPIPSetMyIPAddress
 EXT TCPIPGetDP
 EXT TCPIPGetDebugHex
 EXT TCPIPSetDebugHex
 EXT TCPIPGetDebugTCP
 EXT TCPIPSetDebugTCP
 EXT TCPIPSendIPDatagram
 EXT TCPIPConvertIPToClass
 EXT TCPIPGetConnectMsgFlag
 EXT TCPIPSetConnectMsgFlag
 EXT TCPIPGetUsername
 EXT TCPIPSetUsername
 EXT TCPIPGetPassword
 EXT TCPIPSetPassword
 EXT TCPIPValidateIPString
 EXT TCPIPGetLinkVariables
 EXT TCPIPEditLinkConfig
 EXT TCPIPGetModuleNames
 EXT TCPIPRebuildModuleList
 EXT TCPIPGetHostName
 EXT TCPIPSetHostName
 EXT TCPIPGetLinkLayer
 EXT TCPIPPtrToPtr
 EXT TCPIPPtrToPtrNeg
 EXT TCPIPGetAuthMessage
 EXT TCPIPValidateIPCString
 EXT TCPIPConvertIPCToHex
 EXT TCPIPConvertIPToCASCII
 EXT TCPIPMangleDomainName
 EXT TCPIPGetAliveFlag ;$5A36
 EXT TCPIPSetAliveFlag ;$5B36
 EXT TCPIPGetAliveMinutes ;$5C36
 EXT TCPIPSetAliveMinutes ;$5D36
 EXT TCPIPGetBootConnectFlag ;$5F36
 EXT TCPIPSetBootConnectFlag ;$6036
 EXT TCPIPGetSysEventTrigger ;$6536 v3.0
 EXT TCPIPSetSysEventTrigger ;$6636 v3.0
 EXT TCPIPGetDNRTimeouts ;$6736 v3.0
 EXT TCPIPSetDNRTimeouts ;$6836 v3.0

*-------------------------------------------------
* Main initialisation (boot)
*-------------------------------------------------

INIT ENT
 PHB
 PHK
 PLB
 PHD

* Get a new ProDOS type ID

 ~GetNewID #$3100
 PLA
 STA MYID

* Loader has given me a stack and direct page, but this will be purged
* once I return to the loader at boot time. So, I can use the temporary
* DP, but need to allocate my own permanent one.

 JSR NEWDP

* Check if I'm allowed to start up

 JSL $E100A8 ;Check GS/OS version first
 DA $202A
 ADRL :GETVERSION
 LDA :GETVERSION+2
 CMP #$402
 BCC :NOLOAD ;If bad, just exit. (_ShowBootInfo is 6.0.1)

 LDA >$E0C061 ;Option key down? (tests $E0C062)
 BPL :OPTIONOK

:OPTION ~ShowBootInfo #:LOADSTR;#0
:NOLOAD PLD
 PLB
 LDA #1
 STA 4,S
 RTL

:OPTIONOK

 do EXPIRY
 ~ReadTimeHex
 LDA 4,S
 AND #$FF
 SEC
 ADC #1900-1 ;To stop disassemblers a little
 CMP #YEAR
 SEP $20
 BCC :OK
 BNE :BOMB
 LDA 6,S
 CMP #MONTH-1
 BCC :OK
 BNE :BOMB
 LDA 5,S
 CMP #DAY-1
 BCC :OK
:BOMB SEC
 HEX 24
:OK CLC
 REP $20
 PLS 4
 BCC :DONEDATE

 ~ShowBootInfo #:EXPSTR;#0
 PLD
 PLB
 LDA #1
 STA 4,S
 RTL

:EXPSTR ASC 'TCP/IP                v'
 VERASC
 ASC '  (Marinetti) expired: '
 ASC #DAY
 ASC '/'
 ASC #MONTH
 ASC '/'
 ASC #YEAR
 ASC ' (dmy)!'
 HEX 0D
 DFB 0
:DONEDATE
 fin

* All OK, start it up!

 STZ :STROK
 ~ShowBootInfo #:LOADSTR;#0

* Load long version number

 ~OpenResourceFile #%11;#0;#:MYPATH
 ~LoadResource #$8029;#1
 PLL TMPHANDLE
 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 LDA [TMPTR]
 STA LONGVERSION
 LDA [TMPTR],Y
 STA LONGVERSION+2
 ~ReleaseResource #-1;#$8029;#1
 _CloseResourceFile

* Create message centre stuff for tool stub

 ~MessageByName #$8000;#MSGBLK
 PLS 2

* Set up DP stuff

 STZ MYIPADDRESS ;not connected
 STZ MYIPADDRESS+2

 LDA >$E100DC ;TickCount without Event Manager active
 STA IPUNIQUEID

 PHS 2
 JSL NEWQUEUE
 PLXA RAWPKTSHANDLE

 PHS 2
 JSL NEWQUEUE
 PLXA PKTLISTHANDLE

 PHS 2
 JSL NEWQUEUE
 PLXA FRAGQUEUE

 do 0
 ~NewHandle #2;MYID;#%0000_0000_0001_1000;#0
 PLXA DNRCACHEHANDLE
 LDA [DNRCACHEHANDLE]
 STA TMPTR
 LDY #2
 LDA [DNRCACHEHANDLE],Y
 STA TMPTR+2
 LDA #0
 STA [TMPTR]
 fin

 PHS 2
 JSL NEWQUEUE
 PLXA DNRHANDLE

 STZ DNRSPENDING

 ~NewHandle #0;MYID;#$0008;#0
 PLXA AUTHMSGHANDLE

 LDA >IPRUNQFREQ
 STA RUNQIPFREQ

 LDA #-1
 STA AMIACTIVE

* Install notification procedure for P8 switches

 JSL $E100A8
 DA $2034 ;AddNotifyProc
 ADRL NOTIFYPARMS

* Install RunQ proc for automatic IP and TCP polling

 ~AddToRunQ #RUNQIPITEM

* Bit of housekeeping

 JSL TCPIPLoadPreferences

* And show version of link layer modules

 JSL BuildModuleList
 JSL SHOWLINKVERSIONS

* I'm up, send IPC.

 LDX #0
 TXA
 LDY #TCPIPSaysHello
 JSL SENDIPC

* Continue boot

 PLD
 PLB
 RTL

:LOADSTR ASC 'TCP/IP                v'
 VERASC
 ASC '  (Marinetti)'
:STROK ASC ' not loaded, option key down.',00

:GETVERSION DA 1,0 ;For GS/OS version check

:MYPATH STRL '*:System:System.Setup:TCPIP'

LONGVERSION ADRL 0

*-------------------------------------------------
* Message block for init and tool to talk
*-------------------------------------------------

MSGBLK DA MSGBLKLEN
 STR 'TCP/IP tool info'
 DA CODESYNCVERSION ;internal version to sync init and tool
 ADRL FPTCOUNT ;Pointer to real FTP
MSGBLKLEN = *-MSGBLK

*-------------------------------------------------
* RunQ stuff
*-------------------------------------------------

RUNQIPITEM ADRL 0
RUNQIPFREQ DA 0
 DA $A55A
 ADRL 0

RUNQIPCODE PHB
 PHK
 PLB
 LDA AMIACTIVE
 BEQ :INACT
 LDA LINKFLAG ;Is there an actual connection?
 BEQ :INACT
 JSR POLLIP
:INACT LDA IPRUNQFREQ
 STA RUNQIPFREQ
 PLB
 RTL

*-------------------------------------------------
* NEWDP - Assume no DP, allocate a new one and switch to it
*-------------------------------------------------

NEWDP DBGMSG NEWDP
 PHS 2
 PHL #$100
 PHW MYID
 PEA $C005
 PHL #0
 _NewHandle ;#$100;ID;#$C005;#0
 BCS :ERR
 TSC
 TCD
 LDA 1
 STA MYDPHANDLE
 LDA 1+2
 STA MYDPHANDLE+2
 LDA [1]
 STA MYDP
 TCD
 PLS 2

 do INITDPCC
 LDX #$100-2
 LDA #$CCCC
]L1 STA 0,X
 DEX
 DEX
 BPL ]L1
 fin

 RTS

:ERR SYSERR 'TCP/IP - _NewHandle error on DP $'

*-------------------------------------------------
* TURNON
*-------------------------------------------------

TURNON DBGMSG TURNON
 JSR NEWDP ;Get a new DP
 PHL SAVEDPHANDLE
 PEA 0
 PHD
 PHL #$100
 _HandToPtr ;Copy it back
 ~DisposeHandle SAVEDPHANDLE
 LDA #-1
 STA AMIACTIVE
 RTS

*-------------------------------------------------
* TURNOFF -- Kills all GS/OS stuff when switching to P8, and Shutdown
*
* NOTE: This is called by Shutdown notify, so no GS/OS calls!
* NOTE: When this code exits, there is no direct page!
*-------------------------------------------------

TURNOFF DBGMSG TURNOFF
 STZ AMIACTIVE ;Turn everything off

 PHS 2 ;Allocate some save space for DP
 PHL #$100
 PHW MYID
 PEA $0008 ;non-special movable
 PHL #0
 _NewHandle
 BCS :ERR
 PLX
 STX SAVEDPHANDLE
 PLY
 STY SAVEDPHANDLE+2

 PEA 0
 LDA MYDP
 PHA
 PHY
 PHX
 PHL #$100
 _PtrToHand ;copy it over

 ~DisposeHandle MYDPHANDLE

 RTS

:ERR SYSERR 'TCP/IP - _NewHandle error on DP save $'

*-------------------------------------------------
* Handle P8 switching
*-------------------------------------------------

NOTIFYPARMS DA 1
 ADRL NOTIFYPROC

NOTIFYPROC ADRL 0
 DA 0
 DA $A55A
 ADRL %010_0110 ;Switches between GS/OS and P8, and Shutdown
:EVENTCODE ADRL 0

:PROC PHK
 PLB
 LDA :EVENTCODE
 CMP #%000_0010 ;Switch to P8
 BEQ :TOP8
 CMP #%010_0000 ;Shutdown
 BEQ :SHUTDOWN
 CMP #%000_0100 ;Switch to GS/OS
 BNE :OUT
:FROMP8 JSR TURNON
 RTL
:SHUTDOWN LDA >LINKFLAG
 BEQ :DOSHUT
 ~AlertMessage #:MSGTBL;#1;#0
 PLS
:DOSHUT JSR TURNOFF ;Turn me off and copy DP to main memory
 RTL
:TOP8 LDA >LINKFLAG
 BEQ :DOP8
 ~AlertMessage #:MSGTBL;#0;#0
 PLS
:DOP8 JSR TURNOFF ;Turn me off and copy DP to main memory
:OUT RTL

:MSGTBL DA :TO8MSG-*,:TO8MSG-*
 DA :SHUTMSG-*,:SHUTMSG-*

:TO8MSG ASC '64~You are about to switch to ProDOS 8,'
 HEX 0D
 ASC 'which does not support TCP/IP. When'
 HEX 0D
 ASC 'you switch back to GS/OS, you may have'
 HEX 0D
 ASC 'lost your network connection. ~^Continue'
 DFB 0

:SHUTMSG ASC '64~You are about to shutdown GS/OS while'
 HEX 0D
 ASC 'still connected to the network. Please'
 HEX 0D
 ASC 'turn off or reset your network'
 HEX 0D
 ASC 'hardware before continuing. ~^Continue'
 DFB 0

*-------------------------------------------------
* VARIABLES
*-------------------------------------------------

AMIACTIVE ENT
 DA 0

MYID ENT
 DA 0

MYDP ENT
 DA 0

MYDPHANDLE ADRL 0 ;Only one of these can be valid at any one time
SAVEDPHANDLE ADRL 0

MYTOOLSETNUMBER ENT
 DA 0 ;#$nn00

 DUM 1 ;Tool call stack on entry
RTLROM ADR 0
RTLCALLER ADR 0
RAWSTACKEDPARMS
 DEND

LOGTABLE DS LOGMAX*4,0 ;List of handles by socket to user work area

LOGPORTS DS LOGMAX*2,0 ;List of ports by socket

LOGCOUNT DA 0

IPID ENT
 DA 0 ;Current work socket

*-------------------------------------------------
* Tool dispatch table
*-------------------------------------------------

FPTCOUNT ADRL FPTEND-FPTCOUNT/4

FPTSTART ADRL TCPIPBootInit-1 ;$0136
 ADRL TCPIPStartUp-1 ;$0236
 ADRL TCPIPShutDown-1 ;$0336
 ADRL TCPIPVersion-1 ;$0436
 ADRL TCPIPReset-1 ;$0536
 ADRL TCPIPStatus-1 ;$0636
 ADRL reserved-1 ;$0736
 ADRL TCPIPLongVersion-1 ;$0836
 ADRL TCPIPGetConnectStatus-1 ;$0936 - in CALLS
 ADRL TCPIPGetErrorTable-1 ;$0A36 - in CALLS
 ADRL TCPIPGetReconnectStatus-1 ;$0B36
 ADRL TCPIPReconnect-1 ;$0C36
 ADRL TCPIPConvertIPToHex-1 ;$0D36 - in CALLS
 ADRL TCPIPConvertIPToASCII-1 ;$0E36 - in CALLS
 ADRL TCPIPGetMyIPAddress-1 ;$0F36 - in CALLS
 ADRL TCPIPGetConnectMethod-1 ;$1036 - in CALLS
 ADRL TCPIPSetConnectMethod-1 ;$1136 - in CALLS
 ADRL TCPIPConnect-1 ;$1236
 ADRL TCPIPDisconnect-1 ;$1336
 ADRL TCPIPGetMTU-1 ;$1436 - in CALLS
 ADRL TCPIPValidateIPCString-1 ;$1536
 ADRL TCPIPGetConnectData-1 ;$1636
 ADRL TCPIPSetConnectData-1 ;$1736
 ADRL TCPIPGetDisconnectData-1 ;$1836
 ADRL TCPIPSetDisconnectData-1 ;$1936
 ADRL TCPIPLoadPreferences-1 ;$1A36
 ADRL TCPIPSavePreferences-1 ;$1B36
 ADRL TCPIPGetDNS-1 ;$1C36 - in CALLS
 ADRL TCPIPSetDNS-1 ;$1D36 - in CALLS
 ADRL TCPIPGetTuningTable-1 ;$1E36 - in CALLS
 ADRL TCPIPSetTuningTable-1 ;$1F36 - in CALLS
 ADRL TCPIPCancelDNR-1 ;$2036
 ADRL TCPIPDNRNameToIP-1 ;$2136
 ADRL TCPIPPoll-1 ;$2236
 ADRL TCPIPLogin-1 ;$2336
 ADRL TCPIPLogout-1 ;$2436
 ADRL TCPIPSendICMP-1 ;$2536
 ADRL TCPIPSendUDP-1 ;$2636
 ADRL TCPIPGetDatagramCount-1 ;$2736
 ADRL TCPIPGetnextDatagram-1 ;$2836
 ADRL TCPIPGetLoginCount-1 ;$2936
 ADRL TCPIPSendICMPEcho-1 ;$2A36
 ADRL TCPIPReceiveICMPEcho-1 ;$2B36
 ADRL TCPIPOpenTCP-1 ;$2C36
 ADRL TCPIPWriteTCP-1 ;$2D36
 ADRL TCPIPReadTCP-1 ;$2E36
 ADRL TCPIPCloseTCP-1 ;$2F36
 ADRL TCPIPAbortTCP-1 ;$3036
 ADRL TCPIPStatusTCP-1 ;$3136
 ADRL TCPIPGetSourcePort-1 ;$3236
 ADRL TCPIPGetTOS-1 ;$3336
 ADRL TCPIPSetTOS-1 ;$3436
 ADRL TCPIPGetTTL-1 ;$3536
 ADRL TCPIPSetTTL-1 ;$3636
 ADRL TCPIPSetSourcePort-1 ;$3736
 ADRL TCPIPSetMyIPAddress-1 ;$3836 RESTRICTED - in CALLS
 ADRL TCPIPGetDP-1 ;$3936 RESTRICTED - in CALLS
 ADRL TCPIPGetDebugHex-1 ;$3A36 RESTRICTED - in CALLS
 ADRL TCPIPSetDebugHex-1 ;$3B36 RESTRICTED - in CALLS
 ADRL TCPIPGetDebugTCP-1 ;$3C36 RESTRICTED - in CALLS
 ADRL TCPIPSetDebugTCP-1 ;$3D36 RESTRICTED - in CALLS
 ADRL TCPIPGetUserRecord-1 ;$3E36 RESTRICTED
 ADRL TCPIPConvertIPCToHex-1 ;$3F36 RESTRICTED
 ADRL TCPIPSendIPDatagram-1 ;$4036 - in CALLS
 ADRL TCPIPConvertIPToClass-1 ;$4136 - in CALLS
 ADRL TCPIPGetConnectMsgFlag-1 ;$4236 - in CALLS
 ADRL TCPIPSetConnectMsgFlag-1 ;$4336 - in CALLS
 ADRL TCPIPGetUsername-1 ;$4436 - in CALLS
 ADRL TCPIPSetUsername-1 ;$4536 - in CALLS
 ADRL TCPIPGetPassword-1 ;$4636 - in CALLS
 ADRL TCPIPSetPassword-1 ;$4736 - in CALLS
 ADRL TCPIPValidateIPString-1 ;$4836 - in CALLS
 ADRL TCPIPGetUserStatistic-1 ;$4936
 ADRL TCPIPGetLinkVariables-1 ;$4A36 - in CALLS
 ADRL TCPIPEditLinkConfig-1 ;$4B36 - in CALLS
 ADRL TCPIPGetModuleNames-1 ;$4C36 - in CALLS
 ADRL TCPIPRebuildModuleList-1 ;$4D36 RESTRICTED - in CALLS
 ADRL TCPIPListenTCP-1 ;$4E36
 ADRL TCPIPAcceptTCP-1 ;$4F36
 ADRL TCPIPSetNewDestination-1 ;$5036
 ADRL TCPIPGetHostName-1 ;$5136
 ADRL TCPIPSetHostName-1 ;$5236
 ADRL TCPIPStatusUDP-1 ;$5336
 ADRL TCPIPGetLinkLayer-1 ;$5436
 ADRL TCPIPPtrToPtr-1 ;$5536
 ADRL TCPIPPtrToPtrNeg-1 ;$5636
 ADRL TCPIPGetAuthMessage-1 ;$5736
 ADRL TCPIPConvertIPToCASCII-1 ;$5836
 ADRL TCPIPMangleDomainName-1 ;$5936
 ADRL TCPIPGetAliveFlag-1 ;$5A36
 ADRL TCPIPSetAliveFlag-1 ;$5B36
 ADRL TCPIPGetAliveMinutes-1 ;$5C36
 ADRL TCPIPSetAliveMinutes-1 ;$5D36
 ADRL TCPIPReadLineTCP-1 ;$5E36
 ADRL TCPIPGetBootConnectFlag-1 ;$5F36
 ADRL TCPIPSetBootConnectFlag-1 ;$6036
 ADRL TCPIPSetUDPDispatch-1 ;$6136
 ADRL TCPIPGetDestination-1 ;$6236
 ADRL TCPIPGetUserEventTrigger-1 ;$6336 v3.0
 ADRL TCPIPSetUserEventTrigger-1 ;$6436 v3.0
 ADRL TCPIPGetSysEventTrigger-1 ;$6536 v3.0
 ADRL TCPIPSetSysEventTrigger-1 ;$6636 v3.0
 ADRL TCPIPGetDNRTimeouts-1 ;$6736 v3.0
 ADRL TCPIPSetDNRTimeouts-1 ;$6836 v3.0
FPTEND

*-------------------------------------------------
* Individual tool calls
*-------------------------------------------------

*-------------------------------------------------
* _TCPIPBootInit()  $0136
* _TCPIPStartUp()  $0236
* _TCPIPShutDown()  $0336
* _TCPIPReset()  $0536
* reserved $0736
* reserved $0836
*-------------------------------------------------

TCPIPBootInit DBGMSG TCPIPBootInit
TCPIPStartUp DBGMSG TCPIPStartUp
TCPIPShutDown DBGMSG TCPIPShutDown
TCPIPReset DBGMSG TCPIPReset
reserved
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPVersion():vers  $0436
*-------------------------------------------------

TCPIPVersion DBGMSG TCPIPVersion
 TXA ;This is ALWAYS first call from stub!
 XBA
 AND #$FF00
 STA >MYTOOLSETNUMBER
 LDA #VERSION
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPStatus():flag  $0636
*-------------------------------------------------

TCPIPStatus DBGMSG TCPIPStatus
 LDA #-1
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPLongVersion():vers  $0836 -- taken from resource fork
*-------------------------------------------------

TCPIPLongVersion DBGMSG TCPIPLongVersion
 LDA >LONGVERSION
 STA RAWSTACKEDPARMS,S
 LDA >LONGVERSION+2
 STA RAWSTACKEDPARMS+2,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPGetReconnectStatus:flag  $0B36
*-------------------------------------------------

TCPIPGetReconnectStatus DBGMSG TCPIPGetReconnectStatus
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHD
 LDA >MYDP
 TCD
 LDA >CONNECTMETHOD
 JSL LOADLINKLAYER
 BCS :NO ;A = error
 PHS
 JSL LINKRECONSTATUS
 PLA
 BEQ :NO
 LDA >RECONVALID
 BEQ :NO
 LDA #true
 BRA :OUT
:NO LDA #false
:OUT STA 2+RAWSTACKEDPARMS,S
 PLD
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPReconnect(displayptr)  $0C36
*-------------------------------------------------

TCPIPReconnect DBGMSG TCPIPReconnect
 LDA >AMIACTIVE
 BEQL NOTACTIVE4

 PHB
 PHK
 PLB

 PHD
 LDA MYDP
 TCD

 LDA LINKFLAG
 BNE :ALREADYUP

 LDA >RECONVALID
 BEQ :NOSAVED

 LDA >CONNECTMETHOD
 JSL LOADLINKLAYER
 BCS :ERRB ;A = error

 PHS
 JSL LINKRECONSTATUS
 PLA
 BEQ :NOSAVED ;really unable

 LDA >RECONIPADDRESS
 STA MYIPADDRESS
 LDY #lvIPaddress
 STA [LINKVARIABLESPTR],Y
 LDA >RECONIPADDRESS+2
 STA MYIPADDRESS+2
 LDY #lvIPaddress+2
 STA [LINKVARIABLESPTR],Y

 LDA 2+1+RAWSTACKEDPARMS+2,S
 PHA
 LDA 2+2+1+RAWSTACKEDPARMS,S
 PHA
 JSL LINKRECONNECT
 BCS :ERRB

 LDA #true
 STA LINKFLAG

 JSL StartIPOut

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERRB PLD
 PLB

 LDY #4 ;bytes to strip
 JMP STRIPTOOLEXIT

:ALREADYUP LDA #terrCONNECTED&terrmask
 BRA :ERRB

:NOSAVED LDA #terrNORECONDATA&terrmask
 BRA :ERRB

*-------------------------------------------------
* _TCPIPConnect(displayptr)  $1236
*-------------------------------------------------

TCPIPConnect DBGMSG TCPIPConnect
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB

 PHD
 LDA MYDP
 TCD

 LDA LINKFLAG
 BNEL :ALREADYUP

 STZ MYIPADDRESS ;Point of no return
 STZ MYIPADDRESS+2

 PHL #0
 PZL AUTHMSGHANDLE
 _SetHandleSize

 LDA #false ;Trash reconnect data
 STA >RECONVALID
 JSL TCPIPSavePreferences

 LDA >CONNECTMETHOD
 STA :IPCPARMS+inwMethod
 JSL LOADLINKLAYER
 BCSL :ERR ;A = error

 PHS
 PHS 2 ;space for disposehandle

 PZL AUTHMSGHANDLE
 PHW >CONNECTMSGFLAG
 PxL #USERNAME;#PASSWORD
 PHW 8+2+4+4+2+2+1+RAWSTACKEDPARMS+2,S ;displayptr
 PHW 8+2+2+4+4+2+2+1+RAWSTACKEDPARMS,S

 ~TCPIPGetConnectData MYID;>CONNECTMETHOD

 LDA 1,S ;copy it up stack for disposehandle
 STA 23,S
 LDA 1+2,S
 STA 23+2,S

 JSL LINKCONNECT

 STA 5,S ;move it up stack

 _DisposeHandle ;get rid of the data

 PLA ;result
 BEQ :OK

 PHA
 JSL DUMPLINKLAYER
 PLA
 BRA :ERR

:OK LDA #true ;Connected!
 STA LINKFLAG

 LXA LINKVARIABLESPTR
 STXA :IPCPARMS+inwLVPtr

 LDY #lvMTU
 LDA [LINKVARIABLESPTR],Y
 STA MTU
 STA :IPCPARMS+inwMTU

 LDY #lvIPaddress
 LDA [LINKVARIABLESPTR],Y
 STA MYIPADDRESS
 STA >RECONIPADDRESS
 STA :IPCPARMS+inwIP
 INY
 INY
 LDA [LINKVARIABLESPTR],Y
 STA MYIPADDRESS+2
 STA >RECONIPADDRESS+2
 STA :IPCPARMS+inwIP+2
 LDA #true
 STA >RECONVALID
 JSL TCPIPSavePreferences ;Save reconnect data

 JSR SetAliveTimer

 JSL StartIPOut

 ~SysBeep2 #$8000+$1000 ;Connected to service

 LDA #inwlen
 STA :IPCPARMS+inwLength

 LDA #^:IPCPARMS
 LDX #:IPCPARMS
 LDY #TCPIPSaysNetworkUp
 JSL SENDIPC

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

:ALREADYUP LDA #terrCONNECTED&terrmask
 BRA :ERR

:IPCPARMS DS inwlen

*-------------------------------------------------
* _TCPIPDisconnect(forceflag,displayptr)  $1336
*-------------------------------------------------

TCPIPDisconnect DBGMSG TCPIPDisconnect
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD

 LDA LINKFLAG
 BEQL :NOTCONNECTED

 LDA LOGCOUNT ;And pending logins?
 BEQ :LOGINSOK ;...none, disconnect.

 LDA 2+1+RAWSTACKEDPARMS+4,S ;Shall I force them out?
 BNE :LOGINSOK ;...yep, disconnect.

 LDA #terrLOGINSPENDING
 BRL :ERR

:LOGINSOK JSR FORCECLEANUP ;Kills everything

 PHS ;space for shifted result
 PHS 2 ;space for disposehandle

 LDA >CONNECTMSGFLAG
 STA :IPCPARMS+inwMethod
 PHA

 PxL #USERNAME;#PASSWORD

 LDA 8+2+4+2+2+1+RAWSTACKEDPARMS+2,S ;displayptr
 PHA
 LDA 8+2+2+4+2+2+1+RAWSTACKEDPARMS,S
 PHA

 ~TCPIPGetDisconnectData MYID;>CONNECTMETHOD

 LDA 1,S ;copy it up stack for disposehandle
 STA 19,S
 LDA 1+2,S
 STA 19+2,S

 JSL LINKDISCONNECT ;0=OK, 1=port error, 2=script error

 STA 5,S ;move it up stack

 _DisposeHandle ;get rid of the data

 PLA ;result

 BNE :ERR

 LXA LINKVARIABLESPTR
 STXA :IPCPARMS+inwLVPtr

 LDA MTU
 STA :IPCPARMS+inwMTU
 LDA MYIPADDRESS
 STA :IPCPARMS+inwIP
 LDA MYIPADDRESS+2
 STA :IPCPARMS+inwIP+2
 LDA #inwlen
 STA :IPCPARMS+inwLength

 ~SysBeep2 #$8000+$1001 ;Disconnected from service

 LDA #^:IPCPARMS
 LDX #:IPCPARMS
 LDY #TCPIPSaysNetworkDown
 JSL SENDIPC

 JSR POSTLINKCLEANUP

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
 LDY #6
 JMP STRIPTOOLEXIT

:NOTCONNECTED LDA #terrNOCONNECTION&terrmask
 BRA :ERR

:IPCPARMS DS inwlen

*-------------------------------------------------
* _TCPIPGetConnectData(userid,method)  $1636
* _TCPIPGetDisconnectData(userid,method)  $1836
*-------------------------------------------------

TCPIPGetConnectData DBGMSG TCPIPGetConnectData
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 LDA #'CD'
 BRA JoinGetData
TCPIPGetDisconnectData DBGMSG TCPIPGetDisonnectData
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 LDA #'DD'
JoinGetData PHB
 PHK
 PLB
 STA :RESTYPE
 LDA 1+RAWSTACKEDPARMS,S
 STA :METHOD
 LDA 1+RAWSTACKEDPARMS+2,S
 STA :USERID
 JSR STARTRESOURCES
 PHS
 PEA %1111_1111_1111_1111
 ~DoSysPrefs #%0010_0000_0000_0000;#%1100_0000_0000_0000
 ~OpenResourceFile #%11;#0;#DATAPATH
 BCSL :BADOPEN
 PHS
 ~SetResourceFileDepth #1
 PHS 2
 PHW :RESTYPE
 PEA 0
 PHW :METHOD
 _LoadResource
 BCS :BADLOAD
 PHW :RESTYPE
 PEA 0
 PHW :METHOD
 _DetachResource
 PHS
 PHW :USERID
 PHW 7,S
 PHW 7,S
 _SetHandleID
 PLS
 PLL :HANDLE
 _SetResourceFileDepth
 PLS
 _CloseResourceFile
 _DoSysPrefs
 PLS
 JSR KILLRESOURCES
 BRA :OUT

:BADLOAD PLS 2
 _SetResourceFileDepth
 PLS
 _CloseResourceFile
 BRA :BAD

:BADOPEN PLS
:BAD _DoSysPrefs
 PHS
 PHL #0 ;Empty handle
 PHW :USERID
 PEA 0
 PEA 0
 PEA 0
 _NewHandle
 PLL :HANDLE
 JSR KILLRESOURCES

:OUT LDA :HANDLE
 STA 1+RAWSTACKEDPARMS+4,S
 LDA :HANDLE+2
 STA 1+RAWSTACKEDPARMS+4+2,S

 PLB

 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #4
 JML ToStrip

:RESTYPE DA 0

:METHOD DA 0
:USERID DA 0
:HANDLE ADRL 0

*-------------------------------------------------
* _TCPIPSetConnectData(method,conhandle)  $1736
* _TCPIPSetDisconnectData(method,disconhandle)  $1936
*-------------------------------------------------

TCPIPSetConnectData DBGMSG TCPIPSetConnectData
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 LDA #'CD'
 BRA JoinSetData
TCPIPSetDisconnectData DBGMSG TCPIPSetDisconnectData
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 LDA #'DD'
JoinSetData PHB
 PHK
 PLB
 STA :RESTYPE
 LDA 1+RAWSTACKEDPARMS,S
 STA :HANDLE
 LDA 1+RAWSTACKEDPARMS+2,S
 STA :HANDLE+2
 LDA 1+RAWSTACKEDPARMS+4,S
 STA :METHOD
 PHS
 PEA %1111_1111_1111_1111
 ~DoSysPrefs #%0010_0000_0000_0000;#%1100_0000_0000_0000
 ~CreateResourceFile #0;#$5E;#$C3;#DATAPATH
 ~OpenResourceFile #%11;#0;#DATAPATH
 BCS :BADOPEN
 PHS
 ~SetResourceFileDepth #1
 PHW :RESTYPE
 PEA 0
 PHW :METHOD
 _RemoveResource

 ~GetHandleSize :HANDLE
 PLA
 PLX
 BNE :ADDIT
 EOR #0
 BEQ :EMPTYHANDLE

:ADDIT PHL :HANDLE
 PEA 0
 PHW :RESTYPE
 PEA 0
 PHW :METHOD
 _AddResource
 BCC :OK

:EMPTYHANDLE PHL :HANDLE ;Caller doesn't want, RM doesn't want it...
 _DisposeHandle ;So dump it...

:OK _SetResourceFileDepth
 PLS
 _CloseResourceFile
 BRA :OUT
:BADOPEN PLS
:OUT _DoSysPrefs
 PLS

 PLB

 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #6
 JML ToStrip

:CREATE DA 5
 ADRL DATAPATH
 DA $C3,$F
 ADRL 0
 DA $D

:RESTYPE DA 0
:METHOD DA 0
:HANDLE ADRL 0

*-------------------------------------------------
* _TCPIPLoadPreferences()  $1A36
*
* NOTE: Doesn't return errors.
*-------------------------------------------------

TCPIPLoadPreferences DBGMSG TCPIPLoadPreferences
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 PHB
 PHK
 PLB
 JSL $E100A8
 DA $2010
 ADRL :OPEN
 BCS :DONE
 LDA :OPEN+2
 STA :SETMARK+2
 STA :READVERSION+2
 STA :READ+2
 STA CLOSE+2
 JSL $E100A8
 DA $2012
 ADRL :READVERSION
 BCS :CLOSE
 LDA :VERSION
 CMP #PREFSVERSION
 BNE :CLOSE
 JSL $E100A8
 DA $2016
 ADRL :SETMARK
 LDA >PREFSLENGTH
 STA :READLEN
 JSL $E100A8
 DA $2012
 ADRL :READ
 BCS :SKIPDEC
 JSR DECRYPTPREFS
:SKIPDEC
:CLOSE JSL $E100A8
 DA $2014
 ADRL CLOSE
:DONE PLB
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

:OPEN DA 2,%1
 ADRL PREFSPATHNAME

:READVERSION DA 4,0
 ADRL :VERSION
 ADRL 2,0

:VERSION DA 0

:SETMARK DA 3,0,0
 ADRL 0

:READ DA 4,0
 ADRL PREFERENCES
:READLEN ADRL 0,0

*-------------------------------------------------
* _TCPIPSavePreferences()  $1B36
*
* NOTE: Doesn't return errors.
*-------------------------------------------------

TCPIPSavePreferences DBGMSG TCPIPSavePreferences
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 PHB
 PHK
 PLB
 JSL $E100A8
 DA $2001
 ADRL :CREATE
 JSL $E100A8
 DA $2010
 ADRL :OPEN
 BCS :DONE
 LDA :OPEN+2
 STA :WRITE+2
 STA CLOSE+2
 LDA >PREFSLENGTH
 STA :WRITELEN
 JSR ENCRYPTPREFS
 JSL $E100A8
 DA $2013
 ADRL :WRITE
 JSR DECRYPTPREFS
 JSL $E100A8
 DA $2014
 ADRL CLOSE
:DONE PLB
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

:OPEN DA 2,%11
 ADRL PREFSPATHNAME

:WRITE DA 4,0
 ADRL PREFERENCES
:WRITELEN ADRL 0,0

:CREATE DA 4
 ADRL PREFSPATHNAME
 DA $C3,$5A
 ADRL $0000

CLOSE DA 1,0

*-------------------------------------------------
* _TCPIPPoll()  $2236
*-------------------------------------------------

TCPIPPoll DBGMSG TCPIPPoll
 LDA >AMIACTIVE
 BEQL NOTACTIVE0
 LDA >LINKFLAG ;Is there an actual connection?
 BEQL NOTACTIVE0
 JSR POLLIP
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPLogin(userid,destip,destport,defaultTOS,defaultTTL):ipid  $2336
*-------------------------------------------------

TCPIPLogin DBGMSG TCPIPLogin

 LDA >AMIACTIVE
 BEQL NOTACTIVE12

 LDA >LINKFLAG
 BEQ :ERROR

 LDA RAWSTACKEDPARMS+10,S ;UserID?
 BEQ :ERROR ;Must be valid.

 LDX #LOGMAX*2-2 ;Find free table entry
]L1 LDA >LOGPORTS,X
 BEQ :GOTONE
 DEX
 DEX
 BPL ]L1

:ERROR LDA #terrIPIDTABLEFULL&terrmask
 LDY #12
 JMP STRIPTOOLEXIT

:GOTONE TXA
 STA >IPID ;Got it

 PHD
 LDA >MYDP
 TCD

 ~NewHandle #uwLength;>MYID;#%0000_0000_0001_1000;#0
 PLXA USERHANDLE

 LOCK USERHANDLE

 DEREF USERHANDLE;USERPTR

 SEP $20
 LDY #uwLength-1
 LDA #0
]L1 STA [USERPTR],Y
 DEY
 BPL ]L1
 REP $20

* Initialise everything in it

 LDY #uwUserID
 LDA 2+RAWSTACKEDPARMS+10,S
 STA [USERPTR],Y

 LDY #uwDestIP+2
 LDA 2+RAWSTACKEDPARMS+6+2,S
 STA [USERPTR],Y
 DEY
 DEY
 LDA 2+RAWSTACKEDPARMS+6,S
 STA [USERPTR],Y

 LDY #uwDestPort
 LDA 2+RAWSTACKEDPARMS+4,S
 STA [USERPTR],Y

 LDY #uwIP_TOS
 LDA 2+RAWSTACKEDPARMS+2,S
 STA [USERPTR],Y

 LDY #uwIP_TTL
 LDA 2+RAWSTACKEDPARMS,S
 STA [USERPTR],Y

 LDY #uwTCP_State
 LDA #tcpsCLOSED
 STA [USERPTR],Y ;Not using TCP yet

 LDY #uwLogoutPending
 LDA #0
 STA [USERPTR],Y

* Find a free port

:NEXTNEWPORT LDA >:LASTPORT
 INC
 CMP #5000
 BCC :PORTINCOK
 LDA #1024
:PORTINCOK STA >:LASTPORT
 LDX #LOGMAX*2-2
]L1 LDA >LOGPORTS,X
 BEQ :SKIPNP
 CMP >:LASTPORT
 BEQ :NEXTNEWPORT
:SKIPNP DEX
 DEX
 BPL ]L1
 LDA >IPID
 TAX
 LDA >:LASTPORT ;Found one
 STA >LOGPORTS,X
 LDY #uwSourcePort
 STA [USERPTR],Y

 PHS 2
 JSL NEWQUEUE
 LDY #uwICMPQueue
 PLW [USERPTR],Y
 INY
 INY
 PLW [USERPTR],Y

 PHS 2
 JSL NEWQUEUE
 LDY #uwTCPQueue
 PLW [USERPTR],Y
 INY
 INY
 PLW [USERPTR],Y

;TCP stuff is initialise at TCPIPOpenTCP time
 PHS 2
 JSL NEWQUEUE
 LDY #uwUDPQueue
 PLW [USERPTR],Y
 INY
 INY
 PLW [USERPTR],Y

 LDA #0
 LDY #uwUDPError
 STA [USERPTR],Y
 LDY #uwUDPErrorTick
 STA [USERPTR],Y
 INY
 INY
 STA [USERPTR],Y
 LDY #uwUDPCount
 STA [USERPTR],Y

*

 UNLOCK USERHANDLE

 LDA >IPID ;Copy handle to table
 ASL
 TAX
 LDA USERHANDLE
 STA >LOGTABLE,X
 LDA USERHANDLE+2
 STA >LOGTABLE+2,X

 LDA >LOGCOUNT
 INC ;Increment number of log ins
 STA >LOGCOUNT

 PLD

 LDA >IPID ;And return the ID
 STA RAWSTACKEDPARMS+12,S

 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #12
 JML ToStrip

:LASTPORT DA 1024

*-------------------------------------------------
* _TCPIPLogout(ipid)  $2436
*-------------------------------------------------

TCPIPLogout DBGMSG TCPIPLogout

 LDA >AMIACTIVE
 BEQL NOTACTIVE2

 PHB
 PHK
 PLB

 PHD
 LDA MYDP
 TCD

 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 BEQ :CLOSEME

 CMP #tcpsTIMEWAIT
 BEQ :TIMEWAIT

 JSR CLOSEUSER ;Connection pending...

 LDA #terrSOCKETOPEN&terrmask
 BRA :ERR

:TIMEWAIT LDY #uwLogoutPending ;It's still closing, but we can logout
 LDA #-1 ;the ipid anyway, and we'll take care if it
 STA [USERPTR],Y ;for the user

 JSR CLOSEUSER

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 BRA :ERR

:CLOSEME JSR FORCELOGOUT

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
:ERR1 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSendICMP(ipid,messageptr,messagelen)  $2536
*-------------------------------------------------

TCPIPSendICMP DBGMSG TCPIPSendICMP
 LDA >AMIACTIVE
 BEQL NOTACTIVE8
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+6,S
 JSR OPENUSER
 BCS :ERR
 PZL USERPTR ;keyblock
 LDA 4+2+1+RAWSTACKEDPARMS,S
 PHA
 LDA 4+2+2+1+RAWSTACKEDPARMS+4,S
 PHA
 LDA 4+2+2+2+1+RAWSTACKEDPARMS+2,S
 PHA
 JSL ICMPSEND ;(keyblock:longw,len:integer,msgptr:longw);
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #8
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSendUDP(ipid,udpptr,udplen)  $2636
*-------------------------------------------------

TCPIPSendUDP DBGMSG TCPIPSendUDP
 LDA >AMIACTIVE
 BEQL NOTACTIVE8
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+6,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 PHA
 LDA 2+2+1+RAWSTACKEDPARMS+4,S
 PHA
 LDA 2+2+2+1+RAWSTACKEDPARMS+2,S
 PHA
 JSL UDPSEND ;(len,ptr)
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #8
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetDatagramCount(ipid,protocol):dgmcount  $2736
*-------------------------------------------------

TCPIPGetDatagramCount DBGMSG TCPIPGetDatagramCount
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 JSL PROTOCOLTOQUEUE
 BCS :ANY
 PHS
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL QUEUESIZE
 BRA :JOIN

:ANY PHS
 JSL IPPKTCOUNT

:JOIN PLA
 STA 2+1+RAWSTACKEDPARMS+4,S

 JSR CLOSEUSER

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetNextDatagram(ipid,protocol,flags):dgmhandle  $2836
*-------------------------------------------------

TCPIPGetNextDatagram DBGMSG TCPIPGetNextDatagram
 LDA >AMIACTIVE
 BEQL NOTACTIVE6

 PHB
 PHK
 PLB

 PHD
 LDA MYDP
 TCD

 LDA 2+1+RAWSTACKEDPARMS+4,S
 JSR OPENUSER
 BCSL :ERR

 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSL PROTOCOLTOQUEUE
 BCS :ANY

 PHS 2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
:DOQUEUE JSL GETNEXTINQUEUE
 BRA :JOIN

:ANY PHS 2
 JSL IPNEXTPACKET

:JOIN PLA
 STA TMPHANDLE
 PLA
 STA TMPHANDLE+2
 ORA TMPHANDLE
 BEQL :NOPACKET

 LDA 2+1+RAWSTACKEDPARMS,S ;strip flags
 AND #%1100_0000_0000_0000
 BEQL :NOSTRIP

* OK strip IP header

 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2

 LDY #ip_proto
 LDA [TMPTR],Y
 AND #$FF
 STA :PROTOCOL

 PEA 0 ;for _SetHandleSize
 PHS ;for _SetHandleSize

 LDA [TMPTR]
 AND #$F ;get number of 32 bit words
 ASL ;calculate number of 16 bit words
 ASL ;calculate number of bytes
 TAY
 CLC
 ADC TMPTR
 TAX
 LDA TMPTR+2
 ADC #0
 PHXA
 PZL TMPTR
 PEA 0
 PHY ;header length
 LDY #ip_len
 LDA [TMPTR],Y
 XBA
 SEC
 SBC 1,S
 STA 1,S
 STA 13,S
 JSL PtrToPtr
 PZL TMPHANDLE
 _SetHandleSize

* Try for UDP header

 LDA 2+1+RAWSTACKEDPARMS,S ;strip flags
 AND #%0100_0000_0000_0000
 BEQ :NOSTRIP

 DEREF TMPHANDLE;TMPTR

 LDA :PROTOCOL
 CMP #protocolUDP
 BNE :NOUDP

 PHS 2 ;space for sethandlesize

 LDA TMPTR
 CLC
 ADC #8
 TAX
 LDA TMPTR+2
 ADC #0
 PHA
 PHX
 PZL TMPTR
 LDY #8
 LDA [TMPHANDLE],Y
 SEC
 SBC #8
 TAX
 INY
 INY
 LDA [TMPHANDLE],Y
 SBC #0
 PHA
 PHX
 STA 13+2,S
 TXA
 STA 13,S
 JSL PtrToPtr
 PZL TMPHANDLE
 _SetHandleSize
:NOUDP

* Done stripping

:NOSTRIP LDA [USERPTR] ;UserID
 LDY #6
 STA [TMPHANDLE],Y ;Make it his, I don't want it...

:NOPACKET

 LDA TMPHANDLE
 STA 2+1+RAWSTACKEDPARMS+6,S
 LDA TMPHANDLE+2
 STA 2+1+RAWSTACKEDPARMS+6+2,S

 JSR CLOSEUSER

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
 LDY #6
 JMP STRIPTOOLEXIT

:PROTOCOL DA 0

*-------------------------------------------------
* _TCPIPGetLoginCount():logincount  $2936
*-------------------------------------------------

TCPIPGetLoginCount DBGMSG TCPIPGetLoginCount ;$2936
 LDA >LOGCOUNT
 STA RAWSTACKEDPARMS,S
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 CLC
 RTL

*-------------------------------------------------
* _TCPIPSendICMPEcho(ipid,seqnum)  $2A36
*-------------------------------------------------

TCPIPSendICMPEcho DBGMSG TCPIPSendICMPEcho
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 PZL USERPTR ;ipkeyblock
 LDA 4+2+1+RAWSTACKEDPARMS,S
 PHA
 JSL ICMPSENDECHO ;(ipkeyblock:longword,seq:word)
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPReceiveICMPEcho(ipid):seqnum  $2B36
*-------------------------------------------------

TCPIPReceiveICMPEcho DBGMSG TCPIPReceiveICMPEcho
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB

 PHD
 LDA MYDP
 TCD

 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCSL :ERR

 PEA 0
:LOOP PHS 2
 LDA 5,S
 PHA
 LDY #uwICMPQueue+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL FINDINQUEUE
 LDA 1,S
 ORA 1+2,S
 BEQ :NONE
 PLL TMPHANDLE
 LDA [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 STA TMPTR+2
 LDA [TMPTR]
 AND #$F ;get number of 32 bit words
 ASL ;calculate number of 16 bit words
 ASL ;calculate number of bytes
 TAY
 LDA [TMPTR],Y
 CMP #0
 BEQ :GOTIT
 PLA
 INC
 PHA
 BRA :LOOP
:GOTIT INY
 INY
 INY
 INY
 INY
 INY
 PHY
 LOCK TMPHANDLE
 PHS 2
 LDA 7,S
 PHA
 LDY #uwICMPQueue+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL RIPFROMQUEUE
 PLS 2
 UNLOCK TMPHANDLE
 PLA
 CLC
 ADC [TMPHANDLE]
 STA TMPTR
 LDY #2
 LDA [TMPHANDLE],Y
 ADC #0
 STA TMPTR+2
 PLS
 LDA [TMPTR] ;seq
 XBA

 STA 2+1+RAWSTACKEDPARMS+2,S

 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed

:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

:NONE PLS 2+1

 LDA #0
 STA 2+1+RAWSTACKEDPARMS+2,S

 JSR CLOSEUSER

 LDA #terrNOICMPQUEUED&terrmask
 BRA :ERR

*-------------------------------------------------
* _TCPIPOpenTCP(ipid):tcpError  $2C36
*-------------------------------------------------

TCPIPOpenTCP DBGMSG TCPIPOpenTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 STZ tcCONNECTIONTYPE
 JSL TCPOPEN
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPListenTCP(ipid):tcpError  $4E36
*-------------------------------------------------

TCPIPListenTCP DBGMSG TCPIPListenTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 LDA #1
 STA tcCONNECTIONTYPE
 JSL TCPOPEN
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPAcceptTCP(ipid,reserved):newipid  $4F36
*-------------------------------------------------

TCPIPAcceptTCP DBGMSG TCPIPAcceptTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDY #uwTCP_Server
 LDA [USERPTR],Y
 BEQ :NOTSERVER
 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsLISTEN
 BNE :NOTSERVER
 JSL TCPACCEPT
 STA 2+1+RAWSTACKEDPARMS+2+2,S
 JSR CLOSEUSER
 LDA 2+1+RAWSTACKEDPARMS+2+2,S
 BEQ :NOINCOMING
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2+2
 JMP STRIPTOOLEXIT

:NOTSERVER LDA #terrNOTSERVER&terrmask
 BRA :ERR

:NOINCOMING LDA #terrNOINCOMING&terrmask
 BRA :ERR

*-------------------------------------------------
* _TCPIPWriteTCP(ipid,dataPtr,dataLength,pushFlag,urgentFlag):tcpError  $2D36
*-------------------------------------------------

TCPIPWriteTCP DBGMSG TCPIPWriteTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE14
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+12,S
 JSR OPENUSER
 BCS :ERR

 LDA 2+1+RAWSTACKEDPARMS,S
 STA tcURGENTFLAG

 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA tcPUSHFLAG

 LDA 2+1+RAWSTACKEDPARMS+4,S
 STA tcDATALENGTH
 LDA 2+1+RAWSTACKEDPARMS+4+2,S
 STA tcDATALENGTH+2

 LDA 2+1+RAWSTACKEDPARMS+8,S
 STA tcDATABUFFER
 LDA 2+1+RAWSTACKEDPARMS+8+2,S
 STA tcDATABUFFER+2

 JSL TCPWRITE
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+14,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #14
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPReadTCP(ipid,buffType,buffData,buffLen,rrBuffPtr):tcpError  $2E36
*-------------------------------------------------

TCPIPReadTCP DBGMSG TCPIPReadTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE16
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+14,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 STA tcRESPONSEBUFFPTR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA tcRESPONSEBUFFPTR+2
 LDA 2+1+RAWSTACKEDPARMS+4,S
 STA tcDATALENGTH
 LDA 2+1+RAWSTACKEDPARMS+4+2,S
 STA tcDATALENGTH+2
 LDA 2+1+RAWSTACKEDPARMS+8,S
 STA tcDATABUFFER
 LDA 2+1+RAWSTACKEDPARMS+8+2,S
 STA tcDATABUFFER+2
 LDA 2+1+RAWSTACKEDPARMS+12,S
 STA tcBUFFTYPE
 STZ tcDELIMITSTRING ;No delimit string
 STZ tcDELIMITSTRING+2
 JSL TCPREAD
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+16,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #16
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPReadLineTCP(ipid,delimitStrPtr,buffType,buffData,buffLen,rrBuffPtr):tcpError  $2E36
*-------------------------------------------------

TCPIPReadLineTCP DBGMSG TCPIPReadLineTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE20
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+18,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 STA tcRESPONSEBUFFPTR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA tcRESPONSEBUFFPTR+2
 LDA 2+1+RAWSTACKEDPARMS+4,S
 STA tcDATALENGTH
 LDA 2+1+RAWSTACKEDPARMS+4+2,S
 STA tcDATALENGTH+2
 LDA 2+1+RAWSTACKEDPARMS+8,S
 STA tcDATABUFFER
 LDA 2+1+RAWSTACKEDPARMS+8+2,S
 STA tcDATABUFFER+2
 LDA 2+1+RAWSTACKEDPARMS+12,S
 STA tcBUFFTYPE
 LDA 2+1+RAWSTACKEDPARMS+14,S
 STA tcDELIMITSTRING
 LDA 2+1+RAWSTACKEDPARMS+14+2,S
 STA tcDELIMITSTRING+2
 JSL TCPREAD
 PHA ;Save error code
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+16,S
 JSR CLOSEUSER
 PLA ;Restore error code
:ERR PLD
 PLB
 LDY #20
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPCloseTCP(ipid):tcpError  $2F36
*-------------------------------------------------

TCPIPCloseTCP DBGMSG TCPIPCloseTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR

* See if this is a listen port

 LDY #uwTCP_Server
 LDA [USERPTR],Y ;server?
 BEQ :SKIPSERVER

:NEXTCHILD PHS 2
 LDY #uwTCP_ChildList+2
 LDA [USERPTR],Y
 PHA
 DEY
 DEY
 LDA [USERPTR],Y
 PHA
 JSL GETNEXTINQUEUE ;Removes it
 PLS
 PLA ;IPID
 BEQ :DONESERVER
 PZL USERHANDLE
 PZL USERPTR
 JSR OPENUSER ;open it
 JSL TCPABORT ;sends <RST>, then forces closed
 JSR FORCELOGOUT ;dump it
 PLL USERPTR
 PLL USERHANDLE
 BRA :NEXTCHILD

:DONESERVER
:SKIPSERVER

* Normal close

 JSL TCPCLOSE
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPAbortTCP(ipid):tcpError  $3036
*-------------------------------------------------

TCPIPAbortTCP DBGMSG TCPIPAbortTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 JSL TCPABORT
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPStatusTCP(ipid,srBuffPtr):tcpError  $3136
*-------------------------------------------------

TCPIPStatusTCP DBGMSG TCPIPStatusTCP
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+4,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 STA tcRESPONSEBUFFPTR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA tcRESPONSEBUFFPTR+2
 JSL TCPSTATUS
 LDY #uwTCP_ErrCode
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+6,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #6
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPStatusUDP(ipid,udpVarsPtr):tcpError  $5336
*-------------------------------------------------

TCPIPStatusUDP DBGMSG TCPIPStatusUDP
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+4,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 STA tcRESPONSEBUFFPTR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA tcRESPONSEBUFFPTR+2

 PHS
 LDY #uwUDPQueue+2
 PHW [USERPTR],Y
 DEY
 DEY
 PHW [USERPTR],Y
 JSL QUEUESIZE
 LDY #uvQueueSize
 PLW [tcRESPONSEBUFFPTR],Y

 LDY #uwUDPError
 LDA [USERPTR],Y
 LDY #uvError
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwUDPErrorTick
 LDA [USERPTR],Y
 LDY #uvErrorTick
 STA [tcRESPONSEBUFFPTR],Y
 LDY #uwUDPErrorTick+2
 LDA [USERPTR],Y
 LDY #uvErrorTick+2
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwUDPCount
 LDA [USERPTR],Y
 LDY #uvCount
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uvTotalCount
 LDA >ERRORTABLE+tcpDGMSUDP
 STA [tcRESPONSEBUFFPTR],Y
 INY
 INY
 LDA >ERRORTABLE+tcpDGMSUDP+2
 STA [tcRESPONSEBUFFPTR],Y

 LDY #uwUDP_Server
 LDA [USERPTR],Y
 LDY #uvDispatchFlag
 STA [tcRESPONSEBUFFPTR],Y

 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #6
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetSourcePort(ipid):sourceport  $3236
*-------------------------------------------------

TCPIPGetSourcePort DBGMSG TCPIPGetSourcePort
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 LDY #uwSourcePort
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetTOS(ipid):TOS  $3336
*-------------------------------------------------

TCPIPGetTOS DBGMSG TCPIPGetTOS
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 LDY #uwIP_TOS
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSetTOS(ipid,TOS)  $3436
*-------------------------------------------------

TCPIPSetTOS DBGMSG TCPIPSetTOS
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 LDY #uwIP_TOS
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetTTL(ipid):TTL  $3536
*-------------------------------------------------

TCPIPGetTTL DBGMSG TCPIPGetTTL
 LDA >AMIACTIVE
 BEQL NOTACTIVE2
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 JSR OPENUSER
 BCS :ERR
 LDY #uwIP_TTL
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #2
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSetTTL(ipid,TTL)  $3636
*-------------------------------------------------

TCPIPSetTTL DBGMSG TCPIPSetTTL
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 LDY #uwIP_TTL
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSetSourcePort(ipid,TTL)  $3736
*-------------------------------------------------

TCPIPSetSourcePort DBGMSG TCPIPSetSourcePort
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDX IPID
 LDA 2+1+RAWSTACKEDPARMS,S
 STA LOGPORTS,X
 LDY #uwSourcePort
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPSetNewDestination(ipid,destip,destport)  $5036
*-------------------------------------------------

TCPIPSetNewDestination DBGMSG TCPIPSetNewDestination
 LDA >AMIACTIVE
 BEQL NOTACTIVE8
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+6,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 LDY #uwDestPort
 STA [USERPTR],Y
 LDA 2+1+RAWSTACKEDPARMS+2,S
 LDY #uwDestIP
 STA [USERPTR],Y
 LDA 2+1+RAWSTACKEDPARMS+2+2,S
 INY
 INY
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #8
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetDestination(ipid,destRecPtr)  $6236
*-------------------------------------------------

TCPIPGetDestination DBGMSG TCPIPGetDestination
 LDA >AMIACTIVE
 BEQL NOTACTIVE6
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+4,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 STA TMPTR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA TMPTR+2
 LDY #uwUserID
 LDA [USERPTR],Y
 LDY #drUserID
 STA [TMPTR],Y
 LDY #uwDestIP
 LDA [USERPTR],Y
 LDY #drDestIP
 STA [TMPTR],Y
 LDY #uwDestIP+2
 LDA [USERPTR],Y
 LDY #drDestIP+2
 STA [TMPTR],Y
 LDY #uwDestPort
 LDA [USERPTR],Y
 LDY #drDestPort
 STA [TMPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #6
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* _TCPIPGetUserEventTrigger(triggerNumber,ipid):triggerProcPtr  $6336
*-------------------------------------------------

TCPIPGetUserEventTrigger DBGMSG TCPIPGetUserEventTrigger
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS+2,S
 CMP #trgCount+1
 BCS :BADTRIGGER
 DEC
 ASL
 CLC
 ADC #uwTriggers
 TAY
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+4,S
 INY
 INY
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+4+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT
:BADTRIGGER LDA #terrBADTRIGGERNUM&terrmask
 BRA :ERR

*-------------------------------------------------
* _TCPIPSetUserEventTrigger(triggerNumber,ipid,triggerProcPtr)  $6436
*-------------------------------------------------

TCPIPSetUserEventTrigger DBGMSG TCPIPSetUserEventTrigger
 LDA >AMIACTIVE
 BEQL NOTACTIVE8
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+4,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS+6,S
 CMP #trgCount+1
 BCS :BADTRIGGER
 DEC
 ASL
 CLC
 ADC #uwTriggers
 TAY
 LDA 2+1+RAWSTACKEDPARMS,S
 STA [USERPTR],Y
 INY
 INY
 LDA 2+1+RAWSTACKEDPARMS+2,S
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #8
 JMP STRIPTOOLEXIT
:BADTRIGGER LDA #terrBADTRIGGERNUM&terrmask
 BRA :ERR

*-------------------------------------------------
* _TCPIPGetUserRecord(ipid):userrecentry  $3E36
*-------------------------------------------------

TCPIPGetUserRecord DBGMSG TCPIPGetUserRecord
 LDA RAWSTACKEDPARMS,S
 ASL
 TAX
 LDA >LOGTABLE,X
 STA RAWSTACKEDPARMS+2,S
 LDA >LOGTABLE+2,X
 STA RAWSTACKEDPARMS+2+2,S
 LDX #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
 LDY #2
 JML ToStrip

*-------------------------------------------------
* _TCPIPGetUserStatistic(ipid,statisticNum):statistic  $4936
*-------------------------------------------------

TCPIPGetUserStatistic DBGMSG TCPIPGetUserStatistic(ipid,statisticNum):statistic
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 DEC
 CMP #2 ;Only two allowed. 1 through 2, subbed to 0-1
 BCC :BADPARM
 ASL
 TAX
 LDA :STATINDEX,X
 TAY
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+4,S
 INY
 INY
 LDA [USERPTR],Y
 STA 2+1+RAWSTACKEDPARMS+4+2,S
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT
:BADPARM JSR CLOSEUSER
 LDA #0
 STA 2+1+RAWSTACKEDPARMS+4,S
 STA 2+1+RAWSTACKEDPARMS+4+2,S
 LDA #terrBADPARAMETER&terrmask
 BRA :ERR

:STATINDEX DA uwTCP_TotalIN ;statistic #1
 DA uwTCP_TotalOUT ;statistic #2

*-------------------------------------------------
* _TCPIPSetUDPDispatch(ipid,dispatchFlag)  $6136
*-------------------------------------------------

TCPIPSetUDPDispatch DBGMSG TCPIPSetUDPDispatch
 LDA >AMIACTIVE
 BEQL NOTACTIVE4
 PHB
 PHK
 PLB
 PHD
 LDA MYDP
 TCD
 LDA 2+1+RAWSTACKEDPARMS+2,S
 JSR OPENUSER
 BCS :ERR
 LDA 2+1+RAWSTACKEDPARMS,S
 LDY #uwUDP_Server
 STA [USERPTR],Y
 JSR CLOSEUSER
 LDA #terrOK ;is $0000, so no ORA >MYTOOLSETNUMBER needed
:ERR PLD
 PLB
 LDY #4
 JMP STRIPTOOLEXIT

*-------------------------------------------------
* Tool exit procs
*-------------------------------------------------

NOTACTIVE20 LDY #20
 BRA NOACTIVE
NOTACTIVE16 LDY #16
 BRA NOACTIVE
NOTACTIVE14 LDY #14
 BRA NOACTIVE
NOTACTIVE12 LDY #12
 BRA NOACTIVE
NOTACTIVE10 LDY #10
 BRA NOACTIVE
NOTACTIVE8 ENT
 LDY #8
 BRA NOACTIVE
NOTACTIVE6 LDY #6
 BRA NOACTIVE
NOTACTIVE4 ENT
 LDY #4
 BRA NOACTIVE
NOTACTIVE2 LDY #2
NOACTIVE LDA #terrTCPIPNOTACTIVE&terrmask

STRIPTOOLEXIT ENT
 CMP #1 ;A=error (moves to X before ToStrip), Y=bytes
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
* Subroutines for tool calls which assume DBK and DP are set correctly
*-------------------------------------------------

*-------------------------------------------------
* Subroutines for tool calls which set their own DBK and DP
*-------------------------------------------------

STARTRESOURCES PEA 0
 _ResourceStatus
 PLA
 STA >RMSTATUS
 BNE :RTS
 ~LoadOneTool #30;#$0100
 ~MMStartUp
 _ResourceStartUp
:RTS RTS

KILLRESOURCES LDA >RMSTATUS
 BNE :RTS
 _ResourceShutDown
:RTS RTS

RMSTATUS DA 0

ENCRYPTPREFS DBGMSG ENCRYPTPREFS
 SEP $30
 PHB
 PEA ^USERNAME
 PLB

 LDX USERNAME
 BEQ :SKIPUSERNAME
]L1 LDA USERNAME,X
 ROL
 EOR #$42
 STA USERNAME,X
 DEX
 BPL ]L1
:SKIPUSERNAME

 LDX PASSWORD
 BEQ :SKIPPASSWORD
]L1 LDA PASSWORD,X
 ROL
 EOR #$24
 STA PASSWORD,X
 DEX
 BPL ]L1
:SKIPPASSWORD

 PLB
 PLB
 REP $30
 RTS

DECRYPTPREFS DBGMSG DECRYPTPREFS
 SEP $30
 PHB
 PEA ^USERNAME
 PLB

 LDA USERNAME
 BEQ :SKIPUSERNAME
 LDX #-1
 CLC
]L1 INX
 LDA USERNAME,X
 EOR #$42
 ROR
 STA USERNAME,X
 CPX USERNAME
 BCC ]L1
:SKIPUSERNAME

 LDA PASSWORD
 BEQ :SKIPPASSWORD
 LDX #-1
 CLC
]L1 INX
 LDA PASSWORD,X
 EOR #$24
 ROR
 STA PASSWORD,X
 CPX PASSWORD
 BCC ]L1
:SKIPPASSWORD

 PLB
 PLB
 REP $30
 RTS

IPTOCLASS ENT ;IPTOCLASS(ip:longword):class:integer;
 DBGMSG IPTOCLASS
 TSC
 PHD
 TCD
 CLC
 LDX #0
 LDA 3
]L1 ROL
 BCC :GOTIT
 INX
 BRA ]L1
:GOTIT TXA
 STA 8
 PLD
 PHB
 PLX
 PLY
 PLS 2
 PHY
 PHX
 PLB
 RTL

DATAPATH STRL '*:System:TCPIP:Link.layer.data'

PREFSPATHNAME STRL '*:System:TCPIP:Preferences'

 DUM 5 ;Used for xASC2HEXIP and HEX2ASCIP
IPASCPTR ADRL 0
IPHEX ADRL 0
IPPORT DA 0 ;For HEX2ASCIP, this is the FLAGS word
 DEND

CASC2HEXIP ENT ;ASC2HEXIP(cstringptr:longword):ip:long,port:integer
 DBGMSG CASC2HEXIP ;carry set indicates invalid address
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
*
 STZ IPPORT
 STZ IPHEX
 STZ IPHEX+2
 STZ :ERRORFLAG
 SEP $30
 LDX #0
]L2 LDY #0
]L1 LDA [IPASCPTR],Y
 BEQ :GOTDOT
 CMP #'.'
 BEQ :GOTDOT
 CMP #'0'
 BCC :DONEIP?
 CMP #'9'+1
 BCS :DONEIP?
 INY
 BRA ]L1
:DONEIP? CPX #3
 BNE :DONEIP
:GOTDOT PHX
 PHY
 CPY #3+1
 BCSL :ERROR2BYTES
 REP $30
 PHS
 PZL IPASCPTR
 PHY
 PEA 0
 _Dec2Int
 PLA
 CMP #256
 SEP $30
 BCSL :ERROR2BYTES
 PLY
 PLX
 STA IPHEX,X
 CPX #3
 BEQ :DONEIP
 JSR :BUMP
 INX
 BRA ]L2
:DONEIP DEY
 JSR :BUMP
 LDY #-1 ;Look for comma
]L1 INY
 LDA [IPASCPTR],Y
 BEQ :DONE
 CMP #$20
 BEQ ]L1
 CMP #':'
 BEQ :GOTCOMMA
 CMP #';'
 BEQ :GOTCOMMA
 CMP #','
 BNE :DONE
:GOTCOMMA
]L1 INY ;Move to digits...
 LDA [IPASCPTR],Y
 BEQ :DONE
 CMP #$20
 BEQ ]L1
 CMP #'0'
 BCC :DONE
 CMP #'9'+1
 BCS :DONE

 REP $10
 PHY
 SEP $10

 LDX #0
]L1 INY
 INX
 LDA [IPASCPTR],Y
 CMP #'0'
 BCC :CVTPORT
 CMP #'9'+1
 BCC ]L1

:CVTPORT REP $30
 PHS
 LDA IPASCPTR
 CLC
 ADC 1+2,S
 TAY
 LDA IPASCPTR+2
 ADC #0
 PHA
 PHY
 PHX
 PEA 0
 _Dec2Int
 PLA
 STA IPPORT
 PLY
:DONE REP $30
*
:OUT PLD
 PLX
 PLY
 PLS 2
 PHY
 PHX
 ROL :ERRORFLAG
 PLB
 RTL
 mx %11
:ERROR2BYTES PLS 2 ;
 REP $30
 SEC
 ROR :ERRORFLAG
 BRA :OUT
 mx %11
:BUMP TYA
 REP $30
 AND #$FF
 SEC
 ADC IPASCPTR
 STA IPASCPTR
 LDA IPASCPTR+2
 ADC #0
 STA IPASCPTR+2
 SEP $30
 RTS
 mx 0

:ERRORFLAG DA 0

PASC2HEXIP ENT ;ASC2HEXIP(pstringptr:longword):ip:long,port:integer
 DBGMSG PASC2HEXIP ;carry set indicates invalid address
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
*
 STZ IPPORT
 STZ IPHEX
 STZ IPHEX+2
 STZ :ERRORFLAG
 LDA [IPASCPTR]
 AND #$FF
 STA :PSTRLEN
 INCR IPASCPTR
 SEP $30
 LDX #0 ;X = IP octet that is being processed
;A.B.C.D -> when processing A, X=0; B, X=1 etc
]L2 LDY #0
]L1 CPY :PSTRLEN
 BCS :GOTDOT
 LDA [IPASCPTR],Y
 CMP #'.'
 BEQ :GOTDOT
 CMP #'0'
 BCC :DONEIP?
 CMP #'9'+1
 BCS :DONEIP?
 INY
 BRA ]L1
:DONEIP? CPX #3 ;Are we doing the last octet?
 BNE :DONEIP
:GOTDOT PHX
 PHY
 CPY #3+1 ;An IP octet can have a maximum of 3 digits
 BCSL :ERROR2BYTES
 REP $30
 PHS  ;Convert octet from decimal into hex
 PZL IPASCPTR
 PHY
 PEA 0
 _Dec2Int
 PLA
 CMP #256 ;An IP octet can have maximum value of 255
 SEP $30
 BCSL :ERROR2BYTES
 PLY
 PLX
 STA IPHEX,X ;Store the converted value
 CPX #3
 BEQ :DONEIP
 JSR :BUMP ;Move PTR to beginning of next octet & dec length
 BMI :ERROR ;Premature end of string
 INX
 BRA ]L2
:DONEIP DEY  ;Compensate for :BUMP increasing length for the dot
 JSR :BUMP
 BEQ :DONE
 TAX  ;Remaining length of PString
 LDY #-1 ;Look for comma
]L1 INY
 DEX  ;Observe length of PString
 BMI :DONE ;This limits maximum length to 127
 LDA [IPASCPTR],Y
 CMP #$20
 BEQ ]L1
 CMP #':'
 BEQ :GOTCOMMA
 CMP #';'
 BEQ :GOTCOMMA
 CMP #','
 BNE :DONE
:GOTCOMMA
]L1 INY ;Move to digits...
 DEX  ;Observe length of PString
 BMI :DONE ;This limits maximum length to 127
 LDA [IPASCPTR],Y
 CMP #$20
 BEQ ]L1
 CMP #'0'
 BCC :DONE
 CMP #'9'+1
 BCS :DONE

 DEY  ;Compensate for :BUMP increasing length for the dot
 JSR :BUMP
 TAX  ;Remaining length of PString
 LDY #-1

]L1 INY
 DEX  ;Observe length of PString
 BMI :DONE ;This limits maximum length to 127
 LDA [IPASCPTR],Y
 CMP #'0'
 BCC :CVTPORT
 CMP #'9'+1
 BCC ]L1

:CVTPORT REP $30
 PHS
 LDX IPASCPTR
 LDA IPASCPTR+2
 PHA
 PHX
 PHY
 PEA 0
 _Dec2Int
 PLA
 STA IPPORT
:DONE REP $30
*
:OUT PLD
 PLX
 PLY
 PLS 2
 PHY
 PHX
 ROL :ERRORFLAG
 PLB
 RTL
 mx %11
:ERROR2BYTES PLS 2 ;
:ERROR REP $30
 SEC
 ROR :ERRORFLAG
 BRA :OUT
 mx %11
:BUMP TYA
 REP $30
 AND #$FF
 SEC  ;Sneaky way of incrementing ptr for the dot
 ADC IPASCPTR
 STA IPASCPTR
 LDA IPASCPTR+2
 ADC #0
 STA IPASCPTR+2
 SEP $30
 TYA
 EOR #-1 ;Twos complement subtract of the length processed
 CLC  ;Sneaky way of decrementing length for the dot
 ADC :PSTRLEN
 STA :PSTRLEN
 RTS
 mx 0

:ERRORFLAG DA 0
:PSTRLEN DA 0

HEX2CASCIP ENT ;HEX2CASCIP(flags:int,ip:lw,cstringptr:lw):len:integer;
 DBGMSG HEX2ASCIP
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
*
 PZL IPASCPTR

 PEA 0 ;current string length
 LDX #0
:LOOP LDA IPHEX,X
 AND #$FF
 LDY #1
 CMP #10
 BCC :GOTLEN
 INY
 CMP #100
 BCC :GOTLEN
 INY
:GOTLEN PHX ;save X
 PHY ;save Y
 PHA ;value for _Int2Dec
 TYA
 CLC
 ADC 7,S ;add to counter
 STA 7,S
 PZL IPASCPTR
 PHY
 PEA 0
 _Int2Dec
 PLY ;get length
 PLX ;get index
 CPX #3
 BEQ :DONE
 SEP $20
 LDA #'.'
 STA [IPASCPTR],Y
 REP $20
 TYA
 SEC
 ADC IPASCPTR
 STA IPASCPTR
 LDA IPASCPTR+2
 ADC #0
 STA IPASCPTR+2
 INX
 LDA 1,S
 INC
 STA 1,S
 BRA :LOOP

:DONE SEP $20
 LDA #0
 STA [IPASCPTR],Y
 REP $20

 PLX ;get string length

 PLL IPASCPTR
 LDA IPPORT
 BPL :SKIPORA
 SEP $30
 LDY #0
]L1 LDA [IPASCPTR],Y
 BEQ :SKIPORAZ
 ORA #$80
 STA [IPASCPTR],Y
 INY
 BRA ]L1
:SKIPORAZ REP $30
:SKIPORA

*
 PLD
 PLA
 STA 9,S
 PLA
 STA 9,S
 PLS 3
 TXA
 STA 5,S
 PLB
 RTL

HEX2PASCIP ENT ;HEX2PASCIP(flags:int,ip:lw,pstringptr:lw):len:integer;
 DBGMSG HEX2ASCIP
 PHB
 PHK
 PLB
 TSC
 PHD
 TCD
*
 PZL IPASCPTR

 INCR IPASCPTR

 PEA 0 ;current string length
 LDX #0
:LOOP LDA IPHEX,X
 AND #$FF
 LDY #1
 CMP #10
 BCC :GOTLEN
 INY
 CMP #100
 BCC :GOTLEN
 INY
:GOTLEN PHX ;save X
 PHY ;save Y
 PHA ;value for _Int2Dec
 TYA
 CLC
 ADC 7,S ;add to counter
 STA 7,S
 PZL IPASCPTR
 PHY
 PEA 0
 _Int2Dec
 PLY ;get length
 PLX ;get index
 CPX #3
 BEQ :DONE
 SEP $20
 LDA #'.'
 STA [IPASCPTR],Y
 REP $20
 TYA
 SEC
 ADC IPASCPTR
 STA IPASCPTR
 LDA IPASCPTR+2
 ADC #0
 STA IPASCPTR+2
 INX
 LDA 1,S
 INC
 STA 1,S
 BRA :LOOP

:DONE PLX ;get string length

 PLL IPASCPTR

 TXA
 SEP $20
 STA [IPASCPTR]
 REP $20

 LDA IPPORT
 BPL :SKIPORA
 SEP $30
 TXY
]L1 LDA [IPASCPTR],Y
 ORA #$80
 STA [IPASCPTR],Y
 DEY
 BNE ]L1
 REP $30
:SKIPORA
*
 PLD
 PLA
 STA 9,S
 PLA
 STA 9,S
 PLS 3
 TXA
 STA 5,S
 PLB
 RTL

PROTOCOLTOQUEUE ENT ;in=A, out=Y  (NOTE: is offset PLUS 2!)
 DBGMSG PROTOCOLTOQUEUE
 CMP #protocolICMP
 BEQ :ICMP
 CMP #protocolUDP
 BEQ :UDP
 CMP #protocolTCP
 BEQ :TCP
 LDY #0
 SEC
 RTL
:UDP LDY #uwUDPQueue+2
 CLC
 RTL
:TCP LDY #uwTCPQueue+2
 CLC
 RTL
:ICMP LDY #uwICMPQueue+2
 CLC
 RTL

*-------------------------------------------------
* FORCECLEANUP - bank and MYDP must be set
*
* Purges all users and their controls blocks.
*-------------------------------------------------

FORCECLEANUP DBGMSG FORCECLEANUP
 LDX #LOGMAX*2-2
:LOGINLOOP LDA LOGPORTS,X
 BEQ :NEXT
 PHX
 TXA
 JSR OPENUSER
 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 BEQ :CLOSED
 LDA #tcpsCLOSED
 JSL SETSTATEL
:CLOSED JSR FORCELOGOUT
 PLX
:NEXT DEX
 DEX
 BPL :LOGINLOOP

* Now kill off DNR stuff

 JSL KillDNR

 RTS

*-------------------------------------------------
* POSTLINKCLEANUP - bank and MYDP must be set
*
* Called for final cleanup once link layer has disconnect.
*-------------------------------------------------

POSTLINKCLEANUP STZ MYIPADDRESS
 STZ MYIPADDRESS+2

 LDA #false ;Trash reconnect data
 STA >RECONVALID
 JSL TCPIPSavePreferences

 STZ LINKFLAG ;No longer connected

 JSL DUMPLINKLAYER

 JSL ShutIPOut

 RTS

*-------------------------------------------------
* Main polling routine
*
* This routine is only called if LINKFLAG is true.
*-------------------------------------------------

POLLIP DBGMSG POLLIP
 PHB
 PHK
 PLB

; lda :inside
; beq :ok
; brk 0
; dbgmsg reentrancy!
;:ok inc :inside

 PHD
 LDA MYDP
 TCD

 PEA 0 ;master delta
 PEA 0 ;count
]L1 PHS
 JSL IPPOLL
 PLA
 BEQ :NOMORE
 STA 3,S
 LDA 1,S
 INC
 STA 1,S
 CMP >IPUSERSLICE
 BCC ]L1
:NOMORE PLS ;1 still on stack

 LDY #lvConnected
 LDA [LINKVARIABLESPTR],Y
 BNE :ISUP
;Link layer says link is down
 JSR FORCECLEANUP
 JSR POSTLINKCLEANUP ;This sets LINKFLAG
 BRA :EXIT
:ISUP

; LDA >TCPCONNECTIONS
; BEQ :NONE

 LDX #LOGMAX*2-2
:NEXTPORT LDA LOGPORTS,X
 BEQ :SKIPUSER
 PHX
 JSL OPENUSERBYIPID

 LDY #uwTCP_State
 LDA [USERPTR],Y
 CMP #tcpsCLOSED
 BEQ :CHECKLOGOUT
 JSL TCPPOLLTIMERS
 BRA :NEXT

:CHECKLOGOUT LDY #uwLogoutPending
 LDA [USERPTR],Y
 BEQ :NEXT
 JSR FORCELOGOUT
 BRA :NEXT1

:NEXT JSR CLOSEUSER
:NEXT1 PLX
:SKIPUSER DEX
 DEX
 BPL :NEXTPORT
:NONE

* Check DNR stuff

 LDA DNRSPENDING
 BEQ :SKIPDNR
 JSL PollDNR
:SKIPDNR

* Check for alive timer

 LDA >ALIVEFLAG
 BEQ :DONEALIVE
 LXA ALIVETIMER
 JSL TIMERVALID?
 BCC :DONEALIVE
 PHL #:DUMMYKEYBLOCK
 PEA 12
 PHL #:ICMPHEADER
 JSL ICMPSEND ;(keyblock:longw,len:integer,msgptr:longw);
 JSR SetAliveTimer
:DONEALIVE

:EXIT

 PLA
 PLD

; dec :inside

 PLB

 RTS

;:inside da 0

:DUMMYKEYBLOCK DA 0 ;unused
 ADRL 255,255,255,255 ;limited broadcast
 DA 0 ;unused
 DA 0 ;TOS
 DA 1 ;TTL

:ICMPHEADER HEX 1100
 HEX 0000 ;checksum
 HEX 0000 ;id
 HEX 0000 ;seq
 ADRL 0 ;subnet mask

SetAliveTimer PHS 2
 JSL GetTick
 PHS 2
 LDA >ALIVEMINUTES
 PHA
 PEA 60*60 ;1 minute
 _Multiply
 PLA
 CLC
 ADC 3,S
 STA ALIVETIMER
 PLA
 ADC 3,S
 STA ALIVETIMER+2
 PLS 2
 RTS

*-------------------------------------------------
* IPID routines - REQUIRES DBK TO BE SET!
*-------------------------------------------------

* Requires my DP and IPID in A

* On return USERPTR is locked down pointer to user stuff
* If carry set, A is error code

OPENUSER DBGMSG OPENUSER

 PHA
;Syntax check it first...
 LDA LINKFLAG
 BEQ :NOTCONNECTED

 LDA LOGCOUNT
 BEQ :BADIPID

 LDA 1,S
 CMP #LOGMAX*2
 BCS :BADIPID
 BIT #1
 BNE :BADIPID
 TAX
 LDA LOGPORTS,X
 BNE :IPIDOK

:BADIPID LDA #terrBADIPID&terrmask
 PLX
 SEC
 RTS

:NOTCONNECTED LDA #terrNOCONNECTION&terrmask
 PLX
 SEC
 RTS

:IPIDOK LDA 1,S ;Setup IPID
 STA IPID
 ASL
 TAX
 LDA LOGTABLE,X ;Setup handle to user area
 STA USERHANDLE
 LDA LOGTABLE+2,X
 STA USERHANDLE+2
 LOCK USERHANDLE ;Lock it down
 LDA [USERHANDLE] ;Setup pointer to user area
 STA USERPTR
 LDY #2
 LDA [USERHANDLE],Y
 STA USERPTR+2
 PLX
 CLC
 RTS

CLOSEUSER UNLOCK USERHANDLE
 RTS

FORCELOGOUT DBGMSG FORCELOGOUT
 LDY #uwICMPQueue+2
 PHW [USERPTR],Y
 DEY
 DEY
 PHW [USERPTR],Y
 JSL DESTROYQUEUE
 LDY #uwUDPQueue+2
 PHW [USERPTR],Y
 DEY
 DEY
 PHW [USERPTR],Y
 JSL DESTROYQUEUE
 LDY #uwTCPQueue+2
 PHW [USERPTR],Y
 DEY
 DEY
 PHW [USERPTR],Y
 JSL DESTROYQUEUE
 JSR CLOSEUSER
 PZL USERHANDLE
 _DisposeHandle
 LDX IPID
 STZ LOGPORTS,X
 TXA
 ASL
 TAX
 STZ LOGTABLE,X
 STZ LOGTABLE+2,X
 DEC LOGCOUNT
 RTS

LINKFLAG ENT
 DA 0 ;If the link has started

*-------------------------------------------------
* Socket subroutines from other banks. ASSUMES MY DP but not DBK
*-------------------------------------------------

IPCLOSEUSER ENT
 DBGMSG IPCLOSEUSER
 UNLOCK USERHANDLE
 RTL

* Looks for an IPID using A as local port, and X as far away port.
* If none found, then look for A as local port, and zero as uwDestPort
* (Y is $0000=UDP, $0001=TCP)

IPOPENUSER ENT ;Called from transport layer only
 DBGMSG IPOPENUSER ;Opens user by port number
;A=my port, X=his port
 PHB
 PHK
 PLB
 STY :TRANSPORT
 STX :HISPORT
:TRYAGAIN LDX #LOGMAX*2-2
]L1 CMP LOGPORTS,X
 BEQ :CHECKIT
:NEXT DEX
 DEX
 BPL ]L1
 LDX :HISPORT
 BEQ :NONE
 STZ :HISPORT ;Try looking for a server instead
 BRA :TRYAGAIN

:NONE PLB
 SEC
 RTL

:HISPORT DA 0
:TRANSPORT DA 0

:CHECKIT PHA ;Save my port
 PHX
 TXA
 ASL
 TAX
 LDA LOGTABLE+2,X
 STA USERHANDLE+2
 LDA LOGTABLE,X
 STA USERHANDLE
 PLX
 LDA [USERHANDLE]
 STA USERPTR
 LDY #2
 LDA [USERHANDLE],Y
 STA USERPTR+2
 LDY #uwDestPort
 LDA [USERPTR],Y ;Get destination port
 CMP :HISPORT ;Is this where it came from?
 BEQ :CHECKSERVER
 PLA
 BRA :NEXT

:CHECKSERVER LDA :HISPORT ;Are we looking for servers?
 BNE :OPEN ;Nope, this must be it

 LDA :TRANSPORT ;Which server are we looking for? UDP or TCP?
 BEQ :UDP

:TCP LDY #uwTCP_Server
 LDA [USERPTR],Y
 BNE :OPEN ;Yep, we're a server
 PLA
 BRA :NEXT

:UDP LDY #uwUDP_Server
 LDA [USERPTR],Y
 BNE :OPEN ;Yep, we're a server
 PLA
 BRA :NEXT

:OPEN PLA
 PLB

OPENUSERBYIPID ENT
 PHB
 PHK
 PLB
 STX IPID
 TXA
 ASL
 TAX
 LDA LOGTABLE+2,X
 BEQ :ERR
 STA USERHANDLE+2
 LDA LOGTABLE,X ;Setup handle to user area
 STA USERHANDLE
 LOCK USERHANDLE ;Lock it down
 LDA [USERHANDLE] ;Setup pointer to user area
 STA USERPTR
 LDY #2
 LDA [USERHANDLE],Y
 STA USERPTR+2
 PLB
 CLC
 RTL
:ERR PLB
 SEC
 RTL

CallHook ENT
 DBGMSG CallHook ;Y=offset into user record
 LDA [USERPTR],Y
 STA >:HOOKJML
 INY
 ORA [USERPTR],Y
 BNE :DOJML
 RTL
:DOJML LDA [USERPTR],Y
 STA >:HOOKJML+1
:HOOKJML JML 0

 ASC 'Marinetti is copyright (c) 1996-2003 by Richard Bennett'

 SAV I.INIT.L

 END
