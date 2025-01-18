#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_blue_plus_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_blue_plus_ios'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for connecting and communicating with Bluetooth Low Energy devices, on Android and iOS'
  s.description      = 'Flutter plugin for connecting and communicating with Bluetooth Low Energy devices, on Android and iOS'
  s.homepage         = 'https://github.com/boskokg/flutter_blue_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Chip Weinberger' => 'weinberger.c@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_blue_plus_ios/Sources/flutter_blue_plus_ios/**/*.{h,m}'
  s.public_header_files = 'flutter_blue_plus_ios/Sources/flutter_blue_plus_ios/include/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.framework = 'CoreBluetooth'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', }
end
