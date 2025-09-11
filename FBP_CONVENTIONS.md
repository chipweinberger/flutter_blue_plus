# Flutter Blue Plus (FBP) Code Conventions

This document outlines the coding conventions and architectural patterns used in Flutter Blue Plus, based on analysis of the existing codebase. These conventions should be followed when adding new features or refactoring existing code.

## File Structure Conventions

### Android Implementation
- **Single File Pattern**: All Android functionality is consolidated into `FlutterBluePlusPlugin.java`
- **No Separate Class Files**: Avoid creating separate utility classes, managers, or message classes
- **Inline Processing**: All message handling, serialization/deserialization, and business logic is implemented directly in the main plugin file
- **No External Dependencies**: Avoid adding new utility classes like `MarshallingUtil`, `LogLevel`, `PermissionUtil` etc.

### iOS Implementation  
- **Objective-C Only**: All iOS implementations use Objective-C (`.m` and `.h` files)
- **Single File Pattern**: Main functionality consolidated in `FlutterBluePlusPlugin.m`
- **No Swift Files**: Avoid creating new Swift files - convert any Swift code to Objective-C
- **Inline Processing**: Similar to Android, keep all logic in the main plugin file

### Dart/Flutter Structure
- **Message Consolidation**: All message classes must be in `lib/src/bluetooth_msgs.dart`
- **No Separate Message Files**: Avoid creating separate files for message classes
- **Part of flutter_blue_plus**: All Dart files use `part of flutter_blue_plus;`

## Naming Conventions

### Message Classes (Dart)
- **Prefix**: All message classes MUST start with `Bm` (BluetoothMessage)
- **Examples**:
  - `BmConnectRequest` ✓
  - `BmScanSettings` ✓  
  - `BmCharacteristicData` ✓
  - `ConnectRequest` ✗ (missing Bm prefix)
  - `L2CapChannelRequest` ✗ (missing Bm prefix)

### Method Names
- **String Literals**: Use direct string literals in case statements and method calls
- **Examples**:
  - `case "startScan":` ✓
  - `case "turnOn":` ✓
  - `case L2CapMethodNames.CONNECT_TO_L2CAP_CHANNEL:` ✗ (avoid constants)
  - `if ([@"setOptions" isEqualToString:call.method])` ✓ (iOS)

### Method Naming Pattern
- Use camelCase for method names
- Be descriptive but concise
- Follow existing patterns like: `flutterHotRestart`, `connectedCount`, `setLogLevel`, etc.

## Message Handling Patterns

### Android (Java)
```java
case "methodName": 
{
    // Permission checks if needed
    ensurePermissions(permissions, (granted, perm) -> {
        // Input validation
        Map<String, Object> data = (Map<String, Object>) call.arguments;
        if (data == null) {
            result.error("invalidArguments", "Arguments required", null);
            return;
        }
        
        // Inline parameter extraction
        String remoteId = (String) data.get("remote_id");
        int value = (int) data.get("some_value");
        
        // Business logic directly here
        // No separate manager/utility classes
        
        // Return result
        result.success(responseMap);
    });
    break;
}
```

### iOS (Objective-C)
```objc
else if ([@"methodName" isEqualToString:call.method])
{
    // Input validation
    NSDictionary *data = (NSDictionary*)call.arguments;
    
    // Inline parameter extraction  
    NSString *remoteId = data[@"remote_id"];
    NSNumber *value = data[@"some_value"];
    
    // Business logic directly here
    // No separate manager/utility classes
    
    // Return result
    result(@(success));
}
```

### Dart Message Structure
```dart
class BmMessageName {
  final String remoteId;
  final int value;
  
  BmMessageName({
    required this.remoteId,
    required this.value,
  });
  
  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['value'] = value;
    return data;
  }
  
  factory BmMessageName.fromMap(Map<dynamic, dynamic> json) {
    return BmMessageName(
      remoteId: json['remote_id'],
      value: json['value'],
    );
  }
}
```

## Error Handling Patterns

### Android
```java
// Use existing patterns, not custom error codes
result.error("bluetoothUnavailable", "the device does not support bluetooth", null);
result.error("invalidArguments", "Arguments required", null);
```

### iOS  
```objc
// Use FlutterError pattern
result([FlutterError errorWithCode:@"bluetoothUnavailable" 
                            message:@"the device does not support bluetooth" 
                            details:NULL]);
```

## Current FBP Architecture Analysis

### What FBP Does Right
1. **Single File Structure**: Main plugin logic consolidated in one file per platform
2. **Consistent Naming**: `Bm` prefix for all message classes
3. **Centralized Messages**: All messages in `bluetooth_msgs.dart`
4. **String Literals**: Direct string method names, no constants
5. **Inline Processing**: No unnecessary abstraction layers
6. **Platform Consistency**: Similar patterns across Android/iOS

### Anti-Patterns to Avoid
1. **Multiple Java Classes**: Creating separate managers, utils, message classes
2. **Swift on iOS**: Use Objective-C instead
3. **Message Constants**: Avoid `L2CapMethodNames.CONSTANT` style
4. **External Message Files**: Don't create separate message files
5. **Utility Classes**: Avoid `MarshallingUtil`, `PermissionUtil` etc.
6. **Logging Frameworks**: Don't add custom logging utilities

## Permission Handling

### Android
```java
ArrayList<String> permissions = new ArrayList<>();
if (Build.VERSION.SDK_INT >= 31) {
    permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
}
if (Build.VERSION.SDK_INT <= 30) {
    permissions.add(Manifest.permission.BLUETOOTH);
}

ensurePermissions(permissions, (granted, perm) -> {
    if (granted == false) {
        result.error("methodName", String.format("FlutterBluePlus requires %s permission", perm), null);
        return;
    }
    // Continue with operation
});
```

### iOS
iOS permissions are handled through system prompts and Info.plist configuration.

## Key Takeaways for L2CAP Refactoring

Based on this analysis, the L2CAP implementation needs to be refactored to:

1. **Consolidate All Java Code** into `FlutterBluePlusPlugin.java`
2. **Convert Swift to Objective-C** and integrate into `FlutterBluePlusPlugin.m`  
3. **Move All Messages** to `bluetooth_msgs.dart` with `Bm` prefix
4. **Replace Method Constants** with string literals
5. **Remove Utility Classes** and inline their functionality
6. **Follow Existing Patterns** for error handling, permissions, and message processing

This approach maintains consistency with the existing FBP codebase and follows the project's established architectural principles.