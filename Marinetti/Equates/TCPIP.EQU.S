*=================================================
*
* TCPIP.EQU.S - Equates for use by Marinetti
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
* 1999.07.08 RJB - Updated to 2.1
*
*=================================================

]t0 = $3600 ;Base tool set number

*-------------------------------------------------
* Various numeric equates
*-------------------------------------------------

* Connect methods

conEthernet = 1
conMacIP = 2
conPPPCustom = 3
conSLIP = 4
conTest = 5
conPPP = 6
conDirectConnect = 7
conAppleEthernet = 8

* Protocols

protocolAll = 0
protocolICMP = 1
protocolTCP = 6
protocolUDP = 17

* Tool error codes

terrOK = $0000
terrBADIPID = $0001+]t0 ;Bad IPID for this request
terrNOCONNECTION = $0002+]t0 ;Not connected to the network
terrNORECONDATA = $0003+]t0 ;No reconnect data
terrLINKERROR = $0004+]t0 ;Problem with the link layer
terrSCRIPTFAILED = $0005+]t0 ;The script failed / timed out
terrCONNECTED = $0006+]t0 ;Not while connected to the network
terrSOCKETOPEN = $0007+]t0 ;Cannot complete - socket still open
terrINITNOTFOUND = $0008+]t0 ;The Marinetti init is not loaded
terrVERSIONMISMATCH = $0009+]t0 ;The init and tool set have different versions
terrBADTUNETABLELEN = $000A+]t0 ;Tune table length in Marinetti 2.0 must be 10
terrIPIDTABLEFULL = $000B+]t0 ;Marinetti cannot handle any more ipids
terrNOICMPQUEUED = $000C+]t0 ;No ICMP datagrams in the queue
terrLOGINSPENDING = $000D+]t0 ;There are still ipids logged in
terrTCPIPNOTACTIVE = $000E+]t0 ;Not active - probably in P8 mode
terrNODNSERVERS = $000F+]t0 ;No servers registered with Marinetti
terrDNRBUSY = $0010+]t0 ;DNR is currently busy - try again later
terrNOLINKLAYER = $0011+]t0 ;Unable to load link layer module
terrBADLINKLAYER = $0012+]t0 ;Not a link layer module
terrENJOYCOKE = $0013+]t0 ;But not so close to the keyboard
terrNORECONSUPPRT = $0014+]t0 ;This module doesn't support reconnect
terrUSERABORTED = $0015+]t0 ;The user aborted the connect/disconnect
terrBADUSERPASS = $0016+]t0 ;Invalid username and/or password
terrBADPARAMETER = $0017+]t0 ;Invalid parameter for this call
terrBADENVIRONMENT = $0018+]t0 ;No desktop or tools not started
terrNOINCOMING = $0019+]t0 ;There is no pending incoming request
terrLINKBUSY = $001A+]t0 ;Modem or interface is busy
terrNOLINKINTERFACE = $001B+]t0 ;No dial tone or similar
terrNOLINKRESPONSE = $001C+]t0 ;No modem answer or similar
terrNODNRPENDING = $001D+]t0 ;No such entry in DNR list
terrBADALIVEMINUTES = $001E+]t0 ;Minutes value is invalid
terrBUFFERTOOSMALL = $001F+]t0 ;Buffer is too small
terrNOTSERVER = $0020+]t0 ;This ipid is not set up as a server
terrBADTRIGGERNUM = $0021+]t0 ;Invalid trigger number

terrmask = $00FF

* DNR status codes

DNR_Pending = 0 ;Request still being processed
DNR_OK = 1 ;Request completed successfully
DNR_Failed = 2 ;Network error/timeout
DNR_NoDNSEntry = 3 ;Requested domain has no DNS entry
DNR_Cancelled = 4 ;Cancelled by user

* TCP logic errors

tcperrOK = 0 ;"tcperr" error codes from TCP RFC
tcperrDeafDestPort = 1
tcperrHostReset = 2
tcperrConExists = 3 ;"connection already exists"
tcperrConIllegal = 4 ;"connection illegal for this process"
tcperrNoResources = 5 ;"insufficient resources"
tcperrNoSocket = 6 ;"foreign socket unspecified"
tcperrBadPrec = 7 ;"precedence not allowed"
tcperrBadSec = 8 ;"security/compartment not allowed"
tcperrBadConnection = 9 ;"connection does not exist"
tcperrConClosing = 10 ;"connection closing"
tcperrClosing = 11 ;"closing"
tcperrConReset = 12 ;"connection reset"
tcperrUserTimeout = 13 ;"connection aborted due to user timeout"
tcperrConRefused = 14 ;"connection refused"

