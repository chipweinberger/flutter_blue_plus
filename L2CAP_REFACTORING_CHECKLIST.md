# L2CAP Refactoring Checklist

This document provides a detailed checklist for refactoring the L2CAP implementation to conform with Flutter Blue Plus conventions, based on analysis of the current implementation and FBP code conventions.

## Current Implementation Analysis

### Current L2CAP Structure Issues
1. **Multiple Java files** instead of single-file integration
2. **Swift files on iOS** instead of Objective-C
3. **Message classes** not following `Bm` prefix convention
4. **Separate message files** instead of consolidation in `bluetooth_msgs.dart`
5. **Method name constants** instead of string literals
6. **Utility classes** that should be inlined

## File Mapping and Consolidation Plan

### Android Files to be Consolidated

#### Current Structure → Target Structure

**Core Manager Files:**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapChannelManager.java` → **Integrate into `FlutterBluePlusPlugin.java`**

**Channel Classes:**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapChannel.java` → **Inline into `FlutterBluePlusPlugin.java`**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapClientChannel.java` → **Inline into `FlutterBluePlusPlugin.java`**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapServerChannel.java` → **Inline into `FlutterBluePlusPlugin.java`**

**Info Classes:**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/L2CapInfo.java` → **Inline into `FlutterBluePlusPlugin.java`**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/ClientSocketInfo.java` → **Inline into `FlutterBluePlusPlugin.java`**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/ServerSocketInfo.java` → **Inline into `FlutterBluePlusPlugin.java`**

**Message Classes:**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapChannelRequest.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapServer.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/DeviceConnectedToL2CapChannel.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ListenL2CapChannelRequest.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ListenL2CapChannelResponse.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/OpenL2CapChannelRequest.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ReadL2CapChannelRequest.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ReadL2CapChannelResponse.java` → **Remove (inline processing)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/WriteL2CapChannelRequest.java` → **Remove (inline processing)**

**Constants and Attributes:**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapMethodNames.java` → **Remove (use string literals)**
- `android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapAttributeNames.java` → **Remove (use string literals)**

### iOS Files to be Consolidated

#### Current Structure → Target Structure

**Core Manager Files:**
- `ios/Classes/L2CapChannelManager.swift` → **Convert to Objective-C and integrate into `FlutterBluePlusPlugin.m`**
- `ios/Classes/L2CapServerInfo.swift` → **Convert to Objective-C and inline into `FlutterBluePlusPlugin.m`**

**Message Classes:**
- `ios/Classes/l2capmessages/CloseL2CapChannelRequest.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/CloseL2CapServer.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/DeviceConnectedToL2CapChannel.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/ListenL2CapChannelRequest.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/ListenL2CapChannelResponse.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/OpenL2CapChannelRequest.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/ReadL2CapChannelRequest.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/ReadL2CapChannelResponse.swift` → **Remove (inline processing)**
- `ios/Classes/l2capmessages/WriteL2CapChannelRequest.swift` → **Remove (inline processing)**

**Constants:**
- `ios/Classes/L2CapMethodNames.swift` → **Remove (use string literals)**
- `ios/Classes/l2capmessages/L2CapAttributeNames.swift` → **Remove (use string literals)**

### Dart/Flutter Files to be Consolidated

#### Current Structure → Target Structure

**Message Files:**
- `lib/src/l2cap_messages.dart` → **Move all classes to `bluetooth_msgs.dart` with `Bm` prefix**
- `lib/src/l2cap_constants.dart` → **Remove (use string literals directly)**

## Files to be Deleted

### Android Files for Deletion
```
android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapAttributeNames.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapChannelManager.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/L2CapMethodNames.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapChannel.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapClientChannel.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/channel/L2CapServerChannel.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/L2CapInfo.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/ClientSocketInfo.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/info/ServerSocketInfo.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapChannelRequest.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/CloseL2CapServer.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/DeviceConnectedToL2CapChannel.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ListenL2CapChannelRequest.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ListenL2CapChannelResponse.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/OpenL2CapChannelRequest.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ReadL2CapChannelRequest.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/ReadL2CapChannelResponse.java
android/src/main/java/com/lib/flutter_blue_plus/l2cap/messages/WriteL2CapChannelRequest.java
```

**Entire Directories:**
```
android/src/main/java/com/lib/flutter_blue_plus/l2cap/
```

### iOS Files for Deletion
```
ios/Classes/L2CapChannelManager.swift
ios/Classes/L2CapMethodNames.swift
ios/Classes/L2CapServerInfo.swift
ios/Classes/l2capmessages/CloseL2CapChannelRequest.swift
ios/Classes/l2capmessages/CloseL2CapServer.swift
ios/Classes/l2capmessages/DeviceConnectedToL2CapChannel.swift
ios/Classes/l2capmessages/L2CapAttributeNames.swift
ios/Classes/l2capmessages/ListenL2CapChannelRequest.swift
ios/Classes/l2capmessages/ListenL2CapChannelResponse.swift
ios/Classes/l2capmessages/OpenL2CapChannelRequest.swift
ios/Classes/l2capmessages/ReadL2CapChannelRequest.swift
ios/Classes/l2capmessages/ReadL2CapChannelResponse.swift
ios/Classes/l2capmessages/WriteL2CapChannelRequest.swift
```

**Entire Directories:**
```
ios/Classes/l2capmessages/
```

### Dart Files for Deletion
```
lib/src/l2cap_messages.dart
lib/src/l2cap_constants.dart
```

