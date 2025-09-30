// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// API docs from [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web).
// Attributions and copyright licensing by Mozilla Contributors is licensed
// under [CC-BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/.

// Generated from Web IDL definitions.

// ignore_for_file: unintended_html_in_doc_comment

@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart' show EventTarget;

import 'web_bluetooth.dart';

@JS()
external Window get window;

/// The **`Window`** interface represents a window containing a  document; the
/// `document` property points to the
/// [DOM document](https://developer.mozilla.org/en-US/docs/Web/API/Document)
/// loaded in that window.
///
/// A window for a given document can be obtained using the
/// [document.defaultView] property.
///
/// A global variable, `window`, representing the window in which the script is
/// running, is exposed to JavaScript code.
///
/// The `Window` interface is home to a variety of functions, namespaces,
/// objects, and constructors which are not necessarily directly associated with
/// the concept of a user interface window. However, the `Window` interface is a
/// suitable place to include these items that need to be globally available.
/// Many of these are documented in the
/// [JavaScript Reference](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference)
/// and the
/// [DOM Reference](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model).
///
/// In a tabbed browser, each tab is represented by its own `Window` object; the
/// global `window` seen by JavaScript code running within a given tab always
/// represents the tab in which the code is running. That said, even in a tabbed
/// browser, some properties and methods still apply to the overall window that
/// contains the tab, such as [Window.resizeTo] and [Window.innerHeight].
/// Generally, anything that can't reasonably pertain to a tab pertains to the
/// window instead.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/Window).
extension type Window._(JSObject _) implements EventTarget, JSObject {
  /// The **`Window.navigator`** read-only property returns a
  /// reference to the [Navigator] object, which has methods and properties
  /// about the application running the script.
  external Navigator get navigator;
}

/// The **`Navigator`** interface represents the state and the identity of the
/// user agent. It allows scripts to query it and to register themselves to
/// carry on some activities.
///
/// A `Navigator` object can be retrieved using the read-only [window.navigator]
/// property.
///
/// ---
///
/// API documentation sourced from
/// [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/Navigator).
extension type Navigator._(JSObject _) implements JSObject {
  /// The **`bluetooth`** read-only property of the [Navigator] interface returns
  /// a [Bluetooth] object for the current document, providing access to
  /// [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
  /// functionality.
  external Bluetooth get bluetooth;
}
