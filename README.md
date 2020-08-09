### xAPITester  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)
#### API Explorer for the FlexRadio (TM) 6000 series software defined radios.  
##### Built on:
*  macOS 10.15.6
*  Xcode 12.0 beta 4 (12A8179i)
*  Swift 5.3
*  xLib6000 1.3.8
*  SwiftyUserDefaults 5.0.0
*  XCGLogger 7.0.1 

##### Runs on:  
* macOS 10.13 and higher

##### Builds
Compiled [RELEASE builds](https://github.com/K3TZR/xAPITester/releases) will be created at relatively stable points, please use them.  If you require a DEBUG build you will have to build from sources.  
##### Comments / Questions
Please send any bugs / comments / questions to support@k3tzr.net  
##### Credits
[xLib6000](https://github.com/K3TZR/xLib6000.git)
[SwiftyUserDefaults](https://github.com/sunshinejr/SwiftyUserDefaults.git)
[XCGLogger](https://github.com/DaveWoodCom/XCGLogger.git)  
##### Other software
[![xSDR6000](https://img.shields.io/badge/K3TZR-xSDR6000-informational)]( https://github.com/K3TZR/xSDR6000) A SmartSDR-like client for the Mac.  
[![DL3LSM](https://img.shields.io/badge/DL3LSM-xDAX,_xCAT,_xKey-informational)](https://dl3lsm.blogspot.com) Mac versions of DAX and/or CAT and a Remote CW Keyer.  
[![W6OP](https://img.shields.io/badge/W6OP-xVoiceKeyer,_xCW-informational)](https://w6op.com) A Mac-based Voice Keyer and a CW Keyer.  

---
##### 1.1.11 Release Notes
* README.md format changed
* incorporate latest xLib6000 (v1.3.8)  

##### 1.1.10 Release Notes
* uses xLIb6000 v1.3.5
* updates to RadioManager & RadioPickerViewController to match those in xSDR6000  

##### 1.1.9 Release Notes
* Added "Default Radio NOT found" alert
* Corrected non-GUI implementation
* Corrected delegate type in RadioPicker
* Reorganized / renamed Action methods in ViewController  

##### 1.1.8 Release Notes
* Radio menu added to allow SmartLink Enable/Disable
* refactored to match xSDR6000 v1.2.3 structure
* Uses xLib6000 1.3.2
* Uses SwiftyUserDefaults 5.0.0
