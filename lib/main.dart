import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/admin_controller.dart';
import 'controllers/attendance_controller.dart';
import 'controllers/timetable_controller.dart';
import 'controllers/course_controller.dart';
import 'controllers/discipline_controller.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LecturerPortalApp());
}

class LecturerPortalApp extends StatelessWidget {
  const LecturerPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => AdminController()),
        ChangeNotifierProvider(create: (_) => AttendanceController()),
        ChangeNotifierProvider(create: (_) => TimetableController()),
        ChangeNotifierProvider(create: (_) => CourseController()),
        ChangeNotifierProvider(create: (_) => DisciplineController()),
      ],
      child: Builder(
        builder: (context) {
          final authController = context.read<AuthController>();

          // Attempt auto-login from existing Firebase session
          authController.tryAutoLogin();

          final router = AppRouter(authController).router;

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
