part of flutter_blue_plus;

String _hexEncode(List<int> numbers) {
  return numbers.map((n) => (n & 0xFF).toRadixString(16).padLeft(2, '0')).join();
}

List<int>? _tryHexDecode(String hex) {
  List<int> numbers = [];
  for (int i = 0; i < hex.length; i += 2) {
    String hexPart = hex.substring(i, i + 2);
    int? num = int.tryParse(hexPart, radix: 16);
    if (num == null) {
      return null;
    }
    numbers.add(num);
  }
  return numbers;
}

List<int> _hexDecode(String hex) {
  List<int> numbers = [];
  for (int i = 0; i < hex.length; i += 2) {
    String hexPart = hex.substring(i, i + 2);
    int num = int.parse(hexPart, radix: 16);
    numbers.add(num);
  }
  return numbers;
}

int _compareAsciiLowerCase(String a, String b) {
  const int upperCaseA = 0x41;
  const int upperCaseZ = 0x5a;
  const int asciiCaseBit = 0x20;
  var defaultResult = 0;
  for (var i = 0; i < a.length; i++) {
    if (i >= b.length) return 1;
    var aChar = a.codeUnitAt(i);
    var bChar = b.codeUnitAt(i);
    if (aChar == bChar) continue;
    var aLowerCase = aChar;
    var bLowerCase = bChar;
    // Upper case if ASCII letters.
    if (upperCaseA <= bChar && bChar <= upperCaseZ) {
      bLowerCase += asciiCaseBit;
    }
    if (upperCaseA <= aChar && aChar <= upperCaseZ) {
      aLowerCase += asciiCaseBit;
    }
    if (aLowerCase != bLowerCase) return (aLowerCase - bLowerCase).sign;
    if (defaultResult == 0) defaultResult = aChar - bChar;
  }
  if (b.length > a.length) return -1;
  return defaultResult.sign;
}

extension AddOrUpdate<T> on List<T> {
  /// add an item to a list, or update item if it already exists
  void addOrUpdate(T item) {
    final index = indexOf(item);
    if (index != -1) {
      this[index] = item;
    } else {
      add(item);
    }
  }
}

extension FutureTimeout<T> on Future<T> {
  Future<T> fbpTimeout(int seconds, String function) {
    return this.timeout(Duration(seconds: seconds), onTimeout: () {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp, function, FbpErrorCode.timeout.index, "Timed out after ${seconds}s");
    });
  }

  Future<T> fbpEnsureDeviceIsConnected(BluetoothDevice device, String function) {
    // Create a completer to represent the result of this extended Future.
    var completer = Completer<T>();

    // disconnection listener.
    var subscription = device.connectionState.listen((event) {
      if (event == BluetoothConnectionState.disconnected) {
        if (!completer.isCompleted) {
          completer.completeError(FlutterBluePlusException(
              ErrorPlatform.fbp, function, FbpErrorCode.deviceIsDisconnected.index, "Device is disconnected"));
        }
      }
    });

    // When the original future completes
    // complete our completer and cancel the subscription.
    this.then((value) {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(value);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(error);
      }
    });

    return completer.future;
  }

  Future<T> fbpEnsureAdapterIsOn(String function) {
    // Create a completer to represent the result of this extended Future.
    var completer = Completer<T>();

    // disconnection listener.
    var subscription = FlutterBluePlus.adapterState.listen((event) {
      if (event == BluetoothAdapterState.off || event == BluetoothAdapterState.turningOff) {
        if (!completer.isCompleted) {
          completer.completeError(FlutterBluePlusException(
              ErrorPlatform.fbp, function, FbpErrorCode.adapterIsOff.index, "Bluetooth adapter is off"));
        }
      }
    });

    // When the original future completes
    // complete our completer and cancel the subscription.
    this.then((value) {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(value);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(error);
      }
    });

    return completer.future;
  }
}

// This is a reimplementation of BehaviorSubject from RxDart library.
// It is essentially a stream but:
//  1. we cache the latestValue of the stream
//  2. the "latestValue" is re-emitted whenever the stream is listened to
class _StreamControllerReEmit<T> {
  T latestValue;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  _StreamControllerReEmit({required T initialValue}) : this.latestValue = initialValue;

  Stream<T> get stream {
    if (latestValue != null) {
      return _controller.stream.newStreamWithInitialValue(latestValue!);
    } else {
      return _controller.stream;
    }
  }

  T get value => latestValue;

  void add(T newValue) {
    latestValue = newValue;
    _controller.add(newValue);
  }

  void addError(Object error) {
    _controller.addError(error);
  }

  void listen(Function(T) onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    onData(latestValue);
    _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<void> close() {
    return _controller.close();
  }
}

// imediately starts listening to a broadcast stream and
// buffering it in a new single-subscription stream
class _BufferStream<T> {
  final Stream<T> _inputStream;
  late final StreamSubscription? _subscription;
  late final StreamController<T> _controller;
  late bool hasReceivedValue = false;

  _BufferStream.listen(this._inputStream) {
    _controller = StreamController<T>(
      onCancel: () {
        _subscription?.cancel();
      },
      onPause: () {
        _subscription?.pause();
      },
      onResume: () {
        _subscription?.resume();
      },
      onListen: () {}, // inputStream is already listened to
    );

    // immediately start listening to the inputStream
    _subscription = _inputStream.listen(
      (data) {
        hasReceivedValue = true;
        _controller.add(data);
      },
      onError: (e) {
        _controller.addError(e);
      },
      onDone: () {
        _controller.close();
      },
      cancelOnError: false,
    );
  }

