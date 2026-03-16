import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/setup_provider.dart';
import 'screens/setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_screen.dart';

GoRouter buildRouter(ProviderRef<Object?> ref) {
  final notifier = _RouterChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final setupPhase = ref.read(setupPhaseProvider);
      final authStatus = ref.read(authProvider).status;
      final loc = state.matchedLocation;
      final isSetupPath = loc == '/setup';
      final isAuthPath = loc == '/login' || loc == '/register';

      if (setupPhase == SetupPhase.loading) return null;

      if (setupPhase == SetupPhase.needsSetup) {
        return isSetupPath ? null : '/setup';
      }

      if (authStatus == AuthStatus.unknown) return null;

      if (authStatus == AuthStatus.unauthenticated) {
        return isAuthPath ? null : '/login';
      }

      // Authenticated + setup done
      if (isSetupPath || isAuthPath) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const MainScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
}

/// A [ChangeNotifier] that fires whenever auth or setup state changes so that
/// GoRouter re-evaluates its redirect guard.
class _RouterChangeNotifier extends ChangeNotifier {
  _RouterChangeNotifier(ProviderRef<Object?> ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(setupProvider, (_, __) => notifyListeners());
  }
}
