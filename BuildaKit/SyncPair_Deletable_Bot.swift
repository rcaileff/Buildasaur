//
//  SyncPair_Deletable_Bot.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 16/05/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaGitServer
import XcodeServerSDK

class SyncPair_Deletable_Bot: SyncPair {
    
    let bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
        super.init()
    }
    
    override func sync(_ completion: Completion) {
        
        //delete the bot
        let syncer = self.syncer
        let bot = self.bot
        
        SyncPair_Deletable_Bot.deleteBot(syncer: syncer, bot: bot, completion: completion)
    }
    
    override func syncPairName() -> String {
        return "Deletable Bot (\(self.bot.name))"
    }
    
    fileprivate class func deleteBot(syncer: StandardSyncer, bot: Bot, completion: @escaping Completion) {
        
        syncer.deleteBot(bot, completion: { () -> () in
            completion(error: nil)
        })
    }
}
