import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_flutter_blue_plus.dart';

/// The interface that implementations of flutter_blue_plus must implement.
abstract class FlutterBluePlusPlatform extends PlatformInterface {
  FlutterBluePlusPlatform() : super(token: _token);

  static final _token = Object();

  static FlutterBluePlusPlatform _instance = MethodChannelFlutterBluePlus();

  /// The default instance of [FlutterBluePlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBluePlus].
  static FlutterBluePlusPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [FlutterBluePlusPlatform] when they register themselves.
  static set instance(FlutterBluePlusPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }
}
