 import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/organization/Organization_Dashboard.dart';
import 'package:ideal_cst/screens/config_account_dashboard.dart';
import 'package:ideal_cst/screens/supervisor/supervisor_dashboard.dart';
import 'package:ideal_cst/screens/contractor_entry_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () async {
        final prefs = await SharedPreferences.getInstance();
        final String? role = prefs.getString('persistent_role');

        if (!mounted) return;

        if (role == 'Organization') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OrganizationDashboard()),
          );
        } else if (role == 'Manager') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ConfigAccountDashboard()),
          );
        } else if (role == 'Supervisor') {
          final supervisorId = prefs.getString('sup_supervisorId') ?? '';
          final supervisorName = prefs.getString('sup_supervisorName') ?? '';
          final username = prefs.getString('sup_username') ?? '';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SupervisorDashboard(
                supervisorId: supervisorId,
                supervisorName: supervisorName,
                username: username,
              ),
            ),
          );
        }  else if (role == 'ContractorEntry') {
          final supervisorId = prefs.getString('sup_supervisorId') ?? '';
          final contractorName = prefs.getString('sup_contractorName') ?? '';
          final contractorField = prefs.getString('sup_contractorField') ?? '';
          final username = prefs.getString('sup_username') ?? '';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ContractorEntryPage(
                userName: username,
                userDetails: {
                  'supervisorId': supervisorId,
                  'contractorName': contractorName,
                  'contractorField': contractorField,
                },
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/letsStart');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add the splash screen logo image
            Image.asset(
              'assets/images/splash_screen_logo.png',
              width: 250, // Adjust width as needed
              height: 250, // Adjust height as needed
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to Construct Pro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            CircularProgressIndicator(
              valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF0b3470)),

            ),
          ],
        ),
      ),
    );
  }
}
