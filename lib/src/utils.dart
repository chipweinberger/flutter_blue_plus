

part of flutter_blue_plus;

String hexEncode(List<int> numbers) {
  return numbers.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
}

List<int> hexDecode(String hex) {
  List<int> numbers = [];
  for (int i = 0; i < hex.length; i += 2) {
    String hexPart = hex.substring(i, i + 2);
    int num = int.parse(hexPart, radix: 16);
    numbers.add(num);
  }
  return numbers;
}

int compareAsciiLowerCase(String a, String b) {
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
// 2. the "latestValue" is emitted when a stream is first listened to 
class BehaviorSubject<T> {

  T latestValue;

  final StreamController<T> _controller = StreamController<T>.broadcast();

  BehaviorSubject(this.latestValue);

  Stream<T> get stream => _controller.stream;

  T get value => latestValue;

  void add(T newValue) {
    latestValue = newValue;
    _controller.add(newValue);
  }

  void listen(Function(T) onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    onData(latestValue);
    _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<void> close() {
    return _controller.close();
  }
}

// helper for 'doOnDone' method for streams.
class OnDoneTransformer<T> extends StreamTransformerBase<T, T> {
  final Function onDone;

  OnDoneTransformer({required this.onDone});

  @override
  Stream<T> bind(Stream<T> stream) {
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
}

// helper for 'doOnCancel' method for streams.
class OnCancelTransformer<T> extends StreamTransformerBase<T, T> {
  final Function onCancel;

  OnCancelTransformer({required this.onCancel});

  @override
  Stream<T> bind(Stream<T> stream) {
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
}

extension StreamDoOnDone<T> on Stream<T> {
  Stream<T> doOnDone(void Function() onDone) {
    return transform(OnDoneTransformer(onDone: onDone));
  }
}

extension StreamDoOnCancel<T> on Stream<T> {
  Stream<T> doOnCancel(void Function() onCancel) {
    return transform(OnCancelTransformer(onCancel: onCancel));
  }
}


Stream<T> mergeStreams<T>(List<Stream<T>> streams) {
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
    final s = stream.listen(handleData, onError: handleError, onDone: handleDone);
    subscriptions.add(s);
  }

  streams.forEach(subscribeToStream);

  controller.onCancel = () async {
    await Future.wait(subscriptions.map((s) => s.cancel()));
  };

  return controller.stream;
}


class Mutex {
  Future<void> _lastOperation = Future.value();

  Future<void> synchronized(Function() operation) async {
    final previousOperation = _lastOperation;
    final currentOperation = Completer<void>();

    _lastOperation = currentOperation.future;

    await previousOperation;

    try {
      await operation();
      currentOperation.complete();
    } catch (e, st) {
      currentOperation.completeError(e, st);
      rethrow;
    }
  }
}