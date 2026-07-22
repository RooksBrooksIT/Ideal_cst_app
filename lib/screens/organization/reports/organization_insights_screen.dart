import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/daily_site_report.dart';
import 'package:ideal_cst/screens/organization/reports/site_expenses_reportpage.dart';
import 'package:ideal_cst/screens/organization/site_summary_page.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';
import 'package:ideal_cst/screens/organization/components/custom_calendar.dart';
import 'package:intl/intl.dart';

class SupervisorEntry {
  final String supervisorId;
  final String? siteId;
  final String? siteName;
  final DateTime? date;
  final num? amount;
  final num? totalamount;

  SupervisorEntry({
    required this.supervisorId,
    this.siteId,
    this.siteName,
    this.date,
    this.amount,
    this.totalamount,
  });

  factory SupervisorEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupervisorEntry(
      supervisorId: data['supervisorId'] ?? data['supervisor'] ?? '',
      siteId: data['siteId'] ?? data['site'] ?? doc.id,
      siteName: data['siteName'] ?? data['projectName'],
      date: data['date'] != null
          ? (data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.tryParse(data['date'].toString()))
          : null,
      amount: data['amount'],
      totalamount: data['totalamount'],
    );
  }
}

enum ReportType {
  dailyExpense,
  expenseRange,
  siteSummary,
}

class OrganizationInsightsScreen extends StatefulWidget {
  const OrganizationInsightsScreen({super.key});

  @override
  State<OrganizationInsightsScreen> createState() =>
      _OrganizationInsightsScreenState();
}

