// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

public class ListenL2CapChannelResponse: NSObject {
    
    public let psm: Int
    
    public init (psm: Int) {
        self.psm = psm
    }
                
    public func marshal() -> NSDictionary {
        return [L2CapAttributeNames.keyPsm: psm]
    }
}
