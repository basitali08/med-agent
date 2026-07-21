import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_dashboard.dart';
import '../screens/symptom_checker.dart';
import '../screens/emergency_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = ApiClient.instance.isAuthenticated;
      final loc = state.matchedLocation;
      final inAuth = loc == '/login' || loc == '/splash';
      if (!loggedIn && !inAuth) return '/login';
      if (loggedIn && loc == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeDashboard()),
      GoRoute(path: '/symptom-checker', builder: (_, __) => const SymptomCheckerScreen()),
      GoRoute(path: '/emergency', builder: (_, __) => const EmergencyScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}
