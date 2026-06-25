import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SiteLabourDetailsReportScreen extends StatefulWidget {
  const SiteLabourDetailsReportScreen({super.key});

  @override
  State<SiteLabourDetailsReportScreen> createState() =>
      _SiteLabourDetailsReportScreenState();
}

class _SiteLabourDetailsReportScreenState
    extends State<SiteLabourDetailsReportScreen> {
  // Color scheme based on base color #0b3470
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLightColor = const Color(0xFF1a4a8c);
  final Color primaryDarkColor = const Color(0xFF052356);
  final Color accentColor = const Color(0xFF4a86e8);
  final Color backgroundColor = const Color(0xFFf5f7fa);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2c3e50);
  final Color lightTextColor = const Color(0xFF7f8c8d);
  final Color successColor = const Color(0xFF27ae60);
  final Color warningColor = const Color(0xFFe67e22);
  final Color errorColor = const Color(0xFFe74c3c);

  // Filter variables
  DateTime? startDate;
  DateTime? endDate;
  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedSubContractorId;
  String? selectedLabourCategory;
  bool isLoading = false;

  // Summary variables
  int totalWorkers = 0;
  double totalLabourCost = 0.0;
  double totalOvertimeHours = 0.0;
  double totalAmount = 0.0;

  // Data variables
  List<Map<String, dynamic>> reportData = [];

  @override
  void initState() {
    super.initState();
    // Set default date range to current month
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = now;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Site Labour Details Report',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePDF,
            tooltip: 'Download PDF',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
            tooltip: 'Share Report',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters section
            _buildFiltersCard(),
            const SizedBox(height: 16),

            // Summary cards
            _buildSummaryCards(),
            const SizedBox(height: 16),

            // Generate report button
            _buildGenerateButton(),
            const SizedBox(height: 16),

            // Report data
            Expanded(child: _buildReportData()),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7f8c8d),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    'Start Date',
                    startDate,
                    (d) => setState(() => startDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDatePicker(
                    'End Date',
                    endDate,
                    (d) => setState(() => endDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSiteFilter()),
                const SizedBox(width: 12),
                Expanded(child: _buildSupervisorFilter()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSubContractorFilter()),
                const SizedBox(width: 12),
                Expanded(child: _buildLabourCategoryFilter()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime?) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor),
          ),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select date',
          style: TextStyle(color: date != null ? textColor : lightTextColor),
        ),
      ),
    );
  }

  Widget _buildSiteFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sites')
          .orderBy('siteName')
          .snapshots(),
      builder: (context, snapshot) {
        List<DropdownMenuItem<String>> items = [];
        if (snapshot.hasData) {
          items = snapshot.data!.docs.map((doc) {
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(doc['siteName'] ?? doc.id),
            );
          }).toList();
        }
        return DropdownButtonFormField<String>(
          value: selectedSiteId,
          hint: Text('Select Site', style: TextStyle(color: lightTextColor)),
          isExpanded: true,
          dropdownColor: cardColor,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Site',
            filled: true,
            fillColor: backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: items,
          onChanged: (value) => setState(() => selectedSiteId = value),
        );
      },
    );
  }

  Widget _buildSupervisorFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'supervisor')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        List<DropdownMenuItem<String>> items = [];
        if (snapshot.hasData) {
          items = snapshot.data!.docs.map((doc) {
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(doc['name'] ?? doc.id),
            );
          }).toList();
        }
        return DropdownButtonFormField<String>(
          value: selectedSupervisorId,
          hint: Text(
            'Select Supervisor',
            style: TextStyle(color: lightTextColor),
          ),
          isExpanded: true,
          dropdownColor: cardColor,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Supervisor',
            filled: true,
            fillColor: backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: items,
          onChanged: (value) => setState(() => selectedSupervisorId = value),
        );
      },
    );
  }

  Widget _buildSubContractorFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sub_contractors')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        List<DropdownMenuItem<String>> items = [];
        if (snapshot.hasData) {
          items = snapshot.data!.docs.map((doc) {
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(doc['name'] ?? doc.id),
            );
          }).toList();
        }
        return DropdownButtonFormField<String>(
          value: selectedSubContractorId,
          hint: Text(
            'Select Sub-Contractor',
            style: TextStyle(color: lightTextColor),
          ),
          isExpanded: true,
          dropdownColor: cardColor,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Sub-Contractor',
            filled: true,
            fillColor: backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: items,
          onChanged: (value) => setState(() => selectedSubContractorId = value),
        );
      },
    );
  }

  Widget _buildLabourCategoryFilter() {
    const categories = [
      'Mason',
      'Painter',
      'Helper',
      'Electrician',
      'Carpenter',
      'Plumber',
      'Welder',
      'Bar Bender',
      'Operator',
    ];
    return DropdownButtonFormField<String>(
      value: selectedLabourCategory,
      hint: Text('Select Category', style: TextStyle(color: lightTextColor)),
      isExpanded: true,
      dropdownColor: cardColor,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: 'Labour Category',
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: categories.map((String category) {
        return DropdownMenuItem<String>(value: category, child: Text(category));
      }).toList(),
      onChanged: (value) => setState(() => selectedLabourCategory = value),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Workers',
            value: '$totalWorkers',
            icon: Icons.people,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Labour Cost',
            value: '₹${totalLabourCost.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: lightTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _generateReport,
      icon: const Icon(Icons.summarize),
      label: const Text('GENERATE REPORT'),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => isLoading = true);

    try {
      // Build the query
      Query query = FirebaseFirestore.instance.collection('workers');

      if (selectedSiteId != null) {
        query = query.where('assignedSiteIds', arrayContains: selectedSiteId);
      }
      if (selectedSupervisorId != null) {
        query = query.where('supervisorId', isEqualTo: selectedSupervisorId);
      }
      if (selectedSubContractorId != null) {
        query = query.where(
          'subContractorId',
          isEqualTo: selectedSubContractorId,
        );
      }
      if (selectedLabourCategory != null) {
        query = query.where('workerType', isEqualTo: selectedLabourCategory);
      }

      final snapshot = await query.get();

      // Process the data
      final List<Map<String, dynamic>> data = [];
      int workersCount = 0;
      double labourCost = 0.0;

      for (final doc in snapshot.docs) {
        final workerData = doc.data() as Map<String, dynamic>;
        workersCount++;

        // Get attendance for this worker in date range
        if (startDate != null && endDate != null) {
          final attendanceQuery = await FirebaseFirestore.instance
              .collection('worker_attendance')
              .where('workerId', isEqualTo: workerData['workerId'])
              .where(
                'date',
                isGreaterThanOrEqualTo: startDate!.toIso8601String(),
              )
              .where('date', isLessThanOrEqualTo: endDate!.toIso8601String())
              .get();

          double totalWage = 0.0;
          double overtimeHours = 0.0;

          for (final attendance in attendanceQuery.docs) {
            final attData = attendance.data();
            totalWage += (attData['basicSalary'] as num?)?.toDouble() ?? 0.0;
            totalWage += (attData['overtimeSalary'] as num?)?.toDouble() ?? 0.0;
            overtimeHours +=
                (attData['overtimeHours'] as num?)?.toDouble() ?? 0.0;
          }

          labourCost += totalWage;

          data.add({
            'siteCode': workerData['assignedSiteIds']?.first ?? '-',
            'supervisorName': workerData['supervisorName'] ?? '-',
            'labourType': workerData['workerType'] ?? '-',
            'workerName': workerData['name'] ?? '-',
            'subContractorName': workerData['subContractorName'] ?? '-',
            'numberOfWorkers': 1,
            'overtimeHours': overtimeHours,
            'dailyWages': workerData['basicSalary'] ?? 0.0,
            'totalAmount': totalWage,
            'remarks': '',
          });
        }
      }

      setState(() {
        totalWorkers = workersCount;
        totalLabourCost = labourCost;
        reportData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Widget _buildReportData() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.summarize, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No data available. Please generate report.',
              style: TextStyle(color: lightTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Group data by site
    final groupedData = <String, List<Map<String, dynamic>>>{};
    for (final entry in reportData) {
      final site = entry['siteCode'] ?? 'Unknown';
      if (!groupedData.containsKey(site)) {
        groupedData[site] = [];
      }
      groupedData[site]!.add(entry);
    }

    return SingleChildScrollView(
      child: Column(
        children: groupedData.entries.map((siteEntry) {
          return _buildSiteSection(siteEntry.key, siteEntry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildSiteSection(
    String siteCode,
    List<Map<String, dynamic>> siteData,
  ) {
    // Calculate totals for this site
    int siteTotalWorkers = siteData.length;
    double siteTotalHours = 0.0;
    double siteTotalWage = 0.0;

    for (final entry in siteData) {
      siteTotalHours += entry['overtimeHours'] as double;
      siteTotalWage += entry['totalAmount'] as double;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Site Code: $siteCode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Data table for this site
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => primaryColor.withOpacity(0.05),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Supervisor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Labour Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Worker Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Sub-Contractor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Workers',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'OT Hours',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Daily Wage',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: siteData.map((data) {
                  return DataRow(
                    cells: [
                      DataCell(Text(data['supervisorName'])),
                      DataCell(Text(data['labourType'])),
                      DataCell(Text(data['workerName'])),
                      DataCell(Text(data['subContractorName'])),
                      DataCell(Text('${data['numberOfWorkers']}')),
                      DataCell(Text('${data['overtimeHours']}')),
                      DataCell(Text('₹${data['dailyWages']}')),
                      DataCell(Text('₹${data['totalAmount']}')),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Site totals
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    'Total Workers: $siteTotalWorkers',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total OT: $siteTotalHours',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Cost: ₹$siteTotalWage',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDF() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF generation coming soon!')),
    );
  }

  Future<void> _shareReport() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share report coming soon!')));
  }
}