## Message Class Consolidation Strategy

### Current Messages → New Bm-Prefixed Messages

| Current Class Name | New Class Name (Bm prefix) | Location |
|-------------------|----------------------------|-----------|
| `L2CapChannelConnected` | `BmL2CapChannelConnected` | `bluetooth_msgs.dart` |
| `ListenL2CapChannelRequest` | `BmListenL2CapChannelRequest` | `bluetooth_msgs.dart` |
| `ListenL2CapChannelResponse` | `BmListenL2CapChannelResponse` | `bluetooth_msgs.dart` |
| `CloseL2CapServer` | `BmCloseL2CapServer` | `bluetooth_msgs.dart` |
| `OpenL2CapChannelRequest` | `BmOpenL2CapChannelRequest` | `bluetooth_msgs.dart` |
| `CloseL2CapChannelRequest` | `BmCloseL2CapChannelRequest` | `bluetooth_msgs.dart` |
| `ReadL2CapChannelRequest` | `BmReadL2CapChannelRequest` | `bluetooth_msgs.dart` |
| `ReadL2CapChannelResponse` | `BmReadL2CapChannelResponse` | `bluetooth_msgs.dart` |
| `WriteL2CapChannelRequest` | `BmWriteL2CapChannelRequest` | `bluetooth_msgs.dart` |

### Message Structure Requirements
Each message class must follow FBP conventions:
- Include `toMap()` method for serialization
- Include `fromMap()` factory constructor for deserialization
- Use consistent parameter names matching existing patterns
- Follow existing error handling patterns

## Method Name Changes

### Current Constants → String Literals

| Current Constant | String Literal | Usage Location |
|------------------|----------------|-----------------|
| `L2CapMethodNames.CONNECT_TO_L2CAP_CHANNEL` | `"connectToL2CapChannel"` | Android/iOS method handlers |
| `L2CapMethodNames.CLOSE_L2CAP_CHANNEL` | `"closeL2CapChannel"` | Android/iOS method handlers |
| `L2CapMethodNames.READ_L2CAP_CHANNEL` | `"readL2CapChannel"` | Android/iOS method handlers |
| `L2CapMethodNames.WRITE_L2CAP_CHANNEL` | `"writeL2CapChannel"` | Android/iOS method handlers |
| `L2CapMethodNames.LISTEN_L2CAP_CHANNEL` | `"listenL2CapChannel"` | Android/iOS method handlers |
| `L2CapMethodNames.CLOSE_L2CAP_SERVER` | `"closeL2CapServer"` | Android/iOS method handlers |
| `L2CapMethodNames.DEVICE_CONNECTED` | `"deviceConnectedToL2CapChannel"` | Android/iOS event handlers |

### Dart Constants → String Literals

| Current Constant | String Literal | Usage Location |
|------------------|----------------|-----------------|
| `methodConnectToL2CapChannel` | `"connectToL2CapChannel"` | Dart method calls |
| `methodCloseL2CapChannel` | `"closeL2CapChannel"` | Dart method calls |
| `methodReadL2CapChannel` | `"readL2CapChannel"` | Dart method calls |
| `methodWriteL2CapChannel` | `"writeL2CapChannel"` | Dart method calls |
| `methodListenL2CapChannel` | `"listenL2CapChannel"` | Dart method calls |
| `methodCloseL2CapServer` | `"closeL2CapServer"` | Dart method calls |
| `deviceConnectedCallback` | `"deviceConnectedToL2CapChannel"` | Dart event streams |

## Implementation Strategy

### Phase 1: Dart Layer Consolidation
1. Move all message classes from `l2cap_messages.dart` to `bluetooth_msgs.dart`
2. Add `Bm` prefix to all message classes
3. Remove `l2cap_constants.dart` and replace with string literals
4. Update all imports and references in Flutter files

### Phase 2: Android Consolidation
1. Extract all L2CAP functionality from separate files
2. Integrate everything into `FlutterBluePlusPlugin.java`
3. Implement inline message processing following FBP patterns
4. Replace method name constants with string literals
5. Delete all separate L2CAP files and directories

### Phase 3: iOS Conversion and Consolidation
1. Convert Swift L2CAP code to Objective-C
2. Integrate all functionality into `FlutterBluePlusPlugin.m`
3. Implement inline message processing following FBP patterns
4. Replace method name constants with string literals
5. Delete all Swift L2CAP files and directories

### Phase 4: Integration Testing
1. Verify all L2CAP functionality works after consolidation
2. Test both Android and iOS platforms
3. Ensure no regressions in existing Bluetooth functionality
4. Validate against existing FBP conventions

## Success Metrics

The refactoring will be successful when:

1. **Single File Structure**: All platform code consolidated in main plugin files
2. **Objective-C iOS**: No Swift files remaining
3. **Bm Message Prefix**: All messages follow `BmXxx` naming convention
4. **Consolidated Messages**: All messages in `bluetooth_msgs.dart`
5. **String Literals**: No method name constants
6. **Clean Dependencies**: No utility classes or separate managers
7. **FBP Compliance**: Code follows all existing FBP patterns
8. **Functional Parity**: All L2CAP features work as before
9. **Clean Git History**: Only necessary files in git status

## Risk Mitigation

1. **Backup Current Implementation**: Keep current branch as reference
2. **Incremental Changes**: Implement phase by phase
3. **Test After Each Phase**: Verify functionality before proceeding
4. **Code Review**: Follow FBP review process
5. **Documentation Update**: Update all relevant documentation