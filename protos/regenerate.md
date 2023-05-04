// Copyright 2017, Paul DeMarco.\
// All rights reserved. Use of this source code is governed by a\
// BSD-style license that can be found in the LICENSE file.

# Generate protobuf files in Dart

1. Install protoc plugin globally `dart pub global activate protoc_plugin` [[ref]](https://pub.dev/packages/protoc_plugin).
2. Add pub bin to path PATH="$HOME/.pub-cache/bin:$PATH"
3. Run the following commands from this project's protos folder:
```protoc --dart_out=../lib/gen ./flutterblueplus.proto```
```protoc --objc_out=../ios/gen ./flutterblueplus.proto```
```protoc --objc_out=../macos/gen ./flutterblueplus.proto```
4. Ensure `protoc --version` matches the one in './ios/flutter_blue_plus.podspec' and './macos/flutter_blue_plus.podspec'
