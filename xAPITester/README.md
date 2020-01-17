# xAPITester

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

## API Explorer for the FlexRadio (TM) 6000 series software defined radios.
##      (currently supports Radios with Version 2.4.9 or lower, see Evolution below)

### Built on:

*  macOS 10.14.6 (Deployment Target of macOS 10.11)
*  Xcode 11.3.1 (11C504)
*  Swift 5.1.3


## Usage

**NOTE: This app is a "work in progress" and is not fully functional**  

Portions of this app do not work and changes may be added from time to time which will break all or part of this app.  

## Builds

Compiled RELEASE builds will be created at relatively stable points, please use them.  

If you require a DEBUG build you will have to build from sources. 


## Comments / Questions

Please send any bugs / comments / questions to douglas.adams@me.com


## Evolution

Please see ChangeLog.txt for a running list of changes.

This version currently supports Radios using the Flex v2 API. A Future version of this library will support all Radio versions.

Flex Radios can have one of four different version groups:
*  v1.x.x, the v1 API
*  v2.0.x thru v2.4.9, the v2 API <<-- CURRENTLY SUPPORTED
*  v2.5.1 to less than v3.0.0, the v3 API without MultiFlex <<-- COMING
*  v3.x.x, the v3 API with MultiFlex <<-- COMING




## Credits

SwiftyUserDefaults Package:

* https://github.com/sunshinejr/SwiftyUserDefaults.git

XCGLogger Package:

* https://github.com/DaveWoodCom/XCGLogger.git

xLib6000 Package:

* https://github.com/K3TZR/xLib6000.git

OpusOSX, framework built from sources at:

* https://opus-codec.org/downloads/


For an example of a SmartSDR-like client for the Mac, please click the following:

[![xSDR6000](https://img.shields.io/badge/K3TZR-xSDR6000-informational)]( https://github.com/K3TZR/xSDR6000)


If you require a Mac version of DAX and/or CAT, please click the following:

[![DL3LSM](https://img.shields.io/badge/DL3LSM-xDAX,_xCAT-informational)](https://dl3lsm.blogspot.com)

If you require a Mac-based Voice Keyer , please see.
(works with xSDR6000 on macOS or SmartSDR on Windows)

[![W6OP](https://img.shields.io/badge/W6OP-Voice_Keyer-informational)](https://w6op.com)
