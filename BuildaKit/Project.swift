//
//  Project.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 14/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils
import XcodeServerSDK
import ReactiveCocoa

open class Project {
    
    open var url: URL {
        return URL(fileURLWithPath: self._config.url, isDirectory: true)
    }
    
    open let config: MutableProperty<ProjectConfig>
    
    fileprivate var _config: ProjectConfig {
        return self.config.value
    }
    
    open var urlString: String { return self.url.absoluteString }
    open var privateSSHKey: String? { return self.getContentsOfKeyAtPath(self._config.privateSSHKeyPath) }
    open var publicSSHKey: String? { return self.getContentsOfKeyAtPath(self._config.publicSSHKeyPath) }
    
    open var availabilityState: AvailabilityCheckState = .Unchecked
    
    fileprivate(set) open var workspaceMetadata: WorkspaceMetadata?
    
    public init(config: ProjectConfig) throws {
        
        self.config = MutableProperty<ProjectConfig>(config)
        self.setupBindings()
        try self.refreshMetadata()
    }
    
    fileprivate init(original: Project, forkOriginURL: String) throws {
        
        self.config = MutableProperty<ProjectConfig>(original.config.value)
        self.workspaceMetadata = try original.workspaceMetadata?.duplicateWithForkURL(forkOriginURL)
    }
    
    fileprivate func setupBindings() {
        
        self.config.producer.startWithNext { [weak self] _ in
            _ = try? self?.refreshMetadata()
        }
    }
    
    open func duplicateForForkAtOriginURL(_ forkURL: String) throws -> Project {
        return try Project(original: self, forkOriginURL: forkURL)
    }
    
    open class func attemptToParseFromUrl(_ url: URL) throws -> WorkspaceMetadata {
        return try Project.loadWorkspaceMetadata(url)
    }

    fileprivate func refreshMetadata() throws {
        let meta = try Project.attemptToParseFromUrl(self.url)
        self.workspaceMetadata = meta
    }
    
    open func schemes() -> [XcodeScheme] {
        
        let schemes = XcodeProjectParser.sharedSchemesFromProjectOrWorkspaceUrl(self.url)
        return schemes
    }
    
    fileprivate class func loadWorkspaceMetadata(_ url: URL) throws -> WorkspaceMetadata {
        
        return try XcodeProjectParser.parseRepoMetadataFromProjectOrWorkspaceURL(url)
    }
    
    open func serviceRepoName() -> String? {
        
        guard let meta = self.workspaceMetadata else { return nil }
        
        let projectUrl = meta.projectURL
        let service = meta.service
        
        let originalStringUrl = projectUrl.absoluteString
        let stringUrl = originalStringUrl!.lowercased()
        
        /*
        both https and ssh repos on github have a form of:
        {https://|git@}SERVICE_URL{:|/}organization/repo.git
        here I need the organization/repo bit, which I'll do by finding "SERVICE_URL" and shifting right by one
        and scan up until ".git"
        */
        
        let serviceUrl = service.hostname().lowercaseString
        let dotGitRange = stringUrl.range(of: ".git", options: NSString.CompareOptions.backwards, range: nil, locale: nil) ?? stringUrl.endIndex..<stringUrl.endIndex
        if let githubRange = stringUrl.rangeOfString(serviceUrl, options: NSString.CompareOptions(), range: nil, locale: nil){
                
                let start = githubRange.endIndex.advancedBy(1)
                let end = dotGitRange.lowerBound
            
                let repoName = originalStringUrl![start ..< end]
                return repoName
        }
        return nil
    }

    fileprivate func getContentsOfKeyAtPath(_ path: String) -> String? {
        
        let url = URL(fileURLWithPath: path)
        do {
            let key = try NSString(contentsOf: url, encoding: String.Encoding.ascii.rawValue)
            return key as String
        } catch {
            Log.error("Couldn't load key at url \(url) with error \(error)")
        }
        return nil
    }

}

