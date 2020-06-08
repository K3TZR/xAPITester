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

extension DefaultsKeys {
  
  var clearAtConnect           : DefaultsKey<Bool>            { .init("clearAtConnect", defaultValue: false) }
  var clearAtDisconnect        : DefaultsKey<Bool>            { .init("clearAtDisconnect", defaultValue: false) }
  var clearOnSend              : DefaultsKey<Bool>            { .init("clearOnSend", defaultValue: false) }
  var clientId                 : DefaultsKey<String?>         { .init("clientId") }
  var defaultRadio             : DefaultsKey<String?>         { .init("defaultRadio") }
  var enablePinging            : DefaultsKey<Bool>            { .init("enablePinging", defaultValue: false) }
  var filter                   : DefaultsKey<String>          { .init("filter", defaultValue: "") }
  var filterByTag              : DefaultsKey<Int>             { .init("filterByTag", defaultValue: 0) }
  var filterMeters             : DefaultsKey<String>          { .init("filterMeters", defaultValue: "") }
  var filterMetersByTag        : DefaultsKey<Int>             { .init("filterMetersByTag", defaultValue: 0) }
  var filterObjects            : DefaultsKey<String>          { .init("filterObjects", defaultValue: "") }
  var filterObjectsByTag       : DefaultsKey<Int>             { .init("filterObjectsByTag", defaultValue: 0) }
  var fontMaxSize              : DefaultsKey<Int>             { .init("fontMaxSize", defaultValue: 20) }
  var fontMinSize              : DefaultsKey<Int>             { .init("fontMinSize", defaultValue: 8) }
  var fontName                 : DefaultsKey<String>          { .init("fontName", defaultValue: "Monaco") }
  var fontSize                 : DefaultsKey<Int>             { .init("fontSize", defaultValue: 12) }
  var isGui                    : DefaultsKey<Bool>            { .init("isGui", defaultValue: false) }
  var lowBandwidthEnabled      : DefaultsKey<Bool>            { .init("lowBandwidthEnabled", defaultValue: false) }
  var showAllReplies           : DefaultsKey<Bool>            { .init("showAllReplies", defaultValue: false) }
  var showPings                : DefaultsKey<Bool>            { .init("showPings", defaultValue: false) }
  var showRemoteTabView        : DefaultsKey<Bool>            { .init("showRemoteTabView", defaultValue: false) }
  var showTimestamps           : DefaultsKey<Bool>            { .init("showTimestamps", defaultValue: false) }
  var smartLinkAuth0Email      : DefaultsKey<String?>         { .init("smartLinkAuth0Email") }
  var smartLinkEnabled         : DefaultsKey<Bool>            { .init("smartLinkEnabled", defaultValue: true) }
  var smartLinkToken           : DefaultsKey<String?>         { .init("smartLinkToken") }
  var smartLinkTokenExpiry     : DefaultsKey<Date?>           { .init("smartLinkTokenExpiry") }
  var smartLinkWasLoggedIn     : DefaultsKey<Bool>            { .init("smartLinkWasLoggedIn", defaultValue: false) }
  var suppressUdp              : DefaultsKey<Bool>            { .init("suppressUdp", defaultValue: false) }
  var useLowBw                 : DefaultsKey<Bool>            { .init("useLowBw", defaultValue: false) }
}

/// Struct to hold a Semantic Version number
///     with provision for a Build Number
///
public struct Version {
  var major     : Int = 1
  var minor     : Int = 0
  var patch     : Int = 0
  var build     : Int = 1

  public init(_ versionString: String = "1.0.0") {
    
    let components = versionString.components(separatedBy: ".")
    switch components.count {
    case 3:
      major = Int(components[0]) ?? 1
      minor = Int(components[1]) ?? 0
      patch = Int(components[2]) ?? 0
      build = 1
    case 4:
      major = Int(components[0]) ?? 1
      minor = Int(components[1]) ?? 0
      patch = Int(components[2]) ?? 0
      build = Int(components[3]) ?? 1
    default:
      major = 1
      minor = 0
      patch = 0
      build = 1
    }
  }
  
  public init() {
    // only useful for Apps & Frameworks (which have a Bundle), not Packages
    let versions = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    let build   = Bundle.main.infoDictionary![kCFBundleVersionKey as String] as! String
    self.init(versions + ".\(build)")
   }
  
  public var longString       : String  { "\(major).\(minor).\(patch) (\(build))" }
  public var string           : String  { "\(major).\(minor).\(patch)" }

  public var isV3             : Bool    { major >= 3 }
  public var isV2NewApi       : Bool    { major == 2 && minor >= 5 }
  public var isGreaterThanV22 : Bool    { major >= 2 && minor >= 2 }
  public var isV2             : Bool    { major == 2 && minor < 5 }
  public var isV1             : Bool    { major == 1 }
  
  public var isNewApi         : Bool    { isV3 || isV2NewApi }
  public var isOldApi         : Bool    { isV1 || isV2 }

  static func ==(lhs: Version, rhs: Version) -> Bool { lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch }
  
