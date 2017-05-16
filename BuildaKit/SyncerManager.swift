//
//  SyncerManager.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/3/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import XcodeServerSDK
import BuildaHeartbeatKit
import BuildaUtils

//owns running syncers and their children, manages starting/stopping them,
//creating them from configurations

open class SyncerManager {
    
    open let storageManager: StorageManager
    open let factory: SyncerFactoryType
    open let loginItem: LoginItem
    
    open let syncersProducer: SignalProducer<[StandardSyncer], NoError>
    open let projectsProducer: SignalProducer<[Project], NoError>
    open let serversProducer: SignalProducer<[XcodeServer], NoError>
    
    open let buildTemplatesProducer: SignalProducer<[BuildTemplate], NoError>
    open let triggerProducer: SignalProducer<[Trigger], NoError>
    
    open var syncers: [StandardSyncer]
    fileprivate var configTriplets: SignalProducer<[ConfigTriplet], NoError>
    open var heartbeatManager: HeartbeatManager?

    public init(storageManager: StorageManager, factory: SyncerFactoryType, loginItem: LoginItem) {
        
        self.storageManager = storageManager
        self.loginItem = loginItem
        
        self.factory = factory
        self.syncers = []
        let configTriplets = SyncerProducerFactory.createTripletsProducer(storageManager)
        self.configTriplets = configTriplets
        let syncersProducer = SyncerProducerFactory.createSyncersProducer(factory, triplets: configTriplets)
        
        self.syncersProducer = syncersProducer
        
        let justProjects = storageManager.projectConfigs.producer.map { $0.map { $0.1 } }
        let justServers = storageManager.serverConfigs.producer.map { $0.map { $0.1 } }
        let justBuildTemplates = storageManager.buildTemplates.producer.map { $0.map { $0.1 } }
        let justTriggerConfigs = storageManager.triggerConfigs.producer.map { $0.map { $0.1 } }
        
        self.projectsProducer = SyncerProducerFactory.createProjectsProducer(factory, configs: justProjects)
        self.serversProducer = SyncerProducerFactory.createServersProducer(factory, configs: justServers)
        self.buildTemplatesProducer = SyncerProducerFactory.createBuildTemplateProducer(factory, templates: justBuildTemplates)
        self.triggerProducer = SyncerProducerFactory.createTriggersProducer(factory, configs: justTriggerConfigs)
        
        syncersProducer.startWithNext { [weak self] in self?.syncers = $0 }
        self.checkForAutostart()
        self.setupHeartbeatManager()
    }
    
    fileprivate func setupHeartbeatManager() {
        if let heartbeatOptOut = self.storageManager.config.value["heartbeat_opt_out"] as? Bool, heartbeatOptOut {
            Log.info("User opted out of anonymous heartbeat")
        } else {
            Log.info("Will send anonymous heartbeat. To opt out add `\"heartbeat_opt_out\" = true` to ~/Library/Application Support/Buildasaur/Config.json")
            self.heartbeatManager = HeartbeatManager(server: "https://builda-ekg.herokuapp.com")
            self.heartbeatManager!.delegate = self
            self.heartbeatManager!.start()
        }
    }
    
    fileprivate func checkForAutostart() {
        guard let autostart = self.storageManager.config.value["autostart"] as? Bool, autostart else { return }
        self.syncers.forEach { $0.active = true }
    }
    
    open func xcodeServerWithRef(_ ref: RefType) -> SignalProducer<XcodeServer?, NoError> {
        
        return self.serversProducer.map { allServers -> XcodeServer? in
            return allServers.filter { $0.config.id == ref }.first
        }
    }
    
    open func projectWithRef(_ ref: RefType) -> SignalProducer<Project?, NoError> {
        
        return self.projectsProducer.map { allProjects -> Project? in
            return allProjects.filter { $0.config.value.id == ref }.first
        }
    }
    
    open func syncerWithRef(_ ref: RefType) -> SignalProducer<StandardSyncer?, NoError> {
        
        return self.syncersProducer.map { allSyncers -> StandardSyncer? in
            return allSyncers.filter { $0.config.value.id == ref }.first
        }
    }

    deinit {
        self.stopSyncers()
    }
    
    open func startSyncers() {
        self.syncers.forEach { $0.active = true }
    }

    open func stopSyncers() {
        self.syncers.forEach { $0.active = false }
    }
}

extension SyncerManager: HeartbeatManagerDelegate {
    
    public func typesOfRunningSyncers() -> [String : Int] {
        return self.syncers.filter { $0.active }.reduce([:]) { (all, syncer) -> [String: Int] in
            var stats = all
            let syncerType = syncer._project.workspaceMetadata!.service.type()
            stats[syncerType] = (stats[syncerType] ?? 0) + 1
            return stats
        }
    }
}
