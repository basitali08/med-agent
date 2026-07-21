/// Abstract map widget — resolved via conditional imports per platform.

import 'package:flutter/material.dart';
import 'map_widget_stub.dart'
    if (dart.library.js_interop) 'map_widget_web.dart';

Widget buildHospitalMap({
  required double centerLat,
  required double centerLng,
  required List<Map<String, dynamic>> hospitals,
  required double userLat,
  required double userLng,
}) =>
    resolveMapWidget(
      centerLat: centerLat,
      centerLng: centerLng,
      hospitals: hospitals,
      userLat: userLat,
      userLng: userLng,
    );
