/// Web implementation — uses the browser's Geolocation API.

import 'dart:async';
import 'dart:html' as html;

Future<({double lat, double lng})> resolveLocation() async {
  final completer = Completer<({double lat, double lng})>();
  html.window.navigator.geolocation.getCurrentPosition().then((pos) {
    completer.complete((
      lat: pos.coords!.latitude!.toDouble(),
      lng: pos.coords!.longitude!.toDouble(),
    ));
  }).catchError((_) {
    completer.completeError(Exception('Location denied'));
  });
  return completer.future;
}
