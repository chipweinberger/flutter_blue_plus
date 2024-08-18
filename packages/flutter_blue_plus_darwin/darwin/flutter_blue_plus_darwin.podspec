#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_blue_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name = 'flutter_blue_plus'
  s.version = '0.0.1'
  s.summary = 'Flutter plugin for connecting and communicating with Bluetooth Low Energy devices, on Android and iOS'
  s.description = 'Flutter plugin for connecting and communicating with Bluetooth Low Energy devices, on Android and iOS'
  s.homepage = 'https://github.com/boskokg/flutter_blue_plus'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Chip Weinberger' => 'weinberger.c@gmail.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', }
  s.framework = 'CoreBluetooth'
end
