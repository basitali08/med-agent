/// Web implementation — renders a Leaflet map via an IFrame.

import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget resolveMapWidget({
  required double centerLat,
  required double centerLng,
  required List<Map<String, dynamic>> hospitals,
  required double userLat,
  required double userLng,
}) {
  final viewType = 'leaflet-map-${DateTime.now().millisecondsSinceEpoch}';
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final hJson = hospitals
        .map((h) => {
              'name': h['name'] ?? 'Unknown',
              'lat': h['latitude'] ?? 0,
              'lng': h['longitude'] ?? 0,
              'distance': h['distance_m'] ?? 0,
              'address': h['address'] ?? '',
              'phone': h['phone'] ?? '',
            })
        .toList();
    final htmlContent = '''<!DOCTYPE html><html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"><link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/><script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:'Segoe UI',sans-serif}#map{width:100%;height:100vh}.hp{min-width:200px}.hp h3{color:#1a1a2e;font-size:14px;margin:0 0 4px 0}.hp p{color:#555;font-size:12px;margin:2px 0}.hp .d{color:#00d4aa;font-weight:700}.hp .bd{display:inline-block;margin-top:8px;padding:6px 14px;background:linear-gradient(135deg,#00d4aa,#00b4d8);color:#1a1a2e;font-weight:700;font-size:12px;border-radius:8px;text-decoration:none;cursor:pointer;border:none}.hp .bc{display:inline-block;margin-top:4px;margin-left:4px;padding:6px 14px;background:linear-gradient(135deg,#00e676,#00d4aa);color:#1a1a2e;font-weight:700;font-size:12px;border-radius:8px;text-decoration:none;cursor:pointer;border:none}</style></head><body><div id="map"></div><script>var map=L.map('map',{zoomControl:true}).setView([$centerLat,$centerLng],13);L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OpenStreetMap'}).addTo(map);var uIcon=L.divIcon({html:'<div style="width:18px;height:18px;background:#00d4aa;border:3px solid #fff;border-radius:50%;box-shadow:0 0 12px #00d4aa"></div>',iconSize:[18,18],iconAnchor:[9,9],className:''});L.marker([$userLat,$userLng],{icon:uIcon}).addTo(map).bindPopup('<div class="hp"><h3>📍 Your Location</h3><p class="d">Current position</p></div>');var hospitals=${jsonEncode(hJson)};var hIcon=L.divIcon({html:'<div style="width:28px;height:28px;background:#ff1744;border:2px solid #fff;border-radius:50%;display:flex;align-items:center;justify-content:center;box-shadow:0 0 10px rgba(255,23,68,0.5)"><span style="color:#fff;font-size:14px">🏥</span></div>',iconSize:[28,28],iconAnchor:[14,14],className:''});var nIcon=L.divIcon({html:'<div style="width:32px;height:32px;background:#00e676;border:3px solid #fff;border-radius:50%;display:flex;align-items:center;justify-content:center;box-shadow:0 0 14px #00e676"><span style="color:#fff;font-size:16px">🏥</span></div>',iconSize:[32,32],iconAnchor:[16,16],className:''});hospitals.forEach(function(h,i){var dk=(h.distance/1000).toFixed(1);var dt=h.distance<1000?h.distance+' m':dk+' km';var mu='https://www.google.com/maps/dir/?api=1&destination='+h.lat+','+h.lng;var pb=h.phone?'<a class="bc" href="tel:'+h.phone+'">📞 Call</a>':'';var nr=i===0?'<p style="color:#00e676;font-weight:700">⭐ NEAREST</p>':'';var pp='<div class="hp">'+nr+'<h3>🏥 '+h.name+'</h3><p class="d">📍 '+dt+' away</p>'+(h.address?'<p>'+h.address+'</p>':'')+(h.phone?'<p>📞 '+h.phone+'</p>':'')+'<a class="bd" href="'+mu+'" target="_blank">🗺️ Get Directions</a>'+pb+'</div>';var ic=i===0?nIcon:hIcon;L.marker([h.lat,h.lng],{icon:ic}).addTo(map).bindPopup(pp)});var ap=[[$userLat,$userLng]];hospitals.forEach(function(h){ap.push([h.lat,h.lng])});if(ap.length>1){map.fitBounds(ap,{padding:[40,40]})}</script></body></html>''';
    final iframe = html.IFrameElement()
      ..srcdoc = htmlContent
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
  return HtmlElementView(viewType: viewType);
}
