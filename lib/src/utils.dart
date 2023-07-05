part of flutter_blue_plus;

String _hexEncode(List<int> numbers) {
  return numbers.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
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

// This is a reimpplementation of BehaviorSubject from RxDart library.
// 1. Caches the latestValue of a stream
// 2. the "latestValue" is re-emitted when a stream is listened to
class _BehaviorSubject<T> {
  T latestValue;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  _BehaviorSubject(this.latestValue);

  Stream<T> get stream => _controller.stream;

  T get value => latestValue;

  void add(T newValue) {
    latestValue = newValue;
    _controller.add(newValue);
  }

  void listen(Function(T) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    onData(latestValue);
    _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
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
    _controller.close();
  }

  Stream<T> get stream async* {
    yield* _controller.stream;
  }
}

// helper for 'doOnDone' method for streams.
class _OnDoneTransformer<T> extends StreamTransformerBase<T, T> {
  final Function onDone;

  _OnDoneTransformer({required this.onDone});

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bindBroadcast(stream);
    }
    return _bindSingleSubscription(stream);
  }

  Stream<T> _bindSingleSubscription(Stream<T> stream) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = stream.listen(
          controller?.add,
          onError: controller?.addError,
          onDone: () {
            onDone();
            controller?.close();
          },
        );
      },
      onPause: ([Future<dynamic>? resumeSignal]) {
        subscription?.pause(resumeSignal);
      },
      onResume: () {
        subscription?.resume();
      },
      onCancel: () {
        return subscription?.cancel();
      },
      sync: true,
    );

    return controller.stream;
  }

  Stream<T> _bindBroadcast(Stream<T> stream) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>.broadcast(
      onListen: () {
        subscription = stream
            .listen(controller?.add, onError: controller?.addError, onDone: () {
          onDone();
          controller?.close();
        });
      },
      onCancel: () {
        subscription?.cancel();
      },
      sync: true,
    );

    return controller.stream;
  }
}

// helper for 'doOnCancel' method for streams.
class _OnCancelTransformer<T> extends StreamTransformerBase<T, T> {
  final Function onCancel;

  _OnCancelTransformer({required this.onCancel});

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bindBroadcast(stream);
    }

    return _bindSingleSubscription(stream);
  }

  Stream<T> _bindSingleSubscription(Stream<T> stream) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = stream.listen(
          controller?.add,
          onError: controller?.addError,
          onDone: controller?.close,
        );
      },
      onPause: ([Future<dynamic>? resumeSignal]) {
        subscription?.pause(resumeSignal);
      },
      onResume: () {
        subscription?.resume();
      },
      onCancel: () {
        onCancel();
        return subscription?.cancel();
      },
      sync: true,
    );

    return controller.stream;
  }

  Stream<T> _bindBroadcast(Stream<T> stream) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>.broadcast(
      onListen: () {
        subscription = stream.listen(
          controller?.add,
          onError: controller?.addError,
          onDone: controller?.close,
        );
      },
      onCancel: () {
        onCancel();
        subscription?.cancel();
      },
      sync: true,
    );

    return controller.stream;
  }
}

extension _StreamDoOnDone<T> on Stream<T> {
  Stream<T> doOnDone(void Function() onDone) {
    return transform(_OnDoneTransformer(onDone: onDone));
  }
}

extension _StreamDoOnCancel<T> on Stream<T> {
  Stream<T> doOnCancel(void Function() onCancel) {
    return transform(_OnCancelTransformer(onCancel: onCancel));
  }
}

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
    if (subscriptions.every((s) => s.isPaused)) {
      controller.close();
    }
  }

  void subscribeToStream(Stream<T> stream) {
    final s =
        stream.listen(handleData, onError: handleError, onDone: handleDone);
    subscriptions.add(s);
  }

  streams.forEach(subscribeToStream);

  controller.onCancel = () async {
    await Future.wait(subscriptions.map((s) => s.cancel()));
  };

  return controller.stream;
}

class _Mutex {
  Future<void> _lastOperation = Future.value();

  Future<void> synchronized(Function() operation) async {
    final previousOperation = _lastOperation;
    final currentOperation = Completer<void>();

    _lastOperation = currentOperation.future;

    // The `catchError` ensures that any error from the
    // previous operation is not re-propagated
    await previousOperation.catchError((_) {});

    try {
      await operation();
      currentOperation.complete();
    } catch (e, st) {
      currentOperation.completeError(e, st);
    }

    return currentOperation.future;
  }
}
