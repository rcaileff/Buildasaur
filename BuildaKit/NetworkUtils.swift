//
//  NetworkUtils.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 07/03/2015.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import BuildaGitServer
import BuildaUtils
import XcodeServerSDK

open class NetworkUtils {
    
    public typealias VerificationCompletion = (Bool, Error?) -> ()
    
    open class func checkAvailabilityOfServiceWithProject(_ project: Project, completion: @escaping VerificationCompletion) {
        
        self.checkService(project, completion: { success, error in
            
            if !success {
                completion(false, error)
                return
            }
            
            //now test ssh keys
            let credentialValidationBlueprint = project.createSourceControlBlueprintForCredentialVerification()
            self.checkValidityOfSSHKeys(credentialValidationBlueprint, completion: { (success, error) -> () in
                
                if success {
                    Log.verbose("Finished blueprint validation with success!")
                } else {
                    Log.verbose("Finished blueprint validation with error: \(error)")
                }
                
                //now complete
                completion(success, error)
            })
        })
    }
    
    fileprivate class func checkService(_ project: Project, completion: @escaping VerificationCompletion) {
        
        let auth = project.config.value.serverAuthentication
        let service = auth!.service
        let server = SourceServerFactory().createServer(service, auth: auth)
        
        //check if we can get the repo and verify permissions
        guard let repoName = project.serviceRepoName() else {
            completion(false, Error.withInfo("Invalid repo name"))
            return
        }
        
        //we have a repo name
        server.getRepo(repoName, completion: { (repo, error) -> () in
            
            if error != nil {
                completion(false, error)
                return
            }
            
            if let repo = repo {
                
                let permissions = repo.permissions
                let readPermission = permissions.read
                let writePermission = permissions.write
                
                //look at the permissions in the PR metadata
                if !readPermission {
                    completion(false, Error.withInfo("Missing read permission for repo"))
                } else if !writePermission {
                    completion(false, Error.withInfo("Missing write permission for repo"))
                } else {
                    //now complete
                    completion(true, nil)
                }
            } else {
                completion(false, Error.withInfo("Couldn't find repo permissions in \(service.prettyName()) response"))
            }
        })
    }
    
    open class func checkAvailabilityOfXcodeServerWithCurrentSettings(_ config: XcodeServerConfig, completion: @escaping (Bool, NSError?) -> ()) {
        
        let xcodeServer = XcodeServerFactory.server(config)
        
        //the way we check availability is first by logging out (does nothing if not logged in) and then
        //calling getUserCanCreateBots, which, if necessary, authenticates before resolving to true or false in JSON.
        xcodeServer.logout { (success, error) -> () in
            
            if let error = error {
                completion(false, error)
                return
            }
            
            xcodeServer.getUserCanCreateBots({ (canCreateBots, error) -> () in
                
                if let error = error {
                    completion(false, error)
                    return
                }
                
                completion(canCreateBots, nil)
            })
        }
    }
    
    class func checkValidityOfSSHKeys(_ blueprint: SourceControlBlueprint, completion: (Bool, NSError?) -> ()) {
        
        let blueprintDict = blueprint.dictionarify()
        let r = SSHKeyVerification.verifyBlueprint(blueprintDict)
        
        //based on the return value, either succeed or fail
        if r.terminationStatus == 0 {
            completion(true, nil)
        } else {
            completion(false, Error.withInfo(r.standardError))
        }
    }
}
