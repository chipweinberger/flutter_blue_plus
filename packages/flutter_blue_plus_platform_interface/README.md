# flutter_blue_plus_platform_interface

A common platform interface for the [`flutter_blue_plus`][1] plugin.

This interface allows platform-specific implementations of the `flutter_blue_plus`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `flutter_blue_plus`, extend
[`FlutterBluePlusPlatform`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`FlutterBluePlusPlatform` by calling
`FlutterBluePlusPlatform.instance = MyPlatformFlutterBluePlus()`.

# Note on breaking changes

In a multi-dev scenario where each platform package is maintained by separate people,
you should strongly prefer non-breaking changes to the platform interface 
over breaking changes (such as adding a method to the interface). See 
https://flutter.dev/go/platform-interface-breaking-changes for a discussion
about that.

However, since FBP maintains all the platform packages ourselves, we can do breaking 
changes freely and release the updated platform packages at the same time. There
are therefore no restrictions when it comes to breaking changes.

[1]: ../flutter_blue_plus
[2]: lib/flutter_blue_plus_platform_interface.dart
