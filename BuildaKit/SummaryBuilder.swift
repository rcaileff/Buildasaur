//
//  SummaryCreator.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/15/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import XcodeServerSDK
import BuildaUtils
import BuildaGitServer

class SummaryBuilder {
    
    var statusCreator: BuildStatusCreator!
    var lines: [String] = []
    let resultString: String
    var linkBuilder: (Integration) -> String? = { _ in nil }
    
    init() {
        self.resultString = "*Result*: "
    }
    
    //MARK: high level
    
    func buildPassing(_ integration: Integration) -> StatusAndComment {
        
        let linkToIntegration = self.linkBuilder(integration)
        self.addBaseCommentFromIntegration(integration)
        
        let status = self.createStatus(.Success, description: "Build passed!", targetUrl: linkToIntegration)
        
        let buildResultSummary = integration.buildResultSummary!
        switch integration.result {
        case .Succeeded?:
            self.appendTestsPassed(buildResultSummary)
        case .Warnings?, .AnalyzerWarnings?:
            
            switch (buildResultSummary.warningCount, buildResultSummary.analyzerWarningCount) {
            case (_, 0):
                self.appendWarnings(buildResultSummary)
            case (0, _):
                self.appendAnalyzerWarnings(buildResultSummary)
            default:
                self.appendWarningsAndAnalyzerWarnings(buildResultSummary)
            }
            
        default: break
        }
        
        //and code coverage
        self.appendCodeCoverage(buildResultSummary)
        
        return self.buildWithStatus(status)
    }
    
    func buildFailingTests(_ integration: Integration) -> StatusAndComment {
        
        let linkToIntegration = self.linkBuilder(integration)
        
        self.addBaseCommentFromIntegration(integration)
        
        let status = self.createStatus(.Failure, description: "Build failed tests!", targetUrl: linkToIntegration)
        let buildResultSummary = integration.buildResultSummary!
        self.appendTestFailure(buildResultSummary)
        return self.buildWithStatus(status)
    }
    
    func buildErrorredIntegration(_ integration: Integration) -> StatusAndComment {
        
        let linkToIntegration = self.linkBuilder(integration)
        self.addBaseCommentFromIntegration(integration)
        
        let status = self.createStatus(.Error, description: "Build error!", targetUrl: linkToIntegration)
        
        self.appendErrors(integration)
        return self.buildWithStatus(status)
    }
    
    func buildCanceledIntegration(_ integration: Integration) -> StatusAndComment {
        
        let linkToIntegration = self.linkBuilder(integration)
        
        self.addBaseCommentFromIntegration(integration)
        
        let status = self.createStatus(.Error, description: "Build canceled!", targetUrl: linkToIntegration)
        
        self.appendCancel()
        return self.buildWithStatus(status)
    }
    
    func buildEmptyIntegration() -> StatusAndComment {
        
        let status = self.createStatus(.NoState, description: nil, targetUrl: nil)
        return self.buildWithStatus(status)
    }
    
    //MARK: utils
    
    fileprivate func createStatus(_ state: BuildState, description: String?, targetUrl: String?) -> StatusType {
        
        let status = self.statusCreator.createStatusFromState(state, description: description, targetUrl: targetUrl)
        return status
    }
    
    func addBaseCommentFromIntegration(_ integration: Integration) {
        
        var integrationText = "Integration \(integration.number)"
        if let link = self.linkBuilder(integration) {
            //linkify
            integrationText = "[\(integrationText)](\(link))"
        }
        
        self.lines.append("Result of \(integrationText)")
        self.lines.append("---")
        
        if let duration = self.formattedDurationOfIntegration(integration) {
            self.lines.append("*Duration*: " + duration)
        }
    }
    
    func appendTestsPassed(_ buildResultSummary: BuildResultSummary) {
        
        let testsCount = buildResultSummary.testsCount
        let testSection = testsCount > 0 ? "All \(testsCount) " + "test".pluralizeStringIfNecessary(testsCount) + " passed. " : ""
        self.lines.append(self.resultString + "**Perfect build!** \(testSection):+1:")
    }
    
    func appendWarnings(_ buildResultSummary: BuildResultSummary) {
        
        let warningCount = buildResultSummary.warningCount
        let testsCount = buildResultSummary.testsCount
        self.lines.append(self.resultString + "All \(testsCount) tests passed, but please **fix \(warningCount) " + "warning".pluralizeStringIfNecessary(warningCount) + "**.")
    }
    
    func appendAnalyzerWarnings(_ buildResultSummary: BuildResultSummary) {
        
        let analyzerWarningCount = buildResultSummary.analyzerWarningCount
        let testsCount = buildResultSummary.testsCount
        self.lines.append(self.resultString + "All \(testsCount) tests passed, but please **fix \(analyzerWarningCount) " + "analyzer warning".pluralizeStringIfNecessary(analyzerWarningCount) + "**.")
    }
    
    func appendWarningsAndAnalyzerWarnings(_ buildResultSummary: BuildResultSummary) {
        
        let warningCount = buildResultSummary.warningCount
        let analyzerWarningCount = buildResultSummary.analyzerWarningCount
        let testsCount = buildResultSummary.testsCount
        self.lines.append(self.resultString + "All \(testsCount) tests passed, but please **fix \(warningCount) " + "warning".pluralizeStringIfNecessary(warningCount) + "** and **\(analyzerWarningCount) " + "analyzer warning".pluralizeStringIfNecessary(analyzerWarningCount) + "**.")
    }
    
    func appendCodeCoverage(_ buildResultSummary: BuildResultSummary) {
        
        let codeCoveragePercentage = buildResultSummary.codeCoveragePercentage
        if codeCoveragePercentage > 0 {
            self.lines.append("*Test Coverage*: \(codeCoveragePercentage)%")
        }
    }
    
    func appendTestFailure(_ buildResultSummary: BuildResultSummary) {
        
        let testFailureCount = buildResultSummary.testFailureCount
        let testsCount = buildResultSummary.testsCount
        self.lines.append(self.resultString + "**Build failed \(testFailureCount) " + "test".pluralizeStringIfNecessary(testFailureCount) + "** out of \(testsCount)")
    }
    
    func appendErrors(_ integration: Integration) {
        
        let errorCount: Int = integration.buildResultSummary?.errorCount ?? -1
        self.lines.append(self.resultString + "**\(errorCount) " + "error".pluralizeStringIfNecessary(errorCount) + ", failing state: \(integration.result!.rawValue)**")
    }
    
    func appendCancel() {
        
        //TODO: find out who canceled it and add it to the comment?
        self.lines.append("Build was **manually canceled**.")
    }
    
    func buildWithStatus(_ status: StatusType) -> StatusAndComment {
        
        let comment: String?
        if lines.count == 0 {
            comment = nil
        } else {
            comment = lines.joined(separator: "\n")
        }
        return StatusAndComment(status: status, comment: comment)
    }
}

extension SummaryBuilder {
    
    func formattedDurationOfIntegration(_ integration: Integration) -> String? {
        
        if let seconds = integration.duration {
            
            let result = TimeUtils.secondsToNaturalTime(Int(seconds))
            return result
            
        } else {
            Log.error("No duration provided in integration \(integration)")
            return "[NOT PROVIDED]"
        }
    }
}
