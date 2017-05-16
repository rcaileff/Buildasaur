//
//  GitSourcePublic.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 12/12/2014.
//  Copyright (c) 2014 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils
import Keys
import ReactiveCocoa
import Result

public enum GitService {
    case gitHub
    case enterpriseGitHub(host: String)
    case bitBucket
//    case GitLab = "gitlab"

    public func type() -> String {
        switch self {
        case .gitHub: return "github"
        case .enterpriseGitHub: return "enterprisegithub"
        case .bitBucket: return "bitbucket"
        }
    }

    public func prettyName() -> String {
        switch self {
        case .gitHub: return "GitHub"
        case .enterpriseGitHub: return "EnterpriseGitHub"
        case .bitBucket: return "BitBucket"
        }
    }
    
    public func logoName() -> String {
        switch self {
        case .gitHub: return "github"
        case .enterpriseGitHub: return "enterprisegithub"
        case .bitBucket: return "bitbucket"
        }
    }
    
    public func hostname() -> String {
        switch self {
        case .gitHub: return "github.com"
        case .enterpriseGitHub(let host): return host
        case .bitBucket: return "bitbucket.org"
        }
    }
    
    public func authorizeUrl() -> String {
        switch self {
        case .gitHub: return "https://github.com/login/oauth/authorize"
        case .enterpriseGitHub: assert(false)
        case .bitBucket: return "https://bitbucket.org/site/oauth2/authorize"
        }
    }
    
    public func accessTokenUrl() -> String {
        switch self {
        case .gitHub: return "https://github.com/login/oauth/access_token"
        case .enterpriseGitHub: assert(false)
        case .bitBucket: return "https://bitbucket.org/site/oauth2/access_token"
        }
    }
    
    public func serviceKey() -> String {
        switch self {
        case .gitHub: return BuildasaurxcodeprojKeys().gitHubAPIClientId()
        case .enterpriseGitHub: assert(false)
        case .bitBucket: return BuildasaurxcodeprojKeys().bitBucketAPIClientId()
        }
    }
    
    public func serviceSecret() -> String {
        switch self {
        case .gitHub: return BuildasaurxcodeprojKeys().gitHubAPIClientSecret()
        case .enterpriseGitHub: assert(false)
        case .bitBucket: return BuildasaurxcodeprojKeys().bitBucketAPIClientSecret()
        }
    }

    public static func createEnterpriseService(_ host: String) -> GitService? {
        guard let url = URL(string: "http://\(host)") else { return nil }
        do {
            let response = try NSString.init(contentsOf: url, encoding: String.Encoding.ascii.rawValue)
            if response.lowercased.contains("github") {
                return GitService.enterpriseGitHub(host: host)
            }
        } catch {
        }
        return nil
    }
}

open class GitServer : HTTPServer {
    
    let service: GitService
    
    open func authChangedSignal() -> Signal<ProjectAuthenticator?, NoError> {
        return Signal.never
    }
    
    init(service: GitService, http: HTTP? = nil) {
        self.service = service
        super.init(http: http)
    }
}