* TCP states

tcpsCLOSED = 0
tcpsLISTEN = 1
tcpsSYNSENT = 2
tcpsSYNRCVD = 3
tcpsESTABLISHED = 4
tcpsFINWAIT1 = 5
tcpsFINWAIT2 = 6
tcpsCLOSEWAIT = 7
tcpsLASTACK = 8
tcpsCLOSING = 9
tcpsTIMEWAIT = 10
nTCPSTATES = 11

TCPIPSaysHello = $8101
TCPIPSaysNetworkUp = $8102
TCPIPSaysNetworkDown = $8103

*-------------------------------------------------
* Control/data blocks
*-------------------------------------------------

* Error table

 DUM 0
tcpDGMSTBLEN ADRL tcpDGMSLEN ;Length of table including this longword
tcpDGMSTOTAL ADRL 0 ;Total datagrams received (good and bad)

tcpDGMSFRAGSIN ADRL 0 ;Got a fragment (datagram is queued to frag list)
tcpDGMSFRAGSLOST ADRL 0 ;Fragment purged after timeout in queue
tcpDGMSBUILT ADRL 0 ;Built a datagram from fragments (is then queued)

tcpDGMSOK ADRL 0 ;datagrams queued from link *OR* tcpDGMSBUILT

tcpDGMSBADCHK ADRL 0 ;Bad IP checksum (datagram is purged)
tcpDGMSBADHEADLEN ADRL 0 ;Bad IP header lengths (datagram is purged)
tcpDGMSBADPROTO ADRL 0 ;Unsupported protocols (added to misc queue)
tcpDGMSBADIP ADRL 0 ;Not my or loopback IP (datagram is purged)

tcpDGMSICMP ADRL 0 ;ICMP total datagrams in (good and bad)
tcpDGMSICMPUSER ADRL 0 ;ICMP user datagrams
tcpDGMSICMPKERNEL ADRL 0 ;ICMP kernel datagrams
tcpDGMSICMPBAD ADRL 0 ;ICMP bad checksum or datagram too short
tcpDGMSICMPBADTYPE ADRL 0 ;ICMP bad ic_type
tcpDGMSICMPBADCODE ADRL 0 ;ICMP bad ic_code
tcpDGMSICMPECHORQ ADRL 0 ;ICMP ECHORQs in
tcpDGMSICMPECHORQOUT ADRL 0 ;ICMP ECHORQ replies sent out
tcpDGMSICMPECHORP ADRL 0 ;ICMP ECHORPs in
tcpDGMSICMPECHORPBADID ADRL 0 ;ICMP ECHORPs unclaimed

tcpDGMSUDP ADRL 0 ;UDPs OK (added to UDP queue)
tcpDGMSUDPBAD ADRL 0 ;Bad UDP header (datagram is purged)
tcpDGMSUDPNOPORT ADRL 0 ;No such logged in port (datagram is purged)

tcpDGMSTCP ADRL 0 ;TCPs OK (returned to TCP main logic)
tcpDGMSTCPBAD ADRL 0 ;Bad TCP header or checksum (datagram is purged)
tcpDGMSTCPNOPORT ADRL 0 ;No such logged in port (datagram is purged)
tcpDGMSTCPQUEUED ADRL 0 ;Arrived before required (datagram is queued)
tcpDGMSTCPOLD ADRL 0 ;Already received this segment (datagram is purged)

tcpDGMSOFRAGMENTS ADRL 0 ;Fragments transmitted
tcpDGMSFRAGMENTED ADRL 0 ;Datagrams fragmented for transmission

tcpDGMSLEN
 DEND

* TCPIPReadTCP response buffer

 DUM 0
rrBuffCount ADRL 0
rrBuffHandle ADRL 0
rrMoreFlag DA 0
rrPushFlag DA 0
rrUrgentFlag DA 0
rrlen
 DEND

* TCPIPReadLineTCP response buffer

 DUM 0
rlrBuffCount ADRL 0
rlrBuffHandle ADRL 0
rlrIsDataFlag DA 0
rlrMoreFlag DA 0
rlrBuffSize ADRL 0
rlrlen
 DEND

* TCPIPStatusTCP

 DUM 0
srState DA 0
srNetworkError DA 0
srSndQueued ADRL 0
srRcvQueued ADRL 0
srDestIP ADRL 0
srDestPort DA 0
srConnectType DA 0
srAcceptCount DA 0
srlen
 DEND

* TCPIPStatusUDP

 DUM 0
uvQueueSize DA 0
uvError DA 0
uvErrorTick ADRL 0
uvCount ADRL 0
uvTotalCount ADRL 0 ;same as tcpDGMSUDP
uvDispatchFlag DA 0
uvlen
 DEND