class _OrganizationInsightsScreenState
    extends State<OrganizationInsightsScreen> {
  final Color mainColor = const Color(0xFF003768);

  late Future<List<SupervisorEntry>> supervisorEntriesFuture;
  SupervisorEntry? selectedSupervisorEntry;
  String? _selectedSiteId;
  List<String> _siteIds = [];

  ReportType selectedReportType = ReportType.dailyExpense;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    supervisorEntriesFuture = _fetchSupervisorEntriesAndSites();
  }

  Future<List<SupervisorEntry>> _fetchSupervisorEntriesAndSites() async {
    final siteIds = <String>{};
    List<SupervisorEntry> entries = [];

    // 1. Fetch siteSupervisorEntries
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorEntries')
          .get();
      entries = querySnapshot.docs
          .map((doc) => SupervisorEntry.fromFirestore(doc))
          .toList();
      for (var entry in entries) {
        if (entry.siteId != null && entry.siteId!.isNotEmpty) {
          siteIds.add(entry.siteId!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching siteSupervisorEntries: $e');
    }

    // 2. Fetch siteSupervisorMap
    try {
      final mapSnap = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .get();
      for (var doc in mapSnap.docs) {
        final site = (doc.data()['site'] ?? doc.data()['siteId'] ?? doc.id).toString();
        if (site.isNotEmpty) siteIds.add(site);
      }
    } catch (e) {
      debugPrint('Error fetching siteSupervisorMap: $e');
    }

    // 3. Fetch projects (all 58 sites)
    try {
      final projSnap = await FirebaseFirestore.instance
          .collection('projects')
          .get();
      for (var doc in projSnap.docs) {
        final site = (doc.data()['siteId'] ?? doc.id).toString();
        if (site.isNotEmpty) siteIds.add(site);
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    }

    final sortedSites = siteIds.toList()..sort();
    if (mounted) {
      setState(() {
        _siteIds = sortedSites;
        if (_siteIds.isNotEmpty) {
          _selectedSiteId = _siteIds.first;
        }
      });
    }

    return entries;
  }

  void _openReport() {
    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a site ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final supervisorId = selectedSupervisorEntry?.supervisorId ?? '';

    if (selectedReportType == ReportType.dailyExpense) {
      if (selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailySiteExpensesReportPage(
            supervisorId: supervisorId,
            siteId: _selectedSiteId!,
            date: selectedDate!,
          ),
        ),
      );
    } else if (selectedReportType == ReportType.expenseRange) {
      if (fromDate == null || toDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both From and To dates'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteExpensesReportPage(
            siteId: _selectedSiteId!,
            fromDate: fromDate!,
            toDate: toDate!,
            supervisorId: supervisorId,
          ),
        ),
      );
    } else if (selectedReportType == ReportType.siteSummary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteSummaryPage(
            siteId: _selectedSiteId!,
          ),
        ),
      );
    }
  }

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
                child: Icon(Icons.arrow_back_ios_new, color: mainColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Site & Project Report',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E2D),
        fontSize: 14,
      ),
    );
  }

  Widget _buildReportOption({
    required ReportType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool isSelected = selectedReportType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          selectedReportType = type;
          selectedDate = null;
          fromDate = null;
          toDate = null;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? mainColor.withValues(alpha: 0.1)
                    : const Color.fromARGB(255, 245, 247, 250),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? mainColor : Colors.grey[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? mainColor : const Color(0xFF1E1E2D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<ReportType>(
              value: type,
              groupValue: selectedReportType,
              onChanged: (ReportType? value) {
                if (value == null) return;
                setState(() {
                  selectedReportType = value;
                  selectedDate = null;
                  fromDate = null;
                  toDate = null;
                });
              },
              activeColor: mainColor,
            ),
          ],
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
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<SupervisorEntry>>(
                  future: supervisorEntriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: mainColor),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
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
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: mainColor),
                                const SizedBox(width: 8),
                                _buildSectionTitle('Select Site ID *'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            CustomDropdown<String>(
                              hintText: 'Select Site ID',
                              value: _selectedSiteId,
                              mainColor: mainColor,
                              items: _siteIds
                                  .map(
                                    (siteId) => DropdownMenuItem<String>(
                                      value: siteId,
                                      child: Text(
                                        siteId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E1E2D),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? newSiteId) {
                                setState(() {
                                  _selectedSiteId = newSiteId;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Icon(Icons.receipt_long, color: mainColor),
                                const SizedBox(width: 8),
                                _buildSectionTitle('Select Report Type *'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildReportOption(
                              type: ReportType.dailyExpense,
                              icon: Icons.today,
                              title: 'Daily Expense Report',
                              subtitle: 'View expenses for a specific date',
                            ),
                            const Divider(height: 16),
                            _buildReportOption(
                              type: ReportType.expenseRange,
                              icon: Icons.date_range,
                              title: 'Expense Range Report',
                              subtitle: 'View expenses between two dates',
                            ),
                            const Divider(height: 16),
                            _buildReportOption(
                              type: ReportType.siteSummary,
                              icon: Icons.summarize,
                              title: 'Site Summary Report',
                              subtitle: 'Overview of total site progress & costs',
                            ),
                            const SizedBox(height: 24),

                            // Date Inputs
                            if (selectedReportType == ReportType.dailyExpense) ...[
                              _buildSectionTitle('Select Date *'),
                              const SizedBox(height: 8),
                              CustomCalendar(
                                selectedDate: selectedDate,
                                hintText: 'Choose Date',
                                mainColor: mainColor,
                                onDateSelected: (date) {
                                  setState(() {
                                    selectedDate = date;
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (selectedReportType == ReportType.expenseRange) ...[
                              _buildSectionTitle('From Date *'),
                              const SizedBox(height: 8),
                              CustomCalendar(
                                selectedDate: fromDate,
                                hintText: 'Select Start Date',
                                mainColor: mainColor,
                                onDateSelected: (date) {
                                  setState(() {
                                    fromDate = date;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSectionTitle('To Date *'),
                              const SizedBox(height: 8),
                              CustomCalendar(
                                selectedDate: toDate,
                                hintText: 'Select End Date',
                                mainColor: mainColor,
                                onDateSelected: (date) {
                                  setState(() {
                                    toDate = date;
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _openReport,
                                child: const Text(
                                  'GENERATE REPORT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}