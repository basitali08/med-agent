import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/api_client.dart';
import '../app_theme.dart';
import '../widgets/med_agent_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;

  // Auth fields
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();

  // Profile fields (register only)
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _allergies = TextEditingController();
  String _bloodType = '';
  DateTime? _dob;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _fullName.dispose();
    _phone.dispose();
    _address.dispose();
    _allergies.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() { _isRegister = !_isRegister; _error = null; });

  void _showServerUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiClient.instance.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        title: Text('Server URL', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your PC\'s IP address. Run "ipconfig" in CMD to find it.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'http://192.168.100.24:8000',
                hintStyle: GoogleFonts.poppins(color: AppColors.textMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.secondary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                await ApiClient.instance.updateBaseUrl(url);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(
              color: AppColors.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isRegister) {
        await ApiClient.instance.register(
          _username.text.trim(),
          _email.text.trim(),
          _password.text,
          fullName: _fullName.text.trim(),
          phone: _phone.text.trim(),
          dateOfBirth: _dob != null ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}' : null,
          bloodType: _bloodType,
          heightCm: double.tryParse(_heightCtrl.text),
          weightKg: double.tryParse(_weightCtrl.text),
          knownAllergies: _allergies.text.trim(),
          address: _address.text.trim(),
        );
      } else {
        await ApiClient.instance.login(_email.text.trim(), _password.text);
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.primary.withValues(alpha: 0.1), bgColor]
                : [AppColors.primary.withValues(alpha: 0.05), bgColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 6),
                    ]),
                    child: const MedAgentLogo(size: 80),
                  ),
                  const SizedBox(height: 16),
                  Text('MED AGENT', style: GoogleFonts.poppins(
                    fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted, letterSpacing: 3)),
                  const SizedBox(height: 24),

                  // Glass card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: Card3D.glass(
                      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                      borderOpacity: 0.15,
                    ),
                    child: Column(
                      children: [
                        if (_isRegister) ...[
                          _field('Full Name', Icons.person_rounded, _fullName),
                          const SizedBox(height: 12),
                          _field('Username', Icons.account_circle_rounded, _username),
                          const SizedBox(height: 12),
                        ],
                        _field('Email', Icons.alternate_email_rounded, _email, keyboard: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field('Password', Icons.lock_outline_rounded, _password, obscure: true),
                        if (_isRegister) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('You can fill in medical details later in your Profile.',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.7))),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: GoogleFonts.poppins(color: AppColors.danger, fontSize: 13))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 24),

                        _loading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(14),
                                          onTap: _submit,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(_isRegister ? 'CREATE ACCOUNT' : 'ACCESS',
                                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _toggleMode,
                                    child: Text(
                                      _isRegister ? 'Already have an account? Sign in' : 'Create new account',
                                      style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('v0.1.0 • ENCRYPTED • HIPAA-ALIGNED',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showServerUrlDialog(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dns_rounded, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Text('Server: ${ApiClient.instance.baseUrl}',
                          style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController ctrl,
      {TextInputType? keyboard, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 14),
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      labelStyle: TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
