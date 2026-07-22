import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/reports/projectStage_expenses_reportpage.dart';
import 'package:ideal_cst/screens/organization/reports/projectStage_site_summary_report.dart';
import 'package:ideal_cst/screens/organization/reports/projectstage_daily_site_report.dart';
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
  final String? projectStage;

  SupervisorEntry({
    required this.supervisorId,
    this.siteId,
    this.siteName,
    this.date,
    this.amount,
    this.totalamount,
    this.projectStage,
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
      projectStage: data['projectStage'],
    );
  }
}

class SiteSupervisorMapEntry {
  final String supervisorId;
  final String joinedOn;
  final String location;
  final String projectName;
  final String projectStage;
  final String site;
  final String siteComments;
  final String supervisor;

  SiteSupervisorMapEntry({
    required this.supervisorId,
    required this.joinedOn,
    required this.location,
    required this.projectName,
    required this.projectStage,
    required this.site,
    required this.siteComments,
    required this.supervisor,
  });

  factory SiteSupervisorMapEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SiteSupervisorMapEntry(
      supervisorId: data['Supervisor ID'] ?? '',
      joinedOn: data['joinedOn'] ?? '',
      location: data['location'] ?? '',
      projectName: data['projectName'] ?? '',
      projectStage: data['projectStage'] ?? '',
      site: data['site'] ?? data['siteId'] ?? doc.id,
      siteComments: data['siteComments'] ?? '',
      supervisor: data['supervisor'] ?? '',
    );
  }
}

enum ReportType {
  dailyExpense,
  expenseRange,
  siteSummary,
}

class ProjectstageInsightsDashboard extends StatefulWidget {
  const ProjectstageInsightsDashboard({super.key});

  @override
  State<ProjectstageInsightsDashboard> createState() =>
      _ProjectstageInsightsDashboardState();
}

