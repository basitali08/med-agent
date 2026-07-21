/// Android/iOS stub — shows a simple fallback list instead of Leaflet map.
/// For a production app you'd use flutter_map or google_maps_flutter here.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

Widget resolveMapWidget({
  required double centerLat,
  required double centerLng,
  required List<Map<String, dynamic>> hospitals,
  required double userLat,
  required double userLng,
}) {
  return Container(
    height: 400,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🗺️ Nearby Hospitals (${hospitals.length})',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: hospitals.length.clamp(0, 20),
            itemBuilder: (ctx, i) {
              final h = hospitals[i];
              final name = h['name'] ?? 'Unknown';
              final dist = h['distance_m'] ?? 0;
              final phone = h['phone'] ?? '';
              final lat = h['latitude'] ?? 0.0;
              final lng = h['longitude'] ?? 0.0;
              final distStr = dist < 1000 ? '${dist}m' : '${(dist / 1000).toStringAsFixed(1)}km';
              return Card(
                color: const Color(0xFF1E1E2E),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i == 0 ? Colors.green : Colors.red.shade700,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text('$distStr away', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (phone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                          onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                        ),
                      IconButton(
                        icon: const Icon(Icons.directions, color: Colors.cyan, size: 18),
                        onPressed: () => launchUrl(Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
