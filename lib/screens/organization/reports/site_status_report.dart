import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/reports/site_status_reportPage.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class SiteStatusReportScreen extends StatefulWidget {
  const SiteStatusReportScreen({super.key});

  @override
  State<SiteStatusReportScreen> createState() => _SiteStatusReportScreenState();
}

class _SiteStatusReportScreenState extends State<SiteStatusReportScreen> {
  final Color mainColor = const Color(0xFF003768);

  String? _selectedStatus;
  List<String> _statusOptions = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _spendingPercentage = 0.0;
  double _budgetAmount = 0.0;
  double _spentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      final statusSnapshot =
          await FirebaseFirestore.instance.collection('projectStatus').get();

      final financialSnapshot = await FirebaseFirestore.instance
          .collection('projectFinances')
          .doc('currentProject')
          .get();

      Set<String> uniqueStatuses = {};
      for (var doc in statusSnapshot.docs) {
        final data = doc.data();
        final stateField = data['projectState'];
        if (stateField is String) {
          uniqueStatuses.add(stateField);
        } else if (stateField is List) {
          for (var status in stateField) {
            if (status is String) uniqueStatuses.add(status);
          }
        }
      }

      if (financialSnapshot.exists) {
        final financeData = financialSnapshot.data();
        _budgetAmount = (financeData?['budget'] as num?)?.toDouble() ?? 0.0;
        _spentAmount = (financeData?['spent'] as num?)?.toDouble() ?? 0.0;
        _spendingPercentage =
            _budgetAmount > 0 ? _spentAmount / _budgetAmount : 0.0;
      }

      if (mounted) {
        setState(() {
          _statusOptions = uniqueStatuses.isNotEmpty
              ? (uniqueStatuses.toList()..sort())
              : ['In-Progress', 'Planning', 'Pending', 'Complete', 'On-Hold'];
          _selectedStatus = _statusOptions.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _handleReport() {
    if (_selectedStatus != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SiteStatusReportPage(
            status: _selectedStatus!,
            budgetData: {
              'percentage': _spendingPercentage,
              'budget': _budgetAmount,
              'spent': _spentAmount,
              'status': _getSpendingStatus(_spendingPercentage),
            },
          ),
        ),
      );
    }
  }

  String _getSpendingStatus(double percentage) {
    if (percentage < 0.25) return 'On Budget';
    if (percentage < 0.5) return 'Moderate Spending';
    if (percentage < 0.75) return 'High Spending';
    return 'Critical Spending';
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
                  'Site & Project Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Status Report',
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
      backgroundColor: const Color.fromARGB(255, 207, 226, 243),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: mainColor),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF1E1E2D),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _fetchProjectData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: mainColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: mainColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: mainColor.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: mainColor),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Select a project status below to view detailed site progress and status report.',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Icon(Icons.bar_chart, color: mainColor),
                                    const SizedBox(width: 8),
                                    _buildSectionTitle('Select Project Status *'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CustomDropdown<String>(
                                  hintText: 'Select Project Status',
                                  value: _selectedStatus,
                                  mainColor: mainColor,
                                  items: _statusOptions
                                      .map(
                                        (status) => DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E1E2D),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedStatus = newValue;
                                    });
                                  },
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: mainColor,
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed:
                                        (_selectedStatus == null || _statusOptions.isEmpty)
                                            ? null
                                            : _handleReport,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}