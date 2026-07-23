import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'org_site_weekly_financial_report2.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class SiteWeeklyFinancialReports extends StatefulWidget {
  const SiteWeeklyFinancialReports({super.key});

  @override
  State<SiteWeeklyFinancialReports> createState() =>
      _SiteWeeklyFinancialReportState();
}

class _SiteWeeklyFinancialReportState
    extends State<SiteWeeklyFinancialReports> {
  final Color mainColor = const Color(0xFF003768);

  List<Map<String, dynamic>> supervisorMaps = [];
  int selectedIndex = 0;
  bool isLoading = true;

  int? _selectedYear = DateTime.now().year;
  int? _selectedWeek;
  int? _selectedMonth = DateTime.now().month;
  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    fetchSupervisorData();
  }

  Future<void> fetchSupervisorData() async {
    try {
      final Map<String, Map<String, dynamic>> mapBySiteId = {};

      // 1. Fetch siteSupervisorMap
      try {
        final mapSnap = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .get();
        for (var doc in mapSnap.docs) {
          final data = doc.data();
          final site = data['site'] as String? ?? data['siteId'] as String? ?? doc.id;
          if (site.isNotEmpty) {
            mapBySiteId[site] = {
              'site': site,
              'supervisor': data['supervisor'] ?? '',
              'projectName': data['projectName'] ?? '',
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorMap: $e');
      }

      // 2. Fetch projects (for all 58 sites)
      try {
        final projSnap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        for (var doc in projSnap.docs) {
          final data = doc.data();
          final site = data['siteId'] as String? ?? doc.id;
          if (site.isNotEmpty) {
            final existing = mapBySiteId[site];
            mapBySiteId[site] = {
              'site': site,
              'supervisor': existing?['supervisor'] ?? data['supervisor'] ?? data['supervisorName'] ?? '',
              'projectName': data['projectName'] ?? existing?['projectName'] ?? '',
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      final mergedList = mapBySiteId.values.toList()
        ..sort((a, b) => (a['site'] as String).compareTo(b['site'] as String));

      if (mounted) {
        setState(() {
          supervisorMaps = mergedList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching supervisor data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          supervisorMaps = [];
          selectedIndex = 0;
        });
      }
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
                  'Weekly Site Finance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Report',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 207, 226, 243), // Light Blue Background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: mainColor))
                    : supervisorMaps.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: mainColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Sites Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: mainColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No site supervisor data available',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : Container(
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
                                  // SECTION 1: Select Site
                                  _buildSectionTitle('Select Site *'),
                                  const SizedBox(height: 8),
                                  CustomDropdown<int>(
                                    hintText: 'Choose Site',
                                    value: selectedIndex < supervisorMaps.length ? selectedIndex : null,
                                    mainColor: mainColor,
                                    items: List.generate(
                                      supervisorMaps.length,
                                      (index) => DropdownMenuItem<int>(
                                        value: index,
                                        child: Text(
                                          supervisorMaps[index]['site'] ?? 'Site',
                                          style: const TextStyle(
                                            color: Color(0xFF1E1E2D),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    onChanged: (int? newIndex) {
                                      if (newIndex != null && newIndex < supervisorMaps.length) {
                                        setState(() {
                                          selectedIndex = newIndex;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // SECTION 2: Period Selection
                                  _buildSectionTitle('Year and Month *'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomDropdown<int>(
                                          hintText: 'Select Month',
                                          value: _selectedMonth,
                                          mainColor: mainColor,
                                          items: List.generate(
                                            12,
                                            (i) => DropdownMenuItem<int>(
                                              value: i + 1,
                                              child: Text(
                                                _monthNames[i],
                                                style: const TextStyle(
                                                  color: Color(0xFF1E1E2D),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          onChanged: (int? val) {
                                            setState(() {
                                              _selectedMonth = val;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: CustomDropdown<int>(
                                          hintText: 'Select Year',
                                          value: _selectedYear,
                                          mainColor: mainColor,
                                          items: List.generate(
                                            5,
                                            (i) => DropdownMenuItem<int>(
                                              value: DateTime.now().year - 2 + i,
                                              child: Text(
                                                (DateTime.now().year - 2 + i).toString(),
                                                style: const TextStyle(
                                                  color: Color(0xFF1E1E2D),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          onChanged: (int? val) {
                                            setState(() {
                                              _selectedYear = val;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Week selection
                                  _buildSectionTitle('Select Week *'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: List.generate(
                                      5,
                                      (i) {
                                        final isSelected = _selectedWeek == i + 1;
                                        return ChoiceChip(
                                          label: Text(
                                            'Week ${i + 1}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isSelected ? Colors.white : mainColor,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: mainColor,
                                          backgroundColor: const Color(0xFFE8F0FE),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            side: BorderSide(
                                              color: isSelected ? mainColor : Colors.transparent,
                                            ),
                                          ),
                                          onSelected: (selected) {
                                            setState(() {
                                              _selectedWeek = selected ? i + 1 : null;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Selected period summary
                                  if (_selectedWeek != null)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: mainColor.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: mainColor.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selected Period:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: mainColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Year: $_selectedYear',
                                            style: const TextStyle(color: Color(0xFF1E1E2D), fontSize: 13),
                                          ),
                                          Text(
                                            'Month: ${_selectedMonth != null ? _monthNames[_selectedMonth! - 1] : ''}',
                                            style: const TextStyle(color: Color(0xFF1E1E2D), fontSize: 13),
                                          ),
                                          Text(
                                            'Week: Week $_selectedWeek',
                                            style: const TextStyle(color: Color(0xFF1E1E2D), fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 28),

                                  // Action Buttons
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (supervisorMaps.isEmpty ||
                                                selectedIndex >= supervisorMaps.length) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('No site available to select.'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }
                                            if (_selectedYear == null ||
                                                _selectedMonth == null ||
                                                _selectedWeek == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Please select year, month, and week.'),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                              return;
                                            }
                                            final selectedSite = supervisorMaps[selectedIndex];
                                            final monthName = _monthNames[_selectedMonth! - 1].substring(0, 3);
                                            final paymentPeriod = "${_selectedYear}_${monthName}_Week$_selectedWeek";

                                            final query = await FirebaseFirestore.instance
                                                .collection('siteSupervisorPayments')
                                                .where('paymentPeriod', isEqualTo: paymentPeriod)
                                                .limit(1)
                                                .get()
                                                .timeout(
                                                  const Duration(seconds: 10),
                                                  onTimeout: () {
                                                    throw TimeoutException(
                                                      'Query timeout',
                                                      const Duration(seconds: 10),
                                                    );
                                                  },
                                                );

                                            try {
                                              if (!context.mounted) return;

                                              if (query.docs.isNotEmpty) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => SiteWeeklyFinancialReport2(
                                                      siteDetails: selectedSite,
                                                      paymentPeriod: paymentPeriod,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text(
                                                      'No Data Found',
                                                      style: TextStyle(color: mainColor, fontWeight: FontWeight.bold),
                                                    ),
                                                    content: const Text(
                                                      'No report is available for the selected period.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: Text(
                                                          'OK',
                                                          style: TextStyle(color: mainColor, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              debugPrint('Error loading report: $e');
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Failed to load report. Please try again.'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: mainColor,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 2,
                                          ),
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
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            'CANCEL',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
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
