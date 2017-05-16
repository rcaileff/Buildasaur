//
//  GitHubSource.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 12/12/2014.
//  Copyright (c) 2014 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils
import ReactiveCocoa

class GitHubServer : GitServer {
    
    let endpoints: GitHubEndpoints
    var latestRateLimitInfo: GitHubRateLimit?

	let cache = InMemoryURLCache()

    init(endpoints: GitHubEndpoints, http: HTTP? = nil) {
        
        self.endpoints = endpoints
        super.init(service: .GitHub, http: http)
    }
}

//TODO: from each of these calls, return a "cancellable" object which can be used for cancelling

extension GitHubServer: SourceServerType {
    
    func getBranchesOfRepo(_ repo: String, completion: @escaping (_ branches: [BranchType]?, _ error: Error?) -> ()) {
        
        self._getBranchesOfRepo(repo) { (branches, error) -> () in
            completion(branches?.map { $0 as BranchType }, error)
        }
    }
    
    func getOpenPullRequests(_ repo: String, completion: @escaping (_ prs: [PullRequestType]?, _ error: Error?) -> ()) {
        
        self._getOpenPullRequests(repo) { (prs, error) -> () in
            completion(prs?.map { $0 as PullRequestType }, error)
        }
    }
    
    func getPullRequest(_ pullRequestNumber: Int, repo: String, completion: @escaping (_ pr: PullRequestType?, _ error: Error?) -> ()) {
        
        self._getPullRequest(pullRequestNumber, repo: repo) { (pr, error) -> () in
            completion(pr, error)
        }
    }
    
    func getRepo(_ repo: String, completion: @escaping (_ repo: RepoType?, _ error: Error?) -> ()) {
        
        self._getRepo(repo) { (repo, error) -> () in
            completion(repo, error)
        }
    }
    
    func getStatusOfCommit(_ commit: String, repo: String, completion: @escaping (_ status: StatusType?, _ error: Error?) -> ()) {
        
        self._getStatusOfCommit(commit, repo: repo) { (status, error) -> () in
            completion(status, error)
        }
    }
    
    func postStatusOfCommit(_ commit: String, status: StatusType, repo: String, completion: @escaping (_ status: StatusType?, _ error: Error?) -> ()) {
        
        self._postStatusOfCommit(status as! GitHubStatus, sha: commit, repo: repo) { (status, error) -> () in
            completion(status, error)
        }
    }
    
    func postCommentOnIssue(_ comment: String, issueNumber: Int, repo: String, completion: @escaping (_ comment: CommentType?, _ error: Error?) -> ()) {
        
        self._postCommentOnIssue(comment, issueNumber: issueNumber, repo: repo) { (comment, error) -> () in
            completion(comment, error)
        }
    }
    
    func getCommentsOfIssue(_ issueNumber: Int, repo: String, completion: @escaping (_ comments: [CommentType]?, _ error: Error?) -> ()) {
        
        self._getCommentsOfIssue(issueNumber, repo: repo) { (comments, error) -> () in
            completion(comments?.map { $0 as CommentType }, error)
        }
    }
    
    func createStatusFromState(_ buildState: BuildState, description: String?, targetUrl: String?) -> StatusType {
        
        let state = GitHubStatus.GitHubState.fromBuildState(buildState)
        let context = "Buildasaur"
        return GitHubStatus(state: state, description: description, targetUrl: targetUrl, context: context)
    }
}

extension GitHubServer {
    
    fileprivate func _sendRequestWithPossiblePagination(_ request: NSMutableURLRequest, accumulatedResponseBody: NSArray, completion: HTTP.Completion) {
        
        self._sendRequest(request) {
            (response, body, error) -> () in
            
            if error != nil {
                completion(response: response, body: body, error: error)
                return
            }
            
            if let arrayBody = body as? [AnyObject] {
                
                let newBody = accumulatedResponseBody.arrayByAddingObjectsFromArray(arrayBody)

                if let links = response?.allHeaderFields["Link"] as? String {
                    
                    //now parse page links
                    if let pageInfo = self._parsePageLinks(links) {
                        
                        //here look at the links and go to the next page, accumulate the body from this response
                        //and pass it through
                        
                        if let nextUrl = pageInfo[RelPage.Next] {
                            
                            let newRequest = request.mutableCopy() as! NSMutableURLRequest
                            newRequest.URL = nextUrl
                            self._sendRequestWithPossiblePagination(newRequest, accumulatedResponseBody: newBody, completion: completion)
                            return
                        }
                    }
                }
                
                completion(response: response, body: newBody, error: error)
            } else {
                completion(response: response, body: body, error: error)
            }
        }
    }
    
