/********************************************
*
* Marinetti TCP/IP internal headers for ORCA/C
*
* By Andrew Roughan
* This file is released to the public domain.
*
********************************************
* NB: this file documents interfaces described in the
* Marinetti Debugging Guide.
********************************************
* 2003-07-18 AJR Original version
* 2007-06-06 AJR Added userRecord details [1700658]
********************************************/

#ifndef __TYPES__
#include <TYPES.h>
#endif

#ifndef __TCPIPX__
#define __TCPIPX__

#define trgCount 1
#define strgCount 1

typedef struct
{
  Word uwUserID;
  LongWord uwDestIP;
  Word uwDestPort;
  Word uwIP_TOS;
  Word uwIP_TTL;

  Word uwSourcePort;
  Word uwLogoutPending;
  LongWord uwICMPQueue;
  LongWord uwTCPQueue;

  Word uwTCPMaxSendSeg;
  Word uwTCPMaxReceiveSeg;
  LongWord uwTCPDataInQ;
  LongWord uwTCPDataIn;
  Word uwTCPPushInFlag;
  LongWord uwTCPPushInOffset;
  Word uwTCPPushOutFlag;
  LongWord uwTCPPushOutSEQ;
  LongWord uwTCPDataOut;
  LongWord uwSND_UNA;
  LongWord uwSND_NXT;
  Word uwSND_WND;
  Word uwSND_UP;
  LongWord uwSND_WL1;
  LongWord uwSND_WL2;
  LongWord uwISS;
  LongWord uwRCV_NXT;
  Word uwRCV_WND;
  Word uwRCV_UP;
  LongWord uwIRS;
  Word uwTCP_State;
  LongWord uwTCP_StateTick;
  Word uwTCP_ErrCode;
  Word uwTCP_ICMPError;
  Word uwTCP_Server;
  LongWord uwTCP_ChildList;
  Word uwTCP_ACKPending;
  Word uwTCP_ForceFIN;
  LongWord uwTCP_FINSEQ;
  Word uwTCP_MyFINACKed;
  LongWord uwTCP_Timer;
  Word uwTCP_TimerState;
  Word uwTCP_rt_timer;
  Word uwTCP_2MSL_timer;
  Word uwTCP_SaveTTL;
  Word uwTCP_SaveTOS;
  LongWord uwTCP_TotalIN;
  LongWord uwTCP_TotalOUT;

  Word uwUDP_Server;
  LongWord uwUDPQueue;
  Word uwUDPError;
  LongWord uwUDPErrorTick;
  LongWord uwUDPCount;

  LongWord uwTriggers[trgCount];
  LongWord uwSysTriggers[strgCount];
} userRecord, *userRecordPtr, **userRecordHandle;

extern pascal void TCPIPSetMyIPAddress (Long) inline(0x3836,dispatcher);
extern pascal Integer TCPIPGetDP (void) inline(0x3936,dispatcher);
extern pascal Boolean TCPIPGetDebugHex (void) inline(0x3A36,dispatcher);
extern pascal void TCPIPSetDebugHex (Boolean) inline(0x3B36,dispatcher);
extern pascal Boolean TCPIPGetDebugTCP (void) inline(0x3C36,dispatcher);
extern pascal void TCPIPSetDebugTCP (Boolean) inline(0x3D36,dispatcher);
extern pascal userRecordHandle TCPIPGetUserRecord (Word) inline(0x3E36,dispatcher);
extern pascal void TCPIPRebuildModuleList (void) inline(0x4D36,dispatcher);

#endif
 