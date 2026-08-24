*=================================================
*
* I.EQU.S - Main global equates for Marinetti
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
*
*=================================================

*-------------------------------------------------
* System equates
*-------------------------------------------------

LOGMAX = 50 ;Number of procs that can log in at once.

DEFIPSIZE = $FFFF ;Maximum outgoing IP packet size

DEFIPSLICE = 2 ;Maximum packets IP can build per tellTCPIPPoll
DEFIPRUNQFREQ = 30 ;Call RunQ task every .5 seconds
DEFIPRUNQSLICE = 1 ;Maximum packets IP can build per RunQ request

DEFTCPUSERSLICE = 2 ;Maximum TCP iterations per user per tellTCPIPPoll
;DEFTCPRUNQFREQ = 30 ;Call RunQ task every .5 seconds
;DEFTCPRUNQSLICE = 1 ;Maximum TCP iterations per user per RunQ request

DEFTCPMAXSEGSEND = $4000
DEFTCPMAXSEGRECEIVE = $4000

DEFTCPRECEIVEWINDOW = $4000

DEFCONNECTMSGFLAG = 0 ;No

FRAG_WAIT_TIME = 60*60 ;Time to wait before purging fragments (1min)
RT_TIME = 60*3 ;Round Trip TIME is 3 seconds
MSLX2_TIME = 60*60*2 ;2xMSL = 2 minutes

*-------------------------------------------------
* Direct Page
*-------------------------------------------------

 DUM 0

* Generic stuff

TMPTR ADRL 0
TMPTR1 ADRL 0
TMPHANDLE ADRL 0
TMPWORD DA 0
CNTR DA 0

* Stuff to pass from _TCPIPxxxTCP calls to I.TCP code.

tcRESPONSEBUFFPTR ADRL 0 ;Generic response buffer pointer
tcCONNECTIONTYPE DA 0 ;From _TCPIPOpenTCP
tcDATABUFFER ADRL 0 ;From read and write calls
tcDATALENGTH ADRL 0
tcPUSHFLAG DA 0
tcURGENTFLAG DA 0
tcBUFFTYPE DA 0
tcDELIMITSTRING ADRL 0

* TCP stuff

TCPINHANDLE ADRL 0 ;IP packet in
TCPIPHEADER ADRL 0 ;...pointer to it
TCPHEADER ADRL 0 ;...pointer to it
TCPDATA ADRL 0 ;...pointer to it
TCPDATALEN DA 0 ;...length of it

TCPHANDLE ADRL 0 ;general /
TCPPTR ADRL 0 ;       / use
TCPTEMP DA 0

TCPLEN ADRL 0

TCPCOUNT DA 0 ;count of sent - temp
TCPOFFSET ADRL 0 ;offet into send buffer - temp
TCPMAX DA 0 ;max data I can send - temp
TCPTHISSEGLEN DA 0

* UDP stuff

UDPPTR ADRL 0
UDPLEN DA 0

* ICMP stuff

ICMPPTR ADRL 0
ICMPLEN DA 0

* IP stuff

MYIPADDRESS ADRL 0

DESTINATIONIP ADRL 0

RAWPKTSHANDLE ADRL 0 ;Incoming raw data

PKTLISTHANDLE ADRL 0 ;Miscellaneous packets
PKTLISTPTR ADRL 0

MTU DA 0 ;Maximum Transmission Unit for this link layer

FRAGQUEUE ADRL 0 ;Fragments...
FRAGMASTERH ADRL 0 ;Handle to master entry
FRAGMASTER ADRL 0 ;Pointer to master entry
FRAGENTRYH ADRL 0 ;Handle to an entry
FRAGENTRY ADRL 0 ;Pointer to an entry
FRAGMAX DA 0 ;Entries it queue
FRAGINDEX DA 0 ;Entry up to

IPUNIQUEID DA 0 ;Stored little endian, must be flipped b4 use

IPHEADERLEN DA 0 ;Calculated length of incoming IP header
* IPDATALEN DA 0 ;Calculated length of data after IP header

