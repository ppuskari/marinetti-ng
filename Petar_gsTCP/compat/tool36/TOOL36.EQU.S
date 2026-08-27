*=================================================
* Marinetti-compatible selectors used by the first Petar_gsTCP adapter
* SPDX-License-Identifier: LGPL-2.1-or-later
*=================================================

PGTToolNumber       equ   $36
PGTStartUp          equ   $0236
PGTShutDown         equ   $0336
PGTStatus           equ   $0636
PGTConnectStatus    equ   $0936
PGTConvertIPToHex   equ   $0D36
PGTCancelDNR        equ   $2036
PGTDNRNameToIP      equ   $2136
PGTPollSelector     equ   $2236
PGTLogin            equ   $2336
PGTLogout           equ   $2436
PGTOpenTCP          equ   $2C36
PGTReadTCP          equ   $2E36
PGTCloseTCP         equ   $2F36
PGTAbortTCP         equ   $3036
PGTStatusTCP        equ   $3136
PGTValidateIP       equ   $4836

* Tool `$36` TCP ipids are one-based indexes into the native fixed connection
* table.  No compatibility object owns packet data or another receive queue.

PGT36ConnTable      equ   $70             ; 24-bit native table pointer
