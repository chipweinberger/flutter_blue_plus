// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


import Foundation

@objc
public class CloseL2CapServer: NSObject {
    
    @objc
    public let psm: Int
    
    @objc
    public init (data: NSDictionary) {
        self.psm = data[L2CapAttributeNames.keyPsm] as? Int ?? 0
    }
                
}
