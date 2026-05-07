Pod::Spec.new do |s|
  s.name             = 'core_bluetooth'
  s.version          = '0.1.0'
  s.summary          = 'CoreBluetooth wrapper for Dart on iOS and macOS.'
  s.description      = 'A standalone CoreBluetooth wrapper for Dart on iOS and macOS.'
  s.homepage         = 'https://github.com/chipweinberger/flutter_blue_plus'
  s.license          = { :file => '../LICENSE.md' }
  s.author           = { 'Chip Weinberger' => 'example@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'core_bluetooth/Sources/core_bluetooth/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'
  s.framework = 'CoreBluetooth'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
