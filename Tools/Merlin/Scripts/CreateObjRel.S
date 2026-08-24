*
* CreateObjRel.S - Merlin16+ Link File
*
* Read the HowToRelease document for more info on how to use this script
*
* Utility for Marinetti Open Source Project
*
* Copies intermediary build files from MOSP directory structure to
* packaging directory in preparation for building.
*
* When using the MOSP CVS Repository directory structure as your work area
* you can execute it with the command "link 'tools/merlin/scripts/CreateObjRel".
* To enter a command in Merlin, enter the editor and press Open-Apple-O.
*
* Author: andrew.roughan@writeme.com
*
* 2002-10-08 AJR Initial Release
* 2003-07-18 AJR Remove I.DISPATCH.L, I.IPC.L, I.INIT.L because source is available
* 2005-04-14 AJR Remove I.TCP.L, I.IP.L because source is available
* 2005-07-11 AJR Remove Init link files because source is available
*

doDir KBD "Create directory structure? 0=No, 1=Yes"

 do doDir
 CMD CREATE :RAM5:Mosp
 CMD CREATE :RAM5:Mosp:build
 CMD CREATE :RAM5:Mosp:PPP
 fin

 CMD COPYFORK Marinetti:LinkLayers:PPP:DVR.8530.L :RAM5:Mosp:PPP:DVR.8530.L -d -l