  static func <(lhs: Version, rhs: Version) -> Bool {
    
    switch (lhs, rhs) {
      
    case (let l, let r) where l == r: return false
    case (let l, let r) where l.major < r.major: return true
    case (let l, let r) where l.major == r.major && l.minor < r.minor: return true
    case (let l, let r) where l.major == r.major && l.minor == r.minor && l.patch < r.patch: return true
    default: return false
    }
  }
}

extension URL {
  
  /// setup the Support folders
  ///
  static var appSupport : URL { return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first! }
  static var logs : URL { return createAsNeeded("net.k3tzr.xSDR6000/Logs") }
  static var macros : URL { return createAsNeeded("net.k3tzr.xSDR6000/Macros") }
  
  static func createAsNeeded(_ folder: String) -> URL {
    let fileManager = FileManager.default
    let folderUrl = appSupport.appendingPathComponent( folder )
    
    // does the folder exist?
    if fileManager.fileExists( atPath: folderUrl.path ) == false {
      
      // NO, create it
      do {
        try fileManager.createDirectory( at: folderUrl, withIntermediateDirectories: true, attributes: nil)
      } catch let error as NSError {
        fatalError("Error creating App Support folder: \(error.localizedDescription)")
      }
    }
    return folderUrl
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

extension NSMenuItem {
  /// Boolean equivalent of an NSMenuItem state property
  ///
  var boolState : Bool {
    get { return self.state == NSControl.StateValue.on ? true : false }
    set { self.state = (newValue == true ? NSControl.StateValue.on : NSControl.StateValue.off) }
  }
}

extension NSMenuItem {
  
  func item(title: String) -> NSMenuItem? {
    self.submenu?.items.first(where: {$0.title == title})
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

extension String {
  
  /// Retrun a random collection of character as a String
  /// - Parameter length:     the desired number of characters
  /// - Returns:              a String of the requested length
  ///
   static func random(length:Int)->String{
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""

        while randomString.utf8.count < length{
            let randomLetter = letters.randomElement()
            randomString += randomLetter?.description ?? ""
        }
        return randomString
    }
}

extension String {
  
  /// Pad a string to a fixed length
  /// - Parameters:
  ///   - len:            the desired length
  ///   - padCharacter:   the character to pad with
  /// - Returns:          a padded string
  ///
  func padTo(_ len: Int, with padCharacter: String = " ") -> String {
    
    self.padding(toLength: len, withPad: padCharacter, startingAt: 0)
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

/// Return the version of the named Package
/// - Parameter packageName:    the name of a package
///
//func versionOf(_ packageName: String) -> String {
//
  /* Assumes a file with a structure like this
   {
     "object": {
       "pins": [
         {
           "package": "Nimble",
           "repositoryURL": "https://github.com/Quick/Nimble.git",
           "state": {
             "branch": null,
             "revision": "e9d769113660769a4d9dd3afb855562c0b7ae7b0",
             "version": "7.3.4"
           }
         },
         {
           "package": "Quick",
           "repositoryURL": "https://github.com/Quick/Quick.git",
           "state": {
             "branch": null,
             "revision": "f2b5a06440ea87eba1a167cab37bf6496646c52e",
             "version": "1.3.4"
           }
         },
         {
           "package": "SwiftyUserDefaults",
           "repositoryURL": "https://github.com/sunshinejr/SwiftyUserDefaults.git",
           "state": {
             "branch": null,
             "revision": "566ace16ee91242b61e2e9da6cdbe7dfdadd926c",
             "version": "4.0.0"
           }
         },
         {
           "package": "XCGLogger",
           "repositoryURL": "https://github.com/DaveWoodCom/XCGLogger.git",
           "state": {
             "branch": null,
             "revision": "a9c4667b247928a29bdd41be2ec2c8d304215a54",
             "version": "7.0.1"
           }
         },
         {
           "package": "xLib6000",
           "repositoryURL": "https://github.com/K3TZR/xLib6000.git",
           "state": {
             "branch": null,
             "revision": "43f637fbf0475574618d0aa105478d0a4c41df92",
             "version": "1.2.6"
           }
         }
       ]
     },
     "version": 1
   }

   */
  
//  struct State: Codable {
//    var branch    : String?
//    var revision  : String
//    var version   : String?
//  }
//
//  struct Pin: Codable {
//    var package       : String
//    var repositoryURL : String
//    var state         : State
//  }
//
//  struct Pins: Codable {
//    var pins  : [Pin]
//  }
//
//  struct Object: Codable {
//    var object    : Pins
//    var version   : Int
//  }
//
//  let decoder = JSONDecoder()
//
//  // get the Package.resolved file
//  if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved") {
//    // decode it
//    if let json = try? Data(contentsOf: url), let container = try? decoder.decode(Object.self, from: json) {
//      // find the desired entry
//      for pin in container.object.pins where pin.package == packageName {
//        // return either the version or the branch
//        return pin.state.version != nil ? "v" + pin.state.version! : pin.state.branch ?? "empty branch"
//      }
//      // packageName not present in Package.resolved, must be installed locally
//      return "local"
//    }
//  }
//  // Package.resolved file not found  OR  failed to decode
//  return "unknown"
//}


