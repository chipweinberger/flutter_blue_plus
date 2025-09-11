# L2CAP Implementation Refactoring Plan

This document outlines a comprehensive step-by-step plan to refactor the L2CAP implementation to conform with Flutter Blue Plus (FBP) conventions as requested by the project owner.

## Current Issues Identified

Based on the change request feedback, the current implementation violates several FBP conventions:

1. **Java Code Structure**: Multiple Java files instead of single file integration
2. **iOS Implementation**: Using Swift instead of Objective-C, multiple files instead of single file
3. **Message Naming**: Messages don't follow `Bm` prefix convention and aren't in `bluetooth_msgs.dart`
4. **Message Implementation**: Messages are separate Java/Objective-C classes instead of following existing patterns
5. **Unnecessary Dependencies**: Added `MarshallingUtil` and logging changes that should be separate
6. **Method Naming**: Using constants instead of string literals for method names
7. **Example App Changes**: Added unnecessary dependencies to example app

## Refactoring Plan

### Phase 1: Analysis and Planning
**Estimated Duration: 1-2 days**

#### Step 1.1: Study FBP Conventions
- [x] Analyze existing FBP codebase structure
- [x] Study `FlutterBluePlusPlugin.java` to understand single-file pattern
- [x] Review iOS implementation patterns in existing `.m` files
- [x] Examine `bluetooth_msgs.dart` message structure and naming conventions
- [x] Document current message handling patterns
- [x] Create md file named FBP_CONVENTIONS.md summarizing findings

#### Step 1.2: Create Refactoring Checklist
- [x] Read section "Current Issues Identified" and then and study FBP_CONVENTIONS.md to understand the results of Step 1.1 
- [x] Map current L2CAP classes to consolidated structure
- [x] Identify which files need to be deleted
- [x] Plan message class consolidation strategy
- [x] Document method name changes needed
- [x] Create an md file outlining the results of your work in Step 1.2 named L2CAP_REFACTORING_CHECKLIST.md

### Phase 2: Message System Refactoring
**Estimated Duration: 2-3 days**

#### Step 2.1: Consolidate Dart Messages
- [x] Read the findings in FBP_CONVENTIONS.md and L2CAP_REFACTORING_CHECKLIST.md to understand the results of Step 1.1 and Step 1.2
- [x] Move all L2CAP message classes from separate files to `bluetooth_msgs.dart`
- [x] Rename all message classes to follow `Bm` prefix convention:
  - `CloseL2CapChannelRequest` → `BmCloseL2CapChannelRequest`
  - `CloseL2CapServer` → `BmCloseL2CapServer`
  - `DeviceConnectedToL2CapChannel` → `BmDeviceConnectedToL2CapChannel`
  - `ListenL2CapChannelRequest` → `BmListenL2CapChannelRequest`
  - `OpenL2CapChannelRequest` → `BmOpenL2CapChannelRequest`
  - `ReadL2CapChannelRequest` → `BmReadL2CapChannelRequest`
  - `WriteL2CapChannelRequest` → `BmWriteL2CapChannelRequest`
- [x] Update all imports across Flutter/Dart files
- [x] Remove separate message files from `lib/src/l2cap/messages/`
- [x] Create an md file outlining your changes and call it L2CAP_CONSOLIDATE_DART_MESSAGES_TASK.md

#### Step 2.2: Update Method Naming
- [x] Read the findings in FBP_CONVENTIONS.md, L2CAP_REFACTORING_CHECKLIST.md and  L2CAP_CONSOLIDATE_DART_MESSAGES_TASK.md to understand the results of steps 1.1, 1.2 and 2.1
- [x] Replace method name constants with string literals:
  - `L2CapMethodNames.CONNECT_TO_L2CAP_CHANNEL` → `"connectToL2CapChannel"`
  - Apply to all L2CAP method calls
- [x] Remove `L2CapMethodNames.java` and `L2CapMethodNames.swift` files
- [x] Update all method call references in Java and iOS code
- [x] Create an md file outlining your changes and call it L2CAP_UPDATED_METHOD_NAMING.md

### Phase 3: Android Implementation Refactoring
**Estimated Duration: 3-4 days**

#### Step 3.1: Consolidate Java Classes
- [x] Read the findings in FBP_CONVENTIONS.md, L2CAP_REFACTORING_CHECKLIST.md, L2CAP_CONSOLIDATE_DART_MESSAGES_TASK.md and L2CAP_UPDATED_METHOD_NAMING.md to understand the results of steps 1.1, 1.2, 2.1 and 2.2
- [x] Move all L2CAP functionality from separate files into `FlutterBluePlusPlugin.java`
- [x] Integrate `L2CapChannelManager.java` logic directly into main plugin class
- [x] Remove separate message classes and implement message handling inline
- [x] Follow existing FBP patterns for method handling
- [x] Create an md file outlining your changes and call it L2CAP_CONSOLIDATE_JAVA_CLASSES.md

