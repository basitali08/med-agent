import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/api_client.dart';
import '../app_theme.dart';
import '../widgets/med_agent_logo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _loading = false;
  String? _error;

  // Controllers
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _medications = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _bloodType = '';
  DateTime? _dob;

  Map<String, dynamic> get _user => ApiClient.instance.cachedUser ?? {};
  Map<String, dynamic> get _profile => _user['profile'] ?? {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final p = _profile;
    _fullName.text = (p['full_name'] ?? '') as String;
    _phone.text = (p['phone'] ?? '') as String;
    _address.text = (p['address'] ?? '') as String;
    _allergies.text = (p['known_allergies'] ?? '') as String;
    _conditions.text = (p['medical_conditions'] ?? '') as String;
    _medications.text = (p['medications'] ?? '') as String;
    _bloodType = (p['blood_type'] ?? '') as String;
    if (p['height_cm'] != null) _heightCtrl.text = p['height_cm'].toString();
    if (p['weight_kg'] != null) _weightCtrl.text = p['weight_kg'].toString();
    if (p['date_of_birth'] != null) {
      try { _dob = DateTime.parse(p['date_of_birth']); } catch (_) {}
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fields = <String, dynamic>{
        'full_name': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'known_allergies': _allergies.text.trim(),
        'medical_conditions': _conditions.text.trim(),
        'medications': _medications.text.trim(),
        'blood_type': _bloodType,
        'height_cm': double.tryParse(_heightCtrl.text),
        'weight_kg': double.tryParse(_weightCtrl.text),
        'date_of_birth': _dob != null ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}' : null,
      };
      await ApiClient.instance.updateProfile(fields);
      await ApiClient.instance.getMe(); // refresh cached data
      setState(() { _editing = false; _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profile updated!', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  void dispose() {
    _fullName.dispose(); _phone.dispose(); _address.dispose();
    _allergies.dispose(); _conditions.dispose(); _medications.dispose();
    _heightCtrl.dispose(); _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = (_user['email'] ?? '') as String;
    final username = (_user['username'] ?? '') as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;
    final textColor = isDark ? AppColors.textOnPrimary : AppColors.textDark;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Text('SAVE', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.secondary),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 4)],
              ),
              child: const Center(child: MedAgentLogo(size: 70)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(username.toUpperCase(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 2))),
          Center(child: Text(email, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.secondary))),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
              child: Text(_error!, style: GoogleFonts.poppins(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],

          // Personal info
          _sectionTitle('PERSONAL INFO'),
          const SizedBox(height: 10),
          _editing ? _inputField('Full Name', Icons.person_rounded, _fullName, cardColor: cardColor) : _infoTile('Full Name', _profile['full_name']?.toString() ?? 'Not set', AppColors.primary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          _editing ? _inputField('Phone', Icons.phone_rounded, _phone, keyboard: TextInputType.phone, cardColor: cardColor) : _infoTile('Phone', _profile['phone']?.toString() ?? 'Not set', AppColors.secondary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          if (_editing)
            GestureDetector(
              onTap: _pickDob,
              child: InputDecorator(
                decoration: _inputDeco('Date of Birth', Icons.cake_rounded, cardColor: cardColor),
                child: Text(_dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Select date',
                  style: GoogleFonts.poppins(color: _dob != null ? textColor : AppColors.textMuted, fontSize: 14)),
              ),
            )
          else
            _infoTile('Date of Birth', _profile['date_of_birth']?.toString() ?? 'Not set', AppColors.primary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          _editing ? _inputField('Address', Icons.location_on_rounded, _address, cardColor: cardColor) : _infoTile('Address', _profile['address']?.toString() ?? 'Not set', AppColors.secondary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 20),

          // Medical info
          _sectionTitle('MEDICAL INFO'),
          const SizedBox(height: 10),
          if (_editing)
            DropdownButtonFormField<String>(
              value: _bloodType.isEmpty ? null : _bloodType,
              decoration: _inputDeco('Blood Type', Icons.bloodtype_rounded, cardColor: cardColor),
              items: const [
                DropdownMenuItem(value: '', child: Text('Select')),
                DropdownMenuItem(value: 'A+', child: Text('A+')),
                DropdownMenuItem(value: 'A-', child: Text('A-')),
                DropdownMenuItem(value: 'B+', child: Text('B+')),
                DropdownMenuItem(value: 'B-', child: Text('B-')),
                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                DropdownMenuItem(value: 'O+', child: Text('O+')),
                DropdownMenuItem(value: 'O-', child: Text('O-')),
              ],
              onChanged: (v) => setState(() => _bloodType = v ?? ''),
            )
          else
            _infoTile('Blood Type', _profile['blood_type']?.toString().isNotEmpty == true ? _profile['blood_type'].toString() : 'Not set', AppColors.danger, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          if (_editing) ...[
            Row(
              children: [
                Expanded(child: _inputField('Height (cm)', Icons.height_rounded, _heightCtrl, keyboard: TextInputType.number, cardColor: cardColor)),
                const SizedBox(width: 12),
                Expanded(child: _inputField('Weight (kg)', Icons.monitor_weight_outlined, _weightCtrl, keyboard: TextInputType.number, cardColor: cardColor)),
              ],
            ),
          ] else
            _infoTile('Height / Weight', _formatHeightWeight(), AppColors.primary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          _editing ? _inputField('Known Allergies', Icons.warning_amber_rounded, _allergies, cardColor: cardColor) : _infoTile('Allergies', _profile['known_allergies']?.toString().isNotEmpty == true ? _profile['known_allergies'].toString() : 'None', AppColors.warning, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          _editing ? _inputField('Medical Conditions', Icons.medical_services_rounded, _conditions, cardColor: cardColor) : _infoTile('Conditions', _profile['medical_conditions']?.toString().isNotEmpty == true ? _profile['medical_conditions'].toString() : 'None', AppColors.secondary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 8),
          _editing ? _inputField('Medications', Icons.medication_rounded, _medications, cardColor: cardColor) : _infoTile('Medications', _profile['medications']?.toString().isNotEmpty == true ? _profile['medications'].toString() : 'None', AppColors.primary, cardColor: cardColor, textColor: textColor),
          const SizedBox(height: 24),

          // Logout
          if (!_editing)
            Container(
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await ApiClient.instance.logout();
                    if (mounted) context.go('/login');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Text('LOG OUT', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatHeightWeight() {
    final h = _profile['height_cm'];
    final w = _profile['weight_kg'];
    if (h == null && w == null) return 'Not set';
    final parts = <String>[];
    if (h != null) parts.add('$h cm');
    if (w != null) parts.add('$w kg');
    return parts.join(' / ');
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted));
  }

  Widget _infoTile(String label, String value, Color color, {required Color cardColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
          Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _inputField(String label, IconData icon, TextEditingController ctrl, {TextInputType? keyboard, required Color cardColor}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 14),
      decoration: _inputDeco(label, icon, cardColor: cardColor),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {required Color cardColor}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      labelStyle: TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: cardColor,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
