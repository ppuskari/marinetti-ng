unit TCPIPX;
interface

{********************************************************
*
*  Marinetti TCP/IP internal interfaces for Complete Pascal
*
*  Other USES Files Needed: Types
*
*  Orca/Pascal UNIT Modified for Complete Pascal
*  By Mike Stephens
*  
*  This file is released to the public domain.
*
*********************************************************
* Note: this file documents interfaces described in the
* Marinetti Debugging Guide.
*********************************************************
* 2008-01-12 MAS Original release
*********************************************************}

uses
   Types;

const
   trgCount = 1;
   strgCount = 1;

type

   userRecord = record
       uwUserID: integer;
       uwDestIP: longint;
       uwDestPort: integer;
       uwIP_TOS: integer;
       uwIP_TTL: integer;

       uwSourcePort: integer;
       uwLogoutPending: integer;
       uwICMPQueue: longint;
       uwTCPQueue: longint;

       uwTCPMaxSendSeg: integer;
       uwTCPMaxReceiveSeg: integer;
       uwTCPDataInQ: longint;
       uwTCPDataIn: longint;
       uwTCPPushInFlag: integer;
       uwTCPPushInOffset: longint;
       uwTCPPushOutFlag: integer;
       uwTCPPushOutSEQ: longint;
       uwTCPDataOut: longint;
       uwSND_UNA: longint;
       uwSND_NXT: longint;
       uwSND_WND: integer;
       uwSND_UP: integer;
       uwSND_WL1: longint;
       uwSND_WL2: longint;
       uwISS: longint;
       uwRCV_NXT: longint;
       uwRCV_WND: integer;
       uwRCV_UP: integer;
       uwIRS: longint;
       uwTCP_State: integer;
       uwTCP_StateTick: longint;
       uwTCP_ErrCode: integer;
       uwTCP_ICMPError: integer;
       uwTCP_Server: integer;
       uwTCP_ChildList: longint;
       uwTCP_ACKPending: integer;
       uwTCP_ForceFIN: integer;
       uwTCP_FINSEQ: longint;
       uwTCP_MyFINACKed: integer;
       uwTCP_Timer: longint;
       uwTCP_TimerState: integer;
       uwTCP_rt_timer: integer;
       uwTCP_2MSL_timer: integer;
       uwTCP_SaveTTL: integer;
       uwTCP_SaveTOS: integer;
       uwTCP_TotalIN: longint;
       uwTCP_TotalOUT: longint;

       uwUDP_Server: integer;
       uwUDPQueue: longint;
       uwUDPError: integer;
       uwUDPErrorTick: longint;
       uwUDPCount: longint;

       uwTriggers: array [0..trgCount] of longint;
       uwSysTriggers: array [0..strgCount] of longint;
      end;
   userRecordPtr = ^userRecord;
   userRecordHandle = ^userRecordPtr;

procedure TCPIPSetMyIPAddress (ipaddress: longint); tool $36, $38;
function TCPIPGetDP: integer; tool $36, $39;
function TCPIPGetDebugHex: boolean; tool $36, $3A;
procedure TCPIPSetDebugHex (debugFlag: boolean); tool $36, $3B;
function TCPIPGetDebugTCP: boolean; tool $36, $3C;
procedure TCPIPSetDebugTCP (debugFlag: boolean); tool $36, $3D;
function  TCPIPGetUserRecord(ipid: integer): userRecordHandle; tool $36, $3E;
procedure TCPIPRebuildModuleList; tool $36, $4D;

implementation

end. 
