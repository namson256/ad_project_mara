import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/admin_controller.dart';
import 'controllers/attendance_controller.dart';
import 'routing/app_router.dart';

void main() {
  runApp(const LecturerPortalApp());
}

class LecturerPortalApp extends StatelessWidget {
  const LecturerPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We instantiate AuthController + AdminController at the root so they
    // survive the entire app lifecycle. The router is built once from
    // AuthController so its `refreshListenable` can react to login/logout.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => AdminController()),
        ChangeNotifierProvider(create: (_) => AttendanceController()),
      ],
      // Builder lets us read AuthController from the provider tree
      // when constructing the router.
      child: Builder(
        builder: (context) {
          final router = AppRouter(context.read<AuthController>()).router;

          return MaterialApp.router(
            title: 'Portal Pensyarah',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.indigo,
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              fontFamily: 'Roboto',
              useMaterial3: true,
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
