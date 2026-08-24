{$keep 'TCPIP'}
unit TCPIP;
interface

{********************************************************
*
*  Marinetti TCP/IP interfaces for ORCA/Pascal
*
*  Other USES Files Needed: Common
*
*  By Mike Westerfield, Byte Works, Inc.
*  This file is released to the public domain.
*
*********************************************************
* 1998-12-01 MW  Original release
* 2003-05-31 AJR Update to v2.1 of TCP/IP interfaces
* 2005-04-28 AJR Fix bugs found by Kelvin Sherlock [1179614]
* 2007-06-07 AJR Fix TCPIPGetAuthMessage consistency [1700983]
* 2007-06-09 AJR Fix definition of variablesRecord [1696861]
* 2008-01-06 AJR Fix bugs found by Ryan Suenaga [1829894]
* 2008-01-14 AJR Add TCPIP[Get/Set]DNRTimeouts [1871032]
*********************************************************}

uses
   Common;

const
					{Various numeric equates}
					{-----------------------}
   conEthernet = 1;			{Connect methods}
   conMacIP = 2;
   conPPPCustom = 3;
   conSLIP = 4;
   conTest = 5;
   conPPP = 6;
   conDirectConnect = 7;
   conAppleEthernet = 8;

   protocolAll = 0;			{Protocols}
   protocolICMP = 1;
   protocolTCP = 6;
   protocolUDP = 17;

   terrOK = 0;				{Tool Error codes}
   terrBADIPID = $3601;			{Bad IPID for this request}
   terrNOCONNECTION = $3602;		{Not connected to the network}
   terrNORECONDATA = $3603;		{No reconnect data}
   terrLINKERROR = $3604;		{Problem with the link layer}
   terrSCRIPTFAILED = $3605;		{The script failed / timed out}
   terrCONNECTED = $3606;		{Not while connected to the network}
   terrSOCKETOPEN = $3607;		{Socket still open}
   terrINITNOTFOUND = $3608;		{Init not found in memory}
   terrVERSIONMISMATCH = $3609;		{Different versions of tool, init, cdev}
   terrBADTUNETABLELEN = $360A;		{Bad tune table length}
   terrIPIDTABLEFULL = $360B;		{IPID table full}
   terrNOICMPQUEUED = $360C;		{No ICMP datagrams in the queue}
   terrLOGINSPENDING = $360D;		{There are still IPIDs logged in}
   terrTCPIPNOTACTIVE =	$360E;		{Not active. Probably in P8 mode.}
   terrNODNSERVERS = $360F;		{No servers registered with Marinetti}
   terrDNRBUSY = $3610;			{DNR is current busy. Try again later}
   terrNOLINKLAYER = $3611;		{Unable to load link layer module}
   terrBADLINKLAYER = $3612;		{Not a link layer module}
   terrENJOYCOKE = $3613;		{But not so close to the keyboard}
   terrNORECONSUPPRT = $3614;		{This module doesn't support reconnect}
   terrUSERABORTED = $3615;		{The user aborted the connect/disconnect script}
   terrBADUSERPASS = $3616;		{Invalid username and/or password}
   terrBADPARAMETER = $3617;		{Invalid parameter for this call}
   terrBADENVIRONMENT = $3618;		{No desktop or tools not started}
   terrNOINCOMING = $3619;		{There is no pending incoming request}
   terrLINKBUSY = $361A;		{Modem or interface is busy}
   terrNOLINKINTERFACE = $361B;		{No dial tone or similar}
   terrNOLINKRESPONSE = $361C;		{No modem answer or similar}
   terrNODNRPENDING = $361D;		{No such entry in DNR list}
   terrBADALIVEMINUTES = $361E;		{Minutes value is invalid}
   terrBUFFERTOOSMALL = $361F;		{Buffer is too small}
   terrNOTSERVER = $3620;		{This ipid is not set up as a server}
   terrBADTRIGGERNUM = $3621;		{Invalid trigger number}

   terrmask = $00FF;

					{DNR status codes}
   DNR_Pending = 0;			{Request still being processed}
   DNR_OK = 1;				{Request completed successfully}
   DNR_Failed = 2;			{Network error/timeout}
   DNR_NoDNSEntry = 3;			{Requested domain has no DNS entry}
   DNR_Cancelled = 4;			{Cancelled by user}


					{TCP logic errors}
   tcperrOK = 0;			{"tcperr" error codes from TCP RFC}
   tcperrDeafDestPort = 1;
   tcperrHostReset = 2;
   tcperrConExists = 3;			{"connection already exists"}
   tcperrConIllegal = 4;		{"connection illegal for this process"}
   tcperrNoResources = 5;		{"insuficient resources"}
   tcperrNoSocket = 6;			{"foreign socket unspecified"}
   tcperrBadPrec = 7;			{"precedence not allowed"}
   tcperrBadSec = 8;			{"security/compartment not allowed"}
   tcperrBadConnection = 9;		{"connection does not exist"}
   tcperrConClosing = 10;		{"connection closing"}
   tcperrClosing = 11;			{"closing"}
   tcperrConReset = 12;			{"connection reset"}
   tcperrUserTimeout = 13;		{"connection aborted due to user timeout"}
   tcperrConRefused = 14;		{"connection refused"}

   TCPSCLOSED = 0;			{TCP states}
   TCPSLISTEN = 1;
   TCPSSYNSENT = 2;
   TCPSSYNRCVD = 3;
   TCPSESTABLISHED = 4;
   TCPSFINWAIT1 = 5;
   TCPSFINWAIT2 = 6;
   TCPSCLOSEWAIT = 7;
   TCPSLASTACK = 8;
   TCPSCLOSING = 9;
   TCPSTIMEWAIT = 10;
   nTCPSTATES = 11;

   TCPIPSaysHello = $8101;
   TCPIPSaysNetworkUp = $8102;
   TCPIPSaysNetworkDown = $8103;

					{-------------------------------------}
					{Miscellaneous datagram header equates}
   					{ICMP types - TCP_TYPE - Comer/Steven, vol II, p128}
   ICT_ECHORP = 0;
   ICT_DESTUR = 3;
   ICT_SRCQ = 4;
   ICT_REDIRECT = 5;
   ICT_ECHORQ = 8;
   ICT_TIMEX = 11;
   ICT_PARAMP = 12;
   ICT_TIMERQ = 13;
   ICT_TIMERP = 14;
   ICT_INFORQ = 15;
   ICT_INFORP = 16;
   ICT_MASKRQ = 17;
   ICT_MASKRP = 18;
   ictmax = 19;

   ICC_NETUR = 0;			{p128, Internetworking with TCP/IP Vol 2.}
   ICC_HOSTUR = 1;			{      Design Implementation, and Internals}
   ICC_PROTOUR = 2;			{      Douglas E. Comer / David L. Stevens}
   ICC_PORTUR = 3;
   ICC_FNADF = 4;
   ICC_SRCRT = 5;
   ICC_NETRD = 0;
   ICC_HOSTRD = 1;
   IC_TOSNRD = 2;
   IC_TOSHRD = 3;
   ICC_TIMEX = 0;
   ICC_FTIMEX = 1;
   IC_HLEN = 8;
   IC_PADLEN = 3;
   IC_RDTTL = 300;

					{UDP standard port numbers}
   UP_ECHO = 7;				{echo server}
   UP_DISCARD = 9;			{discard packet}
   UP_USERS = 11;			{users server}
   UP_DAYTIME = 13;			{day and time server}
   UP_QOTD = 17;			{quote of the day server}
   UP_CHARGEN = 19;			{character generator}
   UP_TIME = 37;			{time server}
   UP_WHOIS = 43;			{who is server (user information)}
   UP_DNAME = 53;			{domain name server}
   UP_TFTP = 69;			{trivial file transfer protocol server}
   UP_RWHO = 513;			{remote who server (ruptime)}
   UP_RIP = 520;			{route information exchange (RIP)}

   ip_verlen = 0;			{IP header}
   ip_tos = 1;
   ip_len = 2;
   ip_id = 4;
   ip_fragoff = 6;
   ip_ttl = 8;
   ip_proto = 9;			{protocol*}
   ip_cksum = 10;
   ip_src = 12;
   ip_dst = 16;
   ip_data = 20;

					{ICMP header}
   ic_type = 0;				{ICT_*}
   ic_code = 1;				{ICC_*}
   ic_cksum = 2;
   ic_data = 4;
   ic_echo_id = 4;			{Echo Offsets}
   ic_echo_seq = 6;

					{UDP header}
   u_source = 0;			{source UDP port number - UP_*}
   u_dst = 2;				{destination UDP port number}
   u_len = 4;				{length of UDP data}
   u_cksum = 6;				{UDP checksum (0 = none)}
   u_data = 8;

					{TCP header}
   tcp_sport = 0;			{source port - TCP_*}
   tcp_dport = 2;			{destination port}
   tcp_seq = 4;				{sequence number}
   tcp_ack = 8;				{acknowledgement number}
   tcp_offset = 12;			{longword count in header (def=6)}
   tcp_code = 13;			{flags}
   tcp_window = 14;			{window advertisement}
   tcp_cksum = 16;			{checksum}
   tcp_urgptr = 18;			{urgent pointer}
   tcp_options = 20;
   tcp_data = 20;

type
   errTable = record
      tcpDGMSTBLEN: longint;            {The total length of the error table, in bytes, including tcpDGMSTBLEN}

      tcpDGMSTOTAL: longint;            {Total datagrams received (good and bad)}
      tcpDGMSFRAGSIN: longint;          {Got a fragment (datagram is queued to frag list)}
      tcpDGMSFRAGSLOST: longint;        {Fragment purged after timeout in queue}
      tcpDGMSBUILT: longint;            {Built a datagram from fragments (is then queued)}

      tcpDGMSOK: longint;               {Datagrams queued from link or tcpDGMSBUILT}

      tcpDGMSBADCHK: longint;           {Bad IP checksum (datagram is purged)}
      tcpDGMSBADHEADLEN: longint;       {Bad IP header lengths (datagram is purged)}
      tcpDGMSBADPROTO: longint;         {Unsupported protocols (added to misc queue)}
      tcpDGMSBADIP: longint;            {Not my or loopback IP (datagram is purged)}

      tcpDGMSICMP: longint;             {ICMP total datagrams in (good and bad)}
      tcpDGMSICMPUSER: longint;         {ICMP user datagrams}
      tcpDGMSICMPKERNEL: longint;       {ICMP kernel datagrams}

      tcpDGMSICMPBAD: longint;          {ICMP bad checksum or datagram too short}
      tcpDGMSICMPBADTYPE: longint;      {ICMP bad ic_type}
      tcpDGMSICMPBADCODE: longint;      {ICMP bad ic_code}
      tcpDGMSICMPECHORQ: longint;       {ICMP ECHORQs in}
      tcpDGMSICMPECHORQOUT: longint;    {ICMP ECHORQ replies sent out}
      tcpDGMSICMPECHORP: longint;       {ICMP ECHORPs in}
      tcpDGMSICMPECHORPBADID: longint;  {ICMP ECHORPs unclaimed}

      tcpDGMSUDP: longint;              {UDPs OK (added to UDP queue)}
      tcpDGMSUDPBAD: longint;           {Bad UDP header (datagram is purged)}
      tcpDGMSUDPNOPORT: longint;        {No such logged in port (datagram is purged)}

      tcpDGMSTCP: longint;              {TCPs OK (returned to TCP main logic)}
      tcpDGMSTCPBAD: longint;           {Bad TCP header or checksum (datagram is purged)}
      tcpDGMSTCPNOPORT: longint;        {No such logged in port (datagram is purged)}
      tcpDGMSTCPQUEUED: longint;        {Arrived before required (datagram is queued)}
      tcpDGMSTCPOLD: longint;           {Already received this segment (datagram is purged)}

      tcpDGMSOFRAGMENTS: longint;       {Fragments transmitted}
      tcpDGMSFRAGMENTED: longint;       {Datagrams fragmented for transmission}
      end;
   errTablePtr = ^errTable;

   tuneRecord = record                  {tuning table}
      tcpTUNECOUNT: integer;            {The total length of the tuning table,
                                         in bytes, including tcpTUNECOUNT.
                                         Currently 10.}
      tcpTUNEIPUSERPOLLCT: integer;     {The number of datagrams Marinetti will
                                         build per TCPIPPoll request. The valid
                                         range is 1 through 10 inclusive. The
                                         default is 2.}
      tcpTUNEIPRUNQFREQ: integer;       {The RunQ frequency value (60ths of a
                                         second). The default is 30 (half a
                                         second).}
      tcpTUNEIPRUNQCT: integer;         {The number of datagrams Marinetti will
                                         build per RunQ dispatch. The valid
                                         range is 1 through 10 inclusive. The
                                         default is 2.}
      tcpTUNETCPUSERPOLL: integer;      {The TCP steps to perform per user, per
                                         TCPIPPoll request and RunQ dispatch.
                                         The valid range is 1 through 10
                                         inclusive. The default is 2.}
      end;
   tunePtr = ^tuneRecord;

   unBuff = string[50];
   unBuffPtr = ^unBuff;

   pwBuff = string[50];
   pwBuffPtr = ^pwBuff;

   hnBuff = string[30];
   hnBuffPtr = ^hnBuff;

   pString15 = string[15];
   pString15Ptr = ^pString15;

   module = record
      liMethodID: integer;              {The connect method. See the conXXX
                                         equates at the end of this document}
      liName: string[20];               {Pstring name of the module}
      liVersion: longint;               {rVersion (type $8029 resource layout)
                                         of the module}
      liFlags: integer;                 {Contains the following flags:
                                            bit 15 This link layer uses the
                                               built in Apple IIGS serial ports
                                            bits 14-0 Reserved - set to zeros}
      liFilename: string[15];           {Pstring filename of the module}
      liMenuItem: array[0..13] of byte; {bytes rMenuItem template ready for use,
                                         which defines this connect method as a
                                         menu item}
      end;
   moduleList = array[0..99] of module;
   moduleListPtr = ^moduleList;

   linkInfoBlk = record
      liMethodID: integer;     {The connect method. New modules will need to apply to the author for a unique ID to use. See conXXX equates for details of already defined values}
      liName: string[20];      {Pstring name of the module}
      liVersion: longint;      {rVersion (type $8029 resource layout) of the
                                    module}
      liFlags: integer;        {Contains the following flags:
                                  bit15 This link layer uses the built in Apple
                                      IIGS serial ports
                                  bits14-1 Reserved - set to zeros
                                  bit0 Indicates whether the module contains an
                                      rIcon resource}
      end;
   linkInfoBlkPtr = ^linkInfoBlk;

   DNSRec = record
      DNSMain: longint;        {Main DNS IP address}
      DNSAux: longint;         {Auxilliary DNS IP address}
      end;
   DNSRecPtr = ^DNSRec;

   dnrBuffer = record
      DNRstatus: integer;      {Current status of DNR for this request}
      DNRIPaddress: longint;   {Returned IP address}
      end;
   dnrBufferPtr = ^dnrBuffer;

   udpVars = record
      uvQueueSize: integer;    {Number of entries in receive queue}
      uvError: integer;        {Last ICMP type 3 error code}
      uvErrorTick: longint;    {Tick of when error occurred}
      uvCount: longint;        {Total received for this ipid}
      uvTotalCount: longint;   {Total received for all ipids}
      uvDispatchFlag: integer; {UDP dispatch flag}
      end;
   udpVarsPtr = ^udpVars;

   rrBuff = record
      rrBuffCount: longint;    {Length of the returned data}
      rrBuffHandle: handle;    {Handle to the data}
      rrMoreFlag: boolean;     {Is there more data received?}
      rrPushFlag: boolean;     {word Was this buffer pushed?}
      rrUrgentFlag: boolean;   {Is this urgent data?}
      end;
   rrBuffPtr = ^rrBuff;

   rlrBuff = record
      rlrBuffCount: longint;   {Length of the returned data}
      rlrBuffHandle: handle;   {Handle to the data}
      rlrIsDataFlag: boolean;  {Was a line actually read?}
      rlrMoreFlag: boolean;    {Is there more data received?}
      rlrBuffSize: longint;    {Required buffer size}
      end;
   rlrBuffPtr = ^rlrBuff;

   srBuff = record
      srState: integer;        {TCP state}
      srNetworkError: integer; {ICMP error code}
      srSndQueued: longint;    {Bytes left in send queue}
      srRcvQueued: longint;    {Bytes left in receive queue}
      srDestIP: longint;       {Destination IP address}
      srDestPort: integer;     {Destination port}
      srConnectType: integer;  {Connection type}
      srAcceptCount: integer;  {If in listen mode, number of pending incoming
                                requests}
      end;
   srBuffPtr = ^srBuff;

   destRec = record
      drUserID: integer;       {UserID used by this ipid}
      drDestIP: longint;       {Destination IP address}
      drDestPort: integer;     {Destination port number}
      end;
   destRecPtr = ^destRec;

   cvtRec = record
      cvtIPAddress: longint;   {Returned IP address}
      cvtPort: integer;        {word Port number or nil if none}
      end;
   cvtRecPtr = ^cvtRec;

   IPCDataInRecord = record
      inwLength: integer;      {Length of buffer, including this, is $000E}
      inwIP: longint;          {Your IP address}
      inwMethod: integer;      {The connect method currently being used}
      inwMTU: integer;         {The MTU currently being used}
      inwLVPtr: longint;       {longword Pointer to link layer variables currently being used}
      end;
   IPCDataInPtr = ^IPCDataInRecord;

   variablesRecord = record
      lvVersion: integer;
      lvConnected: integer;
      lvIPaddress: longint;
      lvRefCon: longint;
      lvErrors: longint;
      lvMTU: integer;          {Maximum Transmission Unit size}
                               {... this is the Maximum Receive Unit (MRU) from the host.}
      end;
   variablesPtr = ^variablesRecord;
 
   dnrTimeoutsRecord = record
      dnrRETRIES: integer;          {How many times to try the DNR servers. The default is 5}
      dnrTIMER: integer;          {Number of ticks before timeout. The default is 120=2 secs}
      end;
   dnrTimeoutsBuffPtr = ^dnrTimeoutsRecord;

   displayPtr = procPtr;

   conHandle = handle;
   disconHandle = handle;
   messagePtr = ptr;
   udpPtr = ptr;
   datagramPtr = ptr;
   dgmHandle = handle;
   dataPtr = ptr;
   triggerProcPtr = ptr;
   authMsgHandle = handle;


procedure TCPIPBootInit; tool ($36, $01);
procedure TCPIPStartUp; tool ($36, $02);
procedure TCPIPShutDown; tool ($36, $03);
function  TCPIPVersion: integer; tool ($36, $04);
procedure TCPIPReset; tool ($36, $05);
function  TCPIPStatus: boolean; tool ($36, $06);
function  TCPIPLongVersion: longint; tool ($36, $08);
function  TCPIPGetConnectStatus: boolean; tool ($36, $09);
function  TCPIPGetErrorTable: errTablePtr; tool ($36, $0A);
function  TCPIPGetReconnectStatus: boolean; tool ($36, $0B);
procedure TCPIPReconnect (dPtr: displayPtr); tool ($36, $0C);
function  TCPIPGetMyIPAddress: longint; tool ($36, $0F);
function  TCPIPGetConnectMethod: integer; tool ($36, $10);
procedure TCPIPSetConnectMethod (method: integer); tool ($36, $11);
procedure TCPIPConnect (dPtr: displayPtr); tool ($36, $12);
procedure TCPIPDisconnect (forceFlag: boolean; dPtr: displayPtr);
                tool ($36, $13);
function  TCPIPGetMTU: integer; tool ($36, $14);
function  TCPIPGetConnectData (userid: integer; method: integer): conHandle;
                tool ($36, $16);
procedure TCPIPSetConnectData (method: integer; cHand: conHandle);
                tool ($36, $17);
function  TCPIPGetDisconnectData (userid: integer; method: integer): disconHandle;
                tool ($36, $18);
procedure TCPIPSetDisconnectData (userid: integer; dHand: disconHandle);
                tool ($36, $19);
procedure TCPIPLoadPreferences; tool ($36, $1A);
procedure TCPIPSavePreferences; tool ($36, $1B);
procedure TCPIPGetTuningTable (tPtr: tunePtr); tool ($36, $1E);
procedure TCPIPSetTuningTable (tPtr: tunePtr); tool ($36, $1F);
function  TCPIPGetConnectMsgFlag: boolean; tool ($36, $42);
procedure TCPIPSetConnectMsgFlag (flag: boolean); tool ($36, $43);
procedure TCPIPGetUsername (uPtr: unBuffPtr); tool ($36, $44);
procedure TCPIPSetUsername (username: pstring); tool ($36, $45);
procedure TCPIPGetPassword (pPtr: pwBuffPtr); tool ($36, $46);
procedure TCPIPSetPassword (password: pstring); tool ($36, $47);
function  TCPIPGetLinkVariables: variablesPtr; tool ($36, $4A);
procedure TCPIPEditLinkConfig (connectHand: handle; disconnectHand: handle);
                tool ($36, $4B);
function  TCPIPGetModuleNames: moduleListPtr; tool ($36, $4C);
procedure TCPIPGetHostName (hPtr: hnBuffPtr); tool ($36, $51);
procedure TCPIPSetHostName (hostname: pstring); tool ($36, $52);
procedure TCPIPGetLinkLayer (libPtr: linkInfoBlkPtr); tool ($36, $54);
function  TCPIPGetAuthMessage (userID: integer): authMsgHandle; tool ($36, $57);
function  TCPIPGetAliveFlag: boolean; tool ($36, $5A);
procedure TCPIPSetAliveFlag (alive: boolean); tool ($36, $5B);
function  TCPIPGetAliveMinutes: integer; tool ($36, $5C);
procedure TCPIPSetAliveMinutes (aliveMinutes: integer); tool ($36, $5D);
function  TCPIPGetBootConnectFlag: boolean; tool ($36, $5F);
procedure TCPIPSetBootConnectFlag (bootConnect: boolean); tool ($36, $60);
procedure TCPIPGetDNS (DNS: DNSRecPtr); tool ($36, $1C);
procedure TCPIPSetDNS (DNS: DNSRecPtr); tool ($36, $1D);
procedure TCPIPCancelDNR (dnr: dnrBufferPtr); tool ($36, $20);
procedure TCPIPDNRNameToIP (name: pstring; dnr: dnrBufferPtr); tool ($36, $21);
procedure TCPIPPoll; tool ($36, $22);
procedure TCPIPSendIPDatagram (dPtr: datagramPtr); tool ($36, $40);
function  TCPIPLogin (userID: integer; destip: longint; destport: integer;
                defaultTOS: integer; defaultTTL: integer): integer;
                tool ($36, $23);
procedure TCPIPLogout (ipid: integer); tool ($36, $24);
procedure TCPIPSendICMP (ipid: integer; mPtr: messagePtr; messageLen: integer);
                tool ($36, $25);
procedure TCPIPSendUDP (ipid: integer; uPtr: udpPtr; udpLen: integer);
                tool ($36, $26);
function  TCPIPGetDatagramCount (ipid: integer; protocol: integer): integer;
                tool ($36, $27);
function  TCPIPGetNextDatagram (ipid, protocol, flags: integer): dgmHandle;
                tool ($36, $28);
function  TCPIPGetLoginCount: integer; tool ($36, $29);
procedure TCPIPSendICMPEcho (ipid, seqNum: integer); tool ($36, $2A);
function  TCPIPReceiveICMPEcho (ipid: integer): integer; tool ($36, $2B);
procedure TCPIPSTatusUDP (ipid: integer; uPtr: udpVarsPtr); tool ($36, $43);
procedure TCPIPSetUDPDispatch (ipid: integer; dispatchFlag: boolean);
                tool ($36, $61);
function  TCPIPOpenTCP (ipid: integer): integer; tool ($36, $2C);
function  TCPIPListenTCP (ipid: integer): integer; tool ($36, $4E);
function  TCPIPWriteTCP (ipid: integer; dPtr: dataPtr; dataLength: longint;
                pushFlag, urgentFlag: boolean): integer; tool ($36, $2D);
function  TCPIPReadTCP (ipid, buffType: integer; data: univ longint;
                buffLen: longint; bPtr: rrBuffPtr): integer; tool ($36, $2E);
function  TCPIPReadLineTCP (ipid: integer; delimitStrPtr: pStringPtr; buffType: integer;
                data: univ longint; buffLen: longint; bPtr: rlrBuffPtr): integer;
                tool ($36, $5E);
function  TCPIPCloseTCP (ipid: integer): integer; tool ($36, $2F);
function  TCPIPAbortTCP (ipid: integer): integer; tool ($36, $30);
function  TCPIPStatusTCP (ipid: integer; sPtr: srBuffPtr): integer;
                tool ($36, $31);
function  TCPIPAcceptTCP (ipid, reserved: integer): integer; tool ($36, $4F);
function  TCPIPGetSourcePort (ipid: integer): integer; tool ($36, $32);
function  TCPIPGetTOS (ipid: integer): integer; tool ($36, $33);
procedure TCPIPSetTOS (ipid, TOS: integer); tool ($36, $34);
function  TCPIPGetTTL (ipid: integer): integer; tool ($36, $35);
procedure TCPIPSetTTL (ipid, TTL: integer); tool ($36, $36);
procedure TCPIPSetSourcePort (ipid, sourcePort: integer); tool ($36, $37);
function  TCPIPGetUserStatistic (ipid, statisticNum: integer): longint;
                tool ($36, $49);
procedure TCPIPSetNewDestination (ipid: integer; destip: longint;
                destPort: integer); tool ($36, $50);
procedure TCPIPGetDestination (ipid: integer; dPtr: destRecPtr); tool ($36, $62);

procedure TCPIPConvertIPToHex (cvt: cvtRecPtr; sPtr: pStringPtr); tool ($36, $0D);
procedure TCPIPConvertIPCToHex (cvt: cvtRecPtr; sPtr: pStringPtr); tool ($36, $3F);
function  TCPIPConvertIPToASCII (ipaddress: longint; ddpstring: pString15Ptr;
                flags: integer): integer; tool ($36, $0E);
function  TCPIPConvertIPToCASCII (ipaddress: longint; ddpstring: pString15Ptr;
                flags: integer): integer; tool ($36, $58);
function  TCPIPConvertIPToClass (ipaddress: longint): integer; tool ($36, $41);
function  TCPIPMangleDomainName (flags: integer; dnPstringPtr: pStringPtr):
                integer; tool ($36, $59);
procedure TCPIPPtrToPtr (fromPtr, toPtr: ptr; length: longint); tool ($36, $55);
procedure TCPIPPtrToPtrNeg (fromEndPtr, toEndPtr: ptr; length: longint);
                tool ($36, $56);
function  TCPIPValidateIPString (sPtr: pStringPtr): boolean; tool ($36, $48);
function  TCPIPValidateIPCString (sPtr: cStringPtr): boolean; tool ($36, $15);
function  TCPIPGetUserEventTrigger (triggerNumber, ipid: integer): triggerProcPtr;
                tool ($36, $63);
procedure TCPIPSetUserEventTrigger (triggerNumber, ipid: integer; tPtr: triggerProcPtr);
                tool ($36, $64);
function  TCPIPGetSysEventTrigger (ipid: integer): integer; tool ($36, $65);
procedure TCPIPSetSysEventTrigger (triggerNumber: integer;  tPtr: triggerProcPtr);
                tool ($36, $66);
procedure TCPIPGetDNRTimeouts (dtPtr: dnrTimeoutsBuffPtr); tool ($36, $67);
procedure TCPIPSetDNRTimeouts (dtPtr: dnrTimeoutsBuffPtr); tool ($36, $68);

implementation

end.
