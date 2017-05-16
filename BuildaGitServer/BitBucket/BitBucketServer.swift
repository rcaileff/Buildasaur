//
//  BitBucketServer.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 1/27/16.
//  Copyright © 2016 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaUtils
import ReactiveCocoa
import Result

class BitBucketServer : GitServer {
    
    let endpoints: BitBucketEndpoints
    let cache = InMemoryURLCache()
    
    init(endpoints: BitBucketEndpoints, http: HTTP? = nil) {
        
        self.endpoints = endpoints
        super.init(service: .GitHub, http: http)
    }
    
    override func authChangedSignal() -> Signal<ProjectAuthenticator?, NoError> {
        var res: Signal<ProjectAuthenticator?, NoError>?
        self.endpoints.auth.producer.startWithSignal { res = $0.0 }
        return res!.observeOn(UIScheduler())
    }
}

extension BitBucketServer: SourceServerType {
    
    func createStatusFromState(_ state: BuildState, description: String?, targetUrl: String?) -> StatusType {
        
        let bbState = BitBucketStatus.BitBucketState.fromBuildState(state)
        let key = "Buildasaur"
        let url = targetUrl ?? "https://github.com/czechboy0/Buildasaur"
        return BitBucketStatus(state: bbState, key: key, name: key, description: description, url: url)
    }
    
    func getBranchesOfRepo(_ repo: String, completion: (_ branches: [BranchType]?, _ error: Error?) -> ()) {
        
        //TODO: start returning branches
        completion([], nil)
    }
    
