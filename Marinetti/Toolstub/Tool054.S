 LST OFF
 TYP $BA
 REL
 mx 0

*=================================================
*
* Tool054 - Marinetti
*
* Copyright (c) 1998-2009 Richard Bennett
*
* Written by Richard Bennett
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
* 2009.02.13 RJB - Initial release as open source
*
*=================================================

 USE 4/RJBUTIL.MACS
 USE 4/LOCATOR.MACS
 USE 4/MEM.MACS
 USE 4/TCPIP.MACS
 USE ../Equates/BUILD.EQU
 USE ../Equates/TCPIP.EQU

*-------------------------------------------------
* Mandatory header stuff
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
 ADRL TCPIPGetConnectStatus-1 ;$0936
 ADRL TCPIPGetErrorTable-1 ;$0A36
 ADRL TCPIPGetReconnectStatus-1 ;$0B36
 ADRL TCPIPReconnect-1 ;$0C36
 ADRL TCPIPConvertIPToHex-1 ;$0D36
 ADRL TCPIPConvertIPToASCII-1 ;$0E36
 ADRL TCPIPGetMyIPAddress-1 ;$0F36
 ADRL TCPIPGetConnectMethod-1 ;$1036
 ADRL TCPIPSetConnectMethod-1 ;$1136
 ADRL TCPIPConnect-1 ;$1236
 ADRL TCPIPDisconnect-1 ;$1336
 ADRL TCPIPGetMTU-1 ;$1436
 ADRL TCPIPValidateIPCString-1 ;$1536
 ADRL TCPIPGetConnectData-1 ;$1636
 ADRL TCPIPSetConnectData-1 ;$1736
 ADRL TCPIPGetDisconnectData-1 ;$1836
 ADRL TCPIPSetDisconnectData-1 ;$1936
 ADRL TCPIPLoadPreferences-1 ;$1A36
 ADRL TCPIPSavePreferences-1 ;$1B36
 ADRL TCPIPGetDNS-1 ;$1C36
 ADRL TCPIPSetDNS-1 ;$1D36
 ADRL TCPIPGetTuningTable-1 ;$1E36
 ADRL TCPIPSetTuningTable-1 ;$1F36
 ADRL TCPIPCancelDNR-1 ;$2036
 ADRL TCPIPDNRNameToIP-1 ;$2136
 ADRL TCPIPPoll-1 ;$2236
 ADRL TCPIPLogin-1 ;$2336
 ADRL TCPIPLogout-1 ;$2436
 ADRL TCPIPSendICMP-1 ;$2536
 ADRL TCPIPSendUDP-1 ;$2636
 ADRL TCPIPGetDatagramCount-1 ;$2736
 ADRL TCPIPGetNextDatagram-1 ;$2836
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
 ADRL TCPIPSetMyIPAddress-1 ;$3836 RESTRICTED
 ADRL TCPIPGetDP-1 ;$3936 RESTRICTED
 ADRL TCPIPGetDebugHex-1 ;$3A36 RESTRICTED
 ADRL TCPIPSetDebugHex-1 ;$3B36 RESTRICTED
 ADRL TCPIPGetDebugTCP-1 ;$3C36 RESTRICTED
 ADRL TCPIPSetDebugTCP-1 ;$3D36 RESTRICTED
 ADRL TCPIPGetUserRecord-1 ;$3E36 RESTRICTED
 ADRL TCPIPConvertIPCToHex-1 ;$3F36
 ADRL TCPIPSendIPDatagram-1 ;$4036
 ADRL TCPIPConvertIPToClass-1 ;$4136
 ADRL TCPIPGetConnectMsgFlag-1 ;$4236
 ADRL TCPIPSetConnectMsgFlag-1 ;$4336
 ADRL TCPIPGetUsername-1 ;$4436
 ADRL TCPIPSetUsername-1 ;$4536
 ADRL TCPIPGetPassword-1 ;$4636
 ADRL TCPIPSetPassword-1 ;$4736
 ADRL TCPIPValidateIPString-1 ;$4836
 ADRL TCPIPGetUserStatistic-1 ;$4936
 ADRL TCPIPGetLinkVariables-1 ;$4A36
 ADRL TCPIPEditLinkConfig-1 ;$4B36
 ADRL TCPIPGetModuleNames-1 ;$4C36
 ADRL TCPIPRebuildModuleList-1 ;$4D36 RESTRICTED
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
* Variables
*-------------------------------------------------

