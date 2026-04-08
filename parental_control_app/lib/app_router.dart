// Routing: role-based (parent vs child). After login, redirect by role.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shared/firebase_services/auth_service.dart';
import 'shared/models/user_model.dart';
import 'child_app/screens/child_home_screen.dart';
import 'child_app/screens/pairing_screen.dart';
import 'child_app/screens/sms_consent_screen.dart';
import 'child_app/screens/safe_browser_screen.dart';
import 'child_app/screens/app_request_screen.dart';
import 'parent_app/screens/parent_dashboard_screen.dart';
import 'shared/screens/login_screen.dart';
import 'shared/screens/register_screen.dart';
import 'shared/screens/role_selector_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(AuthService auth) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final isLoggedIn = auth.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != '/') {
        return '/';
      }
      if (isLoggedIn && state.matchedLocation == '/') {
        final role = auth.userRole;
        if (role == null) return '/role';
        if (role == UserRole.parent) return '/parent';
        return '/child';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RoleSelectorScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(initialRole: state.extra as UserRole?),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(initialRole: state.extra as UserRole?),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectorScreen(),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/child',
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: '/child/pair',
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: '/child/sms-consent',
        builder: (context, state) => const SmsConsentScreen(),
      ),
      GoRoute(
        path: '/child/safe-browser',
        builder: (context, state) => const SafeBrowserScreen(),
      ),
      GoRoute(
        path: '/child/app-request',
        builder: (context, state) => const AppRequestScreen(),
      ),
    ],
  );
}

