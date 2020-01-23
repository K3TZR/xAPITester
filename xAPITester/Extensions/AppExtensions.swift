//
//  AppExtensions.swift
//  xAPITester
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

// ----------------------------------------------------------------------------
// MARK: - EXTENSIONS

typealias NC = NotificationCenter

// ----------------------------------------------------------------------------
// MARK: - Definitions for SwiftyUserDefaults

//extension UserDefaults {
//
//  subscript(key: DefaultsKey<NSColor>) -> NSColor {
//    get { return unarchive(key)! }
//    set { archive(key, newValue) }
//  }
//
//  public subscript(key: DefaultsKey<CGFloat>) -> CGFloat {
//    get { return CGFloat(numberForKey(key._key)?.doubleValue ?? 0.0) }
//    set { set(key, Double(newValue)) }
//  }
//}

// defaults keys (for values in defaults.plist)
extension DefaultsKeys {
  
  static var auth0Email               : DefaultsKey<String>   { return .init("auth0Email", defaultValue: "") }
  static var clearAtConnect           : DefaultsKey<Bool>     { return .init("clearAtConnect", defaultValue: false) }
  static var clearOnSend              : DefaultsKey<Bool>     { return .init("clearOnSend", defaultValue: false) }
  static var clientId                 : DefaultsKey<String?>  { return .init("clientId") }
  static var defaultRadioSerialNumber : DefaultsKey<String>   { return .init("defaultRadioSerialNumber", defaultValue: "") }
  static var enablePinging            : DefaultsKey<Bool>     { return .init("enablePinging", defaultValue: false) }
  static var filter                   : DefaultsKey<String>   { return .init("filter", defaultValue: "") }
  static var filterByTag              : DefaultsKey<Int>      { return .init("filterByTag", defaultValue: 0) }
  static var filterMeters             : DefaultsKey<String>   { return .init("filterMeters", defaultValue: "") }
  static var filterMetersByTag        : DefaultsKey<Int>      { return .init("filterMetersByTag", defaultValue: 0) }
  static var filterObjects            : DefaultsKey<String>   { return .init("filterObjects", defaultValue: "") }
  static var filterObjectsByTag       : DefaultsKey<Int>      { return .init("filterObjectsByTag", defaultValue: 0) }
  static var fontMaxSize              : DefaultsKey<Int>      { return .init("fontMaxSize", defaultValue: 20) }
  static var fontMinSize              : DefaultsKey<Int>      { return .init("fontMinSize", defaultValue: 8) }
  static var fontName                 : DefaultsKey<String>   { return .init("fontName", defaultValue: "Monaco") }
  static var fontSize                 : DefaultsKey<Int>      { return .init("fontSize", defaultValue: 12) }
  static var isGui                    : DefaultsKey<Bool>     { return .init("isGui", defaultValue: false) }
  static var lowBandwidthEnabled      : DefaultsKey<Bool>     { return .init("lowBandwidthEnabled", defaultValue: false) }
  static var showAllReplies           : DefaultsKey<Bool>     { return .init("showAllReplies", defaultValue: false) }
  static var showPings                : DefaultsKey<Bool>     { return .init("showPings", defaultValue: false) }
  static var showRemoteTabView        : DefaultsKey<Bool>     { return .init("showRemoteTabView", defaultValue: false) }
  static var showTimestamps           : DefaultsKey<Bool>     { return .init("showTimestamps", defaultValue: false) }
  static var smartLinkAuth0Email      : DefaultsKey<String>   { return .init("smartLinkAuth0Email", defaultValue: "") }
  static var smartLinkToken           : DefaultsKey<String?>  { return .init("smartLinkToken") }
  static var smartLinkTokenExpiry     : DefaultsKey<Date?>    { return .init("smartLinkTokenExpiry") }
  static var suppressUdp              : DefaultsKey<Bool>     { return .init("suppressUdp", defaultValue: false) }
  static var useLowBw                 : DefaultsKey<Bool>     { return .init("useLowBw", defaultValue: false) }
}

extension FileManager {
  
