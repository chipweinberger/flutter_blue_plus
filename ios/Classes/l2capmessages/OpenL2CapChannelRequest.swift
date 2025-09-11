// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

@objc
public class OpenL2CapChannelRequest: NSObject {
    
    @objc
    public let secure: Bool
    @objc
    public let remoteId: String
    @objc
    public let psm: Int;
    
    @objc
    public init (data: NSDictionary) {
        self.secure = data[L2CapAttributeNames.keySecure] as? Bool ?? false
        self.psm = data[L2CapAttributeNames.keyPsm] as? Int ?? 0
        self.remoteId = data[L2CapAttributeNames.keyRemoteId] as? String ?? ""
    }
                
}
