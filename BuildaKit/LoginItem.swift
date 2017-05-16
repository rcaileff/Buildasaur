//
//  LoginItem.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/14/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils

//manages adding/removing Buildasaur as a login item

open class LoginItem {
    
    public init() { }
    
    open var isLaunchItem: Bool {
        get {
            return self.hasPlistInstalled()
        }
        set {
            if newValue {
                do {
                    try self.addLaunchItemPlist()
                } catch {
                    Log.error("Error while adding login item: \(error)")
                }
            } else {
                self.removeLaunchItemPlist()
            }
        }
    }
    
    fileprivate func hasPlistInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: self.launchItemPlistURL().path)
    }
    
    fileprivate func launchItemPlistURL() -> URL {
        let path = ("~/Library/LaunchAgents/com.honzadvorsky.Buildasaur.plist" as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path, isDirectory: false)
        return url
    }
    
    fileprivate func currentBinaryPath() -> String {
        
        let processInfo = ProcessInfo.processInfo
        let launchPath = processInfo.arguments.first!
        return launchPath
    }
    
    fileprivate func launchItemPlistWithLaunchPath(_ launchPath: String) throws -> String {
        
        let plistStringUrl = Bundle.main.url(forResource: "launch_item", withExtension: "plist")!
        let plistString = try String(contentsOf: plistStringUrl)
        
        //replace placeholder with launch path
        let patchedPlistString = plistString.replacingOccurrences(of: "LAUNCH_PATH_PLACEHOLDER", with: launchPath)
        return patchedPlistString
    }
    
    open func removeLaunchItemPlist() {
        _ = try? FileManager.default.removeItem(at: self.launchItemPlistURL())
    }
    
    open func addLaunchItemPlist() throws {
        let launchPath = self.currentBinaryPath()
        let contents = try self.launchItemPlistWithLaunchPath(launchPath)
        let url = self.launchItemPlistURL()
        try contents.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    }
    
}