LOOPBACK DA 0
LOOPBACKHANDLE ADRL 0

WORKBUFFPTR ADRL 0 ;an entire bank of memory locked down while
WORKBUFFINDEX DA 0 ;connected.

* Socket stuff

USERHANDLE ADRL 0
USERPTR ADRL 0

* Queue library stuff

QHANDLE ADRL 0
QPTR ADRL 0

* DNR stuff

DNRCACHEHANDLE ADRL 0 ;not used
DNRHANDLE ADRL 0
DNRSPENDING DA 0

* Internal link layer stuff

LINKVARIABLESPTR ADRL 0
AUTHMSGHANDLE ADRL 0 ;Contains data returned from authentication

* Keep network alive stuff

ALIVETIMER ADRL 0

 DS $E0-4-*

TCPDEBUGHANDLE ADRL 0

* Reserved for Link layer modules

LLSPACE DS 32

 DEND

*-------------------------------------------------
* Util equates
*-------------------------------------------------

FRAME EQU 4 ;for access to stack frame from Pasc proc call
FRAMEB EQU FRAME+1 ;for access to stack frame after PHB
FRAMEDP EQU 4 ;for access to stack as DP
FRAMEBDP EQU FRAMEDP+1 ;for access to stack as DP after PHB

*-------------------------------------------------
* Triggers
*-------------------------------------------------

 DUM 0
trgUDPIn DS 1
trgCount
 DEND

 DUM 0
strgNetworkDown DS 1
strgCount
 DEND

