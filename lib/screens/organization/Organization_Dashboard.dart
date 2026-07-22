import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/organization/incentive_calculation.dart';
import 'package:ideal_cst/screens/organization/insights_dashboard.dart';
import 'package:ideal_cst/screens/organization/manager_expenses.dart';
import 'package:ideal_cst/screens/organization/manager_material_approval_screen.dart';
import 'package:ideal_cst/screens/organization/material_report.dart';
import 'package:ideal_cst/screens/organization/reports/org_site_supervisor_dailyWeek_report.dart';
import 'package:ideal_cst/screens/organization/organization_expenses.dart';
import 'package:ideal_cst/screens/organization/organization_site_entry.dart';
import 'package:ideal_cst/screens/organization/reports/org_site_weekly_financial_report.dart';
import 'package:ideal_cst/screens/organization/tools_inventory_report.dart';
import 'package:ideal_cst/screens/config_account_dashboard.dart';
import 'package:ideal_cst/screens/organization/org_site_payment_screen.dart';
import 'package:ideal_cst/screens/organization/manager_approval_screen.dart';

class OrganizationDashboard extends StatelessWidget {
  const OrganizationDashboard({super.key});

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
        content: const Text('Are you sure you want to logout?'),
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
              backgroundColor: const Color(0xFF160068),
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
      await prefs.clear();

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
        backgroundColor: const Color.fromARGB(255, 207, 226, 243), // Light Blue Background
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              // Configuration Section
              _buildSectionHeader("Configuration"),
              _buildActionCard(
                title: "Manager Account",
                subtitle: "Manage system & account configurations",
                icon: Icons.settings,
                color: Colors.blue[800]!,
                onTap: () => _navigateToConfiguration(context),
              ),

              // Weekly Financial Balance Sheet Section
              _buildSectionHeader("Weekly Financial Balance Sheet"),
              _buildActionCard(
                title: "Site Payment Entry",
                subtitle: "Record and manage site payments",
                icon: Icons.payments,
                color: Colors.green[800]!,
                onTap: () => _navigateToSitePaymentEntry(context),
              ),
              _buildActionCard(
                title: "Site Payment Entry Report",
                subtitle: "View daily/weekly payment logs",
                icon: Icons.receipt_long,
                color: Colors.purple[800]!,
                onTap: () => _navigateToDailyReport(context),
              ),
              _buildActionCard(
                title: "Weekly Site Finance Report",
                subtitle: "Financial summary across sites",
                icon: Icons.bar_chart,
                color: Colors.orange[800]!,
                onTap: () => _navigateToSiteWeeklyFinancialReport(context),
              ),

              // Expenses Section
              _buildSectionHeader("Expenses"),
              _buildActionCard(
                title: "Organization Expenses",
                subtitle: "Track organization-level expenses",
                icon: Icons.account_balance_wallet,
                color: Colors.red[800]!,
                onTap: () => _navigateToOrganizationExpenses(context),
              ),
              _buildActionCard(
                title: "Manager Expenses",
                subtitle: "Review manager submitted expenses",
                icon: Icons.attach_money,
                color: Colors.teal[800]!,
                onTap: () => _navigateToManagerExpenses(context),
              ),
              _buildActionCard(
                title: "Supervisor Expenses",
                subtitle: "Review supervisor site entries",
                icon: Icons.money,
                color: Colors.indigo[800]!,
                onTap: () => _navigateToSiteExpenses(context),
              ),

              // Approvals Section
              _buildSectionHeader("Approvals"),
              _buildActionCard(
                title: "Work Schedule Request Approval",
                subtitle: "Approve supervisor work schedules",
                icon: Icons.work_history,
                color: Colors.deepPurple[800]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerApprovalScreen()),
                ),
              ),
              _buildActionCard(
                title: "Material Request Approval",
                subtitle: "Approve supervisor material requests",
                icon: Icons.inventory_2,
                color: Colors.blueGrey[800]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagerMaterialApprovalScreen(),
                  ),
                ),
              ),

              // Incentive Calculator
              _buildSectionHeader("Supervisor Incentive Calculator"),
              _buildActionCard(
                title: "Incentive Calculation",
                subtitle: "Calculate supervisor incentives",
                icon: Icons.calculate,
                color: Colors.amber[800]!,
                onTap: () => _navigateToIncentiveCaliculation(context),
              ),

              // Insights Section
              _buildSectionHeader("Insights"),
              _buildActionCard(
                title: "Project Financial Reports",
                subtitle: "Detailed financial insights & analytics",
                icon: Icons.analytics,
                color: Colors.pink[800]!,
                onTap: () => _navigateToInsights(context),
              ),
              _buildActionCard(
                title: "Materials Inventory",
                subtitle: "Check site materials status & inventory",
                icon: Icons.inventory,
                color: Colors.deepOrange[800]!,
                onTap: () => _navigateToMaterialReport(context),
              ),
              _buildActionCard(
                title: "Tools Inventory",
                subtitle: "Track tools, equipment & master list",
                icon: Icons.build,
                color: Colors.cyan[800]!,
                onTap: () => _navigateToToolsInventory(context),
              ),

              const SizedBox(height: 32),
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Super Admin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color.fromARGB(163, 25, 1, 112).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.logout, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToConfiguration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigAccountDashboard()),
    );
  }

  void _navigateToDailyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailySitePaymentReportScreen()),
    );
  }

  void _navigateToInsights(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InsightsDashboard()),
    );
  }

  void _navigateToSitePaymentEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SitePaymentScreen()),
    );
  }

  void _navigateToSiteWeeklyFinancialReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SiteWeeklyFinancialReports()),
    );
  }

  void _navigateToIncentiveCaliculation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IncentiveCalculation()),
    );
  }

  void _navigateToOrganizationExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrganizationExpenses()),
    );
  }

  void _navigateToManagerExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManagerExpenses()),
    );
  }

  void _navigateToMaterialReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MaterialReportPage()),
    );
  }

  void _navigateToToolsInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ToolsInventoryPage()),
    );
  }

  void _navigateToSiteExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const OrganizationSiteEntry(userName: '', userDetails: {}),
      ),
    );
  }
}
