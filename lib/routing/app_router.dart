import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../views/login_view.dart';
import '../views/register_view.dart';
import '../views/forgot_password_view.dart';
import '../views/admin/admin_dashboard_view.dart';
import '../views/lecturer/attendance_marking_view.dart';
import '../views/lecturer/lecturer_dashboard_view.dart';
import '../views/ketua/ketua_dashboard_view.dart';
import '../views/timetable_views.dart';
import '../views/senarai_kursus_view.dart';
import '../views/admin/urus_pengguna_view.dart';

/// AppRouter
/// ----------------
/// Centralized go_router configuration with role-based access control.
///
/// Three roles:
///   * pensyarah   → /lecturer-dashboard (+ /lecturer-attendance)
///   * staff       → /admin (admin dashboard)
///   * ketuaProgram → /ketua-dashboard
///
/// Unauthenticated routes: /login, /register, /forgot-password
class AppRouter {
  final AuthController authController;

  AppRouter(this.authController);

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authController,
    redirect: _guard,
    routes: [
      // --- Unauthenticated routes ---
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordView(),
      ),

      // --- Staff (admin) routes ---
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardView(),
      ),

      // --- Pensyarah (lecturer) routes ---
      GoRoute(
        path: '/lecturer-dashboard',
        name: 'lecturer',
        builder: (context, state) => const LecturerDashboardView(),
      ),
      GoRoute(
        path: '/lecturer-attendance',
        name: 'lecturer-attendance',
        builder: (context, state) => const AttendanceMarkingView(),
      ),

      // --- Ketua Program routes ---
      GoRoute(
        path: '/ketua-dashboard',
        name: 'ketua-dashboard',
        builder: (context, state) => const KetuaDashboardView(),
      ),

      // --- Timetable routes (Woo Cheng Shuan) ---
      GoRoute(
        path: '/admin/muat-naik-jadual',
        name: 'upload-schedule',
        builder: (context, state) => const UploadTimeScheduleView(),
      ),
      GoRoute(
        path: '/admin/jadual',
        name: 'admin-timetable',
        builder: (context, state) => const ShowTimetableSlotView(),
      ),
      GoRoute(
        path: '/admin/senarai-kursus',
        name: 'senarai-kursus',
        builder: (context, state) => const SenaraiKursusView(),
      ),
      GoRoute(
        path: '/admin/urus-pengguna',
        name: 'urus-pengguna',
        builder: (context, state) => const UrusPenggunaView(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Laluan tidak ditemui: ${state.uri}'),
      ),
    ),
  );

  /// Pages that don't require authentication.
  static const _publicPaths = {'/login', '/register', '/forgot-password'};

  /// The guard. Returns a path to redirect to, or `null` to allow the
  /// navigation through.
  String? _guard(BuildContext context, GoRouterState state) {
    final loggedIn = authController.isLoggedIn;
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicPaths.contains(currentPath);

    // Not logged in → allow public routes, redirect everything else to /login.
    if (!loggedIn) {
      return isPublicRoute ? null : '/login';
    }

    // Logged in but on a public route → bounce to their role's dashboard.
    if (isPublicRoute) {
      return _dashboardForRole();
    }

    // --- Role-based access control ---

    // Pensyarah can only access /lecturer-* routes.
    if (authController.isPensyarah) {
      if (!currentPath.startsWith('/lecturer')) {
        return '/lecturer-dashboard';
      }
    }

    // Staff can only access /admin routes.
    if (authController.isStaff) {
      if (!currentPath.startsWith('/admin')) {
        return '/admin';
      }
    }

    // Ketua Program can only access /ketua-* routes.
    if (authController.isKetuaProgram) {
      if (!currentPath.startsWith('/ketua')) {
        return '/ketua-dashboard';
      }
    }

    return null; // allowed
  }

  /// Returns the dashboard path for the current user's role.
  String _dashboardForRole() {
    if (authController.isPensyarah) return '/lecturer-dashboard';
    if (authController.isStaff) return '/admin';
    if (authController.isKetuaProgram) return '/ketua-dashboard';
    return '/login'; // fallback
  }
}