#### Step 3.2: Remove Unnecessary Files
- [x] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
Then, if not already been done by the previous steps, proceed to:
- [x] Delete `ErrorCodes.java` (use existing error handling patterns)
- [x] Delete `L2CapChannelManager.java`
- [x] Delete all files in `l2cap/messages/` directory
- [x] Delete `l2cap/` directory entirely
- [x] Remove `MarshallingUtil.java` and `LogLevel.java`
- [x] Remove `PermissionUtil.java` (integrate needed functionality directly)
- [x] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of Step 3.2 so step 3.3 can hit the ground running

#### Step 3.3: Implement Inline Message Processing
- [x] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
  Then, if not already been done by the previous steps, proceed to:
- [x] Study existing message processing in `FlutterBluePlusPlugin.java`
- [x] Implement L2CAP message serialization/deserialization inline
- [x] Follow existing error handling patterns
- [x] Ensure thread safety using existing patterns
- [x] Update L2CAP_REFACTORING_CURRENT_STATE.md with your results

### Phase 4: iOS Implementation Refactoring
**Estimated Duration: 3-4 days**

#### Step 4.1: Convert Swift to Objective-C
- [X] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
- [x] Create new `.m` file for L2CAP functionality
- [x] Convert `FbpL2CapChannelManager.swift` logic to Objective-C
- [x] Integrate L2CAP methods directly into `FlutterBluePlusPlugin.m`
- [x] Follow existing Objective-C patterns and naming conventions
- [X] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of your work

#### Step 4.2: Remove Swift Files
- [x] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running 
- Then, if not already been done by the previous steps, proceed to:
- [x] Delete `FbpL2CapChannelManager.swift`
- [x] Delete all Swift message files in `l2cap/messages/`
- [x] Delete `l2cap/` directory from iOS implementation
- [x] Update iOS project configuration if needed
- [x] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of your work

#### Step 4.3: Implement Inline Message Processing
- [x] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
- [x] Convert Swift message handling to Objective-C inline processing
- [x] Follow existing iOS message handling patterns
- [x] Ensure compatibility with existing iOS architecture
- [x] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of your work

### Phase 5: API Integration Cleanup
**Estimated Duration: 2 days**

#### Step 5.1: Update Flutter Integration
- [x] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
- Then, if not already been done by the previous steps, proceed to:
- [x] Update `flutter_blue_plus.dart` imports and references
- [x] Update `bluetooth_device.dart` imports and references
- [x] Update `events.dart` imports and references
- [x] Remove references to deleted directories and files
- [x] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of your work

#### Step 5.2: Remove Example App Dependencies
- [ ] Read L2CAP_REFACTORING_CURRENT_STATE.md to hit the ground running
- [ ] Review example app, specifically L2CAP demo code
- [ ] Remove any added dependencies from example `pubspec.yaml` (cupertino_icons, permission_handler, convert) while still keeping intended L2CAP demonstration capability
- [ ] Get dependencies via fvm flutter ...
- [ ] Add dependency overrides if needed (so it can build locally)
- [ ] Update L2CAP_REFACTORING_CURRENT_STATE.md with the results of your work

### Phase 6: Testing and Validation
**Estimated Duration: 1 days**

#### Step 6.1: Code Review Preparation
- [ ] Ensure code follows all FBP conventions
- [ ] Verify single-file structure for both platforms
- [ ] Confirm all messages use `Bm` prefix and are in `bluetooth_msgs.dart`
- [ ] Validate method naming consistency
- [ ] Remove all debugging/logging code additions

### Phase 7: Documentation and Cleanup
**Estimated Duration: 1 day**

#### Step 7.1: Update Documentation
- [ ] Update README.md API documentation
- [ ] Ensure documentation reflects new structure
- [ ] Remove references to deleted files/classes

#### Step 7.2: Final Cleanup
- [ ] Remove any remaining unused imports
- [ ] Clean up any temporary code or comments
- [ ] Verify git status shows only intended changes
- [ ] Prepare commit message following project conventions

## Success Criteria

The refactoring will be considered successful when:

1. **Single File Structure**: All Java code consolidated in `FlutterBluePlusPlugin.java`
2. **Objective-C Implementation**: All iOS code in single `.m` file using Objective-C
3. **Message Convention**: All messages start with `Bm` and located in `bluetooth_msgs.dart`
4. **Inline Processing**: No separate message classes, following existing FBP patterns
5. **Clean Dependencies**: No unnecessary utilities or logging changes
6. **String Method Names**: Direct string literals instead of constants
7. **Clean Example**: No unnecessary dependencies in example app
8. **Full Functionality**: All L2CAP features working as intended
9. **Code Review Ready**: Implementation follows all FBP conventions