    enum RelPage: String {
        case First = "first"
        case Next = "next"
        case Previous = "previous"
        case Last = "last"
    }
    
    fileprivate func _parsePageLinks(_ links: String) -> [RelPage: URL]? {
        
        var linkDict = [RelPage: URL]()
        
        for i in links.components(separatedBy: ",") {
            
            let link = i.components(separatedBy: ";")
            if link.count < 2 {
                continue
            }
            
            //url
            var urlString = link[0].trimmingCharacters(in: CharacterSet.whitespaces)
            if urlString.hasPrefix("<") && urlString.hasSuffix(">") {
                urlString = urlString[urlString.characters.index(after: urlString.startIndex) ..< urlString.characters.index(before: urlString.endIndex)]
            }
            
            //rel
            let relString = link[1]
            let relComps = relString.components(separatedBy: "=")
            if relComps.count < 2 {
                continue
            }
            
            var relName = relComps[1]
            if relName.hasPrefix("\"") && relName.hasSuffix("\"") {
                relName = relName[relName.characters.index(after: relName.startIndex) ..< relName.characters.index(before: relName.endIndex)]
            }
            
            if
                let rel = RelPage(rawValue: relName),
                let url = URL(string: urlString)
            {
                linkDict[rel] = url
            }
        }
        
        return linkDict
    }
    
    fileprivate func _sendRequest(_ request: NSMutableURLRequest, completion: HTTP.Completion) {
        
        let cachedInfo = self.cache.getCachedInfoForRequest(request)
        if let etag = cachedInfo.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        self.http.sendRequest(request, completion: { (response, body, error) -> () in
            
            if let error = error {
                completion(response: response, body: body, error: error)
                return
            }

            if response == nil {
                completion(response: nil, body: body, error: Error.withInfo("Nil response"))
                return
            }
            
            if let response = response {
                let headers = response.allHeaderFields
                
                if
                    let resetTime = (headers["X-RateLimit-Reset"] as? NSString)?.doubleValue,
                    let limit = (headers["X-RateLimit-Limit"] as? NSString)?.integerValue,
                    let remaining = (headers["X-RateLimit-Remaining"] as? NSString)?.integerValue {
                        
                        let rateLimitInfo = GitHubRateLimit(resetTime: resetTime, limit: limit, remaining: remaining)
                        self.latestRateLimitInfo = rateLimitInfo

                } else {
                    Log.error("No X-RateLimit info provided by GitHub in headers: \(headers), we're unable to detect the remaining number of allowed requests. GitHub might fail to return data any time now :(")
                }
            }
            
            if
                let respDict = body as? NSDictionary,
                let message = respDict["message"] as? String, message == "Not Found" {
                    
                    let url = request.URL ?? ""
                    completion(response: nil, body: nil, error: Error.withInfo("Not found: \(url)"))
                    return
            }
            
            //error out on special HTTP status codes
            let statusCode = response!.statusCode
            switch statusCode {
            case 200...299: //good response, cache the returned data
                let responseInfo = ResponseInfo(response: response!, body: body)
                cachedInfo.update(responseInfo)
            case 304: //not modified, return the cached response
                let responseInfo = cachedInfo.responseInfo!
                completion(response: responseInfo.response, body: responseInfo.body, error: nil)
                return
            case 400 ... 500:
                let message = (body as? NSDictionary)?["message"] as? String ?? "Unknown error"
                let resultString = "\(statusCode): \(message)"
                completion(response: response, body: body, error: Error.withInfo(resultString, internalError: error))
                return
            default:
                break
            }
            
            completion(response: response, body: body, error: error)
        })
    }
    
