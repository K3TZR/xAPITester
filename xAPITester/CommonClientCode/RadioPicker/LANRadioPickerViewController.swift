
//  RadioPickerViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 13.01.17.
//  Copyright © 2017 Mario Illgen. All rights reserved.
//
//  Originally Created by Douglas Adams on 5/21/15.

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - LAN RadioPicker Delegate definition
// --------------------------------------------------------------------------------

protocol LANRadioPickerDelegate: class {
  
  /// Close this sheet
  ///
  func closeRadioPicker()
  
  /// Open the specified Radio
  ///
  /// - Parameters:
  ///   - radio:          a DiscoveryStruct struct
  ///   - remote:         remote / local
  ///   - handle:         remote handle
  /// - Returns:          success / failure
  ///
  func openRadio(_ radio: DiscoveryPacket?, remote: Bool, handle: String ) -> Bool
  
  /// Close the active Radio
  ///
  func closeRadio()

  /// Clear the reply table
  ///
  func clearTable()
  
  /// Close the application
  ///
  func terminateApp()
}

// --------------------------------------------------------------------------------
// MARK: - RadioPicker View Controller class implementation
// --------------------------------------------------------------------------------

final class LANRadioPickerViewController    : NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private var _radioTableView     : NSTableView!                // table of Radios
  @IBOutlet private var _selectButton       : NSButton!                   // Connect / Disconnect
  @IBOutlet private var _defaultButton      : NSButton!                   // Set as default
  
  private var _api                          = Api.sharedInstance
  private var _discoveryPacket              : DiscoveryPacket?