  void close() {
    _subscription?.cancel();
    _controller.close();
  }

  Stream<T> get stream async* {
    yield* _controller.stream;
  }
}

// Helper for 'newStreamWithInitialValue' method for streams.
class _NewStreamWithInitialValueTransformer<T> extends StreamTransformerBase<T, T> {
  /// the initial value to push to the new stream
  final T initialValue;

  /// controller for the new stream
  late StreamController<T> controller;

  /// subscription to the original stream
  late StreamSubscription<T> subscription;

  /// new stream listener count
  var listenerCount = 0;

  _NewStreamWithInitialValueTransformer(this.initialValue);

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bind(stream, broadcast: true);
    } else {
      return _bind(stream);
    }
  }

  Stream<T> _bind(Stream<T> stream, {bool broadcast = false}) {

    /////////////////////////////////////////
    /// Original Stream Subscription Callbacks
    /// 

    /// When the original stream emits data, forward it to our new stream
    void onData(T data) {
      controller.add(data);
    }

    /// When the original stream is done, close our new stream
    void onDone() {
      controller.close();
    }

    /// When the original stream has an error, forward it to our new stream
    void onError(Object error) {
      controller.addError(error);
    }

    /// When a client listens to our new stream, emit the
    /// initial value and subscribe to original stream if needed
    void onListen() {
      // Emit the initial value to our new stream
      controller.add(initialValue);

      // listen to the original stream, if needed
      if (listenerCount == 0) {
        subscription = stream.listen(
          onData,
          onError: onError,
          onDone: onDone,
        );
      }

      // count listeners of the new stream
      listenerCount++;
    }

    //////////////////////////////////////
    ///  New Stream Controller Callbacks
    /// 

    /// (Single Subscription Only) When a client pauses
    /// the new stream, pause the original stream 
    void onPause() {
      subscription.pause();
    }

    /// (Single Subscription Only) When a client resumes
    /// the new stream, resume the original stream 
    void onResume() {
      subscription.resume();
    }

    /// Called when a client cancels their 
    /// subscription to the new stream, 
    void onCancel() {
      // count listeners of the new stream
      listenerCount--;

      // when there are no more listeners of the new stream,
      // cancel the subscription to the original stream,
      // and close the new stream controller
      if (listenerCount == 0) {
        subscription.cancel();
        controller.close();
      }
    }

    //////////////////////////////////////
    /// Return New Stream
    /// 

    // create a new stream controller
    if (broadcast) {
      controller = StreamController<T>.broadcast(
        onListen: onListen,
        onCancel: onCancel,
      );
    } else {
      controller = StreamController<T>(
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      );
    }

    return controller.stream;
  }
}

extension _StreamNewStreamWithInitialValue<T> on Stream<T> {
  Stream<T> newStreamWithInitialValue(T initialValue) {
    return transform(_NewStreamWithInitialValueTransformer(initialValue));
  }
}

// ignore: unused_element
Stream<T> _mergeStreams<T>(List<Stream<T>> streams) {
  StreamController<T> controller = StreamController<T>();
  List<StreamSubscription<T>> subscriptions = [];

  void handleData(T data) {
    if (!controller.isClosed) {
      controller.add(data);
    }
  }

  void handleError(Object error, StackTrace stackTrace) {
    if (!controller.isClosed) {
      controller.addError(error, stackTrace);
    }
  }

  void handleDone() {
    for (var s in subscriptions) {
      s.cancel();
    }
    controller.close();
  }

  void subscribeToStream(Stream<T> stream) {
    final s = stream.listen(handleData, onError: handleError, onDone: handleDone);
    subscriptions.add(s);
  }

  streams.forEach(subscribeToStream);

  controller.onCancel = () async {
    await Future.wait(subscriptions.map((s) => s.cancel()));
  };

  return controller.stream;
}

// dart is single threaded, but still has task switching.
// this mutex lets a single task through at a time.
class _Mutex {
  final StreamController _controller = StreamController.broadcast();
  int execute = 0;
  int issued = 0;

  Future<bool> take() async {
    int mine = issued;
    issued++;
    // tasks are executed in the same order they call take()
    while (mine != execute) {
      await _controller.stream.first; // wait
    }
    return true;
  }

  bool give() {
    execute++;
    _controller.add(null); // release waiting tasks
    return false;
  }
}

// Create mutexes in a parrallel-safe way,
class _MutexFactory {
  static final Map<String, _Mutex> _all = {};
  static _Mutex getMutexForKey(String key) {
    _all[key] ??= _Mutex();
    return _all[key]!;
  }
}

String _black(String s) {
  // Use ANSI escape codes
  return '\x1B[1;30m$s\x1B[0m';
}

// ignore: unused_element
String _green(String s) {
  // Use ANSI escape codes
  return '\x1B[1;32m$s\x1B[0m';
}

String _magenta(String s) {
  // Use ANSI escape codes
  return '\x1B[1;35m$s\x1B[0m';
}

String _brown(String s) {
  // Use ANSI escape codes
  return '\x1B[1;33m$s\x1B[0m';
}

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  /// returns first item to satisfy `test`, else null
  T? _firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

extension RemoveWhere<T> on List<T> {
  /// returns true if some items where removed
  bool _removeWhere(bool Function(T) test) {
    int initialLength = this.length;
    this.removeWhere(test);
    return this.length != initialLength;
  }
}
