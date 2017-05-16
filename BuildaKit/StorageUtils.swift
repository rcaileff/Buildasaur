//
//  Utils.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 24/01/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import Cocoa
import BuildaUtils
import XcodeServerSDK

open class StorageUtils {
    
    open class func openWorkspaceOrProject() -> URL? {
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["xcworkspace", "xcodeproj"]
        openPanel.title = "Select your Project or Workspace"
        
        let clicked = openPanel.runModal()
        
        switch clicked {
        case NSFileHandlingPanelOKButton:
            let url = openPanel.url
            let urlOrEmpty = url ?? URL()
            Log.info("Project: \(urlOrEmpty)")
            return url
        default:
            //do nothing
            Log.verbose("Dismissed open dialog")
        }
        return nil
    }
    
    open class func openSSHKey(_ publicOrPrivate: String) -> URL? {
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["", "pub"]
        openPanel.title = "Select your \(publicOrPrivate) SSH key"
        openPanel.showsHiddenFiles = true
        
        let clicked = openPanel.runModal()
        
        switch clicked {
        case NSFileHandlingPanelOKButton:
            let url = openPanel.url
            Log.info("Key: \(url)")
            return url
        default:
            //do nothing
            Log.verbose("Dismissed open dialog")
        }
        return nil
    }
    
}

