# vx_flutter_blue_platform_interface

A common platform interface for the [`vx_flutter_blue`][1] plugin.

This interface allows platform-specific implementations of the `vx_flutter_blue`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `vx_flutter_blue`, extend
[`VXFlutterBluePlatform`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`VXFlutterBluePlatform` by calling
`VXFlutterBluePlatform.instance = MyPlatformVXFlutterBlue()`.

# Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See <https://flutter.dev/go/platform-interface-breaking-changes> for a discussion
on why a less-clean interface is preferable to a breaking change.

[1]: ../vx_flutter_blue
[2]: lib/vx_flutter_blue_platform_interface.dart
