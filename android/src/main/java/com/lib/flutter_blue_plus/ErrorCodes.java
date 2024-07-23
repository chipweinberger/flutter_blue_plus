// Copyright 2024, Continental Automotive Technologies GmbH
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
package com.lib.flutter_blue_plus;

public interface ErrorCodes {
    String PLATFORM_NOT_SUPPORTED = "platform_not_supported";
    String OPEN_L2CAP_CHANNEL_FAILED = "open_l2cap_channel_failed";
    String CLOSE_L2CAP_CHANNEL_FAILED = "close_l2cap_channel_failed";
    String SOCKET_NOT_OPEN = "no_socket_or_stream_is_open";
    String INPUT_STREAM_READ_FAILED = "input_stream_read_failed";
    String OUTPUT_STREAM_WRITE_FAILED = "output_stream_write_failed";
    String NO_OPEN_L2CAP_CHANNEL_FOUND = "no_open_l2cap_channel_found";
    String BLUETOOTH_TURNED_OFF = "bluetooth_turned_off";
    String MESSAGE_ARGUMENTS_NOT_PROVIDED = "message_arguments_not_provided";
    String NO_PERMISSION = "no_permissions";
}
