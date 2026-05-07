#!/bin/zsh
set -eu

flutter_sdk=${1:?Usage: test_native.zsh /path/to/flutter}
package_root=${0:A:h:h}
framework_root="$flutter_sdk/bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64"
native_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/core_bluetooth_native.XXXXXX")
trap 'rm -rf "$native_test_dir"' EXIT

xcrun swiftc -swift-version 5 \
  -F "$framework_root" -framework FlutterMacOS \
  -Xlinker -rpath -Xlinker "$framework_root" \
  -module-cache-path "$native_test_dir/cache" \
  "$package_root"/darwin/core_bluetooth/Sources/core_bluetooth/**/*.swift \
  "$package_root"/test/native/*.swift \
  -o "$native_test_dir/registry_test"
"$native_test_dir/registry_test"