//  private var _discoveryPackets             : [DiscoveryPacket] { Discovery.sharedInstance.discoveredRadios }
  private let _log                          = Logger.sharedInstance

  private weak var _parentVc                : NSViewController!
  private weak var _delegate                : RadioPickerDelegate? { representedObject as? RadioPickerDelegate }

  // constants
  private let kColumnIdentifierDefaultRadio = "defaultRadio"
  private let kConnectTitle                 = "Connect"
  private let kDisconnectTitle              = "Disconnect"
  private let kSetAsDefault                 = "Set as Default"
  private let kClearDefault                 = "Clear Default"
  private let kDefaultFlag                  = "YES"
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    // allow the User to double-click the desired Radio
    _radioTableView.doubleAction = #selector(LANRadioPickerViewController.selectButton(_:))
    
    _selectButton.title = kConnectTitle

    // get a reference to the Tab view controller (the "presented" vc)
    _parentVc = parent!
    
    addNotifications()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Quit menu item
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func quitRadio(_ sender: AnyObject) {
    
    _parentVc.dismiss(sender)
    
    // perform an orderly disconnect of all the components
    _api.disconnect(reason: .normal)
    
    _log.logMessage("Application closed by user", .info, #function, #file, #line)
    DispatchQueue.main.async {

      NSApp.terminate(self)
    }
  }
  /// Respond to the Default button
  ///
  /// - Parameter sender: the button
  ///
  @IBAction func defaultButton(_ sender: NSButton) {
    
    // save the selection
    let selectedRow = _radioTableView.selectedRow
    
    // Clear / Set the Default
    if sender.title == kClearDefault {
      
      Defaults[.defaultRadioSerialNumber] = ""
      
    } else {
      
      Defaults[.defaultRadioSerialNumber] = Discovery.sharedInstance.discoveredRadios[selectedRow].serialNumber
    }
    
    // to display the Default status
    _radioTableView.reloadData()
    
    // restore the selection
    _radioTableView.selectRowIndexes(IndexSet(integersIn: selectedRow..<selectedRow+1), byExtendingSelection: true)
    
  }
  /// Respond to the Close button
  ///
  /// - Parameter sender: the button
  ///
  @IBAction func closeButton(_ sender: AnyObject) {

    // close this view & controller
    _parentVc.dismiss(sender)
  }
  /// Respond to the Select button
  ///
  /// - Parameter _: the button
  ///
  @IBAction func selectButton( _: AnyObject ) {
    
    connectDisconnect()
  }
  /// Respond to a double-clicked Table row
  ///
  /// - Parameter _: the row clicked
  ///
  func doubleClick(_: AnyObject) {
    
    connectDisconnect()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Connect / Disconnect a Radio
  ///
  private func connectDisconnect() {
    
    guard let discoveryPacket = _discoveryPacket else { return }
    guard let delegate = _delegate else { return }

    // Connect / Disconnect
    if _selectButton.title == kConnectTitle {

      // CONNECT, tell the delegate to connect to the selected Radio
      _delegate?.openRadio(discoveryPacket)
      
      // close the picker
      DispatchQueue.main.async { [unowned self] in
        self.closeButton(self)
      }
      
    } else {
      // DISCONNECT, RadioPicker remains open
      delegate.closeRadio(discoveryPacket)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    // Available Radios changed
    NC.makeObserver(self, with: #selector(discoveredRadios), of: .discoveredRadios)
    NC.makeObserver(self, with: #selector(guiClientHasBeenAdded), of: .guiClientHasBeenAdded)
    NC.makeObserver(self, with: #selector(guiClientHasBeenRemoved), of: .guiClientHasBeenRemoved)
  }
  /// Process .DiscoveryStructs Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func discoveredRadios(_ note: Notification) {
    
    DispatchQueue.main.async { [weak self] in
      
      self?._radioTableView.reloadData()
    }
  }
  /// Process .guiClientHasBeenAdded Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func guiClientHasBeenAdded(_ note: Notification) {
    
    DispatchQueue.main.async { [weak self] in
      
      self?._radioTableView.reloadData()
    }
  }
  /// Process .guiClientHasBeenRemoved Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func guiClientHasBeenRemoved(_ note: Notification) {
    
    DispatchQueue.main.async { [weak self] in
      
      self?._radioTableView.reloadData()
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - NSTableView DataSource methods
  
  /// Tableview numberOfRows delegate method
  ///
  /// - Parameter aTableView: the Tableview
  /// - Returns: number of rows
  ///
  func numberOfRows(in aTableView: NSTableView) -> Int {

    // get the number of rows
    return Discovery.sharedInstance.discoveredRadios.count
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView Delegate methods
  
  /// Tableview view delegate method
  ///
  /// - Parameters:
  ///   - tableView: the Tableview
  ///   - tableColumn: a Tablecolumn
  ///   - row: the row number
  /// - Returns: an NSView
  ///
  func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

    let version = Version(Discovery.sharedInstance.discoveredRadios[row].firmwareVersion)

    // get a view for the cell
    let cellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
    cellView.toolTip = Discovery.sharedInstance.discoveredRadios[row].description

    // is this the default row?
    let isDefaultRow = (Defaults[.defaultRadioSerialNumber] == Discovery.sharedInstance.discoveredRadios[row].serialNumber)
    
    var stations = ""
    for client in Discovery.sharedInstance.discoveredRadios[row].guiClients {
      stations += (stations == "" ? client.station : ", " + client.station)
    }

    // set the stringValue of the cell's text field to the appropriate field
    switch tableColumn!.identifier.rawValue {
      
    case "model":     cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].model
    case "nickname":  cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].nickname
    case "status":    cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].status
    case "stations":  cellView.textField!.stringValue = (version.isNewApi ? stations : "n/a")
    case "publicIp":  cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].publicIp
    default:          _log.logMessage("Unknown table column: \(tableColumn!.identifier.rawValue)", .error, #function, #file, #line)
    }

    // color the default row
    cellView.wantsLayer = true
    if isDefaultRow {
      cellView.layer!.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.2).cgColor
    } else {
      cellView.layer!.backgroundColor = NSColor.clear.cgColor
    }
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification: notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable the buttons
    _selectButton.isEnabled = (_radioTableView.selectedRow >= 0)
    _defaultButton.isEnabled = (_radioTableView.selectedRow >= 0)
    
    if _radioTableView.selectedRow >= 0 {
      // a row is selected
      _discoveryPacket = Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow]

      // set the "select button" title appropriately
      var isActive = false
      if let radio = Api.sharedInstance.radio {
        isActive = ( radio.discoveryPacket == Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow] )
      }
      // set "default button" title appropriately
      _defaultButton.title = (Defaults[.defaultRadioSerialNumber] == Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow].serialNumber ? kClearDefault : kSetAsDefault)
      _selectButton.title = (isActive ? kDisconnectTitle : kConnectTitle)
      
    } else {
      // no row is selected, set the button titles
      _defaultButton.title = kSetAsDefault
      _selectButton.title = kConnectTitle
    }
  }
}
