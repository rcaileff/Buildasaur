//
//  XcodeProjectXMLParser.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 02/10/2015.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import Ji

class XcodeProjectXMLParser {
    
    enum WorkspaceParsingError: Error {
        case parsingFailed
        case failedToFindWorkspaceNode
        case noProjectsFound
        case noLocationInProjectFound
    }
    
    static func parseProjectsInsideOfWorkspace(_ url: URL) throws -> [URL] {
        
        let contentsUrl = url.appendingPathComponent("contents.xcworkspacedata")
        
        guard let jiDoc = Ji(contentsOfURL: contentsUrl!, isXML: true) else { throw WorkspaceParsingError.parsingFailed }
        guard
            let workspaceNode = jiDoc.rootNode,
            let workspaceTag = workspaceNode.tag, workspaceTag == "Workspace" else { throw WorkspaceParsingError.failedToFindWorkspaceNode }
        
        let projects = workspaceNode.childrenWithName("FileRef")
        guard projects.count > 0 else { throw WorkspaceParsingError.noProjectsFound }
        
        let locations = try projects.map { projectNode throws -> String in
            guard let location = projectNode["location"] else { throw WorkspaceParsingError.NoLocationInProjectFound }
            return location
        }
        
        let parsedRelativePaths = locations.map { $0.componentsSeparatedByString(":").last! }
        let absolutePaths = parsedRelativePaths.map { return url.URLByAppendingPathComponent("..")!.URLByAppendingPathComponent($0)! }
        return absolutePaths
    }
}
