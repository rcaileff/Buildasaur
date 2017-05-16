//
//  SyncPairExtensions.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 19/05/15.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import XcodeServerSDK
import BuildaGitServer
import BuildaUtils

extension SyncPair {
    
    public struct Actions {
        public let integrationsToCancel: [Integration]?
        public let statusToSet: (status: StatusAndComment, commit: String, issue: IssueType?)?
        public let startNewIntegrationBot: Bot? //if non-nil, starts a new integration on this bot
    }

    func performActions(_ actions: Actions, completion: @escaping Completion) {
        
        let group = DispatchGroup()
        var lastGroupError: NSError?
        
        if let integrationsToCancel = actions.integrationsToCancel {
            
            group.enter()
            self.syncer.cancelIntegrations(integrationsToCancel, completion: { () -> () in
                group.leave()
            })
        }
        
        if let newStatus = actions.statusToSet {
            
            let status = newStatus.status
            let commit = newStatus.commit
            let issue = newStatus.issue
            
            group.enter()
            self.syncer.updateCommitStatusIfNecessary(status, commit: commit, issue: issue, completion: { (error) -> () in
                if let error = error {
                    lastGroupError = error
                }
                dispatch_group_leave(group)
            })
        }
        
        if let startNewIntegrationBot = actions.startNewIntegrationBot {
            
            let bot = startNewIntegrationBot
            
            group.enter()
            self.syncer._xcodeServer.postIntegration(bot.id, completion: { (integration, error) -> () in
                
                if let integration = integration, error == nil {
                    Log.info("Bot \(bot.name) successfully enqueued Integration #\(integration.number)")
                } else {
                    let e = Error.withInfo("Bot \(bot.name) failed to enqueue an integration", internalError: error)
                    lastGroupError = e
                }
                
                dispatch_group_leave(group)
            })
        }
        
        group.notify(queue: DispatchQueue.main, execute: {
            completion(lastGroupError)
        })
    }
    
    //MARK: Utility functions
    
    func getIntegrations(_ bot: Bot, completion: (_ integrations: [Integration], _ error: NSError?) -> ()) {
        
        let syncer = self.syncer
        
        /*
        TODO: we should establish some reliable and reasonable plan for how many integrations to fetch.
        currently it's always 20, but some setups might have a crazy workflow with very frequent commits
        on active bots etc.
        */
        let query = [
            "last": "20"
        ]
        syncer._xcodeServer.getBotIntegrations(bot.id, query: query, completion: { (integrations, error) -> () in
            
            if let error = error {
                let e = Error.withInfo("Bot \(bot.name) failed return integrations", internalError: error)
                completion(integrations: [], error: e)
                return
            }
            
            if let integrations = integrations {
                
                completion(integrations: integrations, error: nil)
                
            } else {
                let e = Error.withInfo("Getting integrations", internalError: Error.withInfo("Nil integrations even after returning nil error!"))
                completion(integrations: [], error: e)
            }
        })
    }


}
