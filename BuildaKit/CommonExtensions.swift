//
//  CommonExtensions.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 17/02/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation

public func firstNonNil<T>(_ objects: [T?]) -> T? {
    for i in objects {
        if let i = i {
            return i
        }
    }
    return nil
}

extension Set {
    
    public func filterSet(_ includeElement: (Element) -> Bool) -> Set<Element> {
        return Set(self.filter(includeElement))
    }
}

extension Array {
    
    public func indexOfFirstObjectPassingTest(_ test: (Element) -> Bool) -> Array<Element>.Index? {
        
        for (idx, obj) in self.enumerated() {
            if test(obj) {
                return idx
            }
        }
        return nil
    }
    
    public func firstObjectPassingTest(_ test: (Element) -> Bool) -> Element? {
        for item in self {
            if test(item) {
                return item
            }
        }
        return nil
    }
}

extension Array {
    
    public func mapVoidAsync(_ transformAsync: (_ item: Element, _ itemCompletion: () -> ()) -> (), completion: @escaping () -> ()) {
        self.mapAsync(transformAsync, completion: { (_) -> () in
            completion()
        })
    }
    
    public func mapAsync<U>(_ transformAsync: (_ item: Element, _ itemCompletion: (U) -> ()) -> (), completion: @escaping ([U]) -> ()) {
        
        let group = DispatchGroup()
        var returnedValueMap = [Int: U]()
        
        for (index, element) in self.enumerated() {
            group.enter()
            transformAsync(element, {
                (returned: U) -> () in
                returnedValueMap[index] = returned
                group.leave()
            })
        }
        
        group.notify(queue: DispatchQueue.main) {
            
            //we have all the returned values in a map, put it back into an array of Us
            var returnedValues = [U]()
            for i in 0 ..< returnedValueMap.count {
                returnedValues.append(returnedValueMap[i]!)
            }
            completion(returnedValues)
        }
    }
}

extension Array {
    
    //dictionarify an array for fast lookup by a specific key
    public func toDictionary(_ key: (Element) -> String) -> [String: Element] {
        
        var dict = [String: Element]()
        for i in self {
            dict[key(i)] = i
        }
        return dict
    }
}

public enum NSDictionaryParseError: Error {
    case missingValueForKey(key: String)
    case wrongTypeOfValueForKey(key: String, value: AnyObject)
}

extension NSDictionary {
    
    public func get<T>(_ key: String) throws -> T {
        
        guard let value = self[key] else {
            throw NSDictionaryParseError.missingValueForKey(key: key)
        }
        
        guard let typedValue = value as? T else {
            throw NSDictionaryParseError.wrongTypeOfValueForKey(key: key, value: value as AnyObject)
        }
        return typedValue
    }
    
    public func getOptionally<T>(_ key: String) throws -> T? {
        
        guard let value = self[key] else {
            return nil
        }
        
        guard let typedValue = value as? T else {
            throw NSDictionaryParseError.wrongTypeOfValueForKey(key: key, value: value as AnyObject)
        }
        return typedValue
    }
}

extension Array {
    
    public func dictionarifyWithKey(_ key: @escaping (_ item: Element) -> String) -> [String: Element] {
        var dict = [String: Element]()
        self.forEach { dict[key($0)] = $0 }
        return dict
    }
}

extension String {
    
    //returns nil if string is empty
    public func nonEmpty() -> String? {
        return self.isEmpty ? nil : self
    }
}

public func delayClosure(_ delay: Double, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)
}