*-------------------------------------------------
* User data areas
*-------------------------------------------------

 DUM 0 ;all these are little endian (standard '816)

uwUserID DA 0 ; All these supplied by caller
uwDestIP ADRL 0 ;
uwDestPort DA 0 ; ... this is an IP keyblock
uwIP_TOS DA 0 ;
uwIP_TTL DA 0 ;
uwHeaderLen = *

uwSourcePort DA 0

uwLogoutPending DA 0

uwICMPQueue ADRL 0

uwTCPQueue ADRL 0

* TCP variables - all initialised to zero upon TCP_OPEN call

uwTCPVarStart

uwTCPMaxSendSeg DA 0
uwTCPMaxReceiveSeg DA 0

uwTCPDataInQ ADRL 0 ;handle to out of sequence data queue (cache)
uwTCPDataIn ADRL 0 ;handle to received data - ready for app.

uwTCPPushInFlag DA 0 ;boolean - push is valid
uwTCPPushInOffset ADRL 0 ;offset into uwTCPDataIn

uwTCPPushOutFlag DA 0 ;boolean - push is valid
uwTCPPushOutSEQ ADRL 0 ;sequence number of last byte to be pushed

uwTCPDataOut ADRL 0 ;handle to output data - not in window yet

uwSND_UNA ADRL 0 ;send unacknowledged - somewhere in window
uwSND_NXT ADRL 0 ;send next - the byte at start of DataOut
uwSND_WND DA 0 ;send window - length from start of DataOut
uwSND_UP DA 0 ;send urgent pointer
uwSND_WL1 ADRL 0 ;segment sequence number for last window update
uwSND_WL2 ADRL 0 ;segment ack number for last window update
uwISS ADRL 0 ;initial send sequence number

uwRCV_NXT ADRL 0 ;receive next
uwRCV_WND DA 0 ;receive window
uwRCV_UP DA 0 ;receive urgent pointer
uwIRS ADRL 0 ;initial receive sequence number

uwTCP_State DA 0 ;current state
uwTCP_StateTick ADRL 0 ;tick...
uwTCP_ErrCode DA 0 ;see tcperr_*
uwTCP_ICMPError DA 0 ;code from type 3 Port Unreachable Error
uwTCP_Server DA 0 ;0=active/client, 1=passive/server
uwTCP_ChildList ADRL 0 ;Handle of unaccepted children if passive/server

uwTCP_ACKPending DA 0 ;Must send an ACK before exiting

uwTCP_ForceFIN DA 0 ;Data in out queue is the last before closing
;so send FIN if last segment or none pending.
uwTCP_FINSEQ ADRL 0 ;Sequence number of my FIN
uwTCP_MyFINACKed? DA 0 ;Has my FIN been ACKed?

uwTCP_Timer ADRL 0 ;tick when to resend window
uwTCP_TimerState DA 0 ;See TCPT_*

* Presets for timer values

uwTCP_rt_timer DA 0 ;current round trip time
uwTCP_2MSL_timer DA 0 ;2 MSL timer for CLOSEWAIT

uwTCP_SaveTTL DA 0 ;user's TTL while using TCP
uwTCP_SaveTOS DA 0 ;user's TOS while using TCP

uwTCP_TotalIN ADRL 0 ;Total octets successfully received
uwTCP_TotalOUT ADRL 0 ;Total octets successfully sent

uwTCPVarEnd

* UDP stuff

uwUDP_Server DA 0 ;0=active/client, 1=passive/server

uwUDPQueue ADRL 0

uwUDPError DA 0 ;Last error received
uwUDPErrorTick ADRL 0 ;...and when
uwUDPCount ADRL 0 ;How many UDP packets received for this user

* Triggers

uwTriggers DS trgCount*4
uwSysTriggers DS strgCount*4

uwLength
 DEND

* Timer values

 DUM 0
TCPT_OFF DA 0
TCPT_SYN DA 0 ;normal SYN sent state
TCPT_DATA DA 0
TCPT_2MSL DA 0
TCPT_SYNACK DA 0 ;SYN received state
 DEND

* Fragment entry

 DUM 0
FRAG_ASC DA $FFFF ;indicates block start
FRAG_SRCIP ADRL 0 ;Where it was from
FRAG_PROTOCOL DA 0 ;What protocol
FRAG_ID DA 0 ;Identification
FRAG_TOTAL DA 0 ;Total length of datagram, else 0000
FRAG_EXPIRES ADRL 0 ;Tick when fragments should be purged
FRAGBLOCKLEN
 DEND

* Link layer entry parms. X=?

 DUM 0
LLINTERFACEV DA 0
LLSTARTUP DA 0
LLSHUTDOWN DA 0
LLMODULEINFO DA 0
LLGETPACKET DA 0
LLSENDPACKET DA 0
LLCONNECT DA 0
LLRECONSTATUS DA 0
LLRECONNECT DA 0
LLDISCONNECT DA 0
LLGETVARIABLES DA 0
LLCONFIGURE DA 0
LLCONFIGFNAME DA 0
 DEND

* Link layer variables

lvVer = $0001

 DUM 0
lvVersion DA 0 ;lvVer
lvConnected DA 0
lvIPaddress ADRL 0
lvRefCon ADRL 0
lvErrors ADRL 0
lvMTU DA 0 ;Maximum Transmission Unit size
;... this is the Maximum Receive Unit (MRU)
;... from the host.
lvlen
 DEND

* DNR pending entry

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

*-------------------------------------------------
* Internal protocol equates
*-------------------------------------------------

* TCP header flags

TCPF_URG = %10_0000
TCPF_ACK = %01_0000
TCPF_PSH = %00_1000
TCPF_RST = %00_0100
TCPF_SYN = %00_0010
TCPF_FIN = %00_0001
TCPF_ALL = %11_1111

*-------------------------------------------------
* Miscellaneous equates / macros
*-------------------------------------------------

false = $0000
true = $8000

AMBED MAC
; COP 0
; BRL OK
 BRL OK
 DA $7771
 if ',]1
 STR ]1
 else
 STR ']1'
 fin
OK <<<

DBGMSG MAC
 do EYECATCHERS
 AMBED ]1
 fin
 <<<

FLIPBORDER MAC
 SEP $20
 LDA >$E0C034
 EOR #%0111
 STA >$E0C034
 REP $20
 <<<
