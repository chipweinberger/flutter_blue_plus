// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

@objc
public class MessageUtil: NSObject {

    @objc
    public static func convertHexStringToBytes(hexString: String) -> Data? {
        if (hexString.count % 2 != 0) {
            return nil;
        }

        var data = Data(capacity: hexString.count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: hexString, range: NSRange(hexString.startIndex..., in: hexString)) { match, _, _ in
            let byteString = (hexString as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        return data
    }
    
    @objc
    public static func convertBytesToHexString(data : Data) -> String {
        return data
            .map { String(format: "%02x", $0) }
            .joined()
    }
    
    @objc
    public static func bmBluetoothDevice(peripheral: CBPeer) -> NSDictionary {
        var deviceName = ""
        if peripheral is CBPeripheral {
            deviceName = (peripheral as? CBPeripheral)?.name ?? ""
        }
        
        return [
            "remote_id":   peripheral.identifier.uuidString,
            "platform_name":  deviceName,
        ]
    }
    
    
}
