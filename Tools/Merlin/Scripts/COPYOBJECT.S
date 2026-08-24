*
* CopyObject.S - Merlin16+ Link File
*
* Read the PrepareDevEnv document for more info on how to use this script
*
* Utility for Marinetti Open Source Project
*
* Copies intermediary build files from extraction directory to
* MOSP directory structure in preparation for building.
*
* When using the MOSP CVS Repository directory structure as your work area
* you can execute it with the command "link 'tools/merlin/scripts/copyobject".
* To enter a command in Merlin, enter the editor and press Open-Apple-O.
*
* Author: andrew.roughan@writeme.com
*
* 2002-03-13 AJR Support for Mosp30d5.BXY, PPP.BXY
* 2003-04-21 AJR Support for DC & SLIP Link Layers
* 2003-07-18 AJR Remove I.DISPATCH.L, I.IPC.L, I.INIT.L because source is available
* 2005-04-14 AJR Remove I.TCP.L, I.IP.L because source is available
* 2007-07-11 AJR Remove Init link files because source is available
*

 CMD COPYFORK :RAM5:Mosp:PPP:DVR.8530.L :RAM5:Mosp:Marinetti:LinkLayers:PPP:DVR.8530.L -d -l
 CMD COPYFORK :RAM5:Mosp:PPP:DVR.8530.L :RAM5:Mosp:Marinetti:LinkLayers:PPPX:DVR.8530.L -d -l
 CMD COPYFORK :RAM5:Mosp:PPP:DVR.8530.L :RAM5:Mosp:Marinetti:LinkLayers:DC:DVR.8530.L -d -l
 CMD COPYFORK :RAM5:Mosp:PPP:DVR.8530.L :RAM5:Mosp:Marinetti:LinkLayers:SLIP:DVR.8530.L -d -l
