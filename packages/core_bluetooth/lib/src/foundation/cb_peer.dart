part of '../core_bluetooth.dart';

base class CBPeer {
  CBPeer({
    required this.identifier,
  });

  final UUID identifier;
}