  /// Get / create the Application Support folder
  ///
  static var appFolder : URL {
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask )
    let appFolderUrl = urls.first!.appendingPathComponent( Bundle.main.bundleIdentifier! )
    
    // does the folder exist?
    if !fileManager.fileExists( atPath: appFolderUrl.path ) {
      
      // NO, create it
      do {
        try fileManager.createDirectory( at: appFolderUrl, withIntermediateDirectories: false, attributes: nil)
      } catch let error as NSError {
        fatalError("Error creating App Support folder: \(error.localizedDescription)")
      }
    }
    return appFolderUrl
  }
}

extension URL {
  
  /// Write an array of Strings to a URL
  ///
  /// - Parameters:
  ///   - textArray:                        an array of String
  ///   - addEndOfLine:                     whether to add an end of line to each String
  /// - Returns:                            an error message (if any)
  ///
  func writeArray(_ textArray: [String], addEndOfLine: Bool = true) -> String? {
    
    let eol = (addEndOfLine ? "\n" : "")
    
    // add a return to each line
    // build a string of all the lines
    let fileString = textArray
      .map { $0 + eol }
      .reduce("", +)
    
    do {
      // write the string to the url
      try fileString.write(to: self, atomically: true, encoding: String.Encoding.utf8)
      
    } catch let error as NSError {
      
      // an error occurred
      return "Error writing to file : \(error.localizedDescription)"
      
    } catch {
      
      // an error occurred
      return "Error writing Log"
    }
    return nil
  }
}

extension NSButton {
  /// Boolean equivalent of an NSButton state property
  ///
  var boolState : Bool {
    get { return self.state == NSControl.StateValue.on ? true : false }
    set { self.state = (newValue == true ? NSControl.StateValue.on : NSControl.StateValue.off) }
  }
}

public extension String {
  
  /// Check if a String is a valid IP4 address
  ///
  /// - Returns:          the result of the check as Bool
  ///
  func isValidIP4() -> Bool {
    
    // check for 4 values separated by period
    let parts = self.components(separatedBy: ".")
    
    // convert each value to an Int
    let nums = parts.compactMap { Int($0) }
    
    // must have 4 values containing 4 numbers & 0 <= number < 256
    return parts.count == 4 && nums.count == 4 && nums.filter { $0 >= 0 && $0 < 256}.count == 4
  }
}

// ----------------------------------------------------------------------------
// MARK: - TOP-LEVEL FUNCTIONS

/// Find versions for this app and the specified framework
///
func versionInfo(framework: String) -> (String, String) {
  let kVersionKey             = "CFBundleShortVersionString"  // CF constants
  let kBuildKey               = "CFBundleVersion"
  
  // get the version of the framework
  let frameworkBundle = Bundle(identifier: framework)!
  var version = frameworkBundle.object(forInfoDictionaryKey: kVersionKey)!
  var build = frameworkBundle.object(forInfoDictionaryKey: kBuildKey)!
  let frameworkVersion = "\(version).\(build)"
  
  // get the version of this app
  version = Bundle.main.object(forInfoDictionaryKey: kVersionKey)!
  build = Bundle.main.object(forInfoDictionaryKey: kBuildKey)!
  let appVersion = "\(version).\(build)"
  
  return (frameworkVersion, appVersion)
}

/// Setup & Register User Defaults from a file
///
/// - Parameter file:         a file name (w/wo extension)
///
func defaults(from file: String) {
  var fileURL : URL? = nil
  
  // get the name & extension
  let parts = file.split(separator: ".")
  
  // exit if invalid
  guard parts.count != 0 else {return }
  
  if parts.count >= 2 {
    
    // name & extension
    fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1]))
    
  } else if parts.count == 1 {
    
    // name only
    fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: "")
  }
  
  if let fileURL = fileURL {
    // load the contents
    let myDefaults = NSDictionary(contentsOf: fileURL)!
    
    // register the defaults
    UserDefaults.standard.register(defaults: myDefaults as! Dictionary<String, Any>)
  }
}

