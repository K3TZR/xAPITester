//
//  SplitViewController.swift
//  xAPITester
//
//  Created by Douglas Adams on 3/29/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// ------------------------------------------------------------------------------
// MARK: - SplitViewController Class implementation
// ------------------------------------------------------------------------------

class SplitViewController: NSSplitViewController, ApiDelegate, NSTableViewDelegate, NSTableViewDataSource {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public enum MessagesFilters: Int {
    case none = 0
    case prefix
    case contains
    case exclude
    case myHandle
    case handle
  }
  public enum ObjectsFilters: Int {
    case none = 0
    case prefix
    case contains
    case exclude
  }
  public var selectedStation                  : String? = nil

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  typealias ObjectTuple = (color: NSColor, text: String)
  
  @IBOutlet internal var _tableView           : NSTableView!
  @IBOutlet internal var _objectsTableView    : NSTableView!
  
  public var myHandle: String {
    get { return _objectQ.sync { _myHandle } }
    set { _objectQ.sync(flags: .barrier) { _myHandle = newValue } } }
  
  internal var objects: [ObjectTuple] {
    get { return _objectQ.sync { _objects } }
    set { _objectQ.sync(flags: .barrier) { _objects = newValue } } }
  
  internal var messages: [String] {
    get { return _objectQ.sync { _messages } }
    set { _objectQ.sync(flags: .barrier) { _messages = newValue } } }
  
  internal var replyHandlers: [SequenceNumber: ReplyTuple] {
    get { return _objectQ.sync { _replyHandlers } }
    set { _objectQ.sync(flags: .barrier) { _replyHandlers = newValue } } }
  
  internal var _filteredMessages              : [String] {                  // filtered version of textArray
    get {
      switch MessagesFilters(rawValue: Defaults.filterByTag) ?? .none {
      
      case .none:       return messages
      case .prefix:     return messages.filter { $0.contains("|" + Defaults.filter) }
      case .contains:   return messages.filter { $0.contains(Defaults.filter) }
      case .exclude:    return messages.filter { !$0.contains(Defaults.filter) }
      case .myHandle:   return messages.filter { $0.dropFirst(9).hasPrefix("S" + myHandle) }
      case .handle:     return messages.filter { $0.dropFirst(9).hasPrefix("S" + Defaults.filter) }
      }
    }}
  internal var _filteredObjects           : [ObjectTuple] {                  // filtered version of objectsArray
    get {
      switch ObjectsFilters(rawValue: Defaults.filterObjectsByTag) ?? .none {
      
      case .none:       return objects
      case .prefix:     return objects.filter { $0.text.dropFirst(9).hasPrefix(Defaults.filterObjects) }
      case .contains:   return objects.filter { $0.text.contains(Defaults.filterObjects) }
      case .exclude:    return objects.filter { !$0.text.contains(Defaults.filterObjects) }
      }
    }}
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _api                            : Api {return Api.sharedInstance}          // Api to the Radio
  private let _log                            = Logger.sharedInstance
  internal weak var _parent                   : ViewController?
  internal let _objectQ                       = DispatchQueue(label: Logger.kAppName + ".objectQ", attributes: [.concurrent])
  
  private var _font                           : NSFont!                         // font for table entries
  
  private var _myHandle                       = ""
  private var _replyHandlers                  = [SequenceNumber: ReplyTuple]()  // Dictionary of pending replies
  private var _messages                       = [String]()                      // backing storage for the table
  private var _objects                        = [ObjectTuple]()                 // backing storage for the objects table
  private var _clientIds                      = [String]()
  
  private var _timeoutTimer                   : DispatchSourceTimer!            // timer fired every "checkInterval"
  private var _timerQ                         = DispatchQueue(label: "xAPITester" + ".timerQ")

  private var _selectedStation                : String? = nil
  private let kAutosaveName                   = NSSplitView.AutosaveName(Logger.kAppName + "SplitView")
  private let checkInterval                   : TimeInterval = 1.0
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    splitView.autosaveName = kAutosaveName
    
    _api.testerDelegate = self
    
    // setup the font
    _font = NSFont(name: Defaults.fontName, size: CGFloat(Defaults.fontSize ))!
    _tableView.rowHeight = _font.capHeight * 1.7
    
    // setup & start the Objects table timer
    setupTimer()
    
