//
//  BaseTypes.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/16/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

public protocol BuildStatusCreator {
    func createStatusFromState(_ state: BuildState, description: String?, targetUrl: String?) -> StatusType
}

public protocol SourceServerType: BuildStatusCreator {
    
    func getBranchesOfRepo(_ repo: String, completion: (_ branches: [BranchType]?, _ error: Error?) -> ())
    func getOpenPullRequests(_ repo: String, completion: (_ prs: [PullRequestType]?, _ error: Error?) -> ())
    func getPullRequest(_ pullRequestNumber: Int, repo: String, completion: (_ pr: PullRequestType?, _ error: Error?) -> ())
    func getRepo(_ repo: String, completion: (_ repo: RepoType?, _ error: Error?) -> ())
    func getStatusOfCommit(_ commit: String, repo: String, completion: (_ status: StatusType?, _ error: Error?) -> ())
    func postStatusOfCommit(_ commit: String, status: StatusType, repo: String, completion: (_ status: StatusType?, _ error: Error?) -> ())
    func postCommentOnIssue(_ comment: String, issueNumber: Int, repo: String, completion: (_ comment: CommentType?, _ error: Error?) -> ())
    func getCommentsOfIssue(_ issueNumber: Int, repo: String, completion: (_ comments: [CommentType]?, _ error: Error?) -> ())
    
    func authChangedSignal() -> Signal<ProjectAuthenticator?, NoError>
}

open class SourceServerFactory {
    
    public init() { }
    
    open func createServer(_ service: GitService, auth: ProjectAuthenticator?) -> SourceServerType {
        
        if let auth = auth {
            precondition(service.type() == auth.service.type())
        }
        
        return GitServerFactory.server(service, auth: auth)
    }
}

public struct RepoPermissions {
    public let read: Bool
    public let write: Bool
    public init(read: Bool, write: Bool) {
        self.read = read
        self.write = write
    }
}

public protocol RateLimitType {
    
    var report: String { get }
}

public protocol RepoType {
    
    var permissions: RepoPermissions { get }
    var originUrlSSH: String { get }
    var latestRateLimitInfo: RateLimitType? { get }
}

public protocol BranchType {
    
    var name: String { get }
    var commitSHA: String { get }
}

public protocol IssueType {
    
    var number: Int { get }
}

public protocol PullRequestType: IssueType {
    
    var headName: String { get }
    var headCommitSHA: String { get }
    var headRepo: RepoType { get }
    
    var baseName: String { get }
    
    var title: String { get }
}

public enum BuildState {
    case noState
    case pending
    case success
    case error
    case failure
}

public protocol StatusType {
    
    var state: BuildState { get }
    var description: String? { get }
    var targetUrl: String? { get }
}

extension StatusType {
    
    public func isEqual(_ rhs: StatusType) -> Bool {
        let lhs = self
        return lhs.state == rhs.state && lhs.description == rhs.description
    }
}

public protocol CommentType {
    
    var body: String { get }
}

