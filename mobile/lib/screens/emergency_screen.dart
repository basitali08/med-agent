import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../api/location_service.dart';
import '../api/map_widget.dart';
import '../app_theme.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  double? _lat;
  double? _lng;
  bool _locating = true;
  String? _locError;
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _bloodBanks = [];
  bool _loading = false;
  String? _searchError;
  int _selectedHospitalIndex = 0;
  int _activeTab = 0;
  Map<String, dynamic>? get _profile => ApiClient.instance.cachedUser?['profile'];
  Map<String, dynamic>? get _nearest => _hospitals.isNotEmpty ? _hospitals.first : null;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() { _locating = true; _locError = null; _selectedHospitalIndex = 0; });
    try {
      final pos = await getDeviceLocation();
      setState(() { _lat = pos.lat; _lng = pos.lng; _locating = false; });
      _fetchNearbyHospitals();
    } catch (e) {
      setState(() { _locError = 'Location denied. Showing Islamabad area.'; _lat = 33.6941; _lng = 73.0479; _locating = false; });
      _fetchNearbyHospitals();
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_lat == null || _lng == null) return;
    setState(() { _loading = true; _searchError = null; _selectedHospitalIndex = 0; });
    for (final radius in [10000, 25000, 50000]) {
      try {
        final results = await ApiClient.instance.getNearbyHospitals(latitude: _lat!, longitude: _lng!, radius: radius, category: 'hospital');
        if (results.isNotEmpty) { setState(() { _hospitals = results; _loading = false; }); _fetchBloodBanks(); return; }
      } catch (_) { continue; }
    }
    try {
      final results = await ApiClient.instance.getNearbyHospitals(latitude: _lat!, longitude: _lng!, radius: 25000, category: 'all_hospital');
      setState(() { _hospitals = results; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _searchError = 'Could not find hospitals. Pull down to retry.'; });
    }
  }

  Future<void> _fetchBloodBanks() async {
    try {
      final results = await ApiClient.instance.getNearbyHospitals(latitude: _lat!, longitude: _lng!, radius: 25000, category: 'blood_bank');
      setState(() => _bloodBanks = results);
    } catch (_) {}
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _travelTime(int meters) {
    final minutes = ((meters / 1000) / 30 * 60).round();
    if (minutes < 1) return '< 1 min';
    return '~$minutes min';
  }

  Future<void> _openInMaps(double lat, double lng, String name) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${Uri.encodeComponent(name)}');
    if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
  }

  Future<void> _callHospital(String phone) async {
    if (phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
  }

  void _showMapModal({double? focusLat, double? focusLng, String? focusName}) {
    if (_lat == null || _lng == null) return;
    final cLat = focusLat ?? _lat!;
    final cLng = focusLng ?? _lng!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(
        width: 700, height: 520,
        child: Stack(children: [
          _buildLeafletMap(cLat, cLng, focusName),
          Positioned(top: 8, right: 8, child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.8), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: AppColors.primary, size: 20)),
          )),
          Positioned(top: 8, left: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(focusName ?? 'Nearby Hospitals', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          )),
          Positioned(bottom: 8, left: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
            child: Text('${_hospitals.length} hospitals found', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          )),
        ]),
      )),
    ));
  }

  Widget _buildLeafletMap(double centerLat, double centerLng, String? focusName) {
    return buildHospitalMap(
      centerLat: centerLat,
      centerLng: centerLng,
      hospitals: _hospitals,
      userLat: _lat!,
      userLng: _lng!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Emergency', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (_lat != null && _lng != null) IconButton(
            icon: const Icon(Icons.map_rounded, color: AppColors.primary),
            onPressed: () => _showMapModal(),
            tooltip: 'View All Hospitals on Map',
          ),
        ],
      ),
      body: _locating ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 16),
        Text('Detecting your location...', style: TextStyle(color: AppColors.textMuted)),
        SizedBox(height: 8),
        Text('Searching nearby hospitals', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ])) : RefreshIndicator(
        onRefresh: _initLocation, color: AppColors.primary,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _buildSOS(), const SizedBox(height: 16),
          _buildLocationBar(),
          if (_locError != null) ...[const SizedBox(height: 8), Text(_locError!, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.warning))],
          const SizedBox(height: 16),
          if (!_loading && _nearest != null) ...[_buildNearestHospitalCard(), const SizedBox(height: 16)],
          Row(children: [
            _tabBtn(0, 'All Hospitals', AppColors.primary, Icons.local_hospital_rounded),
            const SizedBox(width: 8),
            _tabBtn(1, 'Contacts', AppColors.secondary, Icons.contact_phone_rounded),
            const SizedBox(width: 8),
            _tabBtn(2, 'Blood', AppColors.danger, Icons.bloodtype_rounded),
          ]),
          const SizedBox(height: 16),
          _buildMedicalId(), const SizedBox(height: 16),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_searchError != null) _errorCard(_searchError!)
          else _buildTabContent(),
        ]),
      ),
    );
  }

  Widget _buildLocationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.my_location_rounded, color: AppColors.success, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Location', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
          Text('${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
        ])),
        if (_hospitals.isNotEmpty) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('${_hospitals.length} found', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        GestureDetector(onTap: _initLocation, child: const Icon(Icons.refresh_rounded, color: AppColors.success, size: 18)),
      ]),
    );
  }

  Widget _buildNearestHospitalCard() {
    final h = _nearest!;
    final name = h['name'] as String? ?? 'Unknown';
    final address = h['address'] as String? ?? '';
    final phone = h['phone'] as String? ?? '';
    final dist = h['distance_m'] as int? ?? 0;
    final lat = h['latitude'] as double? ?? 0;
    final lng = h['longitude'] as double? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 2),
        boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 2)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('⭐ NEAREST HOSPITAL', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
              const SizedBox(height: 4),
              Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _infoChip(Icons.near_me_rounded, _formatDistance(dist), AppColors.success),
            const SizedBox(width: 8),
            _infoChip(Icons.timer_rounded, _travelTime(dist), AppColors.primary),
            const SizedBox(width: 8),
            if (phone.isNotEmpty) _infoChip(Icons.phone_rounded, phone, AppColors.secondary),
          ]),
          if (address.isNotEmpty) ...[const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(address, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            if (phone.isNotEmpty) Expanded(child: GestureDetector(
              onTap: () => _callHospital(phone),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('CALL NOW', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            )),
            if (phone.isNotEmpty) const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => _openInMaps(lat, lng, name),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.secondaryLight]), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.directions_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('DIRECTIONS', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                ]),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showMapModal(focusLat: lat, focusLng: lng, focusName: name),
              child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_hospitals.length > 1) GestureDetector(
            onTap: () => setState(() => _activeTab = 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text('Not reachable? Browse ${_hospitals.length - 1} other hospitals', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.warning),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildSOS() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.danger, AppColors.warning]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 4)],
      ),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => launchUrl(Uri.parse('tel:112'), mode: LaunchMode.externalApplication),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Column(children: [
          Container(width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 40)),
          const SizedBox(height: 12),
          Text('SOS — CALL 112', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('Tap to initiate emergency call', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
        ])),
      )),
    );
  }

  Widget _tabBtn(int index, String label, Color color, IconData icon) {
    final active = _activeTab == index;
    return Expanded(child: GestureDetector(
      onTap: () { setState(() => _activeTab = index); if (index == 0 && _hospitals.isEmpty) _fetchNearbyHospitals(); if (index == 2 && _bloodBanks.isEmpty) _fetchBloodBanks(); },
      child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: Card3D.glass(borderColor: active ? color : AppColors.border, borderOpacity: active ? 0.35 : 0.15, gradient: active ? [color.withValues(alpha: 0.12)] : null),
        child: Column(children: [
          Icon(icon, color: active ? color : AppColors.textMuted, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? color : AppColors.textMuted, letterSpacing: 0.5)),
        ]),
      ),
    ));
  }

  Widget _buildMedicalId() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.medical_information_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Text('MEDICAL ID', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        _infoRow('Blood Type', _profile?['blood_type']?.toString().isNotEmpty == true ? _profile!['blood_type'] : 'Not set', AppColors.danger),
        _infoRow('Allergies', _profile?['known_allergies']?.toString().isNotEmpty == true ? _profile!['known_allergies'] : 'None recorded', AppColors.warning),
        _infoRow('Medications', _profile?['medications']?.toString().isNotEmpty == true ? _profile!['medications'] : 'None recorded', AppColors.primary),
        _infoRow('Conditions', _profile?['medical_conditions']?.toString().isNotEmpty == true ? _profile!['medical_conditions'] : 'None recorded', AppColors.secondary),
      ]),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
        Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
      ]),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        if (_hospitals.isEmpty) return _emptyCard('No hospitals found nearby');
        return Column(children: _hospitals.asMap().entries.map((entry) {
          final i = entry.key; final h = entry.value;
          return _hospitalCard(h, AppColors.primary, index: i, isNearest: i == 0, isSelected: i == _selectedHospitalIndex);
        }).toList());
      case 1:
        final withPhone = _hospitals.where((h) => (h['phone'] as String?)?.isNotEmpty == true).toList();
        if (withPhone.isEmpty) return _emptyCard('No emergency contacts found nearby');
        return Column(children: withPhone.take(20).map((h) => _contactCard(h)).toList());
      case 2:
        if (_bloodBanks.isEmpty) return _emptyCard('No blood banks found nearby');
        return Column(children: _bloodBanks.take(15).map((h) => _hospitalCard(h, AppColors.danger)).toList());
      default: return const SizedBox.shrink();
    }
  }

  Widget _hospitalCard(Map<String, dynamic> h, Color color, {int index = 0, bool isNearest = false, bool isSelected = false}) {
    final dist = h['distance_m'] as int? ?? 0;
    final name = h['name'] as String? ?? 'Unknown';
    final address = h['address'] as String? ?? '';
    final phone = h['phone'] as String? ?? '';
    final lat = h['latitude'] as double? ?? 0;
    final lng = h['longitude'] as double? ?? 0;
    final bColor = isNearest ? AppColors.success : (isSelected ? color : AppColors.border);

    return GestureDetector(
      onTap: () { _selectedHospitalIndex = index; _showMapModal(focusLat: lat, focusLng: lng, focusName: name); },
      child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
        decoration: Card3D.glass(borderColor: bColor, borderOpacity: isNearest ? 0.4 : 0.2),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: isNearest ? AppColors.success.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isNearest ? AppColors.success.withValues(alpha: 0.25) : color.withValues(alpha: 0.2)),
            ),
            child: Icon(isNearest ? Icons.star_rounded : Icons.local_hospital_rounded, color: isNearest ? AppColors.success : color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (isNearest) ...[Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text('⭐', style: GoogleFonts.poppins(fontSize: 9)),
              ), const SizedBox(width: 4)],
              Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            if (address.isNotEmpty) Text(address, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(children: [
              Icon(Icons.near_me_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(_formatDistance(dist), style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text('• ${_travelTime(dist)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
              if (phone.isNotEmpty) ...[const SizedBox(width: 8), Icon(Icons.phone_rounded, size: 11, color: AppColors.textMuted), const SizedBox(width: 3), Text(phone, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted))],
            ]),
          ])),
          Column(children: [
            if (phone.isNotEmpty) GestureDetector(
              onTap: () => _callHospital(phone),
              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.phone_rounded, color: AppColors.success, size: 16)),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openInMaps(lat, lng, name),
              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.directions_rounded, color: color, size: 16)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _contactCard(Map<String, dynamic> h) {
    final name = h['name'] as String? ?? 'Unknown';
    final phone = h['phone'] as String? ?? '';
    final dist = h['distance_m'] as int? ?? 0;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: Card3D.glass(borderColor: AppColors.secondary, borderOpacity: 0.2),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.contact_phone_rounded, color: AppColors.secondary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${_formatDistance(dist)} away', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.secondary)),
        ])),
        GestureDetector(
          onTap: () => _callHospital(phone),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.success, AppColors.primary]), borderRadius: BorderRadius.circular(10)),
            child: Text('CALL', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(padding: const EdgeInsets.all(24), decoration: Card3D.glass(borderColor: AppColors.border, borderOpacity: 0.2),
      child: Center(child: Column(children: [
        Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 36),
        const SizedBox(height: 8),
        Text(msg, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
      ])),
    );
  }

  Widget _errorCard(String msg) {
    return Container(padding: const EdgeInsets.all(16), decoration: Card3D.glass(borderColor: AppColors.warning, borderOpacity: 0.2),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.warning_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning))),
        ]),
        const SizedBox(height: 12),
        GestureDetector(onTap: _initLocation,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('Retry', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)))),
      ]),
    );
  }
}
