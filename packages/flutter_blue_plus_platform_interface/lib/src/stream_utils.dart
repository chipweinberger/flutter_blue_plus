import 'dart:async';

class _NewStreamWithInitialValueTransformer<T> extends StreamTransformerBase<T, T> {
  final T initialValue;

  late StreamController<T> controller;
  late StreamSubscription<T> subscription;
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
    void onData(T data) {
      controller.add(data);
    }

    void onDone() {
      controller.close();
    }

    void onError(Object error) {
      controller.addError(error);
    }

    void onListen() {
      controller.add(initialValue);

      if (listenerCount == 0) {
        subscription = stream.listen(
          onData,
          onError: onError,
          onDone: onDone,
        );
      }

      listenerCount++;
    }

    void onPause() {
      subscription.pause();
    }

    void onResume() {
      subscription.resume();
    }

    void onCancel() {
      listenerCount--;

      if (listenerCount == 0) {
        subscription.cancel();
        controller.close();
      }
    }

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

Stream<T> mergeStreams<T>(Iterable<Stream<T>> streams) {
  return Stream.multi(
    (controller) {
      final subscriptions = <StreamSubscription<T>>[];
      var remaining = 0;
      var isCanceled = false;

      Future<void> cancelAll() async {
        if (isCanceled) return;
        isCanceled = true;
        await Future.wait(
          subscriptions.map(
            (subscription) {
              return subscription.cancel();
            },
          ),
        );
      }

      void maybeClose() {
        if (!isCanceled && remaining == 0) {
          controller.close();
        }
      }

      for (final stream in streams) {
        remaining++;
        subscriptions.add(
          stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              remaining--;
              maybeClose();
            },
          ),
        );
      }

      maybeClose();
      controller.onCancel = cancelAll;
    },
    isBroadcast: true,
  );
}

extension FbpStreamExtensions<T> on Stream<T> {
  Stream<T> mergeWith(Iterable<Stream<T>> streams) {
    return mergeStreams([this, ...streams]);
  }

  Stream<T> newStreamWithInitialValue(T initialValue) {
    return transform(_NewStreamWithInitialValueTransformer(initialValue));
  }

  Stream<T> startWith(T initialValue) {
    return Stream.multi(
      (controller) {
        controller.add(initialValue);
        final subscription = listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      },
      isBroadcast: isBroadcast,
    );
  }

  Stream<S> switchMap<S>(Stream<S> Function(T event) mapper) {
    return Stream.multi(
      (controller) {
        StreamSubscription<T>? outerSubscription;
        StreamSubscription<S>? innerSubscription;
        var outerDone = false;
        var isCanceled = false;

        Future<void> closeIfDone() async {
          if (!isCanceled && outerDone && innerSubscription == null) {
            controller.close();
          }
        }

        outerSubscription = listen(
          (event) async {
            await innerSubscription?.cancel();
            innerSubscription = mapper(event).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                innerSubscription = null;
                closeIfDone();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            closeIfDone();
          },
        );

        controller.onCancel = () async {
          isCanceled = true;
          await innerSubscription?.cancel();
          await outerSubscription?.cancel();
        };
      },
      isBroadcast: true,
    );
  }
}
