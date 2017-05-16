//
//  StandardSyncer.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 15/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaGitServer
import XcodeServerSDK
import ReactiveCocoa

open class StandardSyncer : Syncer {
    
    open var sourceServer: SourceServerType
    open var xcodeServer: XcodeServer
    open var project: Project
    open var buildTemplate: BuildTemplate
    open var triggers: [Trigger]
    
    open let config: MutableProperty<SyncerConfig>
    
    open var configTriplet: ConfigTriplet {
        return ConfigTriplet(syncer: self.config.value, server: self.xcodeServer.config, project: self.project.config.value, buildTemplate: self.buildTemplate, triggers: self.triggers.map { $0.config })
    }
    
    public init(integrationServer: XcodeServer, sourceServer: SourceServerType, project: Project, buildTemplate: BuildTemplate, triggers: [Trigger], config: SyncerConfig) {

        self.config = MutableProperty<SyncerConfig>(config)

        self.sourceServer = sourceServer
        self.xcodeServer = integrationServer
        self.project = project
        self.buildTemplate = buildTemplate
        self.triggers = triggers
        
        super.init(syncInterval: config.syncInterval)
        
        self.config.producer.startWithNext { [weak self] in
            self?.syncInterval = $0.syncInterval
        }
    }
    
    deinit {
        self.active = false
    }
    
    open override func sync(_ completion: () -> ()) {
        
        if let repoName = self.repoName() {
            
            self.syncRepoWithName(repoName, completion: completion)
        } else {
            self.notifyErrorString("Nil repo name", context: "Syncing")
            completion()
        }
    }
}

