//
//  XcodeProjectParser.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 24/01/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils

open class XcodeProjectParser {
    
    static fileprivate var sourceControlFileParsers: [SourceControlFileParser] = [
        CheckoutFileParser(),
        BlueprintFileParser(),
    ]
    
    fileprivate class func firstItemMatchingTestRecursive(_ url: URL, test: (_ itemUrl: URL) -> Bool) throws -> URL? {
        
        let fm = FileManager.default
        
        if let path = url.path {
            
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
            if !exists {
                return nil
            }
            
            if !isDir {
                //not dir, test
                return test(url) ? url : nil
            }
            
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
            for i in contents {
                if let foundUrl = try self.firstItemMatchingTestRecursive(i, test: test) {
                    return foundUrl
                }
            }
        }
        return nil
    }
    
    fileprivate class func firstItemMatchingTest(_ url: URL, test: (_ itemUrl: URL) -> Bool) throws -> URL? {
        
        return try self.allItemsMatchingTest(url, test: test).first
    }

    fileprivate class func allItemsMatchingTest(_ url: URL, test: (_ itemUrl: URL) -> Bool) throws -> [URL] {
        
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
        
        let filtered = contents.filter(test)
        return filtered
    }
    
    fileprivate class func findCheckoutOrBlueprintUrl(_ projectOrWorkspaceUrl: URL) throws -> URL {
        
        if let found = try self.firstItemMatchingTestRecursive(projectOrWorkspaceUrl, test: { (itemUrl: URL) -> Bool in
            
            let pathExtension = itemUrl.pathExtension
            return pathExtension == "xccheckout" || pathExtension == "xcscmblueprint"
        }) {
            return found
        }
        throw Error.withInfo("No xccheckout or xcscmblueprint file found")
    }
    
    fileprivate class func parseCheckoutOrBlueprintFile(_ url: URL) throws -> WorkspaceMetadata {
        
        let pathExtension = url.pathExtension
        
        let maybeParser = self.sourceControlFileParsers.filter {
            Set($0.supportedFileExtensions()).contains(pathExtension)
        }.first
        guard let parser = maybeParser else {
            throw Error.withInfo("Could not find a parser for path extension \(pathExtension)")
        }
        
        let parsedWorkspace = try parser.parseFileAtUrl(url)
        return parsedWorkspace
    }
    
    open class func parseRepoMetadataFromProjectOrWorkspaceURL(_ url: URL) throws -> WorkspaceMetadata {
        
        do {
            let checkoutUrl = try self.findCheckoutOrBlueprintUrl(url)
            let parsed = try self.parseCheckoutOrBlueprintFile(checkoutUrl)
            return parsed
        } catch {
            
            //failed to find a checkout/blueprint file, attempt to parse from repo manually
            let parser = GitRepoMetadataParser()
            
            do {
                return try parser.parseFileAtUrl(url)
            } catch {
                //no we're definitely unable to parse workspace metadata
                throw Error.withInfo("Cannot find the Checkout/Blueprint file and failed to parse repository metadata directly. Please create an issue on GitHub with anonymized information about your repository. (Error \((error as NSError).localizedDescription))")
            }
        }
    }
    
    open class func sharedSchemesFromProjectOrWorkspaceUrl(_ url: URL) -> [XcodeScheme] {
        
        var projectUrls: [URL]
        if self.isWorkspaceUrl(url) {
            //first parse project urls from workspace contents
            projectUrls = self.projectUrlsFromWorkspace(url) ?? [URL]()
            
            //also add the workspace's url, it might own some schemes as well
            projectUrls.append(url)
            
        } else {
            //this already is a project url, take just that
            projectUrls = [url]
        }
        
        //we have the project urls, now let's parse schemes from each of them
        let schemes = projectUrls.map {
            return self.sharedSchemeUrlsFromProjectUrl($0)
        }.reduce([XcodeScheme](), { (arr, newSchemes) -> [XcodeScheme] in
            return arr + newSchemes
        })
        
        return schemes
    }
    
    fileprivate class func sharedSchemeUrlsFromProjectUrl(_ url: URL) -> [XcodeScheme] {
        
        //the structure is
        //in a project file, if there are any shared schemes, they will be in
        //xcshareddata/xcschemes/*
        do {
            if let sharedDataFolder = try self.firstItemMatchingTest(url,
                test: { (itemUrl: URL) -> Bool in
                    
                    return itemUrl.lastPathComponent == "xcshareddata"
            }) {
                
                if let schemesFolder = try self.firstItemMatchingTest(sharedDataFolder,
                    test: { (itemUrl: URL) -> Bool in
                        
                        return itemUrl.lastPathComponent == "xcschemes"
                }) {
                    //we have the right folder, yay! just filter all files ending with xcscheme
                    let schemeUrls = try self.allItemsMatchingTest(schemesFolder, test: { (itemUrl: URL) -> Bool in
                        let ext = itemUrl.pathExtension ?? ""
                        return ext == "xcscheme"
                    })
                    let schemes = schemeUrls.map { XcodeScheme(path: $0, ownerProjectOrWorkspace: url) }
                    return schemes
                }
            }
        } catch {
            Log.error(error)
        }
        return []
    }
    
    fileprivate class func isProjectUrl(_ url: URL) -> Bool {
        return url.pathExtension == "xcodeproj"
    }

    fileprivate class func isWorkspaceUrl(_ url: URL) -> Bool {
        return url.pathExtension == "xcworkspace"
    }

    fileprivate class func projectUrlsFromWorkspace(_ url: URL) -> [URL]? {
        
        assert(self.isWorkspaceUrl(url), "Url \(url) is not a workspace url")
        
        do {
            let urls = try XcodeProjectXMLParser.parseProjectsInsideOfWorkspace(url)
            return urls
        } catch {
            Log.error("Couldn't load workspace at path \(url) with error \(error)")
            return nil
        }
    }
    
    fileprivate class func parseSharedSchemesFromProjectURL(_ url: URL) -> (schemeUrls: [URL]?, error: NSError?) {
        
        return (schemeUrls: [URL](), error: nil)
    }
    
}

