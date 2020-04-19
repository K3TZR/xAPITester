//
//  RadioController.swift
//  xAPITester
//
//  Created by Douglas Adams on 4/18/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

public struct WanToken {

  var value         : String
  var expiresAt     : Date

  public func isValidAtDate(_ date: Date) -> Bool {
    return (date < self.expiresAt)
  }
}

final class RadioController : WanServerDelegate {
    
  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  public var discoveredRadios = [DiscoveryPacket]()
  public var logOnName        = ""
  public var logOnCall        = ""
  public var logOnImage       : NSImage? = nil

  public var smartLinkTestResults : WanTestConnectionResults?
  public var smartLinkTestStatus  = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private var _discovery  : Discovery!
  private var _wanServer  : WanServer!
  private var _token      : WanToken?
  private var _auth0ViewController          : Auth0ViewController?

  private let _log                          = Logger.sharedInstance

  private let kService = Logger.kAppName + ".oauth-token"

  private let kApplicationJson              = "application/json"
  private let kAuth0Delegation              = "https://frtest.auth0.com/delegation"
  private let kClaimEmail                   = "email"
  private let kClaimPicture                 = "picture"
  private let kConnectTitle                 = "Connect"
  private let kDisconnectTitle              = "Disconnect"
  private let kGrantType                    = "urn:ietf:params:oauth:grant-type:jwt-bearer"
  private let kHttpHeaderField              = "content-type"
  private let kHttpPost                     = "POST"
  private let kPlatform                     = "macOS"
  private let kScope                        = "openid email given_name family_name picture"
  private let kKeyClientId                  = "client_id"                   // dictionary keys
  private let kKeyGrantType                 = "grant_type"
  private let kKeyIdToken                   = "id_token"
  private let kKeyRefreshToken              = "refresh_token"
  private let kKeyScope                     = "scope"
  private let kKeyTarget                    = "target"

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  init(smartLinkAuth0Email: String) {
    var idToken = ""
    var mustLogIn = true
    
    _discovery = Discovery.sharedInstance
    _wanServer = WanServer(delegate: self)
    
    addNotifications()
    
    // check if we were logged in into Auth0, try to get a token
    
    if Defaults[.smartLinkWasLoggedIn] {
      
      // is there a saved Auth0 token which has not expired?
      if let previousIdToken = _token, previousIdToken.isValidAtDate( Date()) {
        
        // YES, we can log into SmartLink, use the saved token
        mustLogIn = false
        idToken = previousIdToken.value
        
      } else if Defaults[.smartLinkAuth0Email] != "" {
        
        // there is a saved email, use it to obtain a refresh token from Keychain
        if let refreshToken = Keychain.get(kService, account: smartLinkAuth0Email) {
          
          // can we get an Id Token from the Refresh Token?
          if let refreshedIdToken = getIdToken(from: refreshToken) {
            
            // YES, we can use the saved token to Log in
            mustLogIn = false
            idToken = refreshedIdToken
            
          } else {
            
            // NO, the refresh token and email are no longer valid, delete them
            _token = nil
            Keychain.delete(kService, account: smartLinkAuth0Email)
            Defaults[.smartLinkAuth0Email] = ""
            
            idToken = ""
            mustLogIn = true
          }
        } else {
          
          // no refresh token in Keychain
          mustLogIn = true
          idToken = ""
        }
      } else {
        
        // no saved email, user must log in
        mustLogIn = true
        idToken = ""
      }
    }
    // exit if we don't have the needed token (User will need to press the Log In button)
    guard mustLogIn == false else { return }
    
    // we have the token, get the User image (gravatar)
    do {
      
      // try to get the JSON Web Token
      let jwt = try decode(jwt: idToken)
      
      // get the Log On image (if any) from the token
      let claim = jwt.claim(name: "picture")
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        
        logOnImage = getImage(fromURL: url)

      }
      // connect to the SmartLink server (Log in)
      connectWanServer(token: idToken)

    } catch let error as NSError {
      
      // log the error
      _log.logMessage("Error decoding JWT token: \(error.localizedDescription)", .error, #function, #file, #line)
      
      idToken = ""
      mustLogIn = true
      
    }
    
    // connect to the SmartLink server (Log in)
    connectWanServer(token: idToken)
  }

  
  
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Given a Refresh Token attempt to get a Token
  ///
  /// - Parameter refreshToken:         a Refresh Token
  /// - Returns:                        a Token (if any)
  ///
  private func getIdToken(from refreshToken: String) -> String? {
    
    // guard that the token isn't empty
    guard refreshToken != "" else { return nil }
    
    // build a URL Request
    let url = URL(string: kAuth0Delegation)
    var urlRequest = URLRequest(url: url!)
    urlRequest.httpMethod = kHttpPost
    urlRequest.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
    
    // guard that body data was created
    guard let bodyData = createBodyData(refreshToken: refreshToken) else { return "" }
    
    // update the URL Request and retrieve the data
    urlRequest.httpBody = bodyData
    let (responseData, _, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
    
    // guard that the data isn't empty and that no error occurred
    guard let data = responseData, error == nil else {
      
      // log the error
      _log.logMessage("Error retrieving id token token: \(error?.localizedDescription ?? "")", .error, #function, #file, #line)

      return nil
    }
    
    // is there a Token?
    if let token = parseTokenResponse(data: data) {
      do {
        
        let jwt = try decode(jwt: token)
        
        // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
        if !isJWTValid(jwt) {
          // log the error
          _log.logMessage("JWT token not valid", .error, #function, #file, #line)
          
          return nil
        }
        
      } catch let error as NSError {
        // log the error
        _log.logMessage("Error decoding JWT token: \(error.localizedDescription)", .error, #function, #file, #line)
        
        return nil
      }
      
      return token
    }
    // NO token
    return nil
  }

  private func getImage(fromURL url: URL) -> NSImage? {
      guard let data = try? Data(contentsOf: url) else { return nil }
      guard let image = NSImage(data: data) else { return nil }
      return image
  }
  /// Connect to the Wan Server
  ///
  /// - Parameter token:                token
  ///
  private func connectWanServer(token: String) {
    
    // connect with pinger to avoid the SmartLink server timeout)
    if _wanServer!.connect(appName: Logger.kAppName, platform: kPlatform, token: token, ping: true) {
      
      Defaults[.smartLinkWasLoggedIn] = true

    } else {
      
      Defaults[.smartLinkWasLoggedIn] = false
      // log the error
      _log.logMessage("SmartLink Server log in: FAILED", .warning, #function, #file, #line)
    }
  }
  /// Create the Body Data for use in a URLSession
  ///
  /// - Parameter refreshToken:     a Refresh Token
  /// - Returns:                    the Data (if created)
  ///
  private func createBodyData(refreshToken: String) -> Data? {
    
    // guard that the Refresh Token isn't empty
    guard refreshToken != "" else { return nil }
    
    // create & populate the dictionary
    var dict = [String : String]()
    dict[kKeyClientId] = Auth0ViewController.kClientId
    dict[kKeyGrantType] = kGrantType
    dict[kKeyRefreshToken] = refreshToken
    dict[kKeyTarget] = Auth0ViewController.kClientId
    dict[kKeyScope] = kScope

    // try to obtain the data
    do {
      
      let data = try JSONSerialization.data(withJSONObject: dict)
      // success
      return data

    } catch _ {
      // failure
      return nil
    }
  }
  /// Parse the URLSession data
  ///
  /// - Parameter data:               a Data
  /// - Returns:                      a Token (if any)
  ///
  private func parseTokenResponse(data: Data) -> String? {
    
    do {
      // try to parse
      let myJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
      
      // was something returned?
      if let parseJSON = myJSON {
        
        // YES, does it have a Token?
        if let  idToken = parseJSON[kKeyIdToken] as? String {
          // YES, retutn it
          return idToken
        }
      }
      // nothing returned
      return nil
      
    } catch _ {
      // parse error
      return nil
    }
  }
  /// check if a JWT token is valid
  ///
  /// - Parameter jwt:                  a JWT token
  /// - Returns:                        valid / invalid
  ///
  private func isJWTValid(_ jwt: JWT) -> Bool {
    // see: https://auth0.com/docs/tokens/id-token#validate-an-id-token
    // validate only the claims
    
    // 1.
    // Token expiration: The current date/time must be before the expiration date/time listed in the exp claim (which
    // is a Unix timestamp).
    guard let expiresAt = jwt.expiresAt, Date() < expiresAt else { return false }
    
    // 2.
    // Token issuer: The iss claim denotes the issuer of the JWT. The value must match the the URL of your Auth0
    // tenant. For JWTs issued by Auth0, iss holds your Auth0 domain with a https:// prefix and a / suffix:
    // https://YOUR_AUTH0_DOMAIN/.
    var claim = jwt.claim(name: "iss")
    guard let domain = claim.string, domain == Auth0ViewController.kAuth0Domain else { return false }
    
    // 3.
    // Token audience: The aud claim identifies the recipients that the JWT is intended for. The value must match the
    // Client ID of your Auth0 Client.
    claim = jwt.claim(name: "aud")
    guard let clientId = claim.string, clientId == Auth0ViewController.kClientId else { return false }
    
    return true
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(discoveredRadios(_:)), of: .discoveredRadios)

//    NC.makeObserver(self, with: #selector(guiClientHasBeenAdded(_:)), of: .guiClientHasBeenAdded)
//    NC.makeObserver(self, with: #selector(guiClientHasBeenRemoved(_:)), of: .guiClientHasBeenRemoved)
  }
  /// Process .radioDowngrade Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func discoveredRadios(_ note: Notification) {
  
    if let discoveredRadios = note.object as? [DiscoveryPacket] {
      
      self.discoveredRadios = discoveredRadios
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanServer Delegate methods
  
  /// Received radio list from server
  ///
  func wanRadioListReceived(wanRadioList: [DiscoveryPacket]) {
    
    for (i, _) in wanRadioList.enumerated() {
      
      wanRadioList[i].isWan = true
      Discovery.sharedInstance.processPacket(wanRadioList[i])
    }
  }
  /// Received user settings from server
  ///
  /// - Parameter userSettings:         a User Setting struct
  ///
  func wanUserSettings(_ userSettings: WanUserSettings) {
    
      logOnName = userSettings.firstName + " " + userSettings.lastName
      logOnCall = userSettings.callsign
  }
  /// Radio is ready to connect
  ///
  /// - Parameters:
  ///   - handle:                       a Radio handle
  ///   - serial:                       a Radio Serial Number
  ///
  func wanRadioConnectReady(handle: String, serial: String) {
    
    DispatchQueue.main.async { [unowned self] in
      
      guard self._discoveryPacket?.serialNumber == serial, self._delegate != nil else { return }
      self._discoveryPacket!.wanHandle = handle
      // tell the delegate to connect to the selected Radio
      self._delegate!.openRadio(self._discoveryPacket!)
    }
  }
  
  /// Received Wan test results
  ///
  /// - Parameter results:            test results
  ///
  func wanTestConnectionResultsReceived(results: WanTestConnectionResults) {
    
    // was it successful?
    smartLinkTestStatus = (results.forwardTcpPortWorking == true &&
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
    _log.logMessage("SmartLink Test completed \(smartLinkTestStatus ? "successfully" : "with errors")", .info, #function, #file, #line)
  }
}