MYTOOLSETNUMBER DA 0 ;#$nn00

*-------------------------------------------------
* Tool calls
*-------------------------------------------------

TCPIPStartUp ;$0236
TCPIPShutDown ;$0336
TCPIPVersion ;$0436
TCPIPReset ;$0536
TCPIPStatus ;$0636
reserved ;$0736
TCPIPLongVersion ;$0836
TCPIPGetConnectStatus ;$0936
TCPIPGetErrorTable ;$0A36
TCPIPGetReconnectStatus ;$0B36
TCPIPReconnect ;$0C36
TCPIPConvertIPToHex ;$0D36
TCPIPConvertIPToASCII ;$0E36
TCPIPGetMyIPAddress ;$0F36
TCPIPGetConnectMethod ;$1036
TCPIPSetConnectMethod ;$1136
TCPIPConnect ;$1236
TCPIPDisconnect ;$1336
TCPIPGetMTU ;$1436
TCPIPValidateIPCString ;$1536
TCPIPGetConnectData ;$1636
TCPIPSetConnectData ;$1736
TCPIPGetDisconnectData ;$1836
TCPIPSetDisconnectData ;$1936
TCPIPLoadPreferences ;$1A36
TCPIPSavePreferences ;$1B36
TCPIPGetDNS ;$1C36
TCPIPSetDNS ;$1D36
TCPIPGetTuningTable ;$1E36
TCPIPSetTuningTable ;$1F36
TCPIPCancelDNR ;$2036
TCPIPDNRNameToIP ;$2136
TCPIPPoll ;$2236
TCPIPLogin ;$2336
TCPIPLogout ;$2436
TCPIPSendICMP ;$2536
TCPIPSendUDP ;$2636
TCPIPGetDatagramCount ;$2736
TCPIPGetNextDatagram ;$2836
TCPIPGetLoginCount ;$2936
TCPIPSendICMPEcho ;$2A36
TCPIPReceiveICMPEcho ;$2B36
TCPIPOpenTCP ;$2C36
TCPIPWriteTCP ;$2D36
TCPIPReadTCP ;$2E36
TCPIPCloseTCP ;$2F36
TCPIPAbortTCP ;$3036
TCPIPStatusTCP ;$3136
TCPIPGetSourcePort ;$3236
TCPIPGetTOS ;$3336
TCPIPSetTOS ;$3436
TCPIPGetTTL ;$3536
TCPIPSetTTL ;$3636
TCPIPSetSourcePort ;$3736
TCPIPSetMyIPAddress ;$3836 RESTRICTED
TCPIPGetDP ;$3936 RESTRICTED
TCPIPGetDebugHex ;$3A36 RESTRICTED
TCPIPSetDebugHex ;$3B36 RESTRICTED
TCPIPGetDebugTCP ;$3C36 RESTRICTED
TCPIPSetDebugTCP ;$3D36 RESTRICTED
TCPIPGetUserRecord ;$3E36 RESTRICTED
TCPIPConvertIPCToHex ;$3F36
TCPIPSendIPDatagram ;$4036
TCPIPConvertIPToClass ;$4136
TCPIPGetConnectMsgFlag ;$4236
TCPIPSetConnectMsgFlag ;$4336
TCPIPGetUsername ;$4436
TCPIPSetUsername ;$4536
TCPIPGetPassword ;$4636
TCPIPSetPassword ;$4736
TCPIPValidateIPString ;$4836
TCPIPGetUserStatistic ;$4936
TCPIPGetLinkVariables ;$4A36
TCPIPEditLinkConfig ;$4B36
TCPIPGetModuleNames ;$4C36
TCPIPRebuildModuleList ;$4D36 RESTRICTED
TCPIPListenTCP ;$4E36
TCPIPAcceptTCP ;$4F36
TCPIPSetNewDestination ;$5036
TCPIPGetHostName ;$5136
TCPIPSetHostName ;$5236
TCPIPStatusUDP ;$5336
TCPIPGetLinkLayer ;$5436
TCPIPPtrToPtr ;$5536
TCPIPPtrToPtrNeg ;$5636
TCPIPGetAuthMessage ;$5736
TCPIPConvertIPToCASCII ;$5836
TCPIPMangleDomainName ;$5936
TCPIPGetAliveFlag ;$5A36
TCPIPSetAliveFlag ;$5B36
TCPIPGetAliveMinutes ;$5C36
TCPIPSetAliveMinutes ;$5D36
TCPIPReadLineTCP ;$5E36
TCPIPGetBootConnectFlag ;$5F36
TCPIPSetBootConnectFlag ;$6036
TCPIPSetUDPDispatch ;$6136
TCPIPGetDestination ;$6236
TCPIPGetUserEventTrigger ;$6336 v3.0
TCPIPSetUserEventTrigger ;$6436 v3.0
TCPIPGetSysEventTrigger ;$6536 v3.0
TCPIPSetSysEventTrigger ;$6636 v3.0
TCPIPGetDNRTimeouts ;$6736 v3.0
TCPIPSetDNRTimeouts ;$6836 v3.0

 PHA
 PHX
 PHY
 ~GetMsgHandle #%10;#MSGPSTR
 BCC :OK
 PLS 2
 PLY
 PLX
 PLA
 LDA #terrINITNOTFOUND&terrmask
 ORA >MYTOOLSETNUMBER
 SEC
 RTL

