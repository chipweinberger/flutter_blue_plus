part of '../core_bluetooth.dart';

base class CBManager {
  CBManager({
    CBManagerState state = CBManagerState.unknown,
  }) : _state = state;

  CBManagerState _state;

  CBManagerState get state => _state;

  void _updateState(CBManagerState state) {
    _state = state;
  }
}
