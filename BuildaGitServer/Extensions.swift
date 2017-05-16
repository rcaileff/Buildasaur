//
//  Extensions.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 1/28/16.
//  Copyright © 2016 Honza Dvorsky. All rights reserved.
//

import Foundation

extension String {

    public func base64String() -> String {
        return self
            .data(using: String.Encoding.utf8)!
            .base64EncodedString(options: NSData.Base64EncodingOptions())
    }
}

