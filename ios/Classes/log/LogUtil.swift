// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation


@objc
public enum LogLevel: Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
}

@objc
public class LogUtil: NSObject {
    
    @objc
    public static var LOG_LEVEL: LogLevel = LogLevel.debug
    
    @objc
    public static func log(logLevel: LogLevel, message: String) {
        if (logLevel.rawValue <= LOG_LEVEL.rawValue) {            
            NSLog("[FBP] %@", message)
        }
    }
}
