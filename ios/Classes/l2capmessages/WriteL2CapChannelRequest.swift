// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

@objc
public class WriteL2CapChannelRequest: NSObject {
    
    @objc
    public let psm: Int
    @objc
    public let remoteId: String
    @objc
    public let value: Data
    
    @objc
    public init (data: NSDictionary) {
        self.psm = data[L2CapAttributeNames.keyPsm] as? Int ?? 0
        self.remoteId = data[L2CapAttributeNames.keyRemoteId] as? String ?? ""
        let valueAsString = data[L2CapAttributeNames.keyValue] as? String ?? ""
        self.value = MessageUtil.convertHexStringToBytes(hexString: valueAsString) ?? Data()
    }
                
}
