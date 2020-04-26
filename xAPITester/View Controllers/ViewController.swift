//
//  ViewController.swift
//  xAPITester
//
//  Created by Douglas Adams on 12/10/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults


// ------------------------------------------------------------------------------
// MARK: - ViewController Class implementation
// ------------------------------------------------------------------------------

public final class ViewController: NSViewController, RadioPickerDelegate,  NSTextFieldDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _api    = Api.sharedInstance
  private let _log    = Logger.sharedInstance
  private var _radios : [DiscoveryPacket] { Discovery.sharedInstance.discoveredRadios }

  @IBOutlet weak internal var _command          : NSTextField!
  @IBOutlet weak internal var _connectButton    : NSButton!
  @IBOutlet weak internal var _sendButton       : NSButton!
  @IBOutlet weak internal var _filterBy         : NSPopUpButton!
  @IBOutlet weak internal var _filterObjectsBy  : NSPopUpButton!
  @IBOutlet weak internal var _localRemote      : NSTextField!
  @IBOutlet weak internal var _stationsPopUp    : NSPopUpButton!
  @IBOutlet weak internal var _guiState         : NSTextField!
  @IBOutlet weak internal var _bindingPopUp     : NSPopUpButton!
  @IBOutlet weak internal var _apiType          : NSTextField!
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  internal var _startTimestamp                : Date?

  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private var _previousCommand                = ""                          // last command issued
  private var _commandsIndex                  = 0
  private var _commandsArray                  = [String]()                  // commands history
  private var _radioPickerViewController      : NSViewController?
  private var _splitViewVC                    : SplitViewController?
  private var _appFolderUrl                   : URL!
  private var _macros                         : Macros!
  private var _versions                       : (api: String, app: String)?
  private var _clientId                       : String?
  
  // constants
  private let _dateFormatter                  = DateFormatter()
  private let kAutosaveName                   = NSWindow.FrameAutosaveName("xAPITesterWindow")
  private let kConnectId                      = NSUserInterfaceItemIdentifier( "Connect")
  private let kDisconnectId                   = NSUserInterfaceItemIdentifier( "Disconnect")
  private let kLocal                          = "Local"
  private let kRemote                         = "SmartLink"
  private let kLocalTab                       = 0
  private let kRemoteTab                      = 1
  private let kVersionKey                     = "CFBundleShortVersionString"  // CF constants
  private let kBuildKey                       = "CFBundleVersion"
  private let kDelayForAvailableRadios        : UInt32 = 1
  private let kSizeOfTimeStamp                = 9
  private let kSBI_RadioPicker                = "RadioPicker"
  private let kCommandsRepliesFileName        = "xAPITester"
  private let kCommandsRepliesFileExt         = "txt"
  private let kMacroFileName                  = "macro_1"
  private let kMacroFileExt                   = "macro"
  private let kDefaultsFile                   = "Defaults.plist"
  private let kSWI_SplitView                  = "SplitView"

  private let kClose                          = "Close "
  private let kDisconnect                     = "Disconnect "
  private let kCancel                         = "Cancel"
  private let kInactive                       = "---"
  private let kRemoteControl                  = "Remote Control"
  private let kMultiflexConnect               = "Multiflex Connect"
  private let kMultipleConnections            = "Radio is connected to multiple Stations"
  private let kSingleConnection               = "Radio is connected to one Station"

  private let kAvailable                      = "available"
  private let kInUse                          = "in_use"
  

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods

  public func NSLocalizedString(_ key: String) -> String {
    return Foundation.NSLocalizedString(key, comment: "")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    let _ = Discovery.sharedInstance

    // give the Api access to our logger
    Log.sharedInstance.delegate = Logger.sharedInstance
    
    // get my version
    Logger.sharedInstance.version = Version()

    addNotifications()
    
    // get/create a Client Id
    _clientId = clientId()
    
    _filterBy.selectItem(withTag: Defaults[.filterByTag])
    _filterObjectsBy.selectItem(withTag: Defaults[.filterObjectsByTag])

    _dateFormatter.timeZone = NSTimeZone.local
    _dateFormatter.dateFormat = "mm:ss.SSS"
    
    _command.delegate = self
    
    _sendButton.isEnabled = false
    
    // setup & register Defaults
    defaults(from: kDefaultsFile)
    
    // set the window title
    title()
    
    _stationsPopUp.selectItem(withTitle: "All")
    _bindingPopUp.selectItem(withTitle: "None")
  }
  override public func viewWillAppear() {
    
    super.viewWillAppear()
    // position it
    view.window!.setFrameUsingName(kAutosaveName)
  }
  
  override public func viewWillDisappear() {
    
    super.viewWillDisappear()
    // save its position
    view.window!.saveFrame(usingName: kAutosaveName)
  }

  public override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    
    if segue.identifier! == kSWI_SplitView {
      _splitViewVC = segue.destinationController as? SplitViewController
      _splitViewVC!._parent = self
      
      _splitViewVC?.view.translatesAutoresizingMaskIntoConstraints = false
      _api.testerDelegate = _splitViewVC
      
      _macros = Macros()
    }
  }
  
  
  
  func closeRadioPicker() {
    Swift.print("Close RadioPicker")
    
    _radioPickerViewController?.dismiss(self)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Clear button (in the Commands & Replies box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func clear(_ sender: NSButton) {
    
    // clear all previous commands & replies
    _splitViewVC?.messages.removeAll()
    _splitViewVC?.reloadTable()
    
    // clear all previous objects
    _splitViewVC?.objects.removeAll()
    _splitViewVC?.reloadObjectsTable()
  }
  /// Respond to the Connect button
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func connect(_ sender: NSButton) {
    
    // Connect or Disconnect?
    switch sender.identifier {
      
    case kConnectId:
      
      // open the Default Radio (if any), otherwise open the Picker
      // is the default Radio available?
      if let defaultRadioDiscoveryPacket = defaultRadioFound() {
        // YES, open the default radio
        openRadio(defaultRadioDiscoveryPacket)
        
      } else {
        // NO, open the Radio Picker
        openRadioPicker(self)
      }

    case kDisconnectId:
      
      if let discoveryPacket = _api.radio?.discoveryPacket {
      // close the active Radio
        closeRadio(discoveryPacket)
      } else {
        disconnectApiTester()
      }
      
    default:    // should never happen
      break
    }
  }
  /// The Connect as Gui checkbox changed
  ///
  /// - Parameter sender:     the checkbox
  ///
  @IBAction func connectAsGui(_ sender: NSButton) {
    
    Defaults[.isGui] = sender.boolState
  }
  /// Respond to the Copy button (in the Commands & Replies box)
  ///
  /// - Parameter sender:     any Object
  ///
  @IBAction func copyToClipboard(_ sender: Any){
    
    // if no rows selected, select all
    if _splitViewVC!._tableView.numberOfSelectedRows == 0 { _splitViewVC!._tableView.selectAll(self) }
    
    let pasteBoard = NSPasteboard.general
    pasteBoard.clearContents()
    pasteBoard.setString( copyRows(_splitViewVC!._tableView, from: _splitViewVC!._filteredMessages), forType: NSPasteboard.PasteboardType.string )
  }
  /// Respond to the Copy to Cmd button (in the Commands & Replies box)
  ///
  /// - Parameter sender:     any object
  ///
  @IBAction func copyToCmd(_ sender: Any) {
    
    // paste the text into the command line
    _command.stringValue = copyRows(_splitViewVC!._tableView, from: _splitViewVC!._filteredMessages, stopOnFirst: true)
  }
  /// Respond to the Copy Handle button
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func copyHandle(_ sender: Any) {
    var textToCopy = ""
    
    // get the indexes of the selected rows
    let indexSet = _splitViewVC!._tableView.selectedRowIndexes
    
    for (_, rowIndex) in indexSet.enumerated() {
      
      let rowText = _splitViewVC!._filteredMessages[rowIndex]
      
      // remove the prefixes (Timestamps & Connection Handle)
      textToCopy = String(rowText.components(separatedBy: "|")[0].dropFirst(kSizeOfTimeStamp + 1))
      
      // stop after the first line
      break
    }
    // paste the text into the filter
    Defaults[.filter] = textToCopy
  }
  /// Respond to the Load button (in the Commands & Replies box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func load(_ sender: NSButton) {
    
    let openPanel = NSOpenPanel()
    openPanel.allowedFileTypes = [kCommandsRepliesFileExt]
    openPanel.directoryURL = _appFolderUrl

    // open an Open Dialog
    openPanel.beginSheetModal(for: self.view.window!) { [unowned self] (result: NSApplication.ModalResponse) in
      var fileString = ""
      
      // if the user selects Open
      if result == NSApplication.ModalResponse.OK {
        let url = openPanel.url!
        
        do {
          
          // try to read the file url
          try fileString = String(contentsOf: url)
          
          // separate into lines
          self._splitViewVC?.messages = fileString.components(separatedBy: "\n")
          
          // eliminate the last one (it's blank)
          self._splitViewVC?.messages.removeLast()
          
          // force a redraw
          self._splitViewVC?.reloadTable()
          
        } catch {
          
          // something bad happened!
          self._splitViewVC?.msg("Error reading file")
        }
      }
    }
  }
  /// Respond to the Load button (in the Macros box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func loadMacro(_ sender: NSButton) {
    
    let openPanel = NSOpenPanel()
    openPanel.allowedFileTypes = [kMacroFileExt]
    openPanel.nameFieldStringValue = kMacroFileName
    openPanel.directoryURL = _appFolderUrl
    
    // open an Open Dialog
    openPanel.beginSheetModal(for: self.view.window!) { [unowned self] (result: NSApplication.ModalResponse) in
      var fileString = ""
      
      // if the user selects Open
      if result == NSApplication.ModalResponse.OK {
        let url = openPanel.url!
        
        do {
          
          // try to read the file url
          try fileString = String(contentsOf: url)
          
          // separate into lines
          self._commandsArray = fileString.components(separatedBy: "\n")
          
          // eliminate the last one (it's blank)
          self._commandsArray.removeLast()
          
          // show the first command (if any)
          if self._commandsArray.count > 0 { self._command.stringValue = self._commandsArray[0] }
          
        } catch {
          
          // something bad happened!
          self._splitViewVC?.msg("Error reading file")
        }
      }
    }
  }
  /// Open the Radio Picker sheet
  ///
  /// - Parameter sender:     the sender
  ///
  @IBAction func openRadioPicker(_ sender: AnyObject) {
    
    // get an instance of the RadioPicker
    _radioPickerViewController = storyboard!.instantiateController(withIdentifier: "RadioPicker") as? NSViewController
    
    // make this View Controller the delegate of the RadioPicker
    _radioPickerViewController!.representedObject = self

    DispatchQueue.main.async {
      
      // show the RadioPicker sheet
      self.presentAsSheet(self._radioPickerViewController!)
    }
  }
  /// Respond to the Run button (in the Macros box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func runMacro(_ sender: NSButton) {

    _macros.runMacro("", window: view.window!, appFolderUrl: _appFolderUrl)
  }
  /// Respond to the Save button (in the Commands & Replies box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func save(_ sender: NSButton) {
    
    let savePanel = NSSavePanel()
    savePanel.allowedFileTypes = [kCommandsRepliesFileExt]
    savePanel.nameFieldStringValue = kCommandsRepliesFileName
    savePanel.directoryURL = _appFolderUrl
    
    // open a Save Dialog
    savePanel.beginSheetModal(for: self.view.window!) { [unowned self] (result: NSApplication.ModalResponse) in
      
      // if the user pressed Save
      if result == NSApplication.ModalResponse.OK {
        
        // write it to the File
        if let error = savePanel.url!.writeArray( self._splitViewVC!._filteredMessages ) {
         self._log.logMessage("\(error)", .error, #function, #file, #line)
        }
      }
    }
  }
  /// Respond to the Save button (in the Macros box)
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func saveMacro(_ sender: NSButton) {

    let savePanel = NSSavePanel()
    savePanel.allowedFileTypes = [kMacroFileExt]
    savePanel.nameFieldStringValue = kMacroFileName
    savePanel.directoryURL = _appFolderUrl
    
    // open a Save Dialog
    savePanel.beginSheetModal(for: self.view.window!) { [unowned self] (result: NSApplication.ModalResponse) in
      
      // if the user pressed Save
      if result == NSApplication.ModalResponse.OK {
        
        // write it to the File
        if let error = savePanel.url!.writeArray( self._commandsArray ) {
          self._log.logMessage("\(error)", .error, #function, #file, #line)
        }
      }
    }

  }
  /// Respond to the Send button
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func send(_ sender: NSButton) {
    
    // get the command
    let cmd = _command.stringValue
    
    // if the field isn't blank
    if cmd != "" {
      
      if cmd.first! == Macros.kMacroPrefix {
        
        // the command is a macro file name
        _macros.runMacro(String(cmd.dropFirst()), window: view.window!, appFolderUrl: _appFolderUrl, choose: false)

      } else if cmd.first! == Macros.kConditionPrefix {
      
        // parse the condition
        let evaluatedCommand = _macros.parse(cmd)
        
        // was the condition satisfied?
        if evaluatedCommand.active {
          
          // YES, send the command
          let _ = _api.radio!.sendCommand( _macros.evaluateValues(command: evaluatedCommand.cmd) )
        
        } else {
          
          // NO, log it
          _log.logMessage("Condition false: \(evaluatedCommand.condition)", .error, #function, #file, #line)
        }
      
      } else {
        
        // send the command via TCP
        let _ = _api.radio!.sendCommand( _macros.evaluateValues(command: cmd) )
        
        if cmd != _previousCommand { _commandsArray.append(cmd) }
        
        _previousCommand = cmd
        _commandsIndex = _commandsArray.count - 1
        
        // optionally clear the Command field
        if Defaults[.clearOnSend] { _command.stringValue = "" }
      }
    }
  }
  /// Respond to the Show Timestamps checkbox
  ///
  /// - Parameter sender:   the button
  ///
  @IBAction func showTimestamps(_ sender: NSButton) {
    
    // force a redraw
    _splitViewVC?.reloadTable()
    _splitViewVC?.reloadObjectsTable()
  }
  /// Respond to the Close menu item
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func terminate(_ sender: AnyObject) {
    
    // disconnect the active radio
    _api.disconnect()
    
    _sendButton.isEnabled = false
    _connectButton.title = kConnectId.rawValue
    _localRemote.stringValue = ""
    
    NSApp.terminate(self)
  }
  /// The Filter text field changed (in the Commands & Replies box)
  ///
  /// - Parameter sender:     the text field
  ///
  @IBAction func updateFilter(_ sender: NSTextField) {
    
    // force a redraw
    _splitViewVC?.reloadTable()
  }
  /// The ShowHandles PopUp changed
  ///
  /// - Parameter sender:     the popup
  ///
  @IBAction func updateShowStations(_ sender: NSPopUpButton) {
    
    if sender.titleOfSelectedItem == "All" {
      _splitViewVC!.selectedStation = nil
    } else {
      _splitViewVC!.selectedStation = sender.titleOfSelectedItem
    }
    // force a redraw
    _splitViewVC?.reloadTable()
  }
  @IBAction func updateBinding(_ sender: NSPopUpButton) {
    
    func findClientId(for station: String) -> String? {
      for (_, guiClient) in _api.radio!.discoveryPacket.guiClients where guiClient.station == station {
        return guiClient.clientId
      }
      return nil
    }
    // if a valid handle, bind to it
    if sender.titleOfSelectedItem == "None" {
      _api.radio?.boundClientId = ""

    } else {
      if let clientId = findClientId(for: sender.titleOfSelectedItem!) {
        _api.radio?.boundClientId = clientId
      }
    }
  }
  /// The FilterBy PopUp changed (in the Commands & Replies box)
  ///
  /// - Parameter sender:     the popup
  ///
  @IBAction func updateFilterBy(_ sender: NSPopUpButton) {
    
    // clear the Filter string field
    Defaults[.filter] = ""
    
    // force a redraw
    _splitViewVC?.reloadTable()
  }
  /// The Filter text field changed (in the Objects box)
  ///
  /// - Parameter sender:     the text field
  ///
  @IBAction func updateFilterObjects(_ sender: NSTextField) {
    
    // force a redraw
    _splitViewVC?.reloadObjectsTable()
  }
  /// The FilterBy PopUp changed (in the Objects box)
  ///
  /// - Parameter sender:     the popup
  ///
  @IBAction func updateFilterObjectsBy(_ sender: NSPopUpButton) {
    
    // clear the Filter string field
    Defaults[.filterObjects] = ""
    
    // force a redraw
    _splitViewVC?.reloadObjectsTable()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Enable / Disable various UI elements
  ///
  private func updateButtonStates() {
        
    DispatchQueue.main.async { [unowned self] in
      if let radio = self._api.radio {
        
        self._localRemote.stringValue = radio.discoveryPacket.isWan ? "SmartLink" : "Local"
        self._guiState.stringValue = Defaults[.isGui] ? "Gui" : "Non-Gui"
        self._apiType.stringValue = radio.version.isOldApi ? "Old API" : "New API"

        self._connectButton.title = self.kDisconnectId.rawValue
        self._connectButton.identifier = self.kDisconnectId
        self._sendButton.isEnabled = true

        self._stationsPopUp.isEnabled = radio.version.isNewApi
        self._bindingPopUp.isEnabled = radio.version.isNewApi && !Defaults[.isGui]

      } else {
        self._localRemote.stringValue = ""
        self._guiState.stringValue = ""
        self._apiType.stringValue = ""

        self._connectButton.title = self.kConnectId.rawValue
        self._connectButton.identifier = self.kConnectId
        self._sendButton.isEnabled = false

        self._stationsPopUp.isEnabled = false
        self._stationsPopUp.selectItem(withTitle: "All")
        self._bindingPopUp.isEnabled = false
        self._bindingPopUp.selectItem(withTitle: "None")
      }
    }
  }
  /// Check if there is a Default Radio
  ///
  /// - Returns:        a DiscoveryStruct struct or nil
  ///
  private func defaultRadioFound() -> DiscoveryPacket? {
    
    // see if there is a valid default Radio
    guard Defaults[.defaultRadioSerialNumber] != "" else { return nil }
    
    // allow time to hear the UDP broadcasts
    usleep(2_000_000)
    
    // has the default Radio been found?
    if let discoveryPacket = Discovery.sharedInstance.discoveredRadios.first(where: { $0.serialNumber == Defaults[.defaultRadioSerialNumber]} ) {
      
      _log.logMessage("Default radio found, \(discoveryPacket.nickname) @ \(discoveryPacket.publicIp), serial \(discoveryPacket.serialNumber)", .info, #function, #file, #line)
      
      return discoveryPacket
    }
    return nil
  }
  /// Produce a Client Id (UUID)
  ///
  /// - Returns:                a UUID
  ///
  private func clientId() -> String {

    if Defaults[.clientId] == nil {
      // none stored, create a new UUID
      Defaults[.clientId] = UUID().uuidString
    }
    return Defaults[.clientId]!
  }
  /// Copy selected rows from the array backing a table
  ///
  /// - Parameters:
  ///   - table:                        an NStableView instance
  ///   - array:                        the backing array
  ///   - stopOnFirst:                  stop after first row?
  /// - Returns:                        a String of the rows
  ///
  private func copyRows(_ table: NSTableView, from array: Array<String>, stopOnFirst: Bool = false) -> String {
    var text = ""
    
    // get the selected rows
    for (_, rowIndex) in table.selectedRowIndexes.enumerated() {
      
      text = array[rowIndex]
      
      // remove the prefixes (Timestamps & Connection Handle)
      text = text.components(separatedBy: "|")[1]
      
      // stop after the first line?
      if stopOnFirst { break }
      
      // accumulate the text lines
      text += text + "\n"
    }
    return text
  }
  /// Set the Window's title
  ///
  private func title() {

    // set the title bar
    DispatchQueue.main.async { [unowned self] in
      var title = ""
      // are we connected?
      if let radio = self._api.radio {
        // YES, format and set the window title
        title = "\(radio.discoveryPacket.nickname) v\(radio.version.longString)         \(Logger.kAppName) v\(Logger.sharedInstance.version.string)"

      } else {
        // NO, show App & Api only
        title = "\(Logger.kAppName) v\(Logger.sharedInstance.version.string)"
      }
      self.view.window?.title = title
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(radioDowngrade(_:)), of: .radioDowngrade)
    NC.makeObserver(self, with: #selector(clientDidDisconnect(_:)), of: .clientDidDisconnect)
    NC.makeObserver(self, with: #selector(guiClientHasBeenRemoved(_:)), of: .guiClientHasBeenRemoved)
    NC.makeObserver(self, with: #selector(guiClientHasBeenUpdated(_:)), of: .guiClientHasBeenUpdated)
  }
  /// Process .radioDowngrade Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioDowngrade(_ note: Notification) {
    
    let versions = note.object as! [Version]
    
    // the API & Radio versions are not compatible
    // alert if other than normal
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "The Radio's version may not be supported by this version of \(Logger.kAppName)."
      alert.informativeText = """
      Radio:\t\tv\(versions[1].longString)
      xLib6000:\tv\(versions[0].string)
      
      You can use SmartSDR to DOWNGRADE the Radio
      \t\t\tOR
      Install a newer version of \(Logger.kAppName)
      """
      alert.addButton(withTitle: "Close")
      alert.addButton(withTitle: "Continue")
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
          NSApp.terminate(self)
        }
      })
    }
  }
  /// Process .clientDidDisconnect Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func clientDidDisconnect(_ note: Notification) {
    DispatchQueue.main.async { [unowned self] in
      if self._connectButton.identifier == self.kDisconnectId { self._connectButton.performClick(self) }
    }
  }
  /// Process .guiclientHasBeenRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func guiClientHasBeenRemoved(_ note: Notification) {
    
    if let guiClient = note.object as? GuiClient {
      
      DispatchQueue.main.async { [weak self] in

        if self?._stationsPopUp.itemTitles.contains(guiClient.station) == true {

          self?._stationsPopUp.removeItem(withTitle: guiClient.station)
          self?._bindingPopUp.removeItem(withTitle: guiClient.station)
        }
      }
    }
  }
  /// Process .guiclientHasBeenUpdated Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func guiClientHasBeenUpdated(_ note: Notification) {
    
    if let guiClient = note.object as? GuiClient {
      
      DispatchQueue.main.async { [weak self] in
        
        if self?._stationsPopUp.itemTitles.contains(guiClient.station) == false {
          self?._stationsPopUp.addItem(withTitle: guiClient.station)
          self?._bindingPopUp.addItem(withTitle: guiClient.station)
        }
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - RadioPickerDelegate methods
  
  var token: Token?

  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - radio:                the DiscoveryStruct
  ///   - pendingDisconnect:    type, if any
  ///
  func connectRadio(_ discoveredRadio: DiscoveryPacket?, pendingDisconnect: Api.PendingDisconnect = .none) {
    
    if let _ = _radioPickerViewController {
      self._radioPickerViewController = nil
    }
    
    // exit if no Radio selected
    guard let radio = discoveredRadio else { return }
    
    // clear the previous Commands, Replies & Messages
    if Defaults[.clearAtConnect] { _splitViewVC?.messages.removeAll() ;_splitViewVC?._tableView.reloadData() }
    
    // clear the objects
    _splitViewVC?.objects.removeAll()
    _splitViewVC?._objectsTableView.reloadData()
        
    // if not a GUI connection, allow the Tester to see all stream objects
    _api.testerModeEnabled = !Defaults[.isGui]
        
    // connect to the radio
    if _api.connect(radio,
                    clientStation: Logger.kAppName,
                    programName: Logger.kAppName,
                    clientId: Defaults[.isGui] ? _clientId : nil,
                    isGui: Defaults[.isGui],
                    isWan: radio.isWan,
                    wanHandle: radio.wanHandle,
                    pendingDisconnect: pendingDisconnect) {
      
      _startTimestamp = Date()
      
      updateButtonStates()
      title()
      
      // WAN connect
      if radio.isWan {
        _api.isWan = true
        _api.connectionHandleWan = radio.wanHandle
      } else {
        _api.isWan = false
        _api.connectionHandleWan = ""
      }
      
    } else {
      updateButtonStates()
    }
  }
  
  func openRadio(_ discoveryPacket: DiscoveryPacket) {
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi
    
    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)

    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, Defaults[.isGui], status, guiCount) {

    case (false, false, _, _):            // oldApi, Non-GUI
      connectRadio(discoveryPacket)

    case (false, true, kAvailable, _):    // oldApi, GUI, not connected to another client
      connectRadio(discoveryPacket)
      
    case (false, true, kInUse, _):        // oldApi, GUI, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to another Client"
      alert.informativeText = kClose + "the Client?"
      alert.addButton(withTitle: kClose + "current client")
      alert.addButton(withTitle: kCancel)

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed

        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
          self.connectRadio(discoveryPacket, pendingDisconnect: .oldApi)
          sleep(1)
          self._api.disconnect()
          sleep(1)

        default:  break
        }
        
      })

    case (true, false, _, _):             // newApi, Non-GUI
      connectRadio(discoveryPacket)

    case (true, true, kAvailable, 0):    // newApi, GUI, not connected to another client
      connectRadio(discoveryPacket)

    case (true, true, kAvailable, _):    // newApi, GUI, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to Station: \(clients[0].station)"
      alert.informativeText = kClose + "the Station . . Or . . Connect using Multiflex . . Or . . use " + kRemoteControl
      alert.addButton(withTitle: kClose + "\(clients[0].station)")
      alert.addButton(withTitle: kMultiflexConnect)
      alert.addButton(withTitle: kRemoteControl)
      alert.addButton(withTitle: kCancel)

      // FIXME: Remote Control implementation needed
      alert.buttons[2].isEnabled = false

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed

        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[0]))
        case NSApplication.ModalResponse.alertSecondButtonReturn: self.connectRadio(discoveryPacket)
        default:  break
        }
      })

    case (true, true, kInUse, 2):         // newApi, GUI, 2 clients
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = kMultipleConnections
        alert.informativeText = kClose + "one of the Stations . . Or . . use " + kRemoteControl
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
        alert.addButton(withTitle: kClose + "\(clients[1].station)")
        alert.addButton(withTitle: kRemoteControl)
        alert.addButton(withTitle: kCancel)

        // FIXME: Remote Control implementation needed
        alert.buttons[2].isEnabled = false

        // ignore if not confirmed by the user
        alert.beginSheetModal(for: view.window!, completionHandler: { (response) in

          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[0]))
          case NSApplication.ModalResponse.alertSecondButtonReturn: self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[1]))
          default:  break
          }
        })

    default:
      break
    }
  }
  /// Close  a currently active connection
  ///
  func closeRadio(_ discoveryPacket: DiscoveryPacket) {
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi

    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)

    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, Defaults[.isGui], status, guiCount) {
      
    case (false, _, _, _):                // oldApi, Non-Gui or Gui
      self.disconnectApiTester()
      
    case (true, true, kAvailable, 1):     // newApi, Gui, 1 client
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = kSingleConnection
      alert.informativeText = kClose + "the Station . . Or . . " + kDisconnect + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      alert.addButton(withTitle: kDisconnect + Logger.kAppName)
      alert.addButton(withTitle: kCancel)
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectApiTester()
        default:  break
        }
      })
      
    case (true, true, kInUse, 2):           // newApi, Gui, 2 clients

      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = kMultipleConnections
      alert.informativeText = kClose + "a Station . . Or . . " + kDisconnect + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      if clients[1].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[1].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      alert.addButton(withTitle: kDisconnect + Logger.kAppName)
      alert.addButton(withTitle: kCancel)
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
      alert.buttons[1].isEnabled = clients[1].station != Logger.kAppName

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.disconnectClient( packet: discoveryPacket, handle: handles[1])
        case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectApiTester()
        default:  break
        }
      })

      case (true, false, kAvailable, 1):      // newApi, Non-Gui, 1 clients
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = kSingleConnection
        alert.informativeText = kClose + "the Station . . Or . . Connect using Multiflex . . Or . . " + kDisconnect + Logger.kAppName
        if clients[0].station != Logger.kAppName {
          alert.addButton(withTitle: kClose + "\(clients[0].station)")
        } else {
          alert.addButton(withTitle: kInactive)
        }
        alert.addButton(withTitle: kDisconnect + Logger.kAppName)
        alert.addButton(withTitle: kCancel)
        
        alert.buttons[0].isEnabled = (clients[0].station != Logger.kAppName)

        // ignore if not confirmed by the user
        alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
          case NSApplication.ModalResponse.alertSecondButtonReturn:  self.disconnectApiTester()
          default:  break
          }
        })

    case (true, false, kInUse, 2):          // newApi, Non-Gui, 2 clients
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = kMultipleConnections
      alert.informativeText = kClose + "a Station . . Or . . " + kDisconnect + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      if clients[1].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[1].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      alert.addButton(withTitle: kDisconnect + Logger.kAppName)
      alert.addButton(withTitle: kCancel)
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
      alert.buttons[1].isEnabled = clients[1].station != Logger.kAppName

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.disconnectClient( packet: discoveryPacket, handle: handles[1])
        case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectApiTester()
        default:  break
        }
      })
    default:
        self.disconnectApiTester()
    }
  }
  
  /// Close this app
  ///
  private func disconnectApiTester() {
    // disconnect the active radio
    _api.disconnect()
    
    updateButtonStates()
    title()
    
    // clear the previous Commands, Replies & Messages
    if Defaults[.clearAtDisconnect] {
      _splitViewVC?.messages.removeAll()
      _splitViewVC?._tableView.reloadData()

      _splitViewVC?.objects.removeAll()
      _splitViewVC?._objectsTableView.reloadData()
    }
  }
  /// Close the application
  ///
  func terminateApp() {
    
    terminate(self)
  }

  // ----------------------------------------------------------------------------
  // MARK: - NSTextFieldDelegate methods
  
  /// Allow the user to press Enter to send a command
  ///
  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    
    // nested functions -----------
    
    func previousIndex() -> Int? {
      var index: Int?
      
      guard _commandsArray.count != 0 else { return index }
      
      if _commandsIndex == 0 {
        // at top of the list (oldest command)
        index = 0
        _commandsIndex = 0
      } else {
        // somewhere in list
        index = _commandsIndex
        _commandsIndex = index! - 1
      }
      return index
    }
    
    func nextIndex() -> Int? {
      var index: Int?
      
      guard _commandsArray.count != 0 else { return index }
      
      if _commandsIndex == _commandsArray.count - 1 {
        // at bottom of list (newest command)
        index =  -1
      } else {
        // somewhere else
        index = _commandsIndex + 1
      }
      _commandsIndex = index != -1 ? index! : _commandsArray.count - 1
      return index
    }

    // ----------------------------

    if (commandSelector == #selector(NSResponder.insertNewline(_:))) {
      // "click" the send button
      _sendButton.performClick(self)
      
      return true
    } else if (commandSelector == #selector(NSResponder.moveUp(_:))) {
      
      if let previousIndex = previousIndex() {
        // show the previous command
        _command.stringValue = _commandsArray[previousIndex]
      }
      return true
      
    } else if (commandSelector == #selector(NSResponder.moveDown(_:))) {
      
      if let index = nextIndex() {
        
        if index == -1 {
          _command.stringValue = ""
        } else {
          // show the next command
          _command.stringValue = _commandsArray[index]
        }
      
      }
      return true
    }
    // return true if the action was handled; otherwise false
    return false
  }
}


