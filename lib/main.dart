import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/lets_start_page.dart';
import 'screens/main_dashboard.dart';
import 'screens/site_labour_attendance_report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Construct Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 2, 32, 116),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Define initial route
      initialRoute: '/',
      // Define app routes
      routes: {
        '/': (context) => const SplashScreen(),
        '/letsStart': (context) => const LetsStartPage(),
        '/dashboard': (context) => MainDashboard(),
        '/reports/site-labour-report': (context) =>
            const SiteLabourAttendanceReportScreen(),
      },
    );
  }
}