    _selectedStation = nil
  }

  deinit {
    // stop the Objects table timer
    _timeoutTimer?.cancel()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// 1st Responder to the Format->Font->Bigger menu (or Command=)
  ///
  /// - Parameter sender:     the sender
  ///
  @IBAction func fontBigger(_ sender: AnyObject) {
    
    fontSize(larger: true)
  }
  /// 1st Responder to the Format->Font->Smaller menu (or Command-)
  ///
  /// - Parameter sender:     the sender
  ///
  @IBAction func fontSmaller(_ sender: AnyObject) {
    
    fontSize(larger: false)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Refresh the TableView & make its last row visible
  ///
  internal func reloadTable() {
    
    DispatchQueue.main.async { [unowned self] in
      // reload the table
      self._tableView.reloadData()
      
      // make sure the last row is visible
      if self._tableView.numberOfRows > 0 {
        
        self._tableView.scrollRowToVisible(self._tableView.numberOfRows - 1)
      }
    }
  }
  /// Refresh the Objects TableView & make its last row visible
  ///
  internal func reloadObjectsTable() {
    
    DispatchQueue.main.async { [unowned self] in
      // reload the table
      self._objectsTableView?.reloadData()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Adjust the font size larger or smaller (within limits)
  ///
  /// - Parameter larger:           larger?
  ///
  private func fontSize(larger: Bool) {
    
    // limit the font size
    var newSize =  Defaults.fontSize + (larger ? +1 : -1)
    if larger {
      if newSize > Defaults.fontMaxSize { newSize = Defaults.fontMaxSize }
    } else {
      if newSize < Defaults.fontMinSize { newSize = Defaults.fontMinSize }
    }
    
    // save change to preferences
    Defaults.fontSize = newSize
    
    // update the font
    _font = NSFont(name: Defaults.fontName, size: CGFloat(Defaults.fontSize ))!
    _tableView.rowHeight = _font.capHeight * 1.7
    _objectsTableView.rowHeight = _font.capHeight * 1.7
    
    // force a redraw
    reloadTable()
    reloadObjectsTable()
  }
  /// Setup & start the Objects table timer
  ///
  private func setupTimer() {
    // create a timer to periodically redraw the objetcs table
    _timeoutTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _timerQ)
    
    // Set timer with 100 millisecond leeway
    _timeoutTimer.schedule(deadline: DispatchTime.now(), repeating: checkInterval, leeway: .milliseconds(100))      // Every second +/- 10%
    
    // set the event handler
    _timeoutTimer.setEventHandler { [ unowned self] in
      
      // redraw the objects table when the timer fires
      self.refreshObjects()
    }
    // start the timer
    _timeoutTimer.resume()
  }
  /// Add text to the table
  ///
  /// - Parameter text:       a text String
  ///
  private func showInTable(_ text: String) {
    
    // guard that a session has been started
    guard let startTimestamp = self._parent!._startTimestamp else { return }
    
    // add the Timestamp to the Text
    let timeInterval = Date().timeIntervalSince(startTimestamp)
    messages.append( String( format: "%8.3f", timeInterval) + " " + text )

    reloadTable()
  }
  /// Add text to the Objects table
  ///
  /// - Parameter text:       a text String
  ///
  func addObjectsToTable(_ entry: ObjectTuple) {
    
    // guard that a session has been started
    guard let startTimestamp = self._parent!._startTimestamp else { return }
    
    // add the Timestamp to the Text
    let timeInterval = Date().timeIntervalSince(startTimestamp)
    objects.append( (entry.color, String( format: "%8.3f", timeInterval) + " " + entry.text) )
  }
  /// Parse a Reply message. format: <sequenceNumber>|<hexResponse>|<message>[|<debugOutput>]
  ///
  /// - parameter commandSuffix:    a Command Suffix
  ///
  private func parseReply(_ commandSuffix: String) {
    
    // separate it into its components
    let components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted replies
    if components.count < 2 {
      
      _log.logMessage("Incomplete reply, c\(commandSuffix)", .error, #function, #file, #line)
      return
    }
    
    guard SequenceNumber(components[0]) != nil else { return }
    
    // is there an Object expecting to be notified?
    if let replyTuple = replyHandlers[ SequenceNumber(components[0])! ] {
      
      // an Object is waiting for this reply, send the Command to the Handler on that Object
      
      let command = replyTuple.command
      
      // is there a ReplyHandler for this command?
      //      if let handler = replyTuple.replyTo {
      //
      //        // YES, pass it to the ReplyHandler
      //        handler(command, components[0], components[1], (components.count == 3) ? components[2] : "")
      //      }
      // Show all replies?
      if Defaults.showAllReplies {
        
        // SHOW ALL, is it a ping reply?
        if command == "ping" {
          
          // YES, are pings being shown?
          if Defaults.showPings {
            
            // YES, show the ping reply
            showInTable("R\(commandSuffix)")
          }
        } else {
          
          // SHOW ALL, it's not a ping reply
          showInTable("R\(commandSuffix)")
        }
        
      } else if components[1] != "0" || (components.count > 2 && components[2] != "") {
        
        // NOT SHOW ALL, only show non-zero replies with additional information
        showInTable("R\(commandSuffix)")
      }
      // Remove the object from the notification list
      replyHandlers[SequenceNumber(components[0]) ?? 0] = nil
      
    } else {
      
      // no Object is waiting for this reply, show it
      showInTable("R\(commandSuffix)")
    }
  }
  /// Redraw the Objects table
  ///
  private func refreshObjects() {
    var i = 0
    let alpha : CGFloat = 0.4
    let objectColors = [
      NSColor.systemRed.withAlphaComponent(alpha),
      NSColor.systemOrange.withAlphaComponent(alpha),
      NSColor.systemYellow.withAlphaComponent(alpha),
      NSColor.systemGreen.withAlphaComponent(alpha)
    ]

    DispatchQueue.main.async { [unowned self] in
      var activeHandle : Handle = 0
      
      // Radio
      if let radio = Api.sharedInstance.radio {
        i = 0
        
        self.objects.removeAll()
        var color = NSColor.systemGray.withAlphaComponent(0.2)
        
        self.addObjectsToTable((color, "Radio          name = \(radio.nickname)  model = \(radio.packet.model)  ip = \(radio.packet.publicIp)" +
          "  atu = \(Api.sharedInstance.radio!.atuPresent ? "Yes" : "No")  gps = \(Api.sharedInstance.radio!.gpsPresent ? "Yes" : "No")" +
          "  scu's = \(Api.sharedInstance.radio!.numberOfScus)"))

        // what verion is the Radio?
        if radio.version.isNewApi {
                    
          // newApi
          for (handle, client) in radio.packet.guiClients {
            
            color = objectColors[i]
            
            if self._parent!._stationsPopUp.titleOfSelectedItem == "All" || self._parent!._stationsPopUp.titleOfSelectedItem == client.station {
              activeHandle = handle
              
              self.addObjectsToTable((color, "Gui Client     station = \(client.station.padTo(15))  handle = \(handle.hex)  id = \(client.clientId ?? "unknown")  localPtt = \(client.isLocalPtt ? "Yes" : "No ")  available = \(radio.packet.status.lowercased() == "available" ? "Yes" : "No ")  program = \(client.program)"))
              
              self.addSelectedObjects(activeHandle, radio, color)
            }
            i = (i + 1) % objectColors.count
          }
        } else {
          // oldApi
            color = objectColors[i]
            
            self.addSelectedObjects(activeHandle, radio, color)
            
            i = (i + 1) % objectColors.count
        }
        self.reloadObjectsTable()
        color = NSColor.systemGray.withAlphaComponent(0.2)
               
        // OpusAudioStream
        for (_, stream) in radio.opusAudioStreams {
          self.addObjectsToTable((color, "Opus           id = \(stream.id.hex)  rx = \(stream.rxEnabled)  rx stopped = \(stream.rxStopped)  tx = \(stream.txEnabled)  ip = \(stream.ip)  port = \(stream.port)"))
        }
        
        // AudioStream without a Slice
        for (_, stream) in radio.audioStreams where stream.slice == nil {
          self.addObjectsToTable((color, "Audio          id = \(stream.id.hex)  ip = \(stream.ip)  port = \(stream.port)  slice = -not assigned-"))
        }

        // Tnfs
        for (_, tnf) in radio.tnfs {
          self.addObjectsToTable((color, "Tnf            id = \(tnf.id)  frequency = \(tnf.frequency)  width = \(tnf.width)  depth = \(tnf.depth)  permanent = \(tnf.permanent)"))
        }
        // Amplifiers
        for (_, amplifier) in radio.amplifiers {
          self.addObjectsToTable((color, "Amplifier      id = \(amplifier.id.hex)"))
        }
        // Memories
        for (_, memory) in radio.memories {
          self.addObjectsToTable((color, "Memory         id = \(memory.id)"))
        }
        // USB Cables
        for (_, usbCable) in radio.usbCables {
          self.addObjectsToTable((color, "UsbCable       id = \(usbCable.id)"))
        }
        // Xvtrs
        for (_, xvtr) in radio.xvtrs {
          self.addObjectsToTable((color, "Xvtr           id = \(xvtr.id)  rf frequency = \(xvtr.rfFrequency.hzToMhz)  if frequency = \(xvtr.ifFrequency.hzToMhz)  valid = \(xvtr.isValid.asTrueFalse)"))
        }
        // other Meters (non "slc")
        let sortedMeters = radio.meters.sorted(by: {
            ( $0.value.source[0..<3], Int($0.value.group.suffix(3), radix: 10)!, $0.value.id ) <
            ( $1.value.source[0..<3], Int($1.value.group.suffix(3), radix: 10)!, $1.value.id )
        })
        for (_, meter) in sortedMeters where !meter.source.hasPrefix("slc") {
          self.addObjectsToTable((color, "Meter          source = \(meter.source[0..<3])  group = \(("00" + meter.group).suffix(3))  id = \(String(format: "%03d", meter.id))  name = \(meter.name.padTo(12))  units = \(meter.units.padTo(5))  low = \(String(format: "% 7.2f", meter.low))  high = \(String(format: "% 7.2f", meter.high))  fps = \(String(format: "% 3d", meter.fps))  desc = \(meter.desc)  "))
        }
        self.reloadObjectsTable()
      }
    }
  }
  
  
  
  
  private func addSelectedObjects(_ activeHandle: Handle, _ radio: Radio, _ color: NSColor) {

    // MicAudioStream
    for (_, stream) in radio.micAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "MicAudio       id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  ip = \(stream.ip)  port = \(stream.port)"))
    }
    // IqStream without a Panadapter
    for (_, stream) in radio.iqStreams where stream.clientHandle == activeHandle && stream.pan == 0 {
      self.addObjectsToTable((color, "Iq             id = \(stream.id.hex)  channel = \(stream.daxIqChannel)  rate = \(stream.rate)  ip = \(stream.ip)  panadapter = -not assigned-"))
    }
    // TxAudioStream
    for (_, stream) in radio.txAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "TxAudio        id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  transmit = \(stream.transmit)  ip = \(stream.ip)  port = \(stream.port)"))
    }
    // DaxRxAudioStream without a Slice
    for (_, stream) in radio.daxRxAudioStreams where stream.clientHandle == activeHandle && stream.slice == nil {
      self.addObjectsToTable((color, "DaxRxAudio     id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  channel = \(stream.daxChannel)  ip = \(stream.ip)  slice = -not assigned-"))
    }
    // DaxTxAudioStream
    for (_, stream) in radio.daxTxAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "DaxTxAudio     id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  isTransmit = \(stream.isTransmitChannel)"))
    }
    // DaxIqStream without a Panadapter
    for (_, stream) in radio.daxIqStreams where stream.clientHandle == activeHandle && stream.pan == 0 {
      self.addObjectsToTable((color, "DaxIq          id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  channel = \(stream.channel)  rate = \(stream.rate)  ip = \(stream.ip)  panadapter = -not assigned-"))
    }
    // RemoteRxAudioStream
    for (_, stream) in radio.remoteRxAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "RemoteRxAudio  id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  compression = \(stream.compression)"))
    }
    // RemoteTxAudioStream
    for (_, stream) in radio.remoteTxAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "RemoteTxAudio  id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  compression = \(stream.compression)  ip = \(stream.ip)"))
    }
    // DaxMicAudioStream
    for (_, stream) in radio.daxMicAudioStreams where stream.clientHandle == activeHandle {
      self.addObjectsToTable((color, "DaxMicAudio    id = \(stream.id.hex)  handle = \(stream.clientHandle.hex)  ip = \(stream.ip)"))
    }
    
    // Panadapters & its accompanying objects
    for (_, panadapter) in radio.panadapters {
      if panadapter.clientHandle != activeHandle { continue }
      
      if radio.version.isNewApi {
        self.addObjectsToTable((color, "Panadapter     handle = \(panadapter.clientHandle.hex)  id = \(panadapter.id.hex)  center = \(panadapter.center.hzToMhz)  bandwidth = \(panadapter.bandwidth.hzToMhz)"))
      } else {
        self.addObjectsToTable((color, "Panadapter     id = \(panadapter.id.hex)  center = \(panadapter.center.hzToMhz)  bandwidth = \(panadapter.bandwidth.hzToMhz)"))
      }
      // Waterfall
      for (_, waterfall) in radio.waterfalls where panadapter.id == waterfall.panadapterId {
        self.addObjectsToTable((color, "      Waterfall   id = \(waterfall.id.hex)  autoBlackEnabled = \(waterfall.autoBlackEnabled),  colorGain = \(waterfall.colorGain),  blackLevel = \(waterfall.blackLevel),  duration = \(waterfall.lineDuration)"))
      }
      
      // IqStream
      for (_, iqStream) in radio.iqStreams where panadapter.id == iqStream.pan {
        self.addObjectsToTable((color, "      Iq          id = \(iqStream.id.hex)"))
      }
      
      // DaxIqStream
      for (_, daxIqStream) in radio.daxIqStreams where panadapter.id == daxIqStream.pan {
        self.addObjectsToTable((color, "      DaxIq       id = \(daxIqStream.id.hex)"))
      }
      
      // Slice(s) & their accompanying objects
      for (_, slice) in radio.slices where panadapter.id == slice.panadapterId {
        self.addObjectsToTable((color, "      Slice       id = \(slice.id)  frequency = \(slice.frequency.hzToMhz)  mode = \(slice.mode.padTo(4))  filterLow = \(String(format: "% 5d", slice.filterLow))  filterHigh = \(String(format: "% 5d", slice.filterHigh))  active = \(slice.active)  locked = \(slice.locked)"))
        
        // AudioStream
        for (_, stream) in radio.audioStreams where stream.slice?.id == slice.id {
          self.addObjectsToTable((color, "          Audio       id = \(stream.id.hex)  ip = \(stream.ip)  port = \(stream.port)"))
        }
        
        // DaxRxAudioStream
        for (_, stream) in radio.daxRxAudioStreams where stream.slice?.id == slice.id {
          self.addObjectsToTable((color, "          DaxAudio    id = \(stream.id.hex)  channel = \(stream.daxChannel)  ip = \(stream.ip)"))
        }
        
        // Meters
        for (_, meter) in radio.meters.sorted(by: { $0.value.id < $1.value.id }) {
          if meter.source == "slc" && meter.group == String(slice.id) {
            self.addObjectsToTable((color, "          Meter id = \(meter.id)  name = \(meter.name.padTo(12))  units = \(meter.units.padTo(5))  low = \(String(format: "% 7.2f", meter.low))  high = \(String(format: "% 7.2f", meter.high))  fps = \(String(format: "% 3d", meter.fps))  desc = \(meter.desc)  "))
          }
        }
      }
    }
  }

  private func removeAllStreams() {
    
    Api.sharedInstance.radio!.opusAudioStreams.removeAll()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Api Delegate methods
  
  /// Process a sent message
  ///
  /// - Parameter text:       text of the command
  ///
  public func sentMessage(_ text: String) {
    
    if !text.hasSuffix("|ping") { showInTable(text) }
    
    if text.hasSuffix("|ping") && Defaults.showPings { showInTable(text) }
  }
  /// Process a received message
  ///
  /// - Parameter text:       text received from the Radio
  ///
  public func receivedMessage(_ text: String) {
    
    // get all except the first character
    let suffix = String(text.dropFirst())

    // switch on the first character
    switch text[text.startIndex] {
      
    case "C":   // Commands
      showInTable(text)
      
    case "H":   // Handle type
      myHandle = String(format: "%X", suffix.handle ?? 0)
      showInTable(text)
      
    case "M":   // Message Type
      showInTable(text)
      
    case "R":   // Reply Type
      parseReply(suffix)
      
    case "S":   // Status type
      // format: <apiHandle>|<message>, where <message> is of the form: <msgType> <otherMessageComponents>
      
      showInTable(text)
      
    case "V":   // Version Type
      showInTable(text)
      
    default:    // Unknown Type
      _log.logMessage("Unexpected Message Type from radio, \(text[text.startIndex] as! CVarArg)", .error, #function, #file, #line)
    }
  }
  /// Add a Reply Handler for a specific Sequence/Command
  ///
  /// - Parameters:
  ///   - sequenceId:         sequence number of the Command
  ///   - replyTuple:         a Reply Tuple
  ///
  public func addReplyHandler(_ sequenceId: SequenceNumber, replyTuple: ReplyTuple) {
    
    // add the handler
    replyHandlers[sequenceId] = replyTuple
  }
  /// Process the Reply to a command, reply format: <value>,<value>,...<value>
  ///
  /// - Parameters:
  ///   - command:            the original command
  ///   - seqNum:             the Sequence Number of the original command
  ///   - responseValue:      the response value
  ///   - reply:              the reply
  ///
  public func defaultReplyHandler(_ command: String, sequenceNumber: SequenceNumber, responseValue: String, reply: String) {
    
    // unused in xAPITester
  }
  /// Receive a UDP Stream packet
  ///
  /// - Parameter vita: a Vita packet
  ///
  public func vitaParser(_ vitaPacket: Vita) {
    
    // unused in xAPITester
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - LogHandlerDelegate methods
  
  /// Process log messages
  ///
  /// - Parameters:
  ///   - msg:        a message
  ///   - level:      the severity level of the message
  ///   - function:   the name of the function creating the msg
  ///   - file:       the name of the file containing the function
  ///   - line:       the line number creating the msg
  ///
//  public func msg(_ msg: String, level: OSType, function: StaticString, file: StaticString, line: Int ) -> Void {
  public func msg(_ msg: String) -> Void {

    // Show API log messages
    showInTable("----- \(msg) -----")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView DataSource methods
  
  ///
  ///
  /// - Parameter aTableView: the TableView
  /// - Returns:              number of rows
  ///
  public func numberOfRows(in aTableView: NSTableView) -> Int {
    
    if aTableView == _tableView {
      
      return _filteredMessages.count
      
    } else {
      
      return _filteredObjects.count
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView Delegate methods
  
  /// Return a view to be used for the row/column
  ///
  /// - Parameters:
  ///   - tableView:          the TableView
  ///   - tableColumn:        the current TableColumn
  ///   - row:                the current row number
  /// - Returns:              the view for the column & row
  ///
  public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
    // get a view for the cell
    let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
    
    // Which table?
    if tableView === _tableView! {
      
      // validate the index
      if _filteredMessages.count - 1 >= row {
        
        // Replies & Commands, get the text including Timestamp
        let rowText = _filteredMessages[row]
        
        // get the text without the Timestamp
        let msgText = String(rowText.dropFirst(9))
        
        // determine the type of text, assign a background color
        if msgText.hasPrefix("-----") {                                         // application messages
          
          // application messages from this app
          view.textField!.backgroundColor = NSColor.black

        } else if msgText.hasPrefix("c") || msgText.hasPrefix("C") {
          
          // commands sent by this app
          view.textField!.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.3)

        } else if msgText.hasPrefix("r") || msgText.hasPrefix("R") {
          
          // reply messages
          view.textField!.backgroundColor = NSColor.lightGray.withAlphaComponent(0.3)

        } else if msgText.hasPrefix("v") || msgText.hasPrefix("V") ||
          msgText.hasPrefix("h") || msgText.hasPrefix("H") ||
          msgText.hasPrefix("m") || msgText.hasPrefix("M") {
          
          // messages not directed to a specific client
          view.textField!.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)

        } else if msgText.hasPrefix("s" + myHandle) || msgText.hasPrefix("S" + myHandle) {
          
          // status sent to myHandle
          view.textField!.backgroundColor = NSColor.systemRed.withAlphaComponent(0.3)

        } else {
          
          // status sent to a handle other than mine
          view.textField!.backgroundColor = NSColor.systemRed.withAlphaComponent(0.5)
        }
        // set the font
        view.textField!.font = _font
        
        // set the text
        view.textField!.stringValue = Defaults.showTimestamps ? rowText : msgText
      }
      
    }
    else {
      
      // validate the index
      if _filteredObjects.count - 1 >= row {
        
        // Objects, get the text including Timestamp
        let rowText = _filteredObjects[row].text
        let color = _filteredObjects[row].color
        
        // get the text without the Timestamp
        let msgText = String(rowText.dropFirst(9))
        
        // set the color
        view.textField!.backgroundColor = color
        
        // set the font
        view.textField!.font = _font
        
        // set the text
        view.textField!.stringValue = msgText
      }
    }
    return view
  }
}
