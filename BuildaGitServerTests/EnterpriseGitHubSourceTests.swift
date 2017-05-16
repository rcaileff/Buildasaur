//
//  EnterpriseGitHubSourceTests.swift
//  Buildasaur
//
//  Created by Rachel Caileff on 3/8/16.
//  Copyright © 2016 Honza Dvorsky. All rights reserved.
//

import Cocoa
import XCTest
@testable import BuildaGitServer
import BuildaUtils

class EnterpriseGitHubSourceTests: XCTestCase {

    var github: GitHubServer!
    var repo: String = "my/repo"  // TODO: fill in accessible enterprise github repo

    override func setUp() {
        super.setUp()

        self.github = GitServerFactory.server(.EnterpriseGitHub(host: "git.mycompany.com"), auth: nil) as! GitHubServer  // TODO: fill in accessible enterprise github host
    }

    override func tearDown() {

        self.github = nil

        super.tearDown()
    }

    func tryEndpoint(_ method: HTTP.Method, endpoint: GitHubEndpoints.Endpoint, params: [String: String]?, completion: @escaping (_ body: AnyObject?, _ error: NSError?) -> ()) {

        let expect = expectation(description: "Waiting for url request")

        let request = try! self.github.endpoints.createRequest(method, endpoint: endpoint, params: params)

        self.github.http.sendRequest(request, completion: { (response, body, error) -> () in

            completion(body: body, error: error)
            expect.fulfill()
        })

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testGetPullRequests() {

        let params = [
            "repo": self.repo
        ]

        self.tryEndpoint(.GET, endpoint: .PullRequests, params: params) { (body, error) -> () in

            XCTAssertNotNil(body, "Body must be non-nil")
            if let body = body as? NSArray {
                let prs: [GitHubPullRequest]? = try? GitHubArray(body)
                XCTAssertGreaterThan(prs?.count ?? -1, 0, "We need > 0 items to test parsing")
                Log.verbose("Parsed PRs: \(prs)")
            } else {
                XCTFail("Body nil")
            }
        }
    }


    func testGetBranches() {

        let params = [
            "repo": self.repo
        ]

        self.tryEndpoint(.GET, endpoint: .Branches, params: params) { (body, error) -> () in

            XCTAssertNotNil(body, "Body must be non-nil")
            if let body = body as? NSArray {
                let branches: [GitHubBranch]? = try? GitHubArray(body)
                XCTAssertGreaterThan(branches?.count ?? -1, 0, "We need > 0 items to test parsing")
                Log.verbose("Parsed branches: \(branches)")
            } else {
                XCTFail("Body nil")
            }
        }
    }
}
