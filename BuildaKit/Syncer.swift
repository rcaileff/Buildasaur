//
//  Syncer.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 14/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils
import XcodeServerSDK
import ReactiveCocoa

public enum SyncerEventType {
    
    case initial
    
    case didBecomeActive
    case didStop
    
    case didStartSyncing
    case didFinishSyncing(Error?)
    
    case didEncounterError(Error)
}

class Trampoline: NSObject {
    
    var block: (() -> ())? = nil
    func jump() { self.block?() }
}

@objc open class Syncer: NSObject {
    
    open let state = MutableProperty<SyncerEventType>(.Initial)
    
    //public
    open internal(set) var reports: [String: String] = [:]
    open fileprivate(set) var lastSuccessfulSyncFinishedDate: Date?
    open fileprivate(set) var lastSyncFinishedDate: Date?
    open fileprivate(set) var lastSyncStartDate: Date?
    open fileprivate(set) var lastSyncError: NSError?
    
    fileprivate var currentSyncError: NSError?
    
    /// How often, in seconds, the syncer should pull data from both sources and resolve pending actions
    open var syncInterval: TimeInterval
    
    fileprivate var isSyncing: Bool {
        didSet {
            if !oldValue && self.isSyncing {
                self.lastSyncStartDate = Date()
                self.state.value = .DidStartSyncing
            } else if oldValue && !self.isSyncing {
                self.lastSyncFinishedDate = Date()
                self.state.value = .DidFinishSyncing(self.lastSyncError)
            }
        }
    }
    
    open var active: Bool {
        didSet {
            if active && !oldValue {
                let s = #selector(Trampoline.jump)
                let timer = Timer(timeInterval: self.syncInterval, target: self.trampoline, selector: s, userInfo: nil, repeats: true)
                self.timer = timer
                RunLoop.main.add(timer, forMode: CFRunLoopMode.commonModes as String)
                self._sync() //call for the first time, next one will be called by the timer
                self.state.value = .DidBecomeActive
            } else if !active && oldValue {
                self.timer?.invalidate()
                self.timer = nil
                self.state.value = .DidStop
            }
            self.activeSignalProducer.value = active
        }
    }
    
    //TODO: shouldn't be a mutableproperty, because nothing happens
    //when you actually set it (the syncer isn't affected). only using
    //for observing the active state from the outside world.
    open let activeSignalProducer = MutableProperty<Bool>(false)

    //private
    var timer: Timer?
    fileprivate let trampoline: Trampoline

    //---------------------------------------------------------
    
    public init(syncInterval: TimeInterval) {
        self.syncInterval = syncInterval
        self.active = false
        self.isSyncing = false
        self.trampoline = Trampoline()
        super.init()
        self.trampoline.block = { [weak self] () -> () in
            self?._sync()
        }
    }
    
    func _sync() {
        
        //this shouldn't even be getting called now
        if !self.active {
            self.timer?.invalidate()
            self.timer = nil
            return
        }

        if self.isSyncing {
            //already is syncing, wait till it's finished
            Log.info("Trying to sync again even though the previous sync hasn't finished. You might want to consider making the sync interval longer. Just sayin'")
            return
        }
        
        Log.untouched("\n------------------------------------\n")
        
        self.isSyncing = true
        self.currentSyncError = nil
        self.reports.removeAll(keepingCapacity: true)
        
        let start = Date()
        Log.info("Sync starting at \(start)")
        
        self.sync { () -> () in
            
            let end = Date()
            let finishState: String
            if let error = self.currentSyncError {
                finishState = "with error"
                self.lastSyncError = error
            } else {
                finishState = "successfully"
                self.lastSyncError = nil
                self.lastSuccessfulSyncFinishedDate = Date()
            }
            Log.info("Sync finished \(finishState) at \(end), took \(end.timeIntervalSinceDate(start).clipTo(3)) seconds.")
            self.isSyncing = false
        }
    }
    
    func notifyErrorString(_ errorString: String, context: String?) {
        self.notifyError(Error.withInfo(errorString), context: context)
    }
    
    func notifyError(_ error: Error?, context: String?) {
        self.notifyError(error as? NSError, context: context)
    }
    
    func notifyError(_ error: NSError?, context: String?) {
        
        var message = "Syncing encountered a problem. "
        
        if let error = error {
            message += "Error: \(error.localizedDescription). "
        }
        if let context = context {
            message += "Context: \(context)"
        }
        Log.error(message)
        self.currentSyncError = error
        self.state.value = .DidEncounterError(Error.withInfo(message))
    }
    
    /**
    To be overriden by subclasses to do their logic in
    */
    open func sync(_ completion: () -> ()) {
        //sync logic here
        assertionFailure("Should be overriden by subclasses")
    }
}
