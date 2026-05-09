part of '../flutter_blue_plus.dart';

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
