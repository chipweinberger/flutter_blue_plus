// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

@objc
public class L2CapMethodNames: NSObject {
    private override init() {}
        
    @objc public static let connectToL2CapChannel = "connectToL2CapChannel"
    @objc public static let closeL2CapChannel = "closeL2CapChannel"
    @objc public static let readL2CapChannel = "readL2CapChannel"
    @objc public static let writeL2CapChannel = "writeL2CapChannel"
    @objc public static let deviceConnected = "deviceConnectedToL2CapChannel"
    @objc public static let listenL2CapChannel = "listenL2CapChannel"
    @objc public static let closeL2CapServer = "closeL2CapServer"
}
