part of '../flutter_blue_plus.dart';

// dart is single threaded, but still has task switching.
// this mutex lets a single task through at a time.
class _Mutex {
  final Queue<Completer<bool>> _queue = Queue<Completer<bool>>();

  Future<bool> take() {
    final waiter = Completer<bool>();
    _queue.addLast(waiter);
    if (_queue.length == 1) waiter.complete(true);
    return waiter.future;
  }

  bool give() {
    _queue.removeFirst();
    if (_queue.isNotEmpty) _queue.first.complete(true);
    return false;
  }
}

// Create mutexes in a parallel-safe way,
class _MutexFactory {
  static final Map<String, _Mutex> _all = {};

  static _Mutex getMutexForKey(String key) {
    _all[key] ??= _Mutex();
    return _all[key]!;
  }

  static bool hasMutexWhere(bool Function(String key) test) {
    return _all.keys.any(test);
  }
}
