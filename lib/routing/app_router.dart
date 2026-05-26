import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../views/login_view.dart';
import '../views/admin/admin_dashboard_view.dart';
import '../views/lecturer/lecturer_dashboard_view.dart';

/// AppRouter
/// ----------------
/// Centralized go_router configuration with role-based access control.
///
/// Two important details for Flutter Web:
///   * `refreshListenable` ties the router to AuthController, so when the
///     user logs in / out the redirect runs automatically and the URL
///     updates without a manual `context.go()` call.
///   * `redirect` is the single source of truth for "where am I allowed?".
///     It runs on every navigation event, including direct URL entry —
///     which is the main attack vector on web ("just type /admin").
class AppRouter {
  final AuthController authController;

  AppRouter(this.authController);

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authController,
    redirect: _guard,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardView(),
      ),
      GoRoute(
        path: '/lecturer-dashboard',
        name: 'lecturer',
        builder: (context, state) => const LecturerDashboardView(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );

  /// The guard. Returns a path to redirect to, or `null` to allow the
  /// navigation through.
  String? _guard(BuildContext context, GoRouterState state) {
    final loggedIn = authController.isLoggedIn;
    final goingToLogin = state.matchedLocation == '/login';

    // Not logged in → force them to /login.
    if (!loggedIn) {
      return goingToLogin ? null : '/login';
    }

    // Logged in but sitting on /login → bounce to their dashboard.
    if (goingToLogin) {
      return authController.isAdmin ? '/admin' : '/lecturer-dashboard';
    }

    // CRITICAL: Lecturers must never reach /admin, even via direct URL.
    final isAdminRoute = state.matchedLocation.startsWith('/admin');
    if (isAdminRoute && authController.isLecturer) {
      return '/lecturer-dashboard';
    }

    // Symmetric guard: an admin landing on the lecturer dashboard is
    // probably a stale URL — send them back to /admin.
    if (state.matchedLocation == '/lecturer-dashboard' &&
        authController.isAdmin) {
      return '/admin';
    }

    return null; // allowed
  }
}