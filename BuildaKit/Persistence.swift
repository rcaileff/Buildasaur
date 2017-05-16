//
//  Persistence.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 07/03/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils

open class PersistenceFactory {
    
    open class func migrationPersistenceWithReadingFolder(_ read: URL) -> Persistence {
        
        let name = read.lastPathComponent
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
        let tmp = URL(fileURLWithPath: path, isDirectory: true)
        let fileManager = FileManager.default
        return Persistence(readingFolder: read, writingFolder: tmp, fileManager: fileManager)
    }
    
    open class func createStandardPersistence() -> Persistence {
        
        let folderName = "Buildasaur"
//        let folderName = "Buildasaur-Debug"
        
        let fileManager = FileManager.default
        guard let applicationSupport = fileManager
            .urls(for: .applicationSupportDirectory, in:.userDomainMask)
            .first else {
                preconditionFailure("Couldn't access Builda's persistence folder, aborting")
        }
        let buildaRoot = applicationSupport
            .appendingPathComponent(folderName, isDirectory: true)
        
        let persistence = Persistence(readingFolder: buildaRoot, writingFolder: buildaRoot, fileManager: fileManager)
        return persistence
    }
}

open class Persistence {
    
    open let readingFolder: URL
    open let writingFolder: URL
    open let fileManager: FileManager
    
    public init(readingFolder: URL, writingFolder: URL, fileManager: FileManager) {
        
        self.readingFolder = readingFolder
        self.writingFolder = writingFolder
        self.fileManager = fileManager
        self.ensureFoldersExist()
    }
    
    fileprivate func ensureFoldersExist() {
        
        self.createFolderIfNotExists(self.readingFolder)
        self.createFolderIfNotExists(self.writingFolder)
    }
    
    open func deleteFile(_ name: String) {
        let itemUrl = self.fileURLWithName(name, intention: .writing, isDirectory: false)
        self.delete(itemUrl)
    }
    
    open func deleteFolder(_ name: String) {
        let itemUrl = self.fileURLWithName(name, intention: .writing, isDirectory: true)
        self.delete(itemUrl)
    }
    
    fileprivate func delete(_ url: URL) {
        do {
            try self.fileManager.removeItem(at: url)
        } catch {
            Log.error(error)
        }
    }
    
    func saveData(_ name: String, item: AnyObject) {
        
        let itemUrl = self.fileURLWithName(name, intention: .writing, isDirectory: false)
        let json = item
        do {
            try self.saveJSONToUrl(json, url: itemUrl)
        } catch {
            assert(false, "Failed to save \(name), \(error)")
        }
    }
    
    func saveDictionary(_ name: String, item: NSDictionary) {
        self.saveData(name, item: item)
    }
    
    //crashes when I use [JSONWritable] instead of NSArray :(
    func saveArray(_ name: String, items: NSArray) {
        self.saveData(name, item: items)
    }
    
    func saveArrayIntoFolder<T>(_ folderName: String, items: [T], itemFileName: (_ item: T) -> String, serialize: (_ item: T) -> NSDictionary) {
        
        let folderUrl = self.fileURLWithName(folderName, intention: .writing, isDirectory: true)
        items.forEach { (item: T) -> () in
            
            let json = serialize(item)
            let name = itemFileName(item)
            let url = folderUrl.appendingPathComponent("\(name).json")
            do {
                try self.saveJSONToUrl(json, url: url)
            } catch {
                assert(false, "Failed to save a \(folderName), \(error)")
            }
        }
    }
    
    func saveArrayIntoFolder<T: JSONWritable>(_ folderName: String, items: [T], itemFileName: (_ item: T) -> String) {
        
        self.saveArrayIntoFolder(folderName, items: items, itemFileName: itemFileName) {
            $0.jsonify(<#_#>)
        }
    }
    
    func loadDictionaryFromFile<T>(_ name: String) -> T? {
        return self.loadDataFromFile(name, process: { (json) -> T? in
            
            guard let contents = json as? T else { return nil }
            return contents
        })
    }
    
    func loadArrayFromFile<T>(_ name: String, convert: (_ json: NSDictionary) throws -> T?) -> [T]? {
        
        return self.loadDataFromFile(name, process: { (json) -> [T]? in
            
            guard let json = json as? [NSDictionary] else { return nil }
            
            let allItems = json.map { (item) -> T? in
                do { return try convert(item) } catch { return nil }
            }
            let parsedItems = allItems.filter { $0 != nil }.map { $0! }
            if parsedItems.count != allItems.count {
                Log.error("Some \(name) failed to parse, will be ignored.")
                //maybe show a popup?
            }
            return parsedItems
        })
    }
    
    func loadArrayOfDictionariesFromFile(_ name: String) -> [NSDictionary]? {
        return self.loadArrayFromFile(name, convert: { $0 })
    }
    
    func loadArrayFromFile<T: JSONReadable>(_ name: String) -> [T]? {
        
        return self.loadArrayFromFile(name) { try T(json: $0) }
    }
    
    func loadArrayOfDictionariesFromFolder(_ folderName: String) -> [NSDictionary]? {
        return self.loadArrayFromFolder(folderName) { $0 }
    }
    
    func loadArrayFromFolder<T: JSONReadable>(_ folderName: String) -> [T]? {
        return self.loadArrayFromFolder(folderName) {
            try T(json: $0)
        }
    }
    
    func loadArrayFromFolder<T>(_ folderName: String, parse: (NSDictionary) throws -> T) -> [T]? {
        let folderUrl = self.fileURLWithName(folderName, intention: .reading, isDirectory: true)
        return self.filesInFolder(folderUrl)?.map { (url: URL) -> T? in
            
            do {
                let json = try self.loadJSONFromUrl(url)
                if let json = json as? NSDictionary {
                    let template = try parse(json)
                    return template
                }
            } catch {
                Log.error("Couldn't parse \(folderName) at url \(url), error \(error)")
            }
            return nil
            }.filter { $0 != nil }.map { $0! }
    }
    
    func loadDataFromFile<T>(_ name: String, process: (_ json: AnyObject?) -> T?) -> T? {
        let url = self.fileURLWithName(name, intention: .reading, isDirectory: false)
        do {
            let json = try self.loadJSONFromUrl(url)
            guard let contents = process(json) else { return nil }
            return contents
        } catch {
            //file not found
            if (error as NSError).code != 260 {
                Log.error("Failed to read \(name), error \(error). Will be ignored. Please don't play with the persistence :(")
            }
            return nil
        }
    }
    
    open func loadJSONFromUrl(_ url: URL) throws -> AnyObject? {
        
        let data = try Data(contentsOf: url, options: NSData.ReadingOptions())
        let json: AnyObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
        return json
    }
    
    open func saveJSONToUrl(_ json: AnyObject, url: URL) throws {
        
        let data = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
        try data.write(to: url, options: NSData.WritingOptions.atomic)
    }
    
    open func fileURLWithName(_ name: String, intention: PersistenceIntention, isDirectory: Bool) -> URL {
        
        let root = self.folderForIntention(intention)
        let url = root.appendingPathComponent(name, isDirectory: isDirectory)
        if isDirectory && intention == .writing {
            self.createFolderIfNotExists(url)
        }
        return url
    }
    
    open func copyFileToWriteLocation(_ name: String, isDirectory: Bool) {
        
        let url = self.fileURLWithName(name, intention: .reading, isDirectory: isDirectory)
        let writeUrl = self.fileURLWithName(name, intention: .writingNoCreateFolder, isDirectory: isDirectory)
        
        _ = try? self.fileManager.copyItem(at: url, to: writeUrl)
    }
    
    open func copyFileToFolder(_ fileName: String, folder: String) {
        
        let url = self.fileURLWithName(fileName, intention: .reading, isDirectory: false)
        let writeUrl = self
            .fileURLWithName(folder, intention: .writing, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        
        _ = try? self.fileManager.copyItem(at: url, to: writeUrl)
    }
    
    open func createFolderIfNotExists(_ url: URL) {
        
        let fm = self.fileManager
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Failed to create a folder in Builda's Application Support folder \(url), error \(error)")
        }
    }
    
    public enum PersistenceIntention {
        case reading
        case writing
        case writingNoCreateFolder
    }
    
    func folderForIntention(_ intention: PersistenceIntention) -> URL {
        switch intention {
        case .reading:
            return self.readingFolder
        case .writing, .writingNoCreateFolder:
            return self.writingFolder
        }
    }
    
    open func filesInFolder(_ folderUrl: URL) -> [URL]? {
        
        do {
            let contents = try self.fileManager.contentsOfDirectory(at: folderUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            return contents
        } catch {
            if (error as NSError).code != 260 { //ignore not found errors
                Log.error("Couldn't read folder \(folderUrl), error \(error)")
            }
            return nil
        }
    }
    
}
