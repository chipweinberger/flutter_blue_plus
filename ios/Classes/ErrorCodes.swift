// Copyright 2023, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

class ErrorCodes: NSObject {
    private override init() {}
    
    static let platformNotSupported = "platform_not_supported"
    static let openL2CapChannelFailed = "open_l2cap_channel_failed"
    static let closeL2CapChannelFailed = "close_l2cap_channel_failed"
    static let socketNotOpen = "no_socket_or_stream_is_open"
    static let inputStreamReadFailed = "input_stream_read_failed"
    static let outputStreamWriteFailed = "output_stream_write_failed"
    static let noOpenL2CapChannelFound = "no_open_l2cap_channel_found"
    static let bluetoothTurnedOff = "bluetooth_turned_off"

}
