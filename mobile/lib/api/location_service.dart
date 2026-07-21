/// Abstract interface for getting the device's current GPS location.

import 'location_service_stub.dart'
    if (dart.library.js_interop) 'location_service_web.dart';

Future<({double lat, double lng})> getDeviceLocation() => resolveLocation();