    func getOpenPullRequests(_ repo: String, completion: @escaping (_ prs: [PullRequestType]?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        self._sendRequestWithMethod(.GET, endpoint: .PullRequests, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(prs: nil, error: error)
                return
            }
            
            if let body = body as? [NSDictionary] {
                let prs: [BitBucketPullRequest] = BitBucketArray(body)
                completion(prs: prs.map { $0 as PullRequestType }, error: nil)
            } else {
                completion(prs: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func getPullRequest(_ pullRequestNumber: Int, repo: String, completion: @escaping (_ pr: PullRequestType?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo,
            "pr": pullRequestNumber.description
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .PullRequests, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(pr: nil, error: error)
                return
            }
            
            if let body = body as? NSDictionary {
                let pr = BitBucketPullRequest(json: body)
                completion(pr: pr, error: nil)
            } else {
                completion(pr: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func getRepo(_ repo: String, completion: @escaping (_ repo: RepoType?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .Repos, params: params, query: nil, body: nil) {
            (response, body, error) -> () in
            
            if error != nil {
                completion(repo: nil, error: error)
                return
            }
            
            if let body = body as? NSDictionary {
                let repository = BitBucketRepo(json: body)
                completion(repo: repository, error: nil)
            } else {
                completion(repo: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func getStatusOfCommit(_ commit: String, repo: String, completion: @escaping (_ status: StatusType?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo,
            "sha": commit,
            "status_key": "Buildasaur"
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .CommitStatuses, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if response?.statusCode == 404 {
                //no status yet, just pass nil but OK
                completion(status: nil, error: nil)
                return
            }
            
            if error != nil {
                completion(status: nil, error: error)
                return
            }
            
            if let body = body as? NSDictionary {
                let status = BitBucketStatus(json: body)
                completion(status: status, error: nil)
            } else {
                completion(status: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func postStatusOfCommit(_ commit: String, status: StatusType, repo: String, completion: @escaping (_ status: StatusType?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo,
            "sha": commit
        ]
        
        let body = (status as! BitBucketStatus).dictionarify()
        self._sendRequestWithMethod(.POST, endpoint: .CommitStatuses, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(status: nil, error: error)
                return
            }
            
            if let body = body as? NSDictionary {
                let status = BitBucketStatus(json: body)
                completion(status: status, error: nil)
            } else {
                completion(status: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func postCommentOnIssue(_ comment: String, issueNumber: Int, repo: String, completion: @escaping (_ comment: CommentType?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo,
            "pr": issueNumber.description
        ]
        
        let body = [
            "content": comment
        ]
        
        self._sendRequestWithMethod(.POST, endpoint: .PullRequestComments, params: params, query: nil, body: body) { (response, body, error) -> () in
            
            if error != nil {
                completion(comment: nil, error: error)
                return
            }
            
            if let body = body as? NSDictionary {
                let comment = BitBucketComment(json: body)
                completion(comment: comment, error: nil)
            } else {
                completion(comment: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
    
    func getCommentsOfIssue(_ issueNumber: Int, repo: String, completion: @escaping (_ comments: [CommentType]?, _ error: Error?) -> ()) {
        
        let params = [
            "repo": repo,
            "pr": issueNumber.description
        ]
        
        self._sendRequestWithMethod(.GET, endpoint: .PullRequestComments, params: params, query: nil, body: nil) { (response, body, error) -> () in
            
            if error != nil {
                completion(comments: nil, error: error)
                return
            }
            
            if let body = body as? [NSDictionary] {
                let comments: [BitBucketComment] = BitBucketArray(body)
                completion(comments: comments.map { $0 as CommentType }, error: nil)
            } else {
                completion(comments: nil, error: Error.withInfo("Wrong body \(body)"))
            }
        }
    }
}

extension BitBucketServer {
    
    fileprivate func _sendRequest(_ request: NSMutableURLRequest, isRetry: Bool = false, completion: HTTP.Completion) {
        
        self.http.sendRequest(request) { (response, body, error) -> () in
            
            if let error = error {
                completion(response: response, body: body, error: error)
                return
            }
            
            //error out on special HTTP status codes
            let statusCode = response!.statusCode
            switch statusCode {
            case 401: //unauthorized, use refresh token to get a new access token
                      //only try to refresh token once
                if !isRetry {
                    self._handle401(request, completion: completion)
                }
                return
            case 400, 402 ... 500:
                
                let message = ((body as? NSDictionary)?["error"] as? NSDictionary)?["message"] as? String ?? (body as? String ?? "Unknown error")
                let resultString = "\(statusCode): \(message)"
                completion(response: response, body: body, error: Error.withInfo(resultString, internalError: error))
                return
            default:
                break
            }
            
            completion(response: response, body: body, error: error)
        }
    }
    
    fileprivate func _handle401(_ request: NSMutableURLRequest, completion: HTTP.Completion) {
        
        //we need to use the refresh token to request a new access token
        //then we need to notify that we updated the secret, so that it can
        //be saved by buildasaur
        //then we need to set the new access token to this waiting request and
        //run it again. if that fails too, we fail for real.
        
        Log.verbose("Got 401, starting a BitBucket refresh token flow...")
        
        //get a new access token
        self._refreshAccessToken(request) { error in
            
            if let error = error {
                Log.verbose("Failed to get a new access token")
                completion(response: nil, body: nil, error: error)
                return
            }

            //we have a new access token, force set the new cred on the original
            //request
            self.endpoints.setAuthOnRequest(request)
            
            Log.verbose("Successfully refreshed a BitBucket access token")
            
            //retrying the original request
            self._sendRequest(request, isRetry: true, completion: completion)
        }
    }
    
    fileprivate func _refreshAccessToken(_ request: NSMutableURLRequest, completion: @escaping (NSError?) -> ()) {
        
        let refreshRequest = self.endpoints.createRefreshTokenRequest()
        self.http.sendRequest(refreshRequest) { (response, body, error) -> () in
            
            if let error = error {
                completion(error)
                return
            }
            
            guard response?.statusCode == 200 else {
                completion(Error.withInfo("Wrong status code returned, refreshing access token failed"))
                return
            }
            
            let payload = body as! NSDictionary
            let accessToken = payload.stringForKey("access_token")
            let refreshToken = payload.stringForKey("refresh_token")
            let secret = [refreshToken, accessToken].joinWithSeparator(":")
            
            let newAuth = ProjectAuthenticator(service: .BitBucket, username: "GIT", type: .OAuthToken, secret: secret)
            self.endpoints.auth.value = newAuth
            completion(nil)
        }
    }
    
    fileprivate func _sendRequestWithMethod(_ method: HTTP.Method, endpoint: BitBucketEndpoints.Endpoint, params: [String: String]?, query: [String: String]?, body: NSDictionary?, completion: HTTP.Completion) {
        
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
    
    fileprivate func _sendRequestWithPossiblePagination(_ request: NSMutableURLRequest, accumulatedResponseBody: NSArray, completion: HTTP.Completion) {
        
        self._sendRequest(request) {
            (response, body, error) -> () in
            
            if error != nil {
                completion(response: response, body: body, error: error)
                return
            }
            
            guard let dictBody = body as? NSDictionary else {
                completion(response: response, body: body, error: error)
                return
            }
            
            //pull out the values
            guard let arrayBody = dictBody["values"] as? [AnyObject] else {
                completion(response: response, body: dictBody, error: error)
                return
            }
            
            //we do have more, let's fetch it
            let newBody = accumulatedResponseBody.arrayByAddingObjectsFromArray(arrayBody)

            guard let nextLink = dictBody.optionalStringForKey("next") else {
                
                //is array, but we don't have any more data
                completion(response: response, body: newBody, error: error)
                return
            }
            
            let newRequest = request.mutableCopy() as! NSMutableURLRequest
            newRequest.URL = NSURL(string: nextLink)!
            self._sendRequestWithPossiblePagination(newRequest, accumulatedResponseBody: newBody, completion: completion)
            return
        }
    }

}
