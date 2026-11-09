part of '../flutter_blue_plus_darwin.dart';

/// Watches the automatic MTU exchange for one connection, then stops when stable.
final class _MtuMonitor {
  _MtuMonitor(cb.CBPeripheral peripheral, this.onChanged, void Function(Object, StackTrace) onError) {
    _subscription = Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) => _maximumPayload(peripheral))
        .listen(_onPayload, onError: onError, cancelOnError: true);
  }

  final void Function(int mtu) onChanged;
  late final StreamSubscription<int> _subscription;
  int? _lastPayload;
  int _stableTicks = 0;

  Future<void> cancel() => _subscription.cancel();

  void _onPayload(int payload) {
    if (payload == _lastPayload) {
      if (++_stableTicks == 20) unawaited(cancel());
      return;
    }
    _lastPayload = payload;
    _stableTicks = 0;
    onChanged(payload + 3);
  }
}