class _ProjectstageInsightsDashboardState
    extends State<ProjectstageInsightsDashboard> {
  final Color mainColor = const Color(0xFF003768);

  late Future<List<SupervisorEntry>> supervisorEntriesFuture;
  SupervisorEntry? selectedSupervisorEntry;

  List<String> allSiteIds = [];
  String? selectedSiteId;

  List<String> projectStages = [];
  String? selectedProjectStage;
  List<SupervisorEntry> siteSupervisorEntries = [];

  ReportType selectedReportType = ReportType.dailyExpense;

  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;

  List<SupervisorEntry>? _allSupervisorEntriesCached;

  @override
  void initState() {
    super.initState();
    supervisorEntriesFuture = _fetchSupervisorEntriesFromFirestore();
    _fetchAllSites();
  }

  Future<void> _fetchAllSites() async {
    final siteIds = <String>{};

    // 1. Fetch siteSupervisorMap
    try {
      final snap = await FirebaseFirestore.instance.collection('siteSupervisorMap').get();
      for (var doc in snap.docs) {
        final s = doc.data()['site'] ?? doc.data()['siteId'] ?? doc.id;
        if (s != null && s.toString().isNotEmpty) siteIds.add(s.toString());
      }
    } catch (e) {
      debugPrint('Error fetching siteSupervisorMap: $e');
    }

    // 2. Fetch projects (all 58 sites)
    try {
      final snap = await FirebaseFirestore.instance.collection('projects').get();
      for (var doc in snap.docs) {
        final s = doc.data()['siteId'] ?? doc.id;
        if (s != null && s.toString().isNotEmpty) siteIds.add(s.toString());
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    }

    final sortedSites = siteIds.toList()..sort();
    if (mounted) {
      setState(() {
        allSiteIds = sortedSites;
        if (allSiteIds.isNotEmpty && selectedSiteId == null) {
          selectedSiteId = allSiteIds.first;
        }
      });
    }
    await _fetchProjectStagesForSite(selectedSiteId);
  }

  Future<void> _fetchProjectStagesForSite(String? siteId) async {
    if (siteId == null) {
      setState(() {
        projectStages = [];
        selectedProjectStage = null;
        siteSupervisorEntries = [];
      });
      return;
    }
    try {
      final collections = [
        'siteSupervisorEntries',
        'contractorEntries',
        'managerEntries',
        'organizationEntries',
      ];
      Set<String> stageSet = {};

      final futures = collections.map((collection) async {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('siteId', isEqualTo: siteId)
            .get();
        for (var doc in snapshot.docs) {
          if (doc.data().containsKey('projectStage')) {
            final stage = doc['projectStage'];
            if (stage != null && stage.toString().trim().isNotEmpty) {
              stageSet.add(stage.toString());
            }
          }
        }
      }).toList();

      await Future.wait(futures);

      if (mounted) {
        setState(() {
          projectStages = stageSet.toList()..sort();
          selectedProjectStage =
              projectStages.isNotEmpty ? projectStages.first : null;

          _updateSelectedSupervisorEntry();
        });
      }
    } catch (e) {
      debugPrint("Error fetching project stages: $e");
      if (mounted) {
        setState(() {
          projectStages = [];
          selectedProjectStage = null;
          selectedSupervisorEntry = null;
        });
      }
    }
  }

  Future<List<SupervisorEntry>> _fetchSupervisorEntriesFromFirestore() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorEntries')
        .get();
    final entries = querySnapshot.docs
        .map((doc) => SupervisorEntry.fromFirestore(doc))
        .toList();

    _allSupervisorEntriesCached = entries;
    return entries;
  }

  void _updateSelectedSupervisorEntry() {
    if (_allSupervisorEntriesCached == null) {
      selectedSupervisorEntry = null;
      return;
    }

    final entriesForSite = siteSupervisorEntries.isNotEmpty
        ? siteSupervisorEntries
        : _allSupervisorEntriesCached!
            .where((e) => e.siteId == selectedSiteId)
            .toList();

    if (selectedProjectStage == null) {
      selectedSupervisorEntry =
          entriesForSite.isNotEmpty ? entriesForSite.first : null;
    } else {
      final filteredEntries = entriesForSite
          .where((entry) => entry.projectStage == selectedProjectStage)
          .toList();
      selectedSupervisorEntry =
          filteredEntries.isNotEmpty ? filteredEntries.first : null;
    }
  }

  void _openReport() {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) {
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
          builder: (_) => ProjectStageDailySiteExpensesReportPage(
            supervisorId: supervisorId,
            siteId: selectedSiteId!,
            date: selectedDate!,
            projectStage: selectedProjectStage ?? '',
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
          builder: (_) => ProjectStageExpensesReportPage(
            siteId: selectedSiteId!,
            fromDate: fromDate!,
            toDate: toDate!,
            projectStage: selectedProjectStage ?? '',
          ),
        ),
      );
    } else if (selectedReportType == ReportType.siteSummary) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectstageSiteSummaryReport(
            siteId: selectedSiteId!,
            projectStage: selectedProjectStage ?? '',
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
                  'Stage Expenses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Project Stage Report',
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
                            // Site Selection
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
                              value: selectedSiteId,
                              mainColor: mainColor,
                              items: allSiteIds
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
                              onChanged: (String? newSiteId) async {
                                setState(() {
                                  selectedSiteId = newSiteId;
                                  selectedProjectStage = null;
                                  projectStages = [];
                                  siteSupervisorEntries = [];
                                  selectedSupervisorEntry = null;
                                });
                                await _fetchProjectStagesForSite(newSiteId);
                              },
                            ),
                            const SizedBox(height: 20),

                            // Project Stage Selection
                            Row(
                              children: [
                                Icon(Icons.account_tree, color: mainColor),
                                const SizedBox(width: 8),
                                _buildSectionTitle('Select Project Stage *'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            CustomDropdown<String>(
                              hintText: 'Select Project Stage',
                              value: selectedProjectStage,
                              mainColor: mainColor,
                              items: projectStages
                                  .map(
                                    (stage) => DropdownMenuItem<String>(
                                      value: stage,
                                      child: Text(
                                        stage,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E1E2D),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? newStage) {
                                setState(() {
                                  selectedProjectStage = newStage;
                                  _updateSelectedSupervisorEntry();
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
                              title: 'Stage Daily Expense Report',
                              subtitle: 'View stage expenses for a specific date',
                            ),
                            const Divider(height: 16),
                            _buildReportOption(
                              type: ReportType.expenseRange,
                              icon: Icons.date_range,
                              title: 'Stage Expense Range Report',
                              subtitle: 'View stage expenses between dates',
                            ),
                            const Divider(height: 16),
                            _buildReportOption(
                              type: ReportType.siteSummary,
                              icon: Icons.summarize,
                              title: 'Stage Site Summary Report',
                              subtitle: 'Overview of stage progress & costs',
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
                                  'GENERATE STAGE REPORT',
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