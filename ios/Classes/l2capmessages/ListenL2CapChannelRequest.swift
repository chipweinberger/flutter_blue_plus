// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

@objc
public class ListenL2CapChannelRequest: NSObject {
    
    @objc
    public let secure: Bool
    
    @objc
    public init (data: NSDictionary) {
        let secureValue = data[L2CapAttributeNames.keySecure] as? Bool
        self.secure = secureValue ?? false
    }
                
}
