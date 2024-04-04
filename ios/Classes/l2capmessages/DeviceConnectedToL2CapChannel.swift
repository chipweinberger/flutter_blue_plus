// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

public class DeviceConnectedToL2CapChannel: NSObject {
    
    public let psm: Int
    public let device: CBPeer
    
    public init (device: CBPeer, psm: Int) {
        self.psm = psm
        self.device = device
    }
                
    public func marshal() -> NSDictionary {
        let device = MessageUtil.bmBluetoothDevice(peripheral: device)
        
        return [
            L2CapAttributeNames.keyBluetoothDevice: device,
            L2CapAttributeNames.keyPsm: psm
        ]
    }
}