    fileprivate func _sendRequestWithMethod(_ method: HTTP.Method, endpoint: GitHubEndpoints.Endpoint, params: [String: String]?, query: [String: String]?, body: NSDictionary?, completion: HTTP.Completion) {
        
        var allParams = [
            "method": method.rawValue
        ]
        
        //merge the two params
        if let params = params {
            for (key, value) in params {
                allParams[key] = value
            }
        }
        
        do {
            let request = try self.endpoints.createRequest(method, endpoint: endpoint, params: allParams, query: query, body: body)
            self._sendRequestWithPossiblePagination(request, accumulatedResponseBody: NSArray(), completion: completion)
        } catch {
            completion(response: nil, body: nil, error: Error.withInfo("Couldn't create Request, error \(error)"))
        }
    }
    
    /**
    *   GET all open pull requests of a repo (full name).
    */
    fileprivate func _getOpenPullRequests(_ repo: String, completion: @escaping (_ prs: [GitHubPullRequest]?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        self._sendRequestWithMethod(.GET, endpoint: .PullRequests, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(prs: nil, error: error)
                return
            }
            
            if
                let body = body as? NSArray,
                let prs: [GitHubPullRequest] = try? GitHubArray(body) {
                completion(prs: prs, error: nil)
            } else {
                completion(prs: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET a pull requests of a repo (full name) by its number.
    */
    fileprivate func _getPullRequest(_ pullRequestNumber: Int, repo: String, completion: @escaping (_ pr: GitHubPullRequest?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "pr": pullRequestNumber.description
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .PullRequests, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(pr: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let pr = try? GitHubPullRequest(json: body)
            {
                completion(pr: pr, error: nil)
            } else {
                completion(pr: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET all open issues of a repo (full name).
    */
    fileprivate func _getOpenIssues(_ repo: String, completion: @escaping (_ issues: [GitHubIssue]?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        self._sendRequestWithMethod(.GET, endpoint: .Issues, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(issues: nil, error: error)
                return
            }
            
            if
                let body = body as? NSArray,
                let issues: [GitHubIssue] = try? GitHubArray(body) {
                completion(issues: issues, error: nil)
            } else {
                completion(issues: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET an issue of a repo (full name) by its number.
    */
    fileprivate func _getIssue(_ issueNumber: Int, repo: String, completion: @escaping (_ issue: GitHubIssue?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "issue": issueNumber.description
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .Issues, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(issue: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let issue = try? GitHubIssue(json: body)
            {
                completion(issue: issue, error: nil)
            } else {
                completion(issue: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   POST a new Issue
    */
    fileprivate func _postNewIssue(_ issueTitle: String, issueBody: String?, repo: String, completion: @escaping (_ issue: GitHubIssue?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
        ]
        
        let body = [
            "title": issueTitle,
            "body": issueBody ?? ""
        ]
        
        self._sendRequestWithMethod(.POST, endpoint: .Issues, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(issue: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let issue = try? GitHubIssue(json: body)
            {
                completion(issue: issue, error: nil)
            } else {
                completion(issue: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   Close an Issue by its number and repo (full name).
    */
    fileprivate func _closeIssue(_ issueNumber: Int, repo: String, completion: @escaping (_ issue: GitHubIssue?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "issue": issueNumber.description
        ]
        
        let body = [
            "state": "closed"
        ]
        
        self._sendRequestWithMethod(.PATCH, endpoint: .Issues, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(issue: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let issue = try? GitHubIssue(json: body)
            {
                completion(issue: issue, error: nil)
            } else {
                completion(issue: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET the status of a commit (sha) from a repo.
    */
    fileprivate func _getStatusOfCommit(_ sha: String, repo: String, completion: @escaping (_ status: GitHubStatus?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "sha": sha
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .Statuses, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(status: nil, error: error)
                return
            }
            
            if
                let body = body as? NSArray,
                let statuses: [GitHubStatus] = try? GitHubArray(body)
            {
                //sort them by creation date
                let mostRecentStatus = statuses.sort({ return $0.created! > $1.created! }).first
                completion(status: mostRecentStatus, error: nil)
            } else {
                completion(status: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   POST a new status on a commit.
    */
    fileprivate func _postStatusOfCommit(_ status: GitHubStatus, sha: String, repo: String, completion: @escaping (_ status: GitHubStatus?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "sha": sha
        ]
        
        let body = status.dictionarify()
        self._sendRequestWithMethod(.POST, endpoint: .Statuses, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(status: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let status = try? GitHubStatus(json: body)
            {
                completion(status: status, error: nil)
            } else {
                completion(status: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET comments of an issue - WARNING - there is a difference between review comments (on a PR, tied to code)
    *   and general issue comments - which appear in both Issues and Pull Requests (bc a PR is an Issue + code)
    *   This API only fetches the general issue comments, NOT comments on code.
    */
    fileprivate func _getCommentsOfIssue(_ issueNumber: Int, repo: String, completion: @escaping (_ comments: [GitHubComment]?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "issue": issueNumber.description
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .IssueComments, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(comments: nil, error: error)
                return
            }
            
            if
                let body = body as? NSArray,
                let comments: [GitHubComment] = try? GitHubArray(body)
            {
                completion(comments: comments, error: nil)
            } else {
                completion(comments: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   POST a comment on an issue.
    */
    fileprivate func _postCommentOnIssue(_ commentBody: String, issueNumber: Int, repo: String, completion: @escaping (_ comment: GitHubComment?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "issue": issueNumber.description
        ]
        
        let body = [
            "body": commentBody
        ]
        
        self._sendRequestWithMethod(.POST, endpoint: .IssueComments, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(comment: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let comment = try? GitHubComment(json: body)
            {
                completion(comment: comment, error: nil)
            } else {
                completion(comment: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   PATCH edit a comment with id
    */
    fileprivate func _editCommentOnIssue(_ commentId: Int, newCommentBody: String, repo: String, completion: @escaping (_ comment: GitHubComment?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo,
            "comment": commentId.description
        ]
        
        let body = [
            "body": newCommentBody
        ]
        
        self._sendRequestWithMethod(.PATCH, endpoint: .IssueComments, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(comment: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let comment = try? GitHubComment(json: body)
            {
                completion(comment: comment, error: nil)
            } else {
                completion(comment: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   POST merge a head branch/commit into a base branch.
    *   has a couple of different responses, a bit tricky
    */
    fileprivate func _mergeHeadIntoBase(head: String, base: String, commitMessage: String, repo: String, completion: @escaping (_ result: GitHubEndpoints.MergeResult?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        
        let body = [
            "head": head,
            "base": base,
            "commit_message": commitMessage
        ]
        
        self._sendRequestWithMethod(.POST, endpoint: .Merges, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(result: nil, error: error)
                return
            }
            
            if let response = response {
                let code = response.statusCode
                switch code {
                case 201:
                    //success
                    completion(result: GitHubEndpoints.MergeResult.Success(body as! NSDictionary), error: error)
                    
                case 204:
                    //no-op
                    completion(result: GitHubEndpoints.MergeResult.NothingToMerge, error: error)
                    
                case 409:
                    //conflict
                    completion(result: GitHubEndpoints.MergeResult.Conflict, error: error)
                    
                case 404:
                    //missing
                    let bodyDict = body as! NSDictionary
                    let message = bodyDict["message"] as! String
                    completion(result: GitHubEndpoints.MergeResult.Missing(message), error: error)
                default:
                    completion(result: nil, error: error)
                }
            } else {
                completion(result: nil, error: Error.withInfo("Nil response"))
            }
        }
    }
    
    /**
    *   GET branches of a repo
    */
    fileprivate func _getBranchesOfRepo(_ repo: String, completion: @escaping (_ branches: [GitHubBranch]?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .Branches, params: params, query: nil, body: nil) {
            (response, body, error) -> () in
            
            if error != nil {
                completion(branches: nil, error: error)
                return
            }
            
            if
                let body = body as? NSArray,
                let branches: [GitHubBranch] = try? GitHubArray(body)
            {
                completion(branches: branches, error: nil)
            } else {
                completion(branches: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    /**
    *   GET repo metadata
    */
    fileprivate func _getRepo(_ repo: String, completion: @escaping (_ repo: GitHubRepo?, _ error: NSError?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .Repos, params: params, query: nil, body: nil) {
            (response, body, error) -> () in
            
            if error != nil {
                completion(repo: nil, error: error)
                return
            }
            
            if
                let body = body as? NSDictionary,
                let repository: GitHubRepo = try? GitHubRepo(json: body)
            {
                completion(repo: repository, error: nil)
            } else {
                completion(repo: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
}





