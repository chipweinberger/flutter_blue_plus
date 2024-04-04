// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

public class ReadL2CapChannelResponse: NSObject {
    
    public let psm: Int
    public let remoteId: String
    public let bytesRead: Int
    public let value: Data;

    
    public init (remoteId: String, psm: Int, bytesRead: Int, value: Data) {
        self.psm = psm
        self.remoteId = remoteId
        self.bytesRead = bytesRead
        self.value = value
    }
                
    public func marshal() -> NSDictionary {
        return [
            L2CapAttributeNames.keyRemoteId: remoteId,
            L2CapAttributeNames.keyPsm: psm,
            L2CapAttributeNames.keyBytesRead: bytesRead,
            L2CapAttributeNames.keyValue: MessageUtil.convertBytesToHexString(data: value)
        ]
    }
}
