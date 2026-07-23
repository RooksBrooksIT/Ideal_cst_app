import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/organization/manager_expenses.dart';
import 'package:ideal_cst/screens/manager/manager_site_entry_page.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';

class ManagerExpensesHomeScreen extends StatelessWidget {
  const ManagerExpensesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 218, 238, 220),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSectionCard(
              context,
              icon: Icons.supervisor_account_rounded,
              title: 'Site Supervisor Entry',
              subtitle: 'Add, view, and manage site supervisor expenses and entries.',
              color: Colors.blue[800]!,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagerSiteEntryPage(userName: '', userDetails: const {}),
                  ),
                );
              },
              buttonText: 'Go to Site Supervisor Entry',
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Manager Entry',
              subtitle: 'Add, view, and manage manager-level expenses and approvals.',
              color: Colors.teal[800]!,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManagerExpenses()),
                );
              },
              buttonText: 'Go to Manager Entry',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Expenses',
      title: 'Manager Expenses',
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required String buttonText,
  }) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ManagerTheme.buildPrimaryButton(
                label: buttonText,
                icon: Icons.arrow_forward,
                onPressed: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}