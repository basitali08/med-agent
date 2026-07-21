import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/api_client.dart';
import '../app_theme.dart';
import '../main.dart' show toggleTheme;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;
    final textColor = isDark ? AppColors.textOnPrimary : AppColors.textDark;
    final mutedColor = isDark ? AppColors.textLight : AppColors.textMuted;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Display', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: mutedColor)),
          const SizedBox(height: 12),
          // Theme toggle
          _settingTile(
            context,
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'Theme',
            subtitle: isDark ? 'Dark Mode' : 'Light Mode',
            color: AppColors.secondary,
            cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor,
            trailing: Switch(
              value: isDark,
              onChanged: (_) => toggleTheme(),
              activeThumbColor: AppColors.primary,
            ),
          ),
          _settingTile(
            context,
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English',
            color: AppColors.primary,
            cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor,
          ),
          const SizedBox(height: 24),

          Text('Security', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: mutedColor)),
          const SizedBox(height: 12),
          _settingTile(context, icon: Icons.shield_rounded, title: 'Privacy', subtitle: 'Data encrypted at rest (Fernet)', color: AppColors.primary, cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor),
          _settingTile(context, icon: Icons.fingerprint_rounded, title: 'Biometric Lock', subtitle: 'Disabled', color: AppColors.secondary, cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor),
          const SizedBox(height: 24),

          Text('Connection', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: mutedColor)),
          const SizedBox(height: 12),
          _serverUrlTile(context, cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor),
          const SizedBox(height: 24),

          Text('About', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: mutedColor)),
          const SizedBox(height: 12),
          _settingTile(context, icon: Icons.info_rounded, title: 'Version', subtitle: '0.1.0-alpha', color: mutedColor, cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor),
          _settingTile(context, icon: Icons.code_rounded, title: 'Pipeline', subtitle: '4 agents + Supervisor + RAG', color: AppColors.secondary, cardColor: cardColor, textColor: textColor, mutedColor: mutedColor, borderColor: borderColor),
          const SizedBox(height: 32),

          // Logout
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
                  if (context.mounted) context.go('/login');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Text('Log Out', style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
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

  Widget _serverUrlTile(BuildContext context, {required Color cardColor, required Color textColor, required Color mutedColor, required Color borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showServerUrlDialog(context),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_rounded, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server URL', style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text(ApiClient.instance.baseUrl, style: GoogleFonts.poppins(
                      fontSize: 12, color: mutedColor), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: mutedColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiClient.instance.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Server URL', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the backend server address.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: const InputDecoration(hintText: 'http://192.168.100.24:8000'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                await ApiClient.instance.updateBaseUrl(url);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Server URL updated: $url', style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.primary,
                  ));
                }
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _settingTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.poppins(
                  fontSize: 12, color: mutedColor)),
              ],
            ),
          ),
          if (trailing != null) trailing else Icon(Icons.chevron_right_rounded, color: mutedColor, size: 18),
        ],
      ),
    );
  }
}
