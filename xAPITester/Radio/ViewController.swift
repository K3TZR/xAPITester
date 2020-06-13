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

public final class ViewController: NSViewController, NSTextFieldDelegate, WanManagerDelegate, RadioPickerDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kSearchTime            = 2                 // seconds
  static let kSearchIncrements      : UInt32 = 500_000  // microseconds

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  var defaultPacket: DiscoveryPacket?

  @objc dynamic var smartLinkCall   : String?
  @objc dynamic var smartLinkImage  : NSImage?
  @objc dynamic var smartLinkUser   : String?
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _api    = Api.sharedInstance
  private let _log    = Logger.sharedInstance.logMessage

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

  private var _radioManager                 : RadioManager!

  private var _previousCommand                = ""                          // last command issued
  private var _commandsIndex                  = 0
  private var _commandsArray                  = [String]()                  // commands history
  private var _radioPickerStoryboard          : NSStoryboard?
  private var _radioPickerViewController      : RadioPickerViewController?
  private var _splitViewVC                    : SplitViewController?
  private var _appFolderUrl                   : URL!
  private var _macros                         : Macros!
  private var _versions                       : (api: String, app: String)?
  private var _clientId                       : String?
  private var _pleaseWait                     : NSAlert!

  // constants
  private let _dateFormatter                  = DateFormatter()
  private let kAutosaveName                   = NSWindow.FrameAutosaveName("xAPITesterWindow")
  private let kSizeOfTimeStamp                = 9
  private let kCommandsRepliesFileName        = "xAPITester"
  private let kCommandsRepliesFileExt         = "txt"
  private let kMacroFileName                  = "macro_1"
  private let kMacroFileExt                   = "macro"

  private let kAvailable                      = "available"
  private let kInUse                          = "in_use"
  

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods

  public func NSLocalizedString(_ key: String) -> String {
    return Foundation.NSLocalizedString(key, comment: "")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    // give the Api access to our logger
    Log.sharedInstance.delegate = Logger.sharedInstance
    
    _radioManager = RadioManager(delegate: self)

    // get my version
    Logger.sharedInstance.version = Version()

    // get/create a Client Id
    _clientId = clientId()
    
    _filterBy.selectItem(withTag: Defaults.filterByTag)
    _filterObjectsBy.selectItem(withTag: Defaults.filterObjectsByTag)

    _dateFormatter.timeZone = NSTimeZone.local
    _dateFormatter.dateFormat = "mm:ss.SSS"
    
    _command.delegate = self
    
    _sendButton.isEnabled = false
    
    // set the window title
    title()
    
    _stationsPopUp.selectItem(withTitle: "All")
    _bindingPopUp.selectItem(withTitle: "None")

    addNotifications()
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
    
    switch segue.identifier! {
    case "SplitView":
      _splitViewVC = segue.destinationController as? SplitViewController
      _splitViewVC!._parent = self
      
      _splitViewVC?.view.translatesAutoresizingMaskIntoConstraints = false
      _api.testerDelegate = _splitViewVC
      
      _macros = Macros()

    case "ShowRadioPicker":
      _radioPickerViewController = segue.destinationController as? RadioPickerViewController
      _radioPickerViewController!.delegate = self
    
    default:
      break
    }
  }
  
  func closeRadioPicker() {
    dismiss(_radioPickerViewController)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func clearButton(_ sender: NSButton) {
    
    // clear all previous commands & replies
    _splitViewVC?.messages.removeAll()
    _splitViewVC?.reloadTable()
    
    // clear all previous objects
    _splitViewVC?.objects.removeAll()
    _splitViewVC?.reloadObjectsTable()
  }

  @IBAction func connectAsGuiCheckbox(_ sender: NSButton) {
    
    Defaults.isGui = sender.boolState
  }

  @IBAction func connectButton(_ sender: NSButton) {
    
    // Connect or Disconnect?
    switch sender.title {
      
    case "Connect":
      // open the Default Radio (if any), otherwise open the Picker
      findDefault()
      
    case "Disconnect":
      if let packet = _api.radio?.packet {
      // close the active Radio
        closeRadio(packet)
      } else {
        disconnectApplication()
      }
      
    default:    // should never happen
      break
    }
  }

  @IBAction func copyHandleButton(_ sender: Any) {
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
    Defaults.filter = textToCopy
  }

  @IBAction func copyToClipboardButton(_ sender: Any){
    
    // if no rows selected, select all
    if _splitViewVC!._tableView.numberOfSelectedRows == 0 { _splitViewVC!._tableView.selectAll(self) }
    
    let pasteBoard = NSPasteboard.general
    pasteBoard.clearContents()
    pasteBoard.setString( copyRows(_splitViewVC!._tableView, from: _splitViewVC!._filteredMessages), forType: NSPasteboard.PasteboardType.string )
  }

  @IBAction func copyToCmdButton(_ sender: Any) {
    
    // paste the text into the command line
    _command.stringValue = copyRows(_splitViewVC!._tableView, from: _splitViewVC!._filteredMessages, stopOnFirst: true)
  }
  /// Open the Radio Picker as a sheet
  ///
  func openRadioPicker() {
    let radioPickerStoryboard = NSStoryboard(name: "RadioPicker", bundle: nil)
    _radioPickerViewController = radioPickerStoryboard.instantiateController(withIdentifier: "RadioPicker") as? RadioPickerViewController
    _radioPickerViewController!.delegate = self
    
    DispatchQueue.main.async { [unowned self] in
      // show the RadioPicker sheet
      self.presentAsSheet(self._radioPickerViewController!)
    }
  }

  @IBAction func runMacroButton(_ sender: NSButton) {

    _macros.runMacro("", window: view.window!, appFolderUrl: _appFolderUrl)
  }
  
  @IBAction func bindingPopUp(_ sender: NSPopUpButton) {
    
    // if a valid handle, bind to it
    if sender.titleOfSelectedItem == "None" {
      _api.radio?.boundClientId = ""

    } else {
      _api.radio?.boundClientId = sender.selectedItem?.toolTip
    }
  }

  @IBAction func filterByPopUp(_ sender: NSPopUpButton) {
    
    // clear the Filter string field
    Defaults.filter = ""
    
    // force a redraw
    _splitViewVC?.reloadTable()
  }

  @IBAction func filterObjectsPopUp(_ sender: NSTextField) {
    
    // force a redraw
    _splitViewVC?.reloadObjectsTable()
  }

  @IBAction func filterObjectsByPopUp(_ sender: NSPopUpButton) {
    
    // clear the Filter string field
    Defaults.filterObjects = ""
    
    // force a redraw
    _splitViewVC?.reloadObjectsTable()
  }

  @IBAction func loadButton(_ sender: NSButton) {
    
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

  @IBAction func loadMacroButton(_ sender: NSButton) {
    
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

  @IBAction func radioSelectionMenu(_ sender: NSMenuItem) {
    openRadioPicker()
  }

  @IBAction func saveButton(_ sender: NSButton) {
    
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
         self._log("\(error)", .error, #function, #file, #line)
        }
      }
    }
  }

  @IBAction func saveMacroButton(_ sender: NSButton) {

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
          self._log("\(error)", .error, #function, #file, #line)
        }
      }
    }

  }

  @IBAction func sendButton(_ sender: NSButton) {
    
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
          _log("Condition false: \(evaluatedCommand.condition)", .error, #function, #file, #line)
        }
      
      } else {
        
        // send the command via TCP
        let _ = _api.radio!.sendCommand( _macros.evaluateValues(command: cmd) )
        
        if cmd != _previousCommand { _commandsArray.append(cmd) }
        
        _previousCommand = cmd
        _commandsIndex = _commandsArray.count - 1
        
        // optionally clear the Command field
        if Defaults.clearOnSend { _command.stringValue = "" }
      }
    }
  }
  
  @IBAction func showStationsPopUp(_ sender: NSPopUpButton) {
    
    if sender.titleOfSelectedItem == "All" {
      _splitViewVC!.selectedStation = nil
    } else {
      _splitViewVC!.selectedStation = sender.titleOfSelectedItem
    }
    // force a redraw
    _splitViewVC?.reloadTable()
  }

  @IBAction func showTimestampsCheckbox(_ sender: NSButton) {
    
    // force a redraw
    _splitViewVC?.reloadTable()
    _splitViewVC?.reloadObjectsTable()
  }

  @IBAction func smartLinkMenu(_ sender: NSMenuItem) {
    
    sender.boolState.toggle()
    Defaults.smartLinkEnabled = sender.boolState
    if sender.boolState == false {
      _log("SmartLink: DISABLED", .debug, #function, #file, #line)
      _radioManager?.smartLinkLogout()
      closeRadioPicker()
    } else {
      _log("SmartLink: ENABLED", .debug, #function, #file, #line)
      _radioManager?.smartLinkLogin()
    }
  }

  @IBAction func terminate(_ sender: AnyObject) {
    
    // disconnect the active radio
    _api.disconnect()
    
    NSApp.terminate(self)
  }

  @IBAction func updateFilterTextField(_ sender: NSTextField) {
    
    // force a redraw
    _splitViewVC?.reloadTable()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods

  /// Find and Open the Default Radio (if any) else the Radio Picker
  ///
  private func findDefault() {
    
    if Defaults.defaultRadio == nil {
      openRadioPicker()
    
    } else {
      checkLoop(interval: 1, wait: 4, condition: checkForDefault, completionHandler: { defaultFound in
        if defaultFound {
          self.openSelectedRadio(Discovery.sharedInstance.defaultFound( Defaults.defaultRadio )!)
        } else {
          DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Default Radio NOT found"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
              self.openRadioPicker()
            })
          }
        }
      })
    }
  }
  /// Check if the default radio is in DiscoveredRadios
  /// - Returns: found / NOT found
  ///
  private func checkForDefault() -> Bool {
    return Discovery.sharedInstance.defaultFound( Defaults.defaultRadio ) != nil
  }
  /// Open the specified Radio
  /// - Parameter discoveryPacket: a DiscoveryPacket
  ///
  func openRadio(_ packet: DiscoveryPacket) {
    
    _log("OpenRadio initiated: \(packet.nickname)", .debug, #function, #file, #line)
    
    let status = packet.status.lowercased()
    let guiCount = packet.guiClients.count
    let isNewApi = Version(packet.firmwareVersion).isNewApi
    
    let handles = [Handle](packet.guiClients.keys)
    let clients = [GuiClient](packet.guiClients.values)
    
    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {
      
    case (false, kAvailable, _):          // oldApi, not connected to another client
      _ = _radioManager.connectRadio(packet, isGui: Defaults.isGui) ; updateButtonStates()
      
    case (false, kInUse, _):              // oldApi, connected to another client
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Radio is connected to another Client"
        alert.informativeText = "Close the Client"
        alert.addButton(withTitle: "Close current client")
        alert.addButton(withTitle: "Cancel")
        
        // ignore if not confirmed by the user
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          // close the connected Radio if the YES button pressed
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:
            _ = self._radioManager.connectRadio(packet, isGui: Defaults.isGui, pendingDisconnect: .oldApi) ; self.updateButtonStates()
            sleep(1)
            self._api.disconnect()
            sleep(1)
            self.openRadioPicker()

          default:  break
          }
          
        })}
      
    case (true, kAvailable, 0):           // newApi, not connected to another client
      _ = _radioManager.connectRadio(packet, isGui: Defaults.isGui) ; self.updateButtonStates()
      
    case (true, kAvailable, _):           // newApi, connected to another client
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Radio is connected to Station: \(clients[0].station)"
        alert.informativeText = "Close the Station . . Or . . Make an additional connection"
        alert.addButton(withTitle: "Close \(clients[0].station)")
        alert.addButton(withTitle: "Additional Connect")
        alert.addButton(withTitle: "Cancel")
        
        // ignore if not confirmed by the user
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          // close the connected Radio if the YES button pressed
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:
            _ = self._radioManager.connectRadio(packet, isGui: Defaults.isGui, pendingDisconnect: .newApi(handle: handles[0])) ; self.updateButtonStates()
          case NSApplication.ModalResponse.alertSecondButtonReturn:
            _ = self._radioManager.connectRadio(packet, isGui: Defaults.isGui )  ; self.updateButtonStates()
          default:  break
          }
        })}
      
    case (true, kInUse, 2):               // newApi, connected to 2 clients
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Radio is connected to multiple Stations"
        alert.informativeText = "Close one of the Stations . . Or . . use Remote Control"
        alert.addButton(withTitle: "Close \(clients[0].station)")
        alert.addButton(withTitle: "Close \(clients[1].station)")
        alert.addButton(withTitle: "Remote Control (Non-Gui)")
        alert.addButton(withTitle: "Cancel")
        
        alert.buttons[2].isEnabled = !Defaults.isGui
        
        // ignore if not confirmed by the user
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:
            _ =  self._radioManager.connectRadio(packet, isGui: Defaults.isGui, pendingDisconnect: .newApi(handle: handles[0]))  ; self.updateButtonStates()
          case NSApplication.ModalResponse.alertSecondButtonReturn:
            _ = self._radioManager.connectRadio(packet, isGui: Defaults.isGui, pendingDisconnect: .newApi(handle: handles[1]))  ; self.updateButtonStates()
          case NSApplication.ModalResponse.alertThirdButtonReturn:
            _ = self._radioManager.connectRadio(packet, isGui: false)  ; self.updateButtonStates()
          default:  break
          }
        })}
      
    default:
      break
    }
  }
  /// Close  a currently active connection
  ///
  func closeRadio(_ discoveryPacket: DiscoveryPacket) {
    
    _log("CloseRadio initiated: \(discoveryPacket.nickname)", .debug, #function, #file, #line)
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi
    
    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)
    
    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {
      
    case (false, _, _):                   // oldApi
      self.disconnectApplication()
      
    case (true, kAvailable, 1):           // newApi, 1 client
      // am I the client?
      if handles[0] == _api.connectionHandle {
        // YES, disconnect me
        self.disconnectApplication()
        
      } else {
        
        // FIXME: don't think can ever be executed
        
        // NO, let the user choose what to do
        DispatchQueue.main.async {
          let alert = NSAlert()
          alert.alertStyle = .informational
          alert.messageText = "Radio is connected to one Station"
          alert.informativeText = "Close the Station . . Or . . Disconnect " + Logger.kAppName
          alert.addButton(withTitle: "Close \(clients[0].station)")
          alert.addButton(withTitle: "Disconnect " + Logger.kAppName)
          alert.addButton(withTitle: "Cancel")
          
          alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
          
          // ignore if not confirmed by the user
          alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
            // close the connected Radio if the YES button pressed
            
            switch response {
            case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
            case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectApplication()
            default:  break
            }
          })}
      }
      
    case (true, kInUse, 2):           // newApi, 2 clients
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Radio is connected to multiple Stations"
        alert.informativeText = "Close a Station . . Or . . Disconnect "  + Logger.kAppName
        if clients[0].station != Logger.kAppName {
          alert.addButton(withTitle: "Close \(clients[0].station)")
        } else {
          alert.addButton(withTitle: "---")
        }
        if clients[1].station != Logger.kAppName {
          alert.addButton(withTitle: "Close \(clients[1].station)")
        } else {
          alert.addButton(withTitle: "---")
        }
        alert.addButton(withTitle: "Disconnect " + Logger.kAppName)
        alert.addButton(withTitle: "Cancel")
        
        alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
        alert.buttons[1].isEnabled = clients[1].station != Logger.kAppName
        
        // ignore if not confirmed by the user
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
          case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.disconnectClient( packet: discoveryPacket, handle: handles[1])
          case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectApplication()
          default:  break
          }
        })}
      
    default:
      self.disconnectApplication()
    }
  }
  /// Enable / Disable various UI elements
  ///
  private func updateButtonStates() {
        
    DispatchQueue.main.async { [unowned self] in
      if let radio = self._api.radio {
        
        self._localRemote.stringValue = radio.packet.isWan ? "SmartLink" : "Local"
        self._guiState.stringValue = Defaults.isGui ? "Gui" : "Non-Gui"
        self._apiType.stringValue = radio.version.isOldApi ? "Old API" : "New API"

        self._connectButton.title = "Disconnect"
        self._sendButton.isEnabled = true

        self._stationsPopUp.isEnabled = radio.version.isNewApi
        self._bindingPopUp.isEnabled = radio.version.isNewApi && !Defaults.isGui

      } else {
        self._localRemote.stringValue = ""
        self._guiState.stringValue = ""
        self._apiType.stringValue = ""

        self._connectButton.title = "Connect"
        self._sendButton.isEnabled = false

        self._stationsPopUp.isEnabled = false
        self._stationsPopUp.selectItem(withTitle: "All")
        self._bindingPopUp.isEnabled = false
        self._bindingPopUp.selectItem(withTitle: "None")
      }
    }
  }
  /// Produce a Client Id (UUID)
  ///
  /// - Returns:                a UUID
  ///
  private func clientId() -> String {

    if Defaults.clientId == nil {
      // none stored, create a new UUID
      Defaults.clientId = UUID().uuidString
    }
    return Defaults.clientId!
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
        title = "\(radio.packet.nickname) v\(radio.version.longString)         \(Logger.kAppName) v\(Logger.sharedInstance.version.string)"

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
    
    NC.makeObserver(self, with: #selector(clientDidDisconnect(_:)), of: .clientDidDisconnect)
    NC.makeObserver(self, with: #selector(guiClientHasBeenRemoved(_:)), of: .guiClientHasBeenRemoved)
    NC.makeObserver(self, with: #selector(guiClientHasBeenUpdated(_:)), of: .guiClientHasBeenUpdated)
  }
  /// Process .clientDidDisconnect Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func clientDidDisconnect(_ note: Notification) {
    DispatchQueue.main.async { [unowned self] in
      if self._connectButton.title == "Disconnect" { self._connectButton.performClick(self) }
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
          self?._stationsPopUp.item(withTitle: guiClient.station)?.toolTip = guiClient.clientId

          self?._bindingPopUp.addItem(withTitle: guiClient.station)
          self?._bindingPopUp.item(withTitle: guiClient.station)?.toolTip = guiClient.clientId
        }
      }
    }
  }
  /// Close this app
  ///
  private func disconnectApplication() {
    // disconnect the active radio
    _api.disconnect()
    
    updateButtonStates()
    title()
    
    // clear the previous Commands, Replies & Messages
    if Defaults.clearAtDisconnect {
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
    
    // nested functions ---------------------
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
    // --------------------------------------

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
  
  // ----------------------------------------------------------------------------
  // MARK: - RadioPickerDelegate methods
  
  var smartLinkEnabled : Bool { Defaults.smartLinkEnabled }
  
  /// Open a Radio
  /// - Parameters:
  ///   - packet:       a DiscoveryPacket
  ///
  func openSelectedRadio(_ packet: DiscoveryPacket) {
    
    if packet.isWan {
      _radioManager?.openWanRadio(packet)
    } else {
      openRadio(packet)
    }
    _startTimestamp = Date()
  }
  /// Close a Radio
  /// - Parameters:
  ///   - packet:       a DiscoveryPacket
  ///
  func closeSelectedRadio(_ packet: DiscoveryPacket) {
    
    if packet.isWan {
      _radioManager?.closeWanRadio(packet)
    } else {
      closeRadio(packet)
    }
  }
  /// Test the Wan connection
  ///
  /// - Parameter packet:     a DiscoveryPacket
  ///
  func testWanConnection(_ packet: DiscoveryPacket ) {
    _radioManager.testWanConnection(packet)
  }
  /// Login to SmartLink
  ///
  func smartLinkLogin() {
    _log("SmartLink login requested", .info, #function, #file, #line)

//    closeRadioPicker()
    _radioManager?.smartLinkLogin()
  }
  /// Logout of SmartLink
  ///
  func smartLinkLogout() {
    _log("SmartLink logout requested", .info, #function, #file, #line)
    
    Discovery.sharedInstance.removeSmartLinkRadios()
    
    _radioManager?.smartLinkLogout()
    willChangeValue(for: \.smartLinkUser)
    smartLinkUser = nil
    didChangeValue(for: \.smartLinkUser)
    
    willChangeValue(for: \.smartLinkCall)
    smartLinkCall = nil
    didChangeValue(for: \.smartLinkCall)
    
    willChangeValue(for: \.smartLinkImage)
    smartLinkImage = nil
    didChangeValue(for: \.smartLinkImage)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanManagerDelegate methods
    
  var auth0Email: String? {
    set { Defaults.smartLinkAuth0Email = newValue }
    get { Defaults.smartLinkAuth0Email }
  }
  var smartLinkWasLoggedIn: Bool {
    set { Defaults.smartLinkWasLoggedIn = newValue }
    get { Defaults.smartLinkWasLoggedIn }
  }
  
  func smartLinkTestResults(results: WanTestConnectionResults) {
    // was it successful?
    let status = (results.forwardTcpPortWorking == true &&
      results.forwardUdpPortWorking == true &&
      results.upnpTcpPortWorking == false &&
      results.upnpUdpPortWorking == false &&
      results.natSupportsHolePunch  == false) ||
      
      (results.forwardTcpPortWorking == false &&
        results.forwardUdpPortWorking == false &&
        results.upnpTcpPortWorking == true &&
        results.upnpUdpPortWorking == true &&
        results.natSupportsHolePunch  == false)
    // Log the result
    var msg = status ? "successfully" : "with errors: "
    if status == false { msg += "\(results.forwardUdpPortWorking), \(results.upnpTcpPortWorking), \(results.upnpUdpPortWorking), \(results.natSupportsHolePunch)" }
    _log("SmartLink Test completed \(msg)", .info, #function, #file, #line)
    
    DispatchQueue.main.async { [unowned self] in
      
      // set the indicator
      self._radioPickerViewController?.testIndicator.boolState = status
      
      // Alert the user on failure
      if status == false {
        
        let alert = NSAlert()
        alert.alertStyle = .critical
        let acc = NSTextField(frame: NSMakeRect(0, 0, 233, 125))
        acc.stringValue = results.string()
        acc.isEditable = false
        acc.drawsBackground = true
        alert.accessoryView = acc
        alert.messageText = "SmartLink Test Failure"
        alert.informativeText = "Check your SmartLink settings"
        
        alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
          
          if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        })
      }
    }
  }
  
  func smartLinkConnectionReady(handle: String, serial: String) {
    
    for packet in Discovery.sharedInstance.discoveredRadios where packet.serialNumber == serial && packet.isWan {
      packet.wanHandle = handle
      openRadio(packet)
    }
    Swift.print("wanRadioConnectReady: handle \(handle), serial \(serial)")
  }
  
  func smartLinkUserSettings(name: String?, call: String?) {
    
    willChangeValue(for: \.smartLinkUser)
    smartLinkUser = name
    didChangeValue(for: \.smartLinkUser)
    
    willChangeValue(for: \.smartLinkCall)
    smartLinkCall = call
    didChangeValue(for: \.smartLinkCall)
  }
  
  func smartLinkImage(image: NSImage?) {
    
    willChangeValue(for: \.smartLinkImage)
    smartLinkImage = image
    didChangeValue(for: \.smartLinkImage)
  }
}
