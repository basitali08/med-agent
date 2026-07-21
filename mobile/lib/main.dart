import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api_client.dart';
import 'app_router.dart';
import 'app_theme.dart';

/// Global theme toggle — accessible from any screen
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.init();

  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value = prefs.getBool('dark_mode') ?? true;

  final isDark = darkModeNotifier.value;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? AppColors.darkBg : AppColors.background,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
  runApp(const MedAgentApp());
}

class MedAgentApp extends StatelessWidget {
  const MedAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark ? AppColors.darkBg : AppColors.background,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp.router(
          title: 'MED AGENT',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// Toggle theme from anywhere
void toggleTheme() async {
  darkModeNotifier.value = !darkModeNotifier.value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark_mode', darkModeNotifier.value);
}
