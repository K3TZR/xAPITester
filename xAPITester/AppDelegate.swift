//
//  AppDelegate.swift
//  xAPITester
//
//  Created by Douglas Adams on 12/10/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa
import XCGLogger
import xLib6000

// ------------------------------------------------------------------------------
// MARK: - App Delegate Class implementation
// ------------------------------------------------------------------------------

@NSApplicationMain
final class AppDelegate                     : NSObject, NSApplicationDelegate {
    
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    
    // close the app if the window is closed
    return true
  }
}

