import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/organization/reports/contractor_report_page.dart';
import 'package:ideal_cst/screens/organization/reports/organization_insights_screen.dart';
import 'package:ideal_cst/screens/organization/reports/projectStage_insights_dashboard.dart';
import 'package:ideal_cst/screens/organization/reports/project_financial_status_report_page.dart';
import 'package:ideal_cst/screens/organization/reports/site_status_report.dart';
import 'package:ideal_cst/screens/organization/reports/site_labour_reports_screen.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  final Color mainColor = const Color(0xFF003768);

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: mainColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Financial Reports',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Analytics & Insights',
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
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: mainColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'View Report',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: mainColor,
                          size: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 207, 226, 243),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionCard(
                        context,
                        icon: Icons.receipt_long_rounded,
                        title: 'Site/Project Expenses Report',
                        description:
                            'View and analyze all expenses related to your site or project in detail.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const OrganizationInsightsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSectionCard(
                        context,
                        icon: Icons.timeline_rounded,
                        title: 'Site/Project Stage Expenses Report',
                        description:
                            'Track expenses by project stage for better cost management.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProjectstageInsightsDashboard(),
                            ),
                          );
                        },
                      ),
                      _buildSectionCard(
                        context,
                        icon: Icons.bar_chart_rounded,
                        title: 'Site/Project Status Report',
                        description:
                            'Monitor the current status and progress of your site or project.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SiteStatusReportScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSectionCard(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Project Financial Status Report',
                        description:
                            'Get a detailed overview of your project\'s financial health and budget utilization.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProjectFinancialStatusReportPage(),
                            ),
                          );
                        },
                      ),
                      _buildSectionCard(
                        context,
                        icon: Icons.assignment_turned_in_rounded,
                        title: 'Contractor Report',
                        description:
                            'View contractor-wise entries and totals saved via Contractor Entry.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContractorReportPage(),
                            ),
                          );
                        },
                      ),
                      _buildSectionCard(
                        context,
                        icon: Icons.analytics_rounded,
                        title: 'Centralized Site Labour Reports',
                        description:
                            'Access all labour-related reports, daily wage reports, sub contractor details, worker presence, and billing in one centralized place.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SiteLabourReportsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mainColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: mainColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Select any report card above to open and inspect comprehensive analytics.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
