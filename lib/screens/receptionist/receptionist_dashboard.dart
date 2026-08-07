import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/receptionist/receptionist_all_site_page.dart';
import 'package:ideal_cst/screens/receptionist/receptionist_supervisor_config.dart';
import 'package:ideal_cst/screens/receptionist/receptionist_supervisor_map_screen.dart';
import 'package:ideal_cst/screens/receptionist/receptionist_site_labour_reports_screen.dart';

class ReceptionistDashboard extends StatefulWidget {
  const ReceptionistDashboard({super.key});

  @override
  State<ReceptionistDashboard> createState() => _ReceptionistDashboardState();
}

class _ReceptionistDashboardState extends State<ReceptionistDashboard> {
  String _receptionistName = 'Receptionist';

  @override
  void initState() {
    super.initState();
    _loadReceptionistData();
  }

  Future<void> _loadReceptionistData() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('receptionist_username');
    if (username != null && username.isNotEmpty && mounted) {
      setState(() {
        _receptionistName = username;
      });
    }
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout from Receptionist account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD84315),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('receptionist_is_logged_in', false);
      await prefs.remove('receptionist_username');
      await prefs.remove('persistent_role');

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showLogoutConfirmation(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF3E0), // Light Orange Background
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Management & Configurations'),
              _buildActionCard(
                title: 'All site list',
                subtitle: 'View all sites, locations & status details',
                icon: Icons.location_city_rounded,
                color: const Color(0xFFD84315),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceptionistAllSitePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                title: 'Supervisor Config',
                subtitle: 'Create & manage site supervisor accounts',
                icon: Icons.supervisor_account_rounded,
                color: const Color(0xFFD84315),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceptionistSupervisorConfig(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                title: 'Site-Supervisor Map',
                subtitle: 'Map supervisors to construction sites',
                icon: Icons.map_rounded,
                color: const Color(0xFFD84315),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceptionistSupervisorMapScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Reports & Analytics'),
              _buildActionCard(
                title: 'Site Labour Reports',
                subtitle: 'View labour attendance, cost & worker reports',
                icon: Icons.assessment_rounded,
                color: const Color(0xFFD84315),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceptionistSiteLabourReportsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E1E2D),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD84315),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD84315).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _receptionistName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFD84315),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD84315).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.logout, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
