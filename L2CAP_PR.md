# L2CAP Integration Changes

This document outlines the changes made in the current branch to integrate L2CAP (Logical Link Control and Adaptation Protocol) channels for Bluetooth communication in Flutter Blue Plus.

## Overview

The changes add comprehensive L2CAP channel support, enabling bidirectional communication over Bluetooth using L2CAP sockets. This allows for custom protocols and higher-level data transmission beyond standard GATT characteristics.

## Affected Files

### Configuration Files
- `.gitignore` - Added local.properties exclusions
- `README.md` - Updated API documentation tables

### Android Implementation
- `android/src/main/java/com/lib/flutter_blue_plus/ErrorCodes.java` - **NEW** Error code constants
- `android/src/main/java/com/lib/flutter_blue_plus/FlutterBluePlusPlugin.java` - Enhanced with L2CAP methods
- `android/src/main/java/com/lib/flutter_blue_plus/log/LogLevel.java` - **NEW** Logging utilities
- `android/src/main/java/com/lib/flutter_blue_plus/permission/PermissionUtil.java` - **NEW** Permission handling
- `android/src/main/java/com/lib/flutter_blue_plus/utils/MarshallingUtil.java` - **NEW** Data marshalling utilities
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapChannelManager.java` - **NEW** Core L2CAP manager
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapMethodNames.java` - **NEW** Method constants
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapChannelRequest.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapServer.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/DeviceConnectedToL2CapChannel.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ListenL2CapChannelRequest.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/OpenL2CapChannelRequest.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ReadL2CapChannelRequest.java` - **NEW** Message class
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/WriteL2CapChannelRequest.java` - **NEW** Message class

### iOS Implementation
- `ios/Classes/FbpL2CapChannelManager.swift` - **NEW** iOS L2CAP manager
- `ios/Classes/FlutterBluePlusPlugin.swift` - Enhanced with L2CAP methods
- `ios/Classes/l2cap/L2CapMethodNames.swift` - **NEW** Method constants
- `ios/Classes/l2cap/messages/CloseL2CapChannelRequest.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/CloseL2CapServer.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/DeviceConnectedToL2CapChannel.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/ListenL2CapChannelRequest.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/OpenL2CapChannelRequest.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/ReadL2CapChannelRequest.swift` - **NEW** Message class
- `ios/Classes/l2cap/messages/WriteL2CapChannelRequest.swift` - **NEW** Message class

### Flutter/Dart Implementation
- `lib/src/flutter_blue_plus.dart` - Added L2CAP global methods
- `lib/src/bluetooth_device.dart` - Added L2CAP device methods  
- `lib/src/events.dart` - Added L2CAP event streams
- `lib/src/bluetooth_msgs.dart` - **NEW** Message class definitions for L2CAP
- `lib/src/l2cap/` - **NEW** Directory with L2CAP-specific classes

## Key Changes

### 1. New L2CAP API Methods

#### FlutterBluePlus Global API
- `listenL2CapChannel()` - Opens a server socket and returns the PSM (Protocol/Service Multiplexer) for the channel
- `closeL2CapServer()` - Closes a server socket with the provided PSM

#### BluetoothDevice API
- `openL2CapChannel()` - Opens a L2CAP channel to a Bluetooth device (Android only)
- `closeL2CapChannel()` - Closes a L2CAP channel
- `readL2CapChannel()` - Reads data from a L2CAP channel
- `writeL2CapChannel()` - Sends bytes using the L2CAP channel with the specified PSM

#### Events API
- `events.l2CapChannelConnected` - Stream notification when a device connects to an offered L2CAP channel

### 2. Android Implementation

#### New Files and Classes
- `ErrorCodes.java` - Centralized error code definitions for L2CAP operations
- `L2CapChannelManager.java` - Core manager for L2CAP channel operations
- `L2CapMethodNames.java` - Method name constants for L2CAP operations
- Multiple message classes in `l2cap/messages/` for request/response handling:
  - `CloseL2CapChannelRequest`
  - `CloseL2CapServer`
  - `DeviceConnectedToL2CapChannel`
  - `ListenL2CapChannelRequest`
  - `OpenL2CapChannelRequest`
  - `ReadL2CapChannelRequest`
  - `WriteL2CapChannelRequest`

#### Core Changes
- Enhanced `FlutterBluePlusPlugin.java` with L2CAP method handling
- Added permission utilities (`PermissionUtil.java`)
- Integrated logging system (`LogLevel.java`)
- Added marshalling utilities (`MarshallingUtil.java`)

### 3. iOS Implementation
- `FbpL2CapChannelManager.swift` - iOS L2CAP channel management
- Multiple Swift message classes for iOS L2CAP operations
- Integration with existing iOS plugin architecture

### 4. Flutter/Dart Integration
- `FlutterBluePlusPlugin.swift` updated with L2CAP method handlers
- New Dart classes for L2CAP operations
- Stream integration for L2CAP events
- Error handling and result marshalling

### 5. Documentation Updates
- README.md updated with new L2CAP API documentation
- Added comprehensive API tables showing platform support
- Updated method descriptions and usage examples

### 6. Build Configuration
- Updated `.gitignore` to exclude `local.properties` files
- Added necessary Android permissions and dependencies

## Technical Features

### Cross-Platform Support
- **Android**: Full L2CAP support with all operations
- **iOS**: L2CAP support with some platform-specific limitations

### Error Handling
- Comprehensive error codes for various failure scenarios
- Proper exception handling and user feedback
- Platform-specific error reporting

### Stream Integration
- L2CAP events integrated with Flutter's Stream API
- Real-time notifications for channel connections
- Consistent API pattern with existing Bluetooth operations

### Memory Management
- Proper resource cleanup for L2CAP channels
- Thread-safe operations
- Background processing support

## Impact

This integration significantly expands Flutter Blue Plus capabilities by:
1. Enabling custom Bluetooth protocols beyond GATT
2. Supporting higher throughput data transmission
3. Providing bidirectional communication channels
4. Maintaining consistency with existing API patterns
5. Supporting both server and client L2CAP operations

The changes maintain backward compatibility while adding powerful new functionality for advanced Bluetooth applications.