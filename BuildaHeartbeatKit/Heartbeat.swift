//
//  Heartbeat.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 17/09/2015.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import ekgclient
import BuildaUtils

public protocol HeartbeatManagerDelegate {
    func typesOfRunningSyncers() -> [String: Int]
}

//READ: https://github.com/czechboy0/Buildasaur/tree/master#heartpulse-heartbeat
@objc open class HeartbeatManager: NSObject {
    
    open var delegate: HeartbeatManagerDelegate?
    
    fileprivate let client: EkgClient
    fileprivate let creationTime: Double
    fileprivate var timer: Timer?
    fileprivate var initialTimer: Timer?
    fileprivate let interval: Double = 24 * 60 * 60 //send heartbeat once in 24 hours
    
    public init(server: String) {
        let bundle = Bundle.main
        let appIdentifier = EkgClientHelper.pullAppIdentifierFromBundle(bundle) ?? "Unknown app"
        let version = EkgClientHelper.pullVersionFromBundle(bundle) ?? "?"
        let buildNumber = EkgClientHelper.pullBuildNumberFromBundle(bundle) ?? "?"
        let appInfo = AppInfo(appIdentifier: appIdentifier, version: version, build: buildNumber)
        let host = URL(string: server)!
        let serverInfo = ServerInfo(host: host)
        let userDefaults = UserDefaults.standard
        
        self.creationTime = Date().timeIntervalSince1970
        let client = EkgClient(userDefaults: userDefaults, appInfo: appInfo, serverInfo: serverInfo)
        self.client = client
    }
    
    deinit {
        self.stop()
    }
    
    open func start() {
        self.sendLaunchedEvent()
        self.startSendingHeartbeat()
    }
    
    open func stop() {
        self.stopSendingHeartbeat()
    }
    
    open func willInstallSparkleUpdate() {
        self.sendEvent(UpdateEvent())
    }
    
    fileprivate func sendEvent(_ event: Event) {
        
        Log.info("Sending heartbeat event \(event.jsonify())")
        
        self.client.sendEvent(event) {
            if let error = $0 {
                Log.error("Failed to send a heartbeat event. Error \(error)")
            }
        }
    }
    
    fileprivate func sendLaunchedEvent() {
        self.sendEvent(LaunchEvent())
    }
    
    fileprivate func sendHeartbeatEvent() {
        let uptime = Date().timeIntervalSince1970 - self.creationTime
        let typesOfRunningSyncers = self.delegate?.typesOfRunningSyncers() ?? [:]
        self.sendEvent(HeartbeatEvent(uptime: uptime, typesOfRunningSyncers: typesOfRunningSyncers))
    }
    
    func _timerFired(_ timer: Timer?=nil) {
        self.sendHeartbeatEvent()
        
        if let initialTimer = self.initialTimer, initialTimer.isValid {
            initialTimer.invalidate()
            self.initialTimer = nil
        }
    }
    
    fileprivate func startSendingHeartbeat() {
        
        //send once in 10 seconds to give builda a chance to init and start
        self.initialTimer?.invalidate()
        self.initialTimer = Timer.scheduledTimer(
            timeInterval: 20,
            target: self,
            selector: #selector(_timerFired(_:)),
            userInfo: nil,
            repeats: false)
        
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(
            timeInterval: self.interval,
            target: self,
            selector: #selector(_timerFired(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    fileprivate func stopSendingHeartbeat() {
        self.timer?.invalidate()
    }
}
