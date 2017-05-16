//
//  XcodeDeviceParser.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 30/06/2015.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import XcodeServerSDK
import BuildaUtils

open class XcodeDeviceParser {
    
    public enum DeviceType: String {
        case iPhoneOS = "iphoneos"
        case macOSX = "macosx"
        case watchOS = "watchos"
        case tvOS = "appletvos"
        
        public func toPlatformType() -> DevicePlatform.PlatformType {
            switch self {
            case .iPhoneOS:
                return .iOS
            case .macOSX:
                return .OSX
            case .watchOS:
                return .watchOS
            case .tvOS:
                return .tvOS
            }
        }
    }
    
    open class func parseDeviceTypeFromProjectUrlAndScheme(_ projectUrl: URL, scheme: XcodeScheme) throws -> DeviceType {
        
        let typeString = try self.parseTargetTypeFromSchemeAndProjectAtUrl(scheme, projectFolderUrl: projectUrl)
        guard let deviceType = DeviceType(rawValue: typeString) else {
            throw Error.withInfo("Unrecognized type: \(typeString)")
        }
        return deviceType
    }
    
    fileprivate class func parseTargetTypeFromSchemeAndProjectAtUrl(_ scheme: XcodeScheme, projectFolderUrl: URL) throws -> String {
        
        let ownerArgs = try { () throws -> String in
            
            let ownerUrl = scheme.ownerProjectOrWorkspace.path!
            switch (scheme.ownerProjectOrWorkspace.lastPathComponent! as NSString).pathExtension {
                case "xcworkspace":
                return "-workspace \"\(ownerUrl)\""
                case "xcodeproj":
                return "-project \"\(ownerUrl)\""
            default: throw Error.withInfo("Unrecognized project/workspace path \(ownerUrl)")
            }
            }()
        
        let folder = projectFolderUrl.deletingLastPathComponent().path ?? "~"
        let schemeName = scheme.name
        
        let script = "cd \"\(folder)\"; xcodebuild \(ownerArgs) -scheme \"\(schemeName)\" -showBuildSettings 2>/dev/null | egrep '^\\s*PLATFORM_NAME' | cut -d = -f 2 | uniq | xargs echo"
        let res = Script.runTemporaryScript(script)
        if res.terminationStatus == 0 {
            let deviceType = res.standardOutput.stripTrailingNewline()
            return deviceType
        }
        throw Error.withInfo("Termination status: \(res.terminationStatus), output: \(res.standardOutput), error: \(res.standardError)")
    }
}