* TCPIPGetDestination

 DUM 0
drUserID DA 0
drDestIP ADRL 0
drDestPort DA 0
drlen
 DEND

* TCPIPConvertIPToHex

 DUM 0
cvtIPAddress ADRL 0
cvtPort DA 0
 DEND

* Link layer module info

 DUM 0
liMethodID DA 0 ;Ethernet=1, PPP=3, SLIP=4
liName DS 1+20
liVersion ADRL 0
liFlags DA 0
liFilename DS 1+15
liMenuItem DS 14 ;rMenuItem template
lilen
 DEND

* IPC records

 DUM 0
inwLength DA 0
inwIP ADRL 0
inwMethod DA 0
inwMTU DA 0
inwLVPtr ADRL 0
inwlen
 DEND

* Module list record

 DUM 0
rmiversion DA 0
rmiItemID DA 0
rmiChar DS 1
rmiAltChar DS 1
rmiCheck DA 0
rmiFlag DA 0
rmiTitleRef ADRL 0
 DEND

* DNR dsects

 DUM 0
DNRstatus DA 0
DNRname
DNRIPaddress
 DEND

*-------------------------------------------------
* Miscellaneous datagram header equates
*-------------------------------------------------

* ICMP types - ICT_TYPE - Comer/Stevens, vol II, p128.

ICT_ECHORP = 0
ICT_DESTUR = 3
ICT_SRCQ = 4
ICT_REDIRECT = 5
ICT_ECHORQ = 8
ICT_TIMEX = 11
ICT_PARAMP = 12
ICT_TIMERQ = 13
ICT_TIMERP = 14
ICT_INFORQ = 15
ICT_INFORP = 16
ICT_MASKRQ = 17
ICT_MASKRP = 18
ictmax = 19

* ICMP codes - IC_CODE

ICC_NETUR = 0 ;p128, Internetworking with TCP/IP Vol 2.
ICC_HOSTUR = 1 ;      Design Implementation, and Internals
ICC_PROTOUR = 2 ;      Douglas E. Comer / David L. Stevens
ICC_PORTUR = 3
ICC_FNADF = 4
ICC_SRCRT = 5
ICC_NETRD = 0
ICC_HOSTRD = 1
IC_TOSNRD = 2
IC_TOSHRD = 3
ICC_TIMEX = 0
ICC_FTIMEX = 1
IC_HLEN = 8
IC_PADLEN = 3
IC_RDTTL = 300

* UDP standard port numbers

UP_ECHO = 7 ;echo server
UP_DISCARD = 9 ;discard datagram
UP_USERS = 11 ;users server
UP_DAYTIME = 13 ;day and time server
UP_QOTD = 17 ;quote of the day server
UP_CHARGEN = 19 ;character generator
UP_TIME = 37 ;time server
UP_WHOIS = 43 ;who is server (user information)
UP_DNAME = 53 ;domain name server
UP_TFTP = 69 ;trivial file transfer protocol server
UP_RWHO = 513 ;remote who server (ruptime)
UP_RIP = 520 ;route information exchange (RIP)

* IP header

 DUM 0
ip_verlen DFB 0
ip_tos DFB 0
ip_len DDB 0
ip_id DDB 0
ip_fragoff DDB 0
ip_ttl DFB 0
ip_proto DFB 0 ;protocol*
ip_cksum DDB 0
ip_src ADRL 0
ip_dst ADRL 0
ip_data
 DEND

* ICMP header

 DUM 0
ic_type DFB 0 ;ICT_*
ic_code DFB 0 ;ICC_*
ic_cksum DDB 0
ic_data
 DEND

* Echo offsets

 DUM IC_DATA
IC_ECHO_ID DDB 0
IC_ECHO_SEQ DDB 0
 DEND

* UDP header

 DUM 0
u_source DDB 0 ;source UDP port number - UP_*
u_dst DDB 0 ;destination UDP port number
u_len DDB 0 ;length of UDP data
u_cksum DDB 0 ;UDP checksum (0 = none)
u_data
 DEND

* TCP header

 DUM 0
tcp_sport DDB 0 ;source port - TCP_*
tcp_dport DDB 0 ;destination port
tcp_seq ADRL 0 ;sequence number
tcp_ack ADRL 0 ;acknowledgement number
tcp_offset DFB 0 ;longword count in header (def=6)
tcp_code DFB 0 ;flags
tcp_window DDB 0 ;window advertisement
tcp_cksum DDB 0 ;checksum
tcp_urgptr DDB 0 ;urgent pointer
tcp_options
tcp_data
 DEND