:OK TEMPDPON

 DEREF 0;0

 LDY #SYNCVERSION
 LDA [0],Y
 CMP #CODESYNCVERSION
 BEQ :SYNCOK

 TEMPDPOFF
 PLS 2
 PLY
 PLX
 PLA
 LDA #terrVERSIONMISMATCH&terrmask
 ORA >MYTOOLSETNUMBER
 SEC
 RTL

:SYNCOK LDY #FPTPTR
 LDA [0],Y
 TAX ;start address
 INY
 INY
 LDA [0],Y
 SEP $20
 STA >:MVNMOD+2 ;Set source bank
 REP $20
 LDY #FPTCOUNT
 LDA #FPTEND-FPTCOUNT-1
 PHB
:MVNMOD MVN 0,FPTCOUNT ;Copy real FPT to mine
 PLB
 TEMPDPOFF
 PLS 2

 PLY ;Put a dummy RTL above the saved regs
 PLX
 PLA
 PHK
 PHS
 PHA
 PHX
 PHY

 LDA 3+1,S ;And plug in the original call to it
 AND #$FF
 ASL
 ASL
 TAX
 LDA >FPTCOUNT,X
 STA 7,S
 LDA >FPTCOUNT+1,X
 STA 7+1,S

;Before issuing the call which started all of
;this, make a _TCPIPVersion() call to tell the
 ~TCPIPVersion ;INIT that all is hooked in, so it can set up
 PLS ;its MYTOOLSETNUMBER etc.

 PLY
 PLX
 PLA
 RTL ;Call the original tool call

TCPIPBootInit TXA
 XBA
 AND #$FF00
 STA >MYTOOLSETNUMBER
 LDA #terrOK
 CLC
 RTL

MSGPSTR STR 'TCP/IP tool info'
MSGSTART = 8+*-MSGPSTR

 DUM MSGSTART
SYNCVERSION DA CODESYNCVERSION ;internal version to sync init and tool
FPTPTR ADRL 0 ;Pointer to real FPT
 DEND

 SAV Tool054.L

 END
