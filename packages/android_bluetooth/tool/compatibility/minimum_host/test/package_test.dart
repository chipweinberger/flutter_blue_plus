import 'package:flutter_test/flutter_test.dart';

import '../../../../test/event_routing_test.dart' as event_routing;
import '../../../../test/companion_test.dart' as companion;
import '../../../../test/gatt_test.dart' as gatt;
import '../../../../test/gatt_server_test.dart' as gatt_server;
import '../../../../test/device_test.dart' as device;
import '../../../../test/scan_test.dart' as scan;
import '../../../../test/socket_test.dart' as socket;
import '../../../../test/ranging_test.dart' as ranging;
import '../../../../test/disposal_test.dart' as disposal;
import '../../../../test/advertising_test.dart' as advertising;
import '../../../../test/snapshots_test.dart' as snapshots;
import '../../../../test/compatibility_test.dart' as compatibility;

void main() {
  group('event_routing', event_routing.main);
  group('companion', companion.main);
  group('gatt', gatt.main);
  group('gatt_server', gatt_server.main);
  group('device', device.main);
  group('scan', scan.main);
  group('socket', socket.main);
  group('ranging', ranging.main);
  group('disposal', disposal.main);
  group('advertising', advertising.main);
  group('snapshots', snapshots.main);
  group('compatibility', compatibility.main);
}
