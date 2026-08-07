import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:excel_community/excel_community.dart' as excel;
import 'package:ideal_cst/utils/web_download_stub.dart'
    if (dart.library.html) 'package:ideal_cst/utils/web_download.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';
import 'package:ideal_cst/screens/organization/components/custom_table.dart';


class _GroupedRowItem {
  final int sNo;
  final String date;
  final String coordinator;
  final bool showCoordinator;
  final int coordinatorSpanCount;

  final String siteName;
  final bool showSiteName;
  final int siteSpanCount;
  final int siteTotalCount;

  final String supervisor;
  final bool showSupervisor;

  final String category;
  final String labourType;
  final String subcontractorName;
  final int labourCount;
  final String otStDetails;

  _GroupedRowItem({
    required this.sNo,
    required this.date,
    required this.coordinator,
    required this.showCoordinator,
    required this.coordinatorSpanCount,
    required this.siteName,
    required this.showSiteName,
    required this.siteSpanCount,
    required this.siteTotalCount,
    required this.supervisor,
    required this.showSupervisor,
    required this.category,
    required this.labourType,
    required this.subcontractorName,
    required this.labourCount,
    required this.otStDetails,
  });
}

class _ReportTotals {
  final int totalRecords;
  final int totalSubContractors;
  final int totalWorkers;
  final double totalBasicSalary;
  final double totalEarnedSalary;
  final double totalHours;
  final double totalOtSalaryBasic;
  final double totalOtHours;
  final double totalOtAmount;
  final double totalMealsExpense;
  final int totalMealsCount;
  final double totalMealsAmount;
  final double totalBusFare;
  final int totalBusCount;
  final double totalBusAmount;
  final double totalStdAmount;

  _ReportTotals({
    required this.totalRecords,
    required this.totalSubContractors,
    required this.totalWorkers,
    required this.totalBasicSalary,
    required this.totalEarnedSalary,
    required this.totalHours,
    required this.totalOtSalaryBasic,
    required this.totalOtHours,
    required this.totalOtAmount,
    required this.totalMealsExpense,
    required this.totalMealsCount,
    required this.totalMealsAmount,
    required this.totalBusFare,
    required this.totalBusCount,
    required this.totalBusAmount,
    required this.totalStdAmount,
  });

  factory _ReportTotals.fromRows(List<Map<String, dynamic>> rows) {
    int records = rows.length;
    Set<String> subs = {};
    int workers = 0;
    double basic = 0;
    double totalSal = 0;
    double hrs = 0;
    double otBasic = 0;
    double otHrs = 0;
    double otAmt = 0;
    double mealsExp = 0;
    int mealsCnt = 0;
    double mealsTotal = 0;
    double busFareVal = 0;
    int busCnt = 0;
    double busTotal = 0;
    double stdAmt = 0;

    for (final r in rows) {
      final sub = r['subContractor']?.toString();
      if (sub != null && sub.isNotEmpty && sub != '-') {
        subs.add(sub);
      }
      final wc = r['workerCount'];
      if (wc is int) {
        workers += wc;
      } else if (wc != null) {
        workers += int.tryParse(wc.toString()) ?? 1;
      } else {
        workers += 1;
      }

      basic += (r['salaryBasic'] as num? ?? 0).toDouble();
      final tot = (r['totalSalary'] as num? ?? 0).toDouble();
      totalSal += tot;
      hrs += (r['hours'] as num? ?? 0).toDouble();
      otBasic += (r['otSalaryBasic'] as num? ?? 0).toDouble();
      final ot = (r['otTotalAmount'] as num? ?? 0).toDouble();
      otHrs += (r['otHours'] as num? ?? 0).toDouble();
      otAmt += ot;
      mealsExp += (r['mealsExpense'] as num? ?? 0).toDouble();
      mealsCnt += (r['mealsCount'] as int? ?? 0);
      mealsTotal += (r['totalMealsAmount'] as num? ?? 0).toDouble();
      busFareVal += (r['busFare'] as num? ?? 0).toDouble();
      busCnt += (r['busCount'] as int? ?? 0);
      busTotal += (r['totalBusAmount'] as num? ?? 0).toDouble();
      stdAmt += (tot - ot);
    }

    return _ReportTotals(
      totalRecords: records,
      totalSubContractors: subs.length,
      totalWorkers: workers,
      totalBasicSalary: basic,
      totalEarnedSalary: totalSal,
      totalHours: hrs,
      totalOtSalaryBasic: otBasic,
      totalOtHours: otHrs,
      totalOtAmount: otAmt,
      totalMealsExpense: mealsExp,
      totalMealsCount: mealsCnt,
      totalMealsAmount: mealsTotal,
      totalBusFare: busFareVal,
      totalBusCount: busCnt,
      totalBusAmount: busTotal,
      totalStdAmount: stdAmt,
    );
  }
}

class ReceptionistSiteLabourReportsScreen extends StatefulWidget {
  const ReceptionistSiteLabourReportsScreen({super.key});

  @override
  State<ReceptionistSiteLabourReportsScreen> createState() => _ReceptionistSiteLabourReportsScreenState();
}

class _ReceptionistSiteLabourReportsScreenState extends State<ReceptionistSiteLabourReportsScreen> {

  String _formatOtStDetailsFromMap(Map<String, int> remarkMap) {
    if (remarkMap.isEmpty) return '-';
    final List<String> parts = [];
    remarkMap.forEach((remark, count) {
      final personText = count == 1 ? '1 Person' : '$count Persons';
      parts.add('$personText – $remark');
    });
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  List<_GroupedRowItem> _computeGroupedReportItems(List<Map<String, dynamic>> rawRows) {
    if (rawRows.isEmpty) return [];

    final Map<String, Map<String, Map<String, Map<String, dynamic>>>> hierarchy = {};

    for (final r in rawRows) {
      final coordinator = (r['coordinatorName'] ?? r['coordinator'] ?? 'Unassigned').toString().trim();
      final siteName = _cleanSiteName(r['siteName']?.toString() ?? r['siteId']?.toString() ?? 'Unassigned');
      final supervisor = (r['supervisorName'] ?? r['supervisor'] ?? '-').toString().trim();
      final category = (r['category'] ?? '-').toString().trim();

      final subContractor = (r['subContractor'] ?? r['contractorName'] ?? '-').toString().trim();
      final rawLt = (r['labourType'] ?? r['group'] ?? '').toString().trim();
      final isSc = rawLt.toLowerCase().contains('sub') || rawLt.toLowerCase() == 'sc' || (subContractor.isNotEmpty && subContractor != '-');
      final labourType = isSc ? 'SC' : 'DW';

      final date = _formatDate(r['date']?.toString());
      final workerCount = (r['labourCount'] as num? ?? r['workerCount'] as num? ?? 1).toInt();

      String remarkText = (r['remarks']?.toString() ?? '').trim();
      if (remarkText.isEmpty || remarkText == '-') {
        remarkText = _otDetailsString(r);
        if (remarkText == '-') remarkText = '';
      }

      final rowKey = '$date|$supervisor|$category|$labourType|$subContractor';

      hierarchy.putIfAbsent(coordinator, () => {});
      hierarchy[coordinator]!.putIfAbsent(siteName, () => {});

      final siteRows = hierarchy[coordinator]![siteName]!;
      if (!siteRows.containsKey(rowKey)) {
        siteRows[rowKey] = {
          'date': date,
          'coordinator': coordinator,
          'siteName': siteName,
          'supervisor': supervisor,
          'category': category,
          'labourType': labourType,
          'subcontractorName': subContractor,
          'labourCount': 0,
          'remarkMap': <String, int>{},
        };
      }

      siteRows[rowKey]!['labourCount'] = (siteRows[rowKey]!['labourCount'] as int) + workerCount;

      if (remarkText.isNotEmpty && remarkText != '-') {
        final Map<String, int> rMap = siteRows[rowKey]!['remarkMap'] as Map<String, int>;
        rMap[remarkText] = (rMap[remarkText] ?? 0) + workerCount;
      }
    }

    final List<_GroupedRowItem> result = [];
    int sNoCounter = 1;

    final sortedCoordinators = hierarchy.keys.toList()..sort();
    for (final coord in sortedCoordinators) {
      final sitesMap = hierarchy[coord]!;
      final sortedSites = sitesMap.keys.toList()..sort();

      int coordTotalRows = 0;
      for (final sName in sortedSites) {
        coordTotalRows += sitesMap[sName]!.length;
      }

      bool isFirstRowOfCoord = true;

      for (final sName in sortedSites) {
        final rowsMap = sitesMap[sName]!;
        final rowItemsList = rowsMap.values.toList();

        rowItemsList.sort((a, b) {
          final dComp = (a['date'] as String).compareTo(b['date'] as String);
          if (dComp != 0) return dComp;
          final supComp = (a['supervisor'] as String).compareTo(b['supervisor'] as String);
          if (supComp != 0) return supComp;
          final cComp = (a['category'] as String).compareTo(b['category'] as String);
          if (cComp != 0) return cComp;
          final ltComp = (a['labourType'] as String).compareTo(b['labourType'] as String);
          if (ltComp != 0) return ltComp;
          return (a['subcontractorName'] as String).compareTo(b['subcontractorName'] as String);
        });

        int siteTotalCount = 0;
        for (final item in rowItemsList) {
          siteTotalCount += (item['labourCount'] as int);
        }

        bool isFirstRowOfSite = true;
        String currentSupName = '';

        for (final item in rowItemsList) {
          final supName = item['supervisor'] as String;
          final isFirstRowOfSup = (supName != currentSupName) || isFirstRowOfSite;
          if (isFirstRowOfSup) currentSupName = supName;

          final rMap = item['remarkMap'] as Map<String, int>;
          final formattedOtDetails = _formatOtStDetailsFromMap(rMap);

          result.add(_GroupedRowItem(
            sNo: sNoCounter++,
            date: item['date'] as String,
            coordinator: coord,
            showCoordinator: isFirstRowOfCoord,
            coordinatorSpanCount: coordTotalRows,
            siteName: sName,
            showSiteName: isFirstRowOfSite,
            siteSpanCount: rowItemsList.length,
            siteTotalCount: siteTotalCount,
            supervisor: supName,
            showSupervisor: isFirstRowOfSup,
            category: item['category'] as String,
            labourType: item['labourType'] as String,
            subcontractorName: item['subcontractorName'] as String,
            labourCount: item['labourCount'] as int,
            otStDetails: formattedOtDetails,
          ));

          isFirstRowOfCoord = false;
          isFirstRowOfSite = false;
        }
      }
    }

    return result;
  }

  Widget _buildGroupedLabourReportTable(List<Map<String, dynamic>> rawRows) {
    final groupedItems = _computeGroupedReportItems(rawRows);
    if (groupedItems.isEmpty) return _buildEmptyState();

    int grandTotalLabour = 0;
    for (final item in groupedItems) {
      grandTotalLabour += item.labourCount;
    }

    final Map<String, int> ctBreakdown = {};
    for (final item in groupedItems) {
      final ct = item.category.trim();
      if (ct.isNotEmpty && ct != '-') {
        ctBreakdown[ct] = (ctBreakdown[ct] ?? 0) + item.labourCount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTable<_GroupedRowItem>(
          data: groupedItems,
          mainColor: primaryColor,
          showTotalsRow: true,
          defaultRowsPerPage: 25,
          availableRowsPerPage: const [10, 25, 50, 100],
          columns: [
            CustomTableColumn<_GroupedRowItem>(
              header: 'S.No',
              cellBuilder: (item, index) => Text('${item.sNo}', style: const TextStyle(fontSize: 12)),
              totalCellBuilder: () => Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Date',
              cellBuilder: (item, index) => Text(item.date, style: const TextStyle(fontSize: 12)),
              totalCellBuilder: () => Text('${groupedItems.length} Rows', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Coordinator',
              cellBuilder: (item, index) => Text(
                item.showCoordinator ? item.coordinator : '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: item.showCoordinator ? FontWeight.bold : FontWeight.normal,
                  color: primaryColor,
                ),
              ),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Site Name',
              cellBuilder: (item, index) => Text(
                item.showSiteName ? item.siteName : '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: item.showSiteName ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Supervisor',
              cellBuilder: (item, index) => Text(
                item.showSupervisor ? item.supervisor : '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: item.showSupervisor ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'CT',
              cellBuilder: (item, index) => Text(item.category, style: const TextStyle(fontSize: 12)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'LT',
              cellBuilder: (item, index) => Text(item.labourType, style: const TextStyle(fontSize: 12)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Subcontractor Name',
              cellBuilder: (item, index) => Text(item.subcontractorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Nos',
              cellBuilder: (item, index) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.labourCount}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
              totalCellBuilder: () => Text('$grandTotalLabour', style: TextStyle(fontWeight: FontWeight.w900, color: primaryColor, fontSize: 13)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'Total',
              cellBuilder: (item, index) => Text(
                item.showSiteName ? '${item.siteTotalCount}' : '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D)),
              ),
              totalCellBuilder: () => Text('$grandTotalLabour', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            CustomTableColumn<_GroupedRowItem>(
              header: 'OT / ST Details',
              cellBuilder: (item, index) => Text(
                item.otStDetails,
                style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)),
              ),
            ),
          ],
        ),
        if (ctBreakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Category (CT) Count Summary',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ctBreakdown.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${entry.key} - ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            TextSpan(
                              text: '${entry.value}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Colors & Design
  final Color primaryColor = const Color(0xFFD84315);
  final Color primaryLight = const Color(0xFFE64A19);
  final Color accentColor = const Color(0xFF4a86e8);
  final Color bgColor = const Color(0xFFFFF3E0);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF1E1E2D);
  final Color mutedColor = const Color(0xFF64748b);
  final Color successColor = const Color(0xFF16a34a);
  final Color errorColor = const Color(0xFFdc2626);

  // List of report types
  final List<String> reportTypes = [
    'Site Labour Report',
    'Site Labour Details Report',
    'Daily Wage Report',
    'Sub Contractor Report',
    'Worker on Site Report',
    'Sub Contractor Bill Report',
  ];
  String selectedReportType = 'Site Labour Report';

  // Filters State
  String selectedDateFilter = 'Today';
  DateTime? startDate;
  DateTime? endDate;
  String? selectedSiteId;
  String? selectedSiteName;
  String? selectedSupervisorName;
  String? selectedCoordinatorName;
  String? selectedSubContractorName;
  String? selectedLabourType = 'All';

  // Bill Details for exports
  final TextEditingController _billNoController = TextEditingController(text: 'BILL-2026-001');
  final TextEditingController _workTypeController = TextEditingController(text: 'Contract Work');
  final TextEditingController _narrationController = TextEditingController(text: 'Outer back side plastering work (Maintenance) courtyard glass cutting work');

  // Dropdown list data
  List<_DropdownOption> siteOptions = [];
  List<_DropdownOption> supervisorOptions = [];
  List<_DropdownOption> coordinatorOptions = [];
  List<_DropdownOption> contractorOptions = [];

  bool isLoadingFilters = true;
  bool isLoading = false;
  bool reportGenerated = false;
  bool showFilters = true;
  String searchQuery = '';

  // Processed Report Data
  List<Map<String, dynamic>> reportData = []; // Flat rows of daily entries
  List<_SiteGroup> siteGroups = []; // For grouped layout in attendance report
  List<Map<String, dynamic>> billGroupedData = []; // Grouped subcontractor billing data
  
  // Overall Summary Metrics
  int totalWorkers = 0;
  double totalLabourCost = 0.0;
  double totalMealsAmount = 0.0;
  int totalMealsCount = 0;
  double totalBusAmount = 0.0;
  int totalBusCount = 0;

  @override
  void initState() {
    super.initState();
    selectedDateFilter = 'Today';
    _applyDatePreset('Today', triggerReport: false);
    _loadFilterData().then((_) {
      _generateReport();
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    final dt = DateTime.tryParse(raw);
    if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      final parts = raw.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return raw;
  }

  String _toComparableDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '9999-99-99';
    final trimmed = raw.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(trimmed)) {
      final parts = trimmed.split('/');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    final dt = DateTime.tryParse(trimmed);
    if (dt != null) {
      return DateFormat('yyyy-MM-dd').format(dt);
    }
    return trimmed;
  }

  String _cleanSiteName(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == '-') return '-';
    var cleaned = raw.trim();

    // 1. Remove STxxx_ prefix at the beginning (e.g. ST013_, ST061_, ST001_)
    cleaned = cleaned.replaceFirst(RegExp(r'^ST\d+_', caseSensitive: false), '');

    // 2. Remove _SPxxx_... suffix at the end (e.g. _SP004_Kanish, _SP021_KK)
    cleaned = cleaned.replaceFirst(RegExp(r'_SP\d+.*$', caseSensitive: false), '');

    return cleaned.isNotEmpty ? cleaned : raw;
  }

  void _applyDatePreset(String preset, {bool triggerReport = true}) {
    final now = DateTime.now();
    DateTime? newStart;
    DateTime? newEnd;

    switch (preset) {
      case 'Today':
        newStart = DateTime(now.year, now.month, now.day);
        newEnd = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        newStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
        newEnd = DateTime(yesterday.year, yesterday.month, yesterday.day);
        break;
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        newStart = DateTime(monday.year, monday.month, monday.day);
        newEnd = DateTime(sunday.year, sunday.month, sunday.day);
        break;
      case 'This Month':
        newStart = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        newEnd = DateTime(now.year, now.month, lastDay.day);
        break;
      case 'This Year':
        newStart = DateTime(now.year, 1, 1);
        newEnd = DateTime(now.year, 12, 31);
        break;
      case 'Custom':
        newStart = startDate ?? DateTime(now.year, now.month, now.day);
        newEnd = endDate ?? DateTime(now.year, now.month, now.day);
        break;
    }

    setState(() {
      selectedDateFilter = preset;
      if (preset != 'Custom') {
        startDate = newStart;
        endDate = newEnd;
      }
    });

    if (triggerReport) {
      _generateReport();
    }
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _workTypeController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  // Load Dropdown Options dynamically from attendance entries
  Future<void> _loadFilterData() async {
    await _generateReport();
  }

  Future<List<_DropdownOption>> _fetchSites() async {
    final snap = await FirebaseFirestore.instance
        .collection('Site')
        .orderBy('siteName')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return _DropdownOption(
        id: d.id,
        label: data['siteName']?.toString() ?? d.id,
      );
    }).toList();
  }

  Future<List<_DropdownOption>> _fetchSupervisors() async {
    final snap = await FirebaseFirestore.instance
        .collection('siteSupervisorMap')
        .get();
    final names = <String>{};
    for (final doc in snap.docs) {
      final name = doc.data()['supervisor']?.toString();
      if (name != null && name.trim().isNotEmpty) names.add(name.trim());
    }
    final sorted = names.toList()..sort();
    return sorted.map((n) => _DropdownOption(id: n, label: n)).toList();
  }

  Future<List<_DropdownOption>> _fetchCoordinators() async {
    final names = <String>{};
    try {
      final snap1 = await FirebaseFirestore.instance.collection('Site_Co-ordinator').get();
      for (final doc in snap1.docs) {
        final name = doc.data()['coordinatorName']?.toString();
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    } catch (_) {}
    try {
      final snap2 = await FirebaseFirestore.instance.collection('supervisor').get();
      for (final doc in snap2.docs) {
        final name = doc.data()['CoordinatorName']?.toString();
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    } catch (_) {}
    try {
      final snap3 = await FirebaseFirestore.instance.collection('daily_labour_entries').limit(200).get();
      for (final doc in snap3.docs) {
        final data = doc.data();
        final name = data['coordinatorName']?.toString() ?? data['coordinator']?.toString();
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    } catch (_) {}
    final sorted = names.toList()..sort();
    return sorted.map((n) => _DropdownOption(id: n, label: n)).toList();
  }

  Future<List<_DropdownOption>> _fetchContractors() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('contractors').get(),
      FirebaseFirestore.instance.collection('sub_contractors').get(),
    ]);
    final names = <String>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['contractorName'] ?? data['name'])?.toString();
        if (name != null && name.trim().isNotEmpty) names.add(name.trim());
      }
    }
    final sorted = names.toList()..sort();
    return sorted.map((n) => _DropdownOption(id: n, label: n)).toList();
  }

  void _resetFilters() {
    setState(() {
      selectedDateFilter = 'Today';
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day);
      selectedSiteId = null;
      selectedSiteName = null;
      selectedSupervisorName = null;
      selectedCoordinatorName = null;
      selectedSubContractorName = null;
      selectedLabourType = 'All';
      searchQuery = '';
    });
    _generateReport();
  }

  DateTime? _parseAnyDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    final str = raw.toString().trim();
    if (str.isEmpty || str == '-') return null;
    final tryIso = DateTime.tryParse(str);
    if (tryIso != null) return tryIso;
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(str)) {
      try {
        final parts = str.split('/');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (_) {}
    }
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(str)) {
      try {
        final parts = str.split('-');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (_) {}
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
      try {
        final parts = str.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } catch (_) {}
    }
    return null;
  }

  bool _isDateInRange(dynamic rawDate, DateTime? start, DateTime? end) {
    if (start == null && end == null) return true;
    final dt = _parseAnyDate(rawDate);
    if (dt == null) return true;

    final dayStart = start != null
        ? DateTime(start.year, start.month, start.day, 0, 0, 0)
        : DateTime(2000);
    final dayEnd = end != null
        ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
        : DateTime(2100);

    return !dt.isBefore(dayStart) && !dt.isAfter(dayEnd);
  }

  // Unified Query logic — new structure: workers subcollection
  Future<void> _generateReport() async {
    setState(() {
      isLoading = true;
      reportGenerated = true;
    });

    try {
      // ── Step 1: Query parent documents from daily_labour_entries & attendance ──────
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('daily_labour_entries').get(),
        FirebaseFirestore.instance.collection('attendance').get(),
        FirebaseFirestore.instance.collection('Site_Co-ordinator').get(),
        FirebaseFirestore.instance.collection('supervisor').get(),
        FirebaseFirestore.instance.collection('siteSupervisorMap').get(),
      ]);

      final dailyEntriesSnap = results[0];
      final attendanceSnap = results[1];
      final siteCoordinatorSnap = results[2];
      final supervisorSnap = results[3];
      final siteSupervisorMapSnap = results[4];

      // Merge parent documents by document ID
      final parentDocsMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in dailyEntriesSnap.docs) {
        parentDocsMap[doc.id] = doc;
      }
      for (final doc in attendanceSnap.docs) {
        if (!parentDocsMap.containsKey(doc.id)) {
          parentDocsMap[doc.id] = doc;
        }
      }

      // Build fallback lookup maps
      final siteToCoordinator = <String, String>{};
      final supervisorToCoordinator = <String, String>{};

      for (final doc in siteCoordinatorSnap.docs) {
        final data = doc.data();
        final sName = data['siteName']?.toString().trim();
        final supName = data['supervisorName']?.toString().trim();
        final cName = data['coordinatorName']?.toString().trim();
        if (cName != null && cName.isNotEmpty) {
          if (sName != null && sName.isNotEmpty) {
            siteToCoordinator[sName.toLowerCase()] = cName;
          }
          if (supName != null && supName.isNotEmpty) {
            supervisorToCoordinator[supName.toLowerCase()] = cName;
          }
        }
      }

      for (final doc in supervisorSnap.docs) {
        final data = doc.data();
        final userName = (data['UserName'] ?? data['supervisorName'] ?? data['name'])?.toString().trim();
        final cName = data['CoordinatorName']?.toString().trim();
        if (cName != null && cName.isNotEmpty && userName != null && userName.isNotEmpty) {
          supervisorToCoordinator[userName.toLowerCase()] = cName;
        }
      }

      for (final doc in siteSupervisorMapSnap.docs) {
        final data = doc.data();
        final siteId = (data['siteId'] ?? doc.id)?.toString().trim();
        final supName = data['supervisor']?.toString().trim();
        if (siteId != null && supName != null && supervisorToCoordinator.containsKey(supName.toLowerCase())) {
          siteToCoordinator[siteId.toLowerCase()] = supervisorToCoordinator[supName.toLowerCase()]!;
        }
      }



      // ── Step 2: Fetch flat worker entries for selected Date Range ───────
      final List<Map<String, dynamic>> dateMatchingEntries = [];

      await Future.wait(parentDocsMap.values.map((parentDoc) async {
        final parentData = Map<String, dynamic>.from(parentDoc.data() ?? {});
        final parentDocId = parentDoc.id;

        // Shared metadata from the parent document
        final parentSiteId   = parentData['siteId']?.toString() ?? '-';
        final parentSiteName = parentData['siteName']?.toString() ?? '-';
        final parentDate     = parentData['date']?.toString() ?? '-';
        final parentSupervisor =
            parentData['supervisorName']?.toString() ?? parentData['supervisor']?.toString() ?? '-';

        // 1. Date Range Filter Check
        if (!_isDateInRange(parentDate, startDate, endDate)) {
          return;
        }

        final docCoord = parentData['coordinatorName']?.toString() ??
            parentData['coordinator']?.toString() ??
            parentData['CoordinatorName']?.toString();
        final parentCoordinator = (docCoord != null &&
                docCoord.trim().isNotEmpty &&
                docCoord.trim() != '-')
            ? docCoord.trim()
            : (siteToCoordinator[parentSiteId.toLowerCase()] ??
                siteToCoordinator[parentSiteName.toLowerCase()] ??
                supervisorToCoordinator[parentSupervisor.toLowerCase()] ??
                '-');

        // Fetch workers subcollection from daily_labour_entries
        var workersSnap = await FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc(parentDocId)
            .collection('workers')
            .get();

        // Fallback to attendance subcollection
        if (workersSnap.docs.isEmpty) {
          workersSnap = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(parentDocId)
              .collection('workers')
              .get();
        }

        if (workersSnap.docs.isEmpty) {
          final hasWorkerName = parentData.containsKey('workerName') || parentData.containsKey('name');
          if (hasWorkerName) {
            dateMatchingEntries.add({
              'siteId':          parentSiteId,
              'siteName':        parentSiteName,
              'date':            parentDate,
              'coordinatorName': parentCoordinator,
              'workerName':      parentData['workerName']?.toString() ?? parentData['name']?.toString() ?? '-',
              'contractorName':  parentData['contractor']?.toString() ?? parentData['contractorName']?.toString() ?? parentData['subContractor']?.toString() ?? '-',
              'category':        parentData['category']?.toString() ?? '-',
              'labourType':      parentData['labourType']?.toString() ?? parentData['salaryType']?.toString() ?? '',
              'basicSalary':     parentData['basicSalary'] ?? parentData['salaryBasic'] ?? parentData['salary'] ?? parentData['rate'],
              'hoursWorked':     parentData['hoursWorked'] ?? parentData['hours'],
              'otHours':         parentData['overtimeHours'] ?? parentData['otHours'],
              'overtimeAmount':  parentData['overtimeAmount'] ?? parentData['otAmount'],
              'mealsCount':      parentData['mealsCount'],
              'mealsAmount':     parentData['mealsAmount'] ?? parentData['mealsExpense'],
              'busCount':        parentData['busCount'],
              'busAmount':       parentData['busAmount'] ?? parentData['busFare'],
              'attendanceType':  parentData['attendanceType'] ?? parentData['attendance'] ?? 'Full Day',
              'supervisorName':  parentData['supervisorName']?.toString() ?? parentSupervisor,
              'remarks':         parentData['remarks'] ?? '',
              'defaultHours':    parentData['defaultHours'],
              'contractorId':    parentData['contractorId'],
              '_docId':          parentDocId,
              '_parentDocId':    parentDocId,
            });
          }
          return;
        }

        for (final workerDoc in workersSnap.docs) {
          final wData = Map<String, dynamic>.from(workerDoc.data());
          final wCoord = wData['coordinatorName']?.toString() ?? wData['coordinator']?.toString();
          final effectiveCoord = (wCoord != null && wCoord.trim().isNotEmpty && wCoord.trim() != '-')
              ? wCoord.trim()
              : parentCoordinator;

          dateMatchingEntries.add({
            'siteId':          parentSiteId,
            'siteName':        parentSiteName,
            'date':            parentDate,
            'coordinatorName': effectiveCoord,
            'workerName':         wData['workerName']?.toString() ?? wData['name']?.toString() ?? '-',
            'contractorName':     wData['contractor']?.toString() ?? wData['contractorName']?.toString() ?? wData['subContractor']?.toString() ?? '-',
            'category':           wData['category']?.toString() ?? '-',
            'labourType':         wData['labourType']?.toString() ?? wData['salaryType']?.toString() ?? '',
            'basicSalary':        wData['basicSalary'] ?? wData['salaryBasic'] ?? wData['salary'] ?? wData['rate'],
            'hoursWorked':        wData['hoursWorked'] ?? wData['hours'],
            'otHours':            wData['overtimeHours'] ?? wData['otHours'],
            'overtimeAmount':     wData['overtimeAmount'] ?? wData['otAmount'],
            'mealsCount':         wData['mealsCount'],
            'mealsAmount':        wData['mealsAmount'] ?? wData['mealsExpense'],
            'busCount':           wData['busCount'],
            'busAmount':          wData['busAmount'] ?? wData['busFare'],
            'attendanceType':     wData['attendanceType'] ?? wData['attendance'] ?? 'Full Day',
            'supervisorName':     wData['supervisorName']?.toString() ?? parentSupervisor,
            'remarks':            wData['remarks'] ?? '',
            'defaultHours':       wData['defaultHours'] ?? parentData['defaultHours'],
            'contractorId':       wData['contractorId'],
            '_docId':             workerDoc.id,
            '_parentDocId':       parentDocId,
          });
        }
      }));

      // Sort dateMatchingEntries orderwise: Date ascending -> Coordinator -> Site -> Supervisor -> SubContractor -> Worker
      dateMatchingEntries.sort((a, b) {
        final dateA = _toComparableDate(a['date']?.toString());
        final dateB = _toComparableDate(b['date']?.toString());
        final cDate = dateA.compareTo(dateB);
        if (cDate != 0) return cDate;

        final coordA = (a['coordinatorName'] ?? a['coordinator'] ?? '').toString();
        final coordB = (b['coordinatorName'] ?? b['coordinator'] ?? '').toString();
        final cCoord = coordA.compareTo(coordB);
        if (cCoord != 0) return cCoord;

        final siteA = (a['siteName'] ?? a['siteId'] ?? '').toString();
        final siteB = (b['siteName'] ?? b['siteId'] ?? '').toString();
        final cSite = siteA.compareTo(siteB);
        if (cSite != 0) return cSite;

        final supA = (a['supervisorName'] ?? a['supervisor'] ?? '').toString();
        final supB = (b['supervisorName'] ?? b['supervisor'] ?? '').toString();
        final cSup = supA.compareTo(supB);
        if (cSup != 0) return cSup;

        final subA = (a['contractorName'] ?? a['subContractor'] ?? '').toString();
        final subB = (b['contractorName'] ?? b['subContractor'] ?? '').toString();
        final cSub = subA.compareTo(subB);
        if (cSub != 0) return cSub;

        final wA = (a['workerName'] ?? '').toString();
        final wB = (b['workerName'] ?? '').toString();
        return wA.compareTo(wB);
      });

      // ── Step 3: Compute Dynamic Dependent Filter Dropdown Options ──────────

      // 3a. Site Options: Sites present in dateMatchingEntries
      final Map<String, String> siteMap = {};
      for (final e in dateMatchingEntries) {
        final sId = e['siteId']?.toString().trim() ?? '';
        final sName = e['siteName']?.toString().trim() ?? '';
        final key = sId.isNotEmpty && sId != '-' ? sId : sName;
        final label = _cleanSiteName(sName.isNotEmpty && sName != '-' ? sName : sId);
        if (key.isNotEmpty && key != '-') {
          siteMap[key] = label;
        }
      }
      final newSiteOptions = siteMap.entries.map((kv) => _DropdownOption(id: kv.key, label: kv.value)).toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (selectedSiteId != null && !newSiteOptions.any((opt) => opt.id == selectedSiteId)) {
        selectedSiteId = null;
        selectedSiteName = null;
      }

      // 3b. Supervisor Options: Supervisors present for selected date & selected site
      List<Map<String, dynamic>> siteFilteredEntries = dateMatchingEntries;
      if (selectedSiteId != null) {
        final selId = selectedSiteId!.toLowerCase().trim();
        final selLabel = (selectedSiteName ?? selectedSiteId!).toLowerCase().trim();
        siteFilteredEntries = siteFilteredEntries.where((e) {
          final pSiteId = (e['siteId'] ?? '').toString().toLowerCase().trim();
          final pSiteName = (e['siteName'] ?? '').toString().toLowerCase().trim();
          return pSiteId == selId || pSiteName == selId || pSiteId == selLabel || pSiteName == selLabel || pSiteName.contains(selId) || pSiteName.contains(selLabel);
        }).toList();
      }

      final Set<String> uniqueSupervisors = {};
      for (final e in siteFilteredEntries) {
        final sup = (e['supervisorName'] ?? e['supervisor'])?.toString().trim();
        if (sup != null && sup.isNotEmpty && sup != '-') {
          uniqueSupervisors.add(sup);
        }
      }
      final newSupervisorOptions = uniqueSupervisors.map((s) => _DropdownOption(id: s, label: s)).toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (selectedSupervisorName != null && !newSupervisorOptions.any((opt) => opt.id == selectedSupervisorName)) {
        selectedSupervisorName = null;
      }

      // 3c. Coordinator Options: Coordinators present for selected date, site & supervisor
      List<Map<String, dynamic>> supFilteredEntries = siteFilteredEntries;
      if (selectedSupervisorName != null && selectedSupervisorName!.isNotEmpty) {
        final selSup = selectedSupervisorName!.toLowerCase().trim();
        supFilteredEntries = supFilteredEntries.where((e) {
          final sup = (e['supervisorName'] ?? e['supervisor'] ?? '').toString().toLowerCase().trim();
          return sup == selSup || sup.contains(selSup) || selSup.contains(sup);
        }).toList();
      }

      final Set<String> uniqueCoordinators = {};
      for (final e in supFilteredEntries) {
        final c = (e['coordinatorName'] ?? e['coordinator'])?.toString().trim();
        if (c != null && c.isNotEmpty && c != '-') {
          uniqueCoordinators.add(c);
        }
      }
      final newCoordinatorOptions = uniqueCoordinators.map((c) => _DropdownOption(id: c, label: c)).toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (selectedCoordinatorName != null && !newCoordinatorOptions.any((opt) => opt.id == selectedCoordinatorName)) {
        selectedCoordinatorName = null;
      }

      // 3d. Sub Contractor Options: Contractors present for selected date, site, supervisor & coordinator
      List<Map<String, dynamic>> coordFilteredEntries = supFilteredEntries;
      if (selectedCoordinatorName != null && selectedCoordinatorName!.isNotEmpty) {
        final selCoord = selectedCoordinatorName!.toLowerCase().trim();
        coordFilteredEntries = coordFilteredEntries.where((e) {
          final c = (e['coordinatorName'] ?? e['coordinator'])?.toString().trim().toLowerCase() ?? '';
          return c == selCoord || c.contains(selCoord) || selCoord.contains(c);
        }).toList();
      }

      final Set<String> uniqueContractors = {};
      for (final e in coordFilteredEntries) {
        final sc = (e['contractorName'] ?? e['subContractor'])?.toString().trim();
        if (sc != null && sc.isNotEmpty && sc != '-') {
          uniqueContractors.add(sc);
        }
      }
      final newContractorOptions = uniqueContractors.map((sc) => _DropdownOption(id: sc, label: sc)).toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (selectedSubContractorName != null && !newContractorOptions.any((opt) => opt.id == selectedSubContractorName)) {
        selectedSubContractorName = null;
      }

      // Update dropdown options
      siteOptions = newSiteOptions;
      supervisorOptions = newSupervisorOptions;
      coordinatorOptions = newCoordinatorOptions;
      contractorOptions = newContractorOptions;

      // ── Step 4: Final filtering on entries for report display ──────────────
      List<Map<String, dynamic>> entries = coordFilteredEntries;

      if (selectedSubContractorName != null && selectedSubContractorName!.isNotEmpty) {
        final selSub = selectedSubContractorName!.toLowerCase().trim();
        entries = entries.where((e) {
          final sc = (e['contractorName'] ?? e['subContractor'] ?? '').toString().trim().toLowerCase();
          return sc == selSub || sc.contains(selSub) || selSub.contains(sc);
        }).toList();
      }
      if (selectedLabourType != null && selectedLabourType != 'All') {
        entries = entries.where((e) {
          final lt = (e['labourType'])?.toString().trim().toLowerCase() ?? '';
          final isDW = lt == 'dw' || lt.contains('daily') || lt == 'daily wage';
          if (selectedLabourType == 'Daily Wage (DW)') return isDW;
          if (selectedLabourType == 'Sub Contractor (SC)') return !isDW;
          return true;
        }).toList();
      }

      // ── Step 5: Fetch sub_contractors for salary fallback mapping ─────────
      final subContractorsSnap =
          await FirebaseFirestore.instance.collection('sub_contractors').get();
      final subContractorSalaryById = <String, double>{};
      final subContractorSalaryByName = <String, double>{};
      for (final doc in subContractorsSnap.docs) {
        final data = doc.data();
        final salary = data['salaryRate'] ?? data['basicSalary'] ?? data['salary'];
        final salaryValue =
            salary is num ? salary.toDouble() : double.tryParse(salary?.toString() ?? '') ?? 0.0;
        final name = (data['name'] ?? data['contractorName'])?.toString().trim();
        final contractorId = data['contractorId']?.toString().trim();
        subContractorSalaryById[doc.id] = salaryValue;
        if (contractorId != null && contractorId.isNotEmpty) {
          subContractorSalaryById[contractorId] = salaryValue;
        }
        if (name != null && name.isNotEmpty) {
          subContractorSalaryByName[name.toLowerCase()] = salaryValue;
        }
      }

      // ── Step 6: Build report rows ─────────────────────────────────────────
      _processReportData(entries, subContractorSalaryById, subContractorSalaryByName);

      setState(() {
        isLoading = false;
        isLoadingFilters = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isLoadingFilters = false;
      });
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

  void _processReportData(
    List<Map<String, dynamic>> entries,
    Map<String, double> subContractorSalaryById,
    Map<String, double> subContractorSalaryByName,
  ) {
    // Each entry in [entries] is already a flat worker-level map produced by
    // _generateReport() merging the parent document metadata with the worker
    // subcollection document. We only need to compute derived fields here.
    final List<Map<String, dynamic>> rows = [];

    for (final e in entries) {
      final siteId   = e['siteId']?.toString() ?? '-';
      final siteName = e['siteName']?.toString() ?? '-';
      final date     = e['date']?.toString() ?? '-';

      // ── Contractor / group ──────────────────────────────────────────────
      final subContractor =
          (e['contractorName'] ?? '-').toString().trim();
      final labourType =
          (e['labourType'])?.toString().trim().toLowerCase() ?? '';
      final isDW = labourType == 'dw' || labourType.contains('daily');
      final group = isDW ? 'DW' : 'SC';

      // ── Worker identity ─────────────────────────────────────────────────
      final workerName = e['workerName']?.toString() ?? '-';
      final category   = e['category']?.toString() ?? '-';

      // ── Basic Salary ────────────────────────────────────────────────────
      // Priority: worker's own basicSalary → sub_contractors fallback.
      final rawSalary = e['basicSalary'];
      final entrySalaryBasic = rawSalary is num
          ? rawSalary.toDouble()
          : double.tryParse(rawSalary?.toString() ?? '') ?? 0.0;

      final subContractorSalary = group == 'SC'
          ? (subContractorSalaryById[e['contractorId']?.toString()] ??
              subContractorSalaryByName[subContractor.toLowerCase()] ??
              0.0)
          : 0.0;

      final salaryBasic = entrySalaryBasic > 0
          ? entrySalaryBasic
          : (group == 'SC' && subContractorSalary > 0 ? subContractorSalary : 0.0);

      // ── Hours worked ────────────────────────────────────────────────────
      final rawHours = e['hoursWorked'];
      final hoursWorked = rawHours is num
          ? rawHours.toDouble()
          : double.tryParse(rawHours?.toString() ?? '') ?? 0.0;

      // ── OT Hours ────────────────────────────────────────────────────────
      final rawOtHours = e['otHours'];
      final doubleOtHours = rawOtHours is num
          ? rawOtHours.toDouble()
          : double.tryParse(
                  rawOtHours?.toString().split(' ').first ?? '') ??
              0.0;

      // ── Default / basic hours computation ───────────────────────────────
      final rawDefaultHrs = e['defaultHours'];
      final defaultHrs = rawDefaultHrs is num
          ? rawDefaultHrs.toDouble()
          : double.tryParse(rawDefaultHrs?.toString() ?? '') ?? 8.0;

      double basicHours;
      if (e['isHeaderOnly'] == true) {
        basicHours = 0.0;
      } else if (hoursWorked > doubleOtHours) {
        basicHours = hoursWorked - doubleOtHours;
      } else if (hoursWorked > 0) {
        basicHours = hoursWorked;
      } else {
        final att = e['attendanceType']?.toString() ?? 'Full Day';
        if (att == 'Full Day' || att == 'Night Shift') {
          basicHours = defaultHrs;
        } else if (att == 'Half Day') {
          basicHours = defaultHrs / 2;
        } else {
          basicHours = 0.0;
        }
      }

      // ── OT Amount (from worker doc, not computed) ────────────────────────
      final rawOtAmt = e['overtimeAmount'];
      final overtimeAmt = rawOtAmt is num
          ? rawOtAmt.toDouble()
          : double.tryParse(rawOtAmt?.toString() ?? '') ?? 0.0;

      // ── OT Rate ─────────────────────────────────────────────────────────
      double otRate = 0.0;
      if (doubleOtHours > 0 && overtimeAmt > 0) {
        otRate = overtimeAmt / doubleOtHours;
      } else if (salaryBasic > 0 && defaultHrs > 0) {
        otRate = (salaryBasic / defaultHrs) * 1.5;
      }

      // ── Meals ───────────────────────────────────────────────────────────
      final rawMealsCnt = e['mealsCount'];
      final mealsCount = rawMealsCnt is num
          ? rawMealsCnt.toInt()
          : int.tryParse(rawMealsCnt?.toString() ?? '') ?? 0;

      final rawMealsAmt = e['mealsAmount'];
      final mealsAmount = rawMealsAmt is num
          ? rawMealsAmt.toDouble()
          : double.tryParse(rawMealsAmt?.toString() ?? '') ?? 0.0;

      final totalMealsAmt = mealsCount * mealsAmount;

      // ── Bus ─────────────────────────────────────────────────────────────
      final rawBusCnt = e['busCount'];
      final busCount = rawBusCnt is num
          ? rawBusCnt.toInt()
          : int.tryParse(rawBusCnt?.toString() ?? '') ?? 0;

      final rawBusAmt = e['busAmount'];
      final busAmount = rawBusAmt is num
          ? rawBusAmt.toDouble()
          : double.tryParse(rawBusAmt?.toString() ?? '') ?? 0.0;

      final totalBusAmt = busCount * busAmount;

      // ── Total Earned ─────────────────────────────────────────────────────
      // Basic Wage + OT Amount + Meals Total + Bus Total
      final totalSalary = salaryBasic + overtimeAmt + totalMealsAmt + totalBusAmt;

      rows.add({
        'siteId':          siteId,
        'siteName':        siteName,
        'coordinatorName': e['coordinatorName']?.toString() ?? e['coordinator']?.toString() ?? '-',
        'supervisorName':  e['supervisorName']?.toString() ?? e['supervisor']?.toString() ?? '-',
        'subContractor':   subContractor,
        'workerName':      workerName,
        'group':           group,
        'category':        category,
        'labourCount':     e['isHeaderOnly'] == true ? 0 : 1,
        'salaryBasic':     salaryBasic,
        'totalSalary':     totalSalary,
        'hours':           basicHours,
        'otSalaryBasic':   otRate,
        'otTotalAmount':   overtimeAmt,
        'mealsExpense':    mealsAmount,
        'mealsCount':      mealsCount,
        'totalMealsAmount': totalMealsAmt,
        'busFare':         busAmount,
        'busCount':        busCount,
        'totalBusAmount':  totalBusAmt,
        'otHours':         doubleOtHours,
        'date':            date,
        'attendanceType':  e['attendanceType']?.toString() ?? 'Full Day',
        'inTime':          e['inTime']?.toString() ?? '',
        'outTime':         e['outTime']?.toString() ?? '',
        'remarks':         e['remarks']?.toString() ?? '',
      });
    }

    // Ensure rows are sorted orderwise: Date ascending -> Coordinator -> Site -> Supervisor -> SubContractor -> Worker
    rows.sort((a, b) {
      final dateA = _toComparableDate(a['date']?.toString());
      final dateB = _toComparableDate(b['date']?.toString());
      final cDate = dateA.compareTo(dateB);
      if (cDate != 0) return cDate;

      final coordA = (a['coordinatorName'] ?? '').toString();
      final coordB = (b['coordinatorName'] ?? '').toString();
      final cCoord = coordA.compareTo(coordB);
      if (cCoord != 0) return cCoord;

      final siteA = (a['siteName'] ?? a['siteId'] ?? '').toString();
      final siteB = (b['siteName'] ?? b['siteId'] ?? '').toString();
      final cSite = siteA.compareTo(siteB);
      if (cSite != 0) return cSite;

      final supA = (a['supervisorName'] ?? '').toString();
      final supB = (b['supervisorName'] ?? '').toString();
      final cSup = supA.compareTo(supB);
      if (cSup != 0) return cSup;

      final subA = (a['subContractor'] ?? '').toString();
      final subB = (b['subContractor'] ?? '').toString();
      final cSub = subA.compareTo(subB);
      if (cSub != 0) return cSub;

      final wA = (a['workerName'] ?? '').toString();
      final wB = (b['workerName'] ?? '').toString();
      return wA.compareTo(wB);
    });

    // ── Filter rows by report type ────────────────────────────────────────
    if (selectedReportType == 'Daily Wage Report') {
      reportData = rows.where((r) => r['group'] == 'DW').toList();
    } else if (selectedReportType == 'Sub Contractor Report') {
      reportData = rows.where((r) => r['group'] == 'SC').toList();
    } else if (selectedReportType == 'Worker on Site Report') {
      reportData = rows
          .where((r) =>
              r['attendanceType'] != 'Absent' &&
              r['attendanceType'] != 'Leave')
          .toList();
    } else {
      reportData = rows;
    }

    // ── Update summary totals ─────────────────────────────────────────────
    totalWorkers    = reportData.length;
    totalLabourCost = reportData.fold(
        0.0, (sum, r) => sum + (r['totalSalary'] as double));
    totalMealsAmount = reportData.fold(
        0.0, (sum, r) => sum + (r['totalMealsAmount'] as double));
    totalMealsCount = reportData.fold(
        0, (sum, r) => sum + (r['mealsCount'] as int));
    totalBusAmount = reportData.fold(
        0.0, (sum, r) => sum + (r['totalBusAmount'] as double));
    totalBusCount = reportData.fold(
        0, (sum, r) => sum + (r['busCount'] as int));

    // ── Secondary groupings ───────────────────────────────────────────────
    _buildAttendanceGroupData(entries);
    _buildSubContractorBillTotals();
  }

  void _buildAttendanceGroupData(List<Map<String, dynamic>> entries) {
    final siteMap = <String, Map<String, dynamic>>{};
    for (final e in entries) {
      final siteId = e['siteId']?.toString() ?? '-';
      final siteName = e['siteName']?.toString() ?? siteId;
      final supervisor = e['supervisorName']?.toString() ?? '-';
      final category = e['category']?.toString() ?? '-';
      final lt = (e['labourType']?.toString().toLowerCase().contains('sub') == true || e['labourType']?.toString().toLowerCase() == 'sc') ? 'SC' : 'DW';
      final contractor = (e['contractorName'] ?? e['subContractorName'] ?? e['contractor'] ?? '-').toString().trim();
      final date = e['date']?.toString() ?? '-';
      final rowKey = '$siteId|$supervisor|$category|$lt|$contractor|$date';

      final coordVal = (e['coordinatorName'] ?? e['coordinator'])?.toString().trim();
      final coordinator = (coordVal != null && coordVal.isNotEmpty && coordVal != '-') ? coordVal : '-';

      final otHours = e['otHours'] ?? e['overtimeHours'];
      final ot = otHours is num ? otHours.toDouble() : double.tryParse(otHours?.toString().split(' ').first ?? '0.0') ?? 0.0;
      final hoursWorked = (e['hoursWorked'] as num?)?.toDouble() ?? 0;
      final attendance = e['attendanceType']?.toString() ?? '';

      if (!siteMap.containsKey(siteId)) {
        siteMap[siteId] = {
          'siteId': siteId,
          'siteName': siteName,
          'supervisors': <String, Map<String, dynamic>>{},
          'totalCount': 0,
        };
      }

      final site = siteMap[siteId]!;
      site['totalCount'] = (site['totalCount'] as int) + 1;

      final supervisors = site['supervisors'] as Map<String, Map<String, dynamic>>;
      if (!supervisors.containsKey(supervisor)) {
        supervisors[supervisor] = {
          'supervisor': supervisor,
          'rows': <String, Map<String, dynamic>>{},
          'totalCount': 0,
        };
      }

      final sup = supervisors[supervisor]!;
      sup['totalCount'] = (sup['totalCount'] as int) + 1;

      final rows = sup['rows'] as Map<String, Map<String, dynamic>>;
      if (!rows.containsKey(rowKey)) {
        rows[rowKey] = {
          'date': date,
          'siteCode': siteId,
          'siteName': siteName,
          'coordinator': coordinator,
          'supervisor': supervisor,
          'categoryType': category,
          'labourType': lt,
          'subContractor': contractor,
          'workerCount': 0,
          'otDetails': _otDetailsString(e),
          'remarks': e['remarks']?.toString() ?? '',
          'otHours': 0.0,
          'stHours': 0.0,
        };
      }

      final row = rows[rowKey]!;
      row['workerCount'] = (row['workerCount'] as int) + 1;
      row['otHours'] = (row['otHours'] as double) + ot;
      if (attendance == 'Night Shift') {
        row['stHours'] = (row['stHours'] as double) + hoursWorked;
      }
    }

    final groups = <_SiteGroup>[];
    for (final siteEntry in siteMap.values) {
      final supervisors = siteEntry['supervisors'] as Map<String, Map<String, dynamic>>;
      final supGroups = <_SupervisorGroup>[];
      for (final supEntry in supervisors.values) {
        final rowsMap = supEntry['rows'] as Map<String, Map<String, dynamic>>;
        supGroups.add(_SupervisorGroup(
          supervisor: supEntry['supervisor'] as String,
          totalCount: supEntry['totalCount'] as int,
          rows: rowsMap.values.toList(),
        ));
      }
      groups.add(_SiteGroup(
        siteCode: siteEntry['siteId'] as String,
        siteName: siteEntry['siteName'] as String,
        totalCount: siteEntry['totalCount'] as int,
        supervisors: supGroups,
      ));
    }
    groups.sort((a, b) => a.siteCode.compareTo(b.siteCode));
    siteGroups = groups;
  }

  void _buildSubContractorBillTotals() {
    final Map<String, Map<String, dynamic>> summaryMap = {};
    for (final row in reportData) {
      if (row['group'] != 'SC') continue;
      final contractor = row['subContractor']?.toString() ?? '-';
      if (contractor == '-' || contractor.trim().isEmpty) continue;

      final stdHours = row['hours'] as double;
      final otHours = row['otHours'] as double;
      final otAmount = row['otTotalAmount'] as double;
      final meals = row['totalMealsAmount'] as double;
      final bus = row['totalBusAmount'] as double;
      final total = row['totalSalary'] as double;
      final stdAmount = total - otAmount;

      if (!summaryMap.containsKey(contractor)) {
        summaryMap[contractor] = {
          'name': contractor,
          'count': 0,
          'stdHours': 0.0,
          'otHours': 0.0,
          'stdAmount': 0.0,
          'otAmount': 0.0,
          'mealsAmount': 0.0,
          'busAmount': 0.0,
          'netAmount': 0.0,
        };
      }

      final sum = summaryMap[contractor]!;
      sum['count'] = (sum['count'] as int) + 1;
      sum['stdHours'] = (sum['stdHours'] as double) + stdHours;
      sum['otHours'] = (sum['otHours'] as double) + otHours;
      sum['stdAmount'] = (sum['stdAmount'] as double) + stdAmount;
      sum['otAmount'] = (sum['otAmount'] as double) + otAmount;
      sum['mealsAmount'] = (sum['mealsAmount'] as double) + meals;
      sum['busAmount'] = (sum['busAmount'] as double) + bus;
      sum['netAmount'] = (sum['netAmount'] as double) + total;
    }

    billGroupedData = summaryMap.values.toList()
      ..sort((a, b) => (b['netAmount'] as double).compareTo(a['netAmount'] as double));
  }

  String _otDetailsString(Map<String, dynamic> e) {
    final out = e['outTime']?.toString().trim() ?? '';
    final inTime = e['inTime']?.toString().trim() ?? '';
    final otHours = e['otHours'] ?? e['overtimeHours'];
    final ot = otHours is num ? otHours.toDouble() : double.tryParse(otHours?.toString().split(' ').first ?? '0.0') ?? 0.0;
    final parts = <String>[];
    if (out.isNotEmpty) parts.add('$out out');
    if (inTime.isNotEmpty && e['attendanceType'] == 'Night Shift') {
      parts.add('$inTime to');
    }
    if (ot > 0) parts.add('${ot.toStringAsFixed(1)} Hrs');
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  // ── Build Main UI ────────────────────────────────────────────────────────
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
                child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Labour Reports',
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
        InkWell(
          onTap: _showDownloadOptionsSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
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
            child: Icon(Icons.download_rounded, color: primaryColor, size: 22),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Report Selection Header
                      _buildReportSelector(),
                      const SizedBox(height: 12),

                      // Collapsible filter section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filters & Parameters',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          IconButton(
                            icon: Icon(showFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: primaryColor),
                            onPressed: () => setState(() => showFilters = !showFilters),
                          ),
                        ],
                      ),
                      if (showFilters) ...[
                        _buildFiltersCard(),
                        const SizedBox(height: 12),
                      ],

                      // Result Rendering Area
                      _buildResultArea(),
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

  Widget _buildReportSelector() {
    return CustomDropdown<String>(
      value: selectedReportType,
      hintText: 'Select Report Type',
      items: reportTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (type) {
        if (type != null) {
          setState(() {
            selectedReportType = type;
            reportGenerated = false;
          });
          _generateReport();
        }
      },
    );
  }

  Widget _buildDateField(String label, DateTime? date, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: primaryColor)),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: mutedColor),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 14, color: mutedColor),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yyyy').format(date) : '—',
          style: TextStyle(fontSize: 13, color: date != null ? textColor : mutedColor),
        ),
      ),
    );
  }

  Widget _buildDynamicDropdown({
    required String label,
    required List<_DropdownOption> options,
    required String? value,
    required ValueChanged<_DropdownOption?> onChanged,
  }) {
    if (isLoadingFilters) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
            ),
            const SizedBox(width: 8),
            Text('Loading…', style: TextStyle(fontSize: 12, color: mutedColor)),
          ],
        ),
      );
    }

    final validValue = options.any((o) => o.id == value) ? value : null;

    return CustomDropdown<String>(
      value: validValue,
      hintText: 'All $label',
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All $label', style: TextStyle(color: mutedColor)),
        ),
        ...options.map((opt) => DropdownMenuItem<String>(
              value: opt.id,
              child: Text(opt.label, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (id) {
        if (id == null) {
          onChanged(null);
        } else {
          onChanged(options.firstWhere((o) => o.id == id));
        }
      },
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomDropdown<String>(
                  value: selectedDateFilter,
                  hintText: 'Date Filter',
                  items: ['Today', 'Yesterday', 'This Week', 'This Month', 'This Year', 'Custom'].map((preset) {
                    return DropdownMenuItem<String>(
                      value: preset,
                      child: Text(preset, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _applyDatePreset(val);
                    }
                  },
                ),
              ),
              if (selectedDateFilter != 'Custom') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _dateRangeText(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (selectedDateFilter == 'Custom') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDateField('From Date', startDate, (d) => setState(() { startDate = d; _generateReport(); }))),
                const SizedBox(width: 8),
                Expanded(child: _buildDateField('To Date', endDate, (d) => setState(() { endDate = d; _generateReport(); }))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDynamicDropdown(label: 'Site', options: siteOptions, value: selectedSiteId, onChanged: (opt) => setState(() { selectedSiteId = opt?.id; selectedSiteName = opt?.label; _generateReport(); }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDynamicDropdown(label: 'Supervisor', options: supervisorOptions, value: selectedSupervisorName, onChanged: (opt) => setState(() { selectedSupervisorName = opt?.id; _generateReport(); }))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDynamicDropdown(label: 'Co-ordinator', options: coordinatorOptions, value: selectedCoordinatorName, onChanged: (opt) => setState(() { selectedCoordinatorName = opt?.id; _generateReport(); }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDynamicDropdown(label: 'Sub Contractor', options: contractorOptions, value: selectedSubContractorName, onChanged: (opt) => setState(() { selectedSubContractorName = opt?.id; _generateReport(); }))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomDropdown<String>(
                  value: selectedLabourType,
                  hintText: 'Labour Type',
                  items: ['All', 'Daily Wage (DW)', 'Sub Contractor (SC)'].map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() { selectedLabourType = val; _generateReport(); }),
                ),
              ),
            ],
          ),
          if (selectedReportType == 'Sub Contractor Bill Report') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _billNoController,
                    decoration: InputDecoration(
                      labelText: 'Bill Number',
                      labelStyle: TextStyle(fontSize: 12, color: mutedColor),
                      filled: true,
                      fillColor: bgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _workTypeController,
                    decoration: InputDecoration(
                      labelText: 'Work Type',
                      labelStyle: TextStyle(fontSize: 12, color: mutedColor),
                      filled: true,
                      fillColor: bgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _narrationController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Work Narration',
                labelStyle: TextStyle(fontSize: 12, color: mutedColor),
                filled: true,
                fillColor: bgColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: Icon(Icons.refresh, size: 14, color: errorColor),
              label: Text('Reset Filters', style: TextStyle(color: errorColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }





  // ── Client-Side Filter Helpers ───────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredReportData {
    if (searchQuery.isEmpty) return reportData;
    final q = searchQuery.toLowerCase();
    return reportData.where((row) {
      return (row['workerName']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['subContractor']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['siteName']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['category']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['supervisorName']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['coordinatorName']?.toString().toLowerCase().contains(q) ?? false) ||
          (row['siteId']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<_SiteGroup> get _filteredSiteGroups {
    if (searchQuery.isEmpty) return siteGroups;
    final q = searchQuery.toLowerCase();
    List<_SiteGroup> filtered = [];
    for (final site in siteGroups) {
      final siteMatch = site.siteCode.toLowerCase().contains(q) || site.siteName.toLowerCase().contains(q);
      List<_SupervisorGroup> matchingSups = [];
      for (final sup in site.supervisors) {
        final supMatch = sup.supervisor.toLowerCase().contains(q);
        final matchingRows = sup.rows.where((r) =>
            r['subContractor']?.toString().toLowerCase().contains(q) == true ||
            r['categoryType']?.toString().toLowerCase().contains(q) == true ||
            r['labourType']?.toString().toLowerCase().contains(q) == true ||
            r['coordinator']?.toString().toLowerCase().contains(q) == true ||
            r['supervisor']?.toString().toLowerCase().contains(q) == true).toList();
        if (siteMatch || supMatch || matchingRows.isNotEmpty) {
          final rowsList = (siteMatch || supMatch) ? sup.rows : matchingRows;
          matchingSups.add(_SupervisorGroup(
            supervisor: sup.supervisor,
            totalCount: rowsList.length,
            rows: rowsList,
          ));
        }
      }
      if (matchingSups.isNotEmpty) {
        final groupTotal = matchingSups.fold(0, (acc, s) => acc + s.totalCount);
        filtered.add(_SiteGroup(
          siteCode: site.siteCode,
          siteName: site.siteName,
          totalCount: groupTotal,
          supervisors: matchingSups,
        ));
      }
    }
    return filtered;
  }

  List<Map<String, dynamic>> get _filteredBillGroupedData {
    final rows = _filteredReportData;
    final summaryMap = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final contractor = (row['subContractor'] ?? row['contractorName'] ?? 'Unknown').toString();
      final stdHours = (row['hours'] as num? ?? 0).toDouble();
      final otHours = (row['otHours'] as num? ?? 0).toDouble();
      final otAmount = (row['otTotalAmount'] as num? ?? 0).toDouble();
      final meals = (row['totalMealsAmount'] as num? ?? 0).toDouble();
      final bus = (row['totalBusAmount'] as num? ?? 0).toDouble();
      final total = (row['totalSalary'] as num? ?? 0).toDouble();
      final stdAmount = total - otAmount;

      if (!summaryMap.containsKey(contractor)) {
        summaryMap[contractor] = {
          'name': contractor,
          'count': 0,
          'stdHours': 0.0,
          'otHours': 0.0,
          'stdAmount': 0.0,
          'otAmount': 0.0,
          'mealsAmount': 0.0,
          'busAmount': 0.0,
          'netAmount': 0.0,
        };
      }

      final sum = summaryMap[contractor]!;
      sum['count'] = (sum['count'] as int) + 1;
      sum['stdHours'] = (sum['stdHours'] as double) + stdHours;
      sum['otHours'] = (sum['otHours'] as double) + otHours;
      sum['stdAmount'] = (sum['stdAmount'] as double) + stdAmount;
      sum['otAmount'] = (sum['otAmount'] as double) + otAmount;
      sum['mealsAmount'] = (sum['mealsAmount'] as double) + meals;
      sum['busAmount'] = (sum['busAmount'] as double) + bus;
      sum['netAmount'] = (sum['netAmount'] as double) + total;
    }

    final result = summaryMap.values.toList()
      ..sort((a, b) => (b['netAmount'] as double).compareTo(a['netAmount'] as double));
    return result;
  }

  // ── Result Area Routing ──────────────────────────────────────────────────
  Widget _buildResultArea() {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    final filteredRows = _filteredReportData;
    final currentSiteGroups = _filteredSiteGroups;

    if (reportGenerated && filteredRows.isEmpty && currentSiteGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: _buildEmptyState(),
      );
    }

    Widget reportWidget;
    switch (selectedReportType) {
      case 'Site Labour Report':
      case 'Site Labour Attendance Report':
        reportWidget = _buildGroupedLabourReportTable(filteredRows);
        break;
      case 'Site Labour Details Report':
        reportWidget = _buildDetailsTable(filteredRows);
        break;
      case 'Daily Wage Report':
        reportWidget = _buildDailyWageTable(filteredRows);
        break;
      case 'Sub Contractor Report':
        reportWidget = _buildSubContractorTable(filteredRows);
        break;
      case 'Worker on Site Report':
        reportWidget = _buildWorkerOnSiteTable(filteredRows);
        break;
      case 'Sub Contractor Bill Report':
        reportWidget = _buildSubContractorBillLayout(filteredRows);
        break;
      default:
        reportWidget = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filteredRows.isNotEmpty || currentSiteGroups.isNotEmpty)
          _buildSummaryKpiBanner(filteredRows),
        reportWidget,
      ],
    );
  }

  Widget _buildSummaryKpiBanner(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    final screenWidth = MediaQuery.of(context).size.width;

    // Media Query Breakpoints
    final isExtraSmall = screenWidth < 360;
    final isCompactMobile = screenWidth < 400;

    final titleFontSize = isExtraSmall ? 11.5 : (isCompactMobile ? 12.5 : 13.5);
    final badgeFontSize = isExtraSmall ? 10.5 : (isCompactMobile ? 11.5 : 12.5);
    final iconSize = isExtraSmall ? 16.0 : (isCompactMobile ? 18.0 : 20.0);
    final containerPadding = isExtraSmall ? 10.0 : (isCompactMobile ? 12.0 : 16.0);

    return Container(
      padding: EdgeInsets.all(containerPadding),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: iconSize, color: primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'REPORT TOTALS & SUMMARY',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isExtraSmall ? 8 : 10,
                  vertical: isExtraSmall ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totals.totalRecords} Records',
                  style: TextStyle(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildKpiBadge('Total Subs', '${totals.totalSubContractors}', Icons.badge_outlined, Colors.indigo),
                _buildKpiBadge('Total Workers', '${totals.totalWorkers}', Icons.people_outline, Colors.blue),
                _buildKpiBadge('Total Hours', '${(totals.totalHours + totals.totalOtHours).toStringAsFixed(1)} hrs', Icons.access_time, Colors.orange),
                _buildKpiBadge('OT Amount', '₹${totals.totalOtAmount.toStringAsFixed(2)}', Icons.more_time, Colors.deepOrange),
                _buildKpiBadge('Meals & Bus', '₹${(totals.totalMealsAmount + totals.totalBusAmount).toStringAsFixed(2)}', Icons.directions_bus_outlined, Colors.teal),
                _buildKpiBadge('Grand Total', '₹${totals.totalEarnedSalary.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined, Colors.green, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBadge(String label, String value, IconData icon, Color color, {bool isBold = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isExtraSmall = screenWidth < 360;

    final labelFontSize = isExtraSmall ? 10.5 : 11.5;
    final valueFontSize = isExtraSmall ? 13.0 : 14.5;
    final badgeIconSize = isExtraSmall ? 16.0 : 18.0;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(
        horizontal: isExtraSmall ? 10 : 12,
        vertical: isExtraSmall ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: badgeIconSize, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: mutedColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No Data Found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('Try altering your filter configuration.', style: TextStyle(fontSize: 12, color: mutedColor)),
        ],
      ),
    );
  }

  // ── 1. Details Table Layout ──────────────────────────────────────────────
  Widget _buildDetailsTable(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);

    const Color otHighlightBg    = Color(0xFFFFF3E0);
    const Color otHighlightFg    = Color(0xFFE65100);
    const Color mealsHighlightBg = Color(0xFFE0F7FA);
    const Color mealsHighlightFg = Color(0xFF00838F);
    const Color busHighlightBg   = Color(0xFFEDE7F6);
    const Color busHighlightFg   = Color(0xFF4527A0);
    const Color earnedBg         = Color(0xFFE8F5E9);
    const Color earnedFg         = Color(0xFF1B5E20);

    Widget _hCell(String text, Color bg, Color fg, {bool bold = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return CustomTable<Map<String, dynamic>>(
      data: rows,
      mainColor: primaryColor,
      showTotalsRow: true,
      columns: [
        CustomTableColumn<Map<String, dynamic>>(
          header: 'SI',
          cellBuilder: (r, index) => Text('${index + 1}'),
          totalCellBuilder: () => Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Date',
          cellBuilder: (r, index) => Text(_formatDate(r['date']?.toString())),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Coordinator',
          cellBuilder: (r, index) => Text(r['coordinatorName']?.toString() ?? '-'),
          totalCellBuilder: () => Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Site Name',
          cellBuilder: (r, index) => Text(_cleanSiteName(r['siteName']?.toString() ?? r['siteId']?.toString())),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Supervisor',
          cellBuilder: (r, index) => Text(r['supervisorName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Contractor',
          cellBuilder: (r, index) => Text(r['subContractor']?.toString() ?? '-'),
          totalCellBuilder: () => Text('${totals.totalSubContractors} Subs', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Worker Name',
          cellBuilder: (r, index) => Text(r['workerName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Group',
          cellBuilder: (r, index) => Text(r['group']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Category',
          cellBuilder: (r, index) => Text(r['category']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Basic Wage',
          cellBuilder: (r, index) => Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Hrs',
          cellBuilder: (r, index) => Text((r['hours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Rate',
          cellBuilder: (r, index) => Text('₹${(r['otSalaryBasic'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalOtSalaryBasic.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Hrs',
          cellBuilder: (r, index) => Text((r['otHours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Amount',
          cellBuilder: (r, index) => _hCell('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}', otHighlightBg, otHighlightFg),
          totalCellBuilder: () => _hCell('₹${totals.totalOtAmount.toStringAsFixed(2)}', otHighlightBg, otHighlightFg, bold: true),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Meals Exp',
          cellBuilder: (r, index) => Text('₹${(r['mealsExpense'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalMealsExpense.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Meals Count',
          cellBuilder: (r, index) => Text('${r['mealsCount']}'),
          totalCellBuilder: () => Text('${totals.totalMealsCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Meals Total',
          cellBuilder: (r, index) => _hCell('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}', mealsHighlightBg, mealsHighlightFg),
          totalCellBuilder: () => _hCell('₹${totals.totalMealsAmount.toStringAsFixed(2)}', mealsHighlightBg, mealsHighlightFg, bold: true),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Bus Fare',
          cellBuilder: (r, index) => Text('₹${(r['busFare'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBusFare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Bus Count',
          cellBuilder: (r, index) => Text('${r['busCount']}'),
          totalCellBuilder: () => Text('${totals.totalBusCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Bus Total',
          cellBuilder: (r, index) => _hCell('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}', busHighlightBg, busHighlightFg),
          totalCellBuilder: () => _hCell('₹${totals.totalBusAmount.toStringAsFixed(2)}', busHighlightBg, busHighlightFg, bold: true),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Total Earned Amount',
          cellBuilder: (r, index) => _hCell('₹${(r['totalSalary'] as double).toStringAsFixed(2)}', earnedBg, earnedFg, bold: true),
          totalCellBuilder: () => _hCell('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', earnedBg, earnedFg, bold: true),
        ),
      ],
    );
  }


  // ── 2. Attendance List Layout (Grouped Site/Supervisor) ──────────────────
  Widget _buildAttendanceList() {
    final currentGroups = _filteredSiteGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: currentGroups
          .map((site) => _SiteAttendanceCardItem(site: site, searchQuery: searchQuery))
          .toList(),
    );
  }

  // ── 3. Daily Wage Table Layout ───────────────────────────────────────────
  Widget _buildDailyWageTable(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    return CustomTable<Map<String, dynamic>>(
      data: rows,
      mainColor: primaryColor,
      showTotalsRow: true,
      columns: [
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Sl',
          cellBuilder: (r, index) => Text('${index + 1}'),
          totalCellBuilder: () => Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Date',
          cellBuilder: (r, index) => Text(_formatDate(r['date']?.toString())),
          totalCellBuilder: () => Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Site Name',
          cellBuilder: (r, index) => Text(_cleanSiteName(r['siteName']?.toString())),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Worker Name',
          cellBuilder: (r, index) => Text(r['workerName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Category',
          cellBuilder: (r, index) => Text(r['category']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Basic Rate',
          cellBuilder: (r, index) => Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Attendance',
          cellBuilder: (r, index) => Text(r['attendanceType']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Hours',
          cellBuilder: (r, index) => Text((r['hours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Hours',
          cellBuilder: (r, index) => Text((r['otHours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Amount',
          cellBuilder: (r, index) => Text('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Meals',
          cellBuilder: (r, index) => Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Bus',
          cellBuilder: (r, index) => Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Total Wages',
          cellBuilder: (r, index) => Text('₹${(r['totalSalary'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Supervisor',
          cellBuilder: (r, index) => Text(r['supervisorName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Remarks',
          cellBuilder: (r, index) => Text(r['remarks']?.toString() ?? '-'),
        ),
      ],
    );
  }

  // ── 4. Sub Contractor Table Layout ───────────────────────────────────────
  Widget _buildSubContractorTable(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    return CustomTable<Map<String, dynamic>>(
      data: rows,
      mainColor: primaryColor,
      showTotalsRow: true,
      columns: [
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Sl',
          cellBuilder: (r, index) => Text('${index + 1}'),
          totalCellBuilder: () => Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Date',
          cellBuilder: (r, index) => Text(_formatDate(r['date']?.toString())),
          totalCellBuilder: () => Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Site Name',
          cellBuilder: (r, index) => Text(_cleanSiteName(r['siteName']?.toString())),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Sub Contractor',
          cellBuilder: (r, index) => Text(r['subContractor']?.toString() ?? '-'),
          totalCellBuilder: () => Text('${totals.totalSubContractors} Subs', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Worker Name',
          cellBuilder: (r, index) => Text(r['workerName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Category',
          cellBuilder: (r, index) => Text(r['category']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Basic Rate',
          cellBuilder: (r, index) => Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Attendance',
          cellBuilder: (r, index) => Text(r['attendanceType']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Hours',
          cellBuilder: (r, index) => Text((r['hours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Hours',
          cellBuilder: (r, index) => Text((r['otHours'] as double).toStringAsFixed(1)),
          totalCellBuilder: () => Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'OT Amount',
          cellBuilder: (r, index) => Text('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Meals',
          cellBuilder: (r, index) => Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Bus',
          cellBuilder: (r, index) => Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Total Amount',
          cellBuilder: (r, index) => Text('₹${(r['totalSalary'] as double).toStringAsFixed(2)}'),
          totalCellBuilder: () => Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Supervisor',
          cellBuilder: (r, index) => Text(r['supervisorName']?.toString() ?? '-'),
        ),
        CustomTableColumn<Map<String, dynamic>>(
          header: 'Remarks',
          cellBuilder: (r, index) => Text(r['remarks']?.toString() ?? '-'),
        ),
      ],
    );
  }

  Widget _buildWorkerOnSiteTable(List<Map<String, dynamic>> rows) {
    final allocations = _getWorkerOnSiteAllocations();
    final List<DataRow> dataRows = [];

    for (final alloc in allocations) {
      for (int i = 0; i < alloc.sites.length; i++) {
        final site = alloc.sites[i];
        dataRows.add(DataRow(cells: [
          DataCell(Text(i == 0 ? alloc.subContractor : '', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(site.siteId)),
          DataCell(Text(site.labourType)),
        ]));
      }
    }

    if (allocations.isNotEmpty) {
      int totalSites = allocations.fold(0, (sum, a) => sum + a.sites.length);
      dataRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('TOTAL: ${allocations.length} Subs', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('$totalSites Sites', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${rows.length} Allocations', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 36,
          headingRowColor: WidgetStateProperty.all(primaryColor),
          columns: _headersToColumns([
            'Sub Contractor Name', 'Site Code', 'Labour Type'
          ]),
          rows: dataRows,
        ),
      ),
    );
  }

  // ── 6. Sub Contractor Bill Layout ─────────────────────────────────────────
  Widget _buildSubContractorBillLayout(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    final List<DataRow> detailRows = List.generate(rows.length, (index) {
      final r = rows[index];
      final ot = r['otTotalAmount'] as double;
      final total = r['totalSalary'] as double;
      final stdAmt = total - ot;
      return DataRow(cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(r['date']?.toString() ?? '-')),
        DataCell(Text(r['siteName']?.toString() ?? '-')),
        DataCell(Text(r['subContractor']?.toString() ?? '-')),
        DataCell(Text(r['workerName']?.toString() ?? '-')),
        DataCell(Text(r['category']?.toString() ?? '-')),
        DataCell(Text((r['hours'] as double).toStringAsFixed(1))),
        DataCell(Text((r['otHours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${stdAmt.toStringAsFixed(2)}')),
        DataCell(Text('₹${ot.toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${total.toStringAsFixed(2)}')),
      ]);
    });

    if (rows.isNotEmpty) {
      detailRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(Text('${totals.totalSubContractors} Subs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalStdAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          ],
        ),
      );
    }

    final currentBillGroupedData = _filteredBillGroupedData;
    final List<DataRow> summaryRows = currentBillGroupedData.map((row) {
      return DataRow(cells: [
        DataCell(Text(row['name']?.toString() ?? '-')),
        DataCell(Text('${row['count']}')),
        DataCell(Text((row['stdHours'] as double).toStringAsFixed(1))),
        DataCell(Text((row['otHours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(row['stdAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['otAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['mealsAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['busAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['netAmount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
      ]);
    }).toList();

    if (currentBillGroupedData.isNotEmpty) {
      int sumManDays = currentBillGroupedData.fold(0, (sum, r) => sum + (r['count'] as int? ?? 0));
      double sumStdHrs = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['stdHours'] as double? ?? 0));
      double sumOtHrs = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['otHours'] as double? ?? 0));
      double sumStdAmt = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['stdAmount'] as double? ?? 0));
      double sumOtAmt = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['otAmount'] as double? ?? 0));
      double sumMealsAmt = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['mealsAmount'] as double? ?? 0));
      double sumBusAmt = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['busAmount'] as double? ?? 0));
      double sumNetBill = currentBillGroupedData.fold(0.0, (sum, r) => sum + (r['netAmount'] as double? ?? 0));

      summaryRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('$sumManDays', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(sumStdHrs.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(sumOtHrs.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${sumStdAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${sumOtAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${sumMealsAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${sumBusAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${sumNetBill.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detailed entries
        Text('Detailed Billing Entries', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(primaryColor),
              columns: _headersToColumns([
                'Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker Name', 'Category',
                'Std Hours', 'OT Hours', 'Basic Rate', 'Std Amount', 'OT Amount', 'Meals', 'Bus', 'Total Bill'
              ]),
              rows: detailRows,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Grouped summaries
        Text('Sub Contractor Summary', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(primaryLight),
              columns: _headersToColumns([
                'Sub Contractor', 'Man-Days', 'Std Hours', 'OT Hours',
                'Std Amount', 'OT Amount', 'Meals', 'Bus', 'Net Bill'
              ]),
              rows: summaryRows,
            ),
          ),
        ),
      ],
    );
  }

  List<_SubContractorAllocation> _getWorkerOnSiteAllocations([List<Map<String, dynamic>>? rowsData]) {
    final rows = rowsData ?? _filteredReportData;
    final Map<String, Set<String>> subConToSites = {};
    for (final r in rows) {
      final sub = r['subContractor']?.toString() ?? 'Unassigned';
      final siteId = r['siteId']?.toString() ?? '-';
      final group = r['group']?.toString() ?? '-';
      subConToSites.putIfAbsent(sub, () => <String>{}).add('$siteId|$group');
    }

    final List<_SubContractorAllocation> result = [];
    final sortedSubCons = subConToSites.keys.toList()..sort();
    for (final sub in sortedSubCons) {
      final List<_SiteAllocationItem> items = [];
      final sortedAllocations = subConToSites[sub]!.toList()..sort();
      for (final alloc in sortedAllocations) {
        final parts = alloc.split('|');
        items.add(_SiteAllocationItem(
          siteId: parts[0],
          labourType: parts[1],
        ));
      }
      result.add(_SubContractorAllocation(subContractor: sub, sites: items));
    }
    return result;
  }

  void _showDownloadOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF Document (.pdf)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExportPreviewDialog('pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excel Spreadsheet (.xlsx)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExportPreviewDialog('excel');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: const Text('CSV Document (.csv)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExportPreviewDialog('csv');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportPreviewDialog(String format) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _ExportPreviewDialogContent(
              format: format,
              reportType: selectedReportType,
              buildPdfDoc: _buildActivePDFDocument,
              reportName: _getActiveReportName(),
              onDownload: () async {
                if (format == 'pdf') {
                  final doc = await _buildActivePDFDocument();
                  final bytes = await doc.save();
                  await _shareFile(bytes, '${_getActiveReportName()}.pdf', 'application/pdf');
                } else {
                  await _exportActiveReport(format);
                }
              },
              tableData: _getReportTableData(),
              primaryColor: primaryColor,
            ),
          ),
        );
      },
    );
  }

  Future<pw.Document> _buildActivePDFDocument() async {
    if (selectedReportType == 'Site Labour Details Report') {
      return _buildDetailsPDFDocument();
    } else if (selectedReportType == 'Site Labour Report' || selectedReportType == 'Site Labour Attendance Report') {
      return _buildAttendancePDFDocument();
    } else if (selectedReportType == 'Daily Wage Report') {
      return _buildDWPDFDocument();
    } else if (selectedReportType == 'Sub Contractor Report') {
      return _buildSCPDFDocument();
    } else if (selectedReportType == 'Worker on Site Report') {
      return _buildPresencePDFDocument();
    } else {
      return _buildBillPDFDocument();
    }
  }

  String _getActiveReportName() {
    return selectedReportType.replaceAll(' ', '_');
  }

  List<List<String>> _getReportTableData() {
    final List<List<String>> result = [];
    final rows = _filteredReportData;
    final totals = _ReportTotals.fromRows(rows);
    final currentGroups = _filteredSiteGroups;

    if (selectedReportType == 'Site Labour Details Report') {
      result.add([
        'Sl', 'Date', 'Co-ordinator', 'Site Code', 'Site Name', 'Supervisor',
        'Contractor', 'Worker Name', 'Group', 'Category', 'Basic Wage', 'Hrs',
        'OT Rate', 'OT Hrs', 'OT Amount', 'Meals Exp', 'Meals Count', 'Meals Total',
        'Bus Fare', 'Bus Count', 'Bus Total', 'Total Earned Amount'
      ]);
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        result.add([
          (i + 1).toString(),
          _formatDate(r['date']?.toString()),
          (r['coordinatorName'] ?? r['coordinator'] ?? '-').toString(),
          (r['siteId'] ?? '-').toString(),
          (r['siteName'] ?? '-').toString(),
          (r['supervisorName'] ?? '-').toString(),
          (r['subContractor'] ?? '-').toString(),
          (r['workerName'] ?? '-').toString(),
          (r['group'] ?? '-').toString(),
          (r['category'] ?? '-').toString(),
          '₹${(r['salaryBasic'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['hours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          '₹${(r['otSalaryBasic'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['otHours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          '₹${(r['otTotalAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['mealsExpense'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['mealsCount'] as num? ?? 0).toInt().toString(),
          '₹${(r['totalMealsAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['busFare'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['busCount'] as num? ?? 0).toInt().toString(),
          '₹${(r['totalBusAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalSalary'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
        ]);
      }
      if (rows.isNotEmpty) {
        result.add([
          'TOTAL', '-', '-', '${totals.totalRecords} Recs', '-', '-',
          '${totals.totalSubContractors} Subs', '-', '-', '-',
          '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
          totals.totalHours.toStringAsFixed(1),
          '₹${totals.totalOtSalaryBasic.toStringAsFixed(2)}',
          totals.totalOtHours.toStringAsFixed(1),
          '₹${totals.totalOtAmount.toStringAsFixed(2)}',
          '₹${totals.totalMealsExpense.toStringAsFixed(2)}',
          totals.totalMealsCount.toString(),
          '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
          '₹${totals.totalBusFare.toStringAsFixed(2)}',
          totals.totalBusCount.toString(),
          '₹${totals.totalBusAmount.toStringAsFixed(2)}',
          '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
        ]);
        result.add([]);
        result.add(['GRAND TOTAL SUMMARY', '']);
        result.add(['Total Records', '${totals.totalRecords} Recs']);
        result.add(['Total Amount', '₹${(totals.totalBasicSalary + totals.totalOtAmount).toStringAsFixed(2)}']);
        result.add(['Total Expense', '₹${(totals.totalMealsAmount + totals.totalBusAmount).toStringAsFixed(2)}']);
        result.add(['Grand Total', '₹${totals.totalEarnedSalary.toStringAsFixed(2)}']);
      }
    } else if (selectedReportType == 'Site Labour Report' || selectedReportType == 'Site Labour Attendance Report') {
      final groupedItems = _computeGroupedReportItems(rows);
      result.add([
        'S.No',
        'Date',
        'Coordinator',
        'Site Name',
        'Supervisor',
        'CT',
        'LT',
        'Subcontractor Name',
        'Nos',
        'Total',
        'OT / ST Details',
      ]);
      int grandTotalLabour = 0;
      for (final item in groupedItems) {
        grandTotalLabour += item.labourCount;
        result.add([
          '${item.sNo}',
          item.date,
          item.showCoordinator ? item.coordinator : '',
          item.showSiteName ? item.siteName : '',
          item.showSupervisor ? item.supervisor : '',
          item.category,
          item.labourType,
          item.subcontractorName,
          '${item.labourCount}',
          item.showSiteName ? '${item.siteTotalCount}' : '',
          item.otStDetails,
        ]);
      }
      if (groupedItems.isNotEmpty) {
        result.add([
          'TOTAL',
          '${groupedItems.length} Rows',
          '-',
          '-',
          '-',
          '-',
          '-',
          '-',
          '$grandTotalLabour',
          '$grandTotalLabour',
          '-',
        ]);

        final Map<String, int> ctBreakdown = {};
        for (final item in groupedItems) {
          final ct = item.category.trim();
          if (ct.isNotEmpty && ct != '-') {
            ctBreakdown[ct] = (ctBreakdown[ct] ?? 0) + item.labourCount;
          }
        }

        if (ctBreakdown.isNotEmpty) {
          result.add([]);
          result.add(['CATEGORY (CT) BREAKDOWN SUMMARY', 'COUNT']);
          ctBreakdown.forEach((ct, cnt) {
            result.add(['$ct - $cnt', '$cnt']);
          });
        }
      }
    } else if (selectedReportType == 'Daily Wage Report') {
      result.add(['Sl', 'Date', 'Site Name', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Wages', 'Supervisor', 'Remarks']);
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        result.add([
          (i + 1).toString(),
          (r['date'] ?? '').toString(),
          (r['siteName'] ?? '').toString(),
          (r['workerName'] ?? '').toString(),
          (r['category'] ?? '').toString(),
          '₹${(r['salaryBasic'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['attendanceType'] ?? '').toString(),
          (r['hours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          (r['otHours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          '₹${(r['otTotalAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalMealsAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalBusAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalSalary'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['supervisorName'] ?? '').toString(),
          (r['remarks'] ?? '').toString(),
        ]);
      }
      if (rows.isNotEmpty) {
        result.add([
          'TOTAL', '${totals.totalRecords} Recs', '-', '-', '-',
          '₹${totals.totalBasicSalary.toStringAsFixed(2)}', '-',
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtHours.toStringAsFixed(1),
          '₹${totals.totalOtAmount.toStringAsFixed(2)}',
          '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
          '₹${totals.totalBusAmount.toStringAsFixed(2)}',
          '₹${totals.totalEarnedSalary.toStringAsFixed(2)}', '-', '-'
        ]);
        result.add([]);
        result.add(['GRAND TOTAL SUMMARY', '']);
        result.add(['Total Records', '${totals.totalRecords} Recs']);
        result.add(['Total Amount', '₹${(totals.totalBasicSalary + totals.totalOtAmount).toStringAsFixed(2)}']);
        result.add(['Total Expense', '₹${(totals.totalMealsAmount + totals.totalBusAmount).toStringAsFixed(2)}']);
        result.add(['Grand Total', '₹${totals.totalEarnedSalary.toStringAsFixed(2)}']);
      }
    } else if (selectedReportType == 'Sub Contractor Report') {
      result.add(['Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Amount', 'Supervisor', 'Remarks']);
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        result.add([
          (i + 1).toString(),
          (r['date'] ?? '').toString(),
          (r['siteName'] ?? '').toString(),
          (r['subContractor'] ?? '').toString(),
          (r['workerName'] ?? '').toString(),
          (r['category'] ?? '').toString(),
          '₹${(r['salaryBasic'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['attendanceType'] ?? '').toString(),
          (r['hours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          (r['otHours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          '₹${(r['otTotalAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalMealsAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalBusAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalSalary'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          (r['supervisorName'] ?? '').toString(),
          (r['remarks'] ?? '').toString(),
        ]);
      }
      if (rows.isNotEmpty) {
        result.add([
          'TOTAL', '${totals.totalRecords} Recs', '-',
          '${totals.totalSubContractors} Subs', '-', '-',
          '₹${totals.totalBasicSalary.toStringAsFixed(2)}', '-',
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtHours.toStringAsFixed(1),
          '₹${totals.totalOtAmount.toStringAsFixed(2)}',
          '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
          '₹${totals.totalBusAmount.toStringAsFixed(2)}',
          '₹${totals.totalEarnedSalary.toStringAsFixed(2)}', '-', '-'
        ]);
        result.add([]);
        result.add(['GRAND TOTAL SUMMARY', '']);
        result.add(['Total Records', '${totals.totalRecords} Recs']);
        result.add(['Total Amount', '₹${(totals.totalBasicSalary + totals.totalOtAmount).toStringAsFixed(2)}']);
        result.add(['Total Expense', '₹${(totals.totalMealsAmount + totals.totalBusAmount).toStringAsFixed(2)}']);
        result.add(['Grand Total', '₹${totals.totalEarnedSalary.toStringAsFixed(2)}']);
      }
    } else if (selectedReportType == 'Worker on Site Report') {
      result.add(['Sub Contractor Name', 'Site Code', 'Labour Type']);
      final allocations = _getWorkerOnSiteAllocations(rows);
      for (final alloc in allocations) {
        for (int i = 0; i < alloc.sites.length; i++) {
          final site = alloc.sites[i];
          result.add([
            i == 0 ? alloc.subContractor : '',
            site.siteId,
            site.labourType,
          ]);
        }
      }
      if (allocations.isNotEmpty) {
        int totalSites = allocations.fold(0, (sum, a) => sum + a.sites.length);
        result.add(['TOTAL', '${allocations.length} Subs', '$totalSites Sites']);
        result.add([]);
        result.add(['GRAND TOTAL SUMMARY', '']);
        result.add(['Total Sub Contractors', '${allocations.length} Subs']);
        result.add(['Total Sites Allocated', '$totalSites Sites']);
      }
    } else if (selectedReportType == 'Sub Contractor Bill Report') {
      result.add(['Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker Name', 'Category', 'Hours', 'OT Hours', 'Basic Rate', 'Standard Amount', 'OT Amount', 'Meals', 'Bus', 'Total Bill']);
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final ot = (r['otTotalAmount'] as num? ?? 0).toDouble();
        final total = (r['totalSalary'] as num? ?? 0).toDouble();
        final stdAmt = total - ot;
        result.add([
          (i + 1).toString(),
          _formatDateString(r['date']?.toString()),
          (r['siteName'] ?? '-').toString(),
          (r['subContractor'] ?? '-').toString(),
          (r['workerName'] ?? '-').toString(),
          (r['category'] ?? '-').toString(),
          (r['hours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          (r['otHours'] as num? ?? 0).toDouble().toStringAsFixed(1),
          '₹${(r['salaryBasic'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${stdAmt.toStringAsFixed(2)}',
          '₹${ot.toStringAsFixed(2)}',
          '₹${(r['totalMealsAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${(r['totalBusAmount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
          '₹${total.toStringAsFixed(2)}',
        ]);
      }
      if (rows.isNotEmpty) {
        result.add([
          'TOTAL', '${totals.totalRecords} Recs', '-',
          '${totals.totalSubContractors} Subs', '-', '-',
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtHours.toStringAsFixed(1),
          '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
          '₹${totals.totalStdAmount.toStringAsFixed(2)}',
          '₹${totals.totalOtAmount.toStringAsFixed(2)}',
          '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
          '₹${totals.totalBusAmount.toStringAsFixed(2)}',
          '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
        ]);
        result.add([]);
        result.add(['GRAND TOTAL SUMMARY', '']);
        result.add(['Total Records', '${totals.totalRecords} Recs']);
        result.add(['Total Amount', '₹${(totals.totalBasicSalary + totals.totalOtAmount).toStringAsFixed(2)}']);
        result.add(['Total Expense', '₹${(totals.totalMealsAmount + totals.totalBusAmount).toStringAsFixed(2)}']);
        result.add(['Grand Total', '₹${totals.totalEarnedSalary.toStringAsFixed(2)}']);
      }
    }
    if (result.isNotEmpty) {
      final colCount = result.first.length;
      for (int i = 0; i < result.length; i++) {
        if (result[i].length < colCount) {
          result[i] = [...result[i], ...List.filled(colCount - result[i].length, '')];
        } else if (result[i].length > colCount) {
          result[i] = result[i].sublist(0, colCount);
        }
      }
    }
    return result;
  }

  List<DataColumn> _headersToColumns(List<String> headers) {
    return headers.map((h) {
      return DataColumn(
        label: Text(
          h,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
        ),
      );
    }).toList();
  }


  // ── Unified Active Export Handlers ────────────────────────────────────────
  String _formatDateString(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == '-') return '-';
    try {
      final parsed = DateTime.parse(rawDate);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _exportActiveReport(String format) async {
    final reportName = _getActiveReportName();
    final tableData = _getReportTableData();

    if (format == 'pdf') {
      final doc = await _buildActivePDFDocument();
      final bytes = await doc.save();
      await _shareFile(bytes, '$reportName.pdf', 'application/pdf');
    } else if (format == 'excel') {
      await _exportTableDataToExcel(tableData, reportName);
    } else if (format == 'csv') {
      await _exportTableDataToCSV(tableData, reportName);
    }
  }

  Future<void> _exportTableDataToExcel(List<List<String>> tableData, String reportName) async {
    if (tableData.isEmpty) return;

    final excelDoc = excel.Excel.createExcel();
    final cleanSheetName = reportName.replaceAll('_', ' ');
    final sheet = excelDoc[cleanSheetName];

    if (excelDoc.sheets.containsKey('Sheet1') && cleanSheetName != 'Sheet1') {
      excelDoc.delete('Sheet1');
    }

    for (int i = 0; i < tableData.length; i++) {
      final row = tableData[i];
      final List<excel.CellValue> excelRow = row.map((cell) => excel.TextCellValue(cell)).toList();
      sheet.appendRow(excelRow);
    }

    final bytes = excelDoc.encode();
    if (bytes != null) {
      await _shareFile(bytes, '$reportName.xlsx', 'application/vnd.ms-excel');
    }
  }

  Future<void> _exportTableDataToCSV(List<List<String>> tableData, String reportName) async {
    if (tableData.isEmpty) return;

    final csvBuffer = StringBuffer();
    for (final row in tableData) {
      final escapedRow = row.map((cell) {
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(',');
      csvBuffer.writeln(escapedRow);
    }

    await _shareFile(csvBuffer.toString().codeUnits, '$reportName.csv', 'text/csv');
  }

  String _dateRangeText() {
    final startStr = startDate != null ? DateFormat('dd MMM yyyy').format(startDate!) : '-';
    final endStr = endDate != null ? DateFormat('dd MMM yyyy').format(endDate!) : '-';
    return '$startStr to $endStr';
  }



  // Generic PDF layouts
  Future<pw.Document> _buildPdfBase(
    String title,
    List<String> headers,
    List<List<String>> tableData, {
    Map<int, pw.TableColumnWidth>? columnWidths,
    PdfPageFormat? pageFormat,
    _ReportTotals? totals,
  }) async {
    final effectivePageFormat = pageFormat ?? PdfPageFormat.a3.landscape;
    final pdf = pw.Document();
    final now = DateTime.now();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: effectivePageFormat,
        margin: const pw.EdgeInsets.all(16),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(now)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Period: ${_dateRangeText()}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    if (selectedSiteName != null) pw.Text('Site: $selectedSiteName', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final double totalAmountVal = totals != null ? (totals.totalBasicSalary + totals.totalOtAmount) : 0.0;
          final double totalExpenseVal = totals != null ? (totals.totalMealsAmount + totals.totalBusAmount) : 0.0;
          final double grandTotalVal = totals != null ? totals.totalEarnedSalary : 0.0;

          return [
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              headers: headers,
              headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              columnWidths: columnWidths,
              data: tableData,
            ),
            if (totals != null) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.blue900, width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GRAND TOTAL SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.SizedBox(height: 2),
                        pw.Text('Filtered Records: ${totals.totalRecords} Recs | Subs: ${totals.totalSubContractors} | Workers: ${totals.totalWorkers}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Total Amount: ₹${totalAmountVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.SizedBox(height: 2),
                            pw.Text('Total Expense: ₹${totalExpenseVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                          ],
                        ),
                        pw.SizedBox(width: 16),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue900,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text('GRAND TOTAL', style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
                              pw.Text('₹${grandTotalVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );
    return pdf;
  }

  // 1. Details PDF
  Future<pw.Document> _buildDetailsPDFDocument() {
    final rows = _filteredReportData;
    final totals = _ReportTotals.fromRows(rows);
    final headers = [
      'Sl',
      'Date',
      'Co-ordinator',
      'Site Code',
      'Site Name',
      'Supervisor',
      'Contractor',
      'Worker Name',
      'Group',
      'Category',
      'Basic Wage',
      'Hrs',
      'OT Rate',
      'OT Hrs',
      'OT Amount',
      'Meals Exp',
      'Meals Count',
      'Meals Total',
      'Bus Fare',
      'Bus Count',
      'Bus Total',
      'Total Earned Amount',
    ];
    final data = List<List<String>>.generate(rows.length, (index) {
      final r = rows[index];
      return [
        '${index + 1}',
        _formatDate(r['date']?.toString()),
        r['coordinatorName']?.toString() ?? r['coordinator']?.toString() ?? '-',
        r['siteId']?.toString() ?? '-',
        r['siteName']?.toString() ?? '-',
        r['supervisorName']?.toString() ?? '-',
        r['subContractor']?.toString() ?? '-',
        r['workerName']?.toString() ?? '-',
        r['group']?.toString() ?? '-',
        r['category']?.toString() ?? '-',
        '₹${(r['salaryBasic'] as double).toStringAsFixed(2)}',
        (r['hours'] as double).toStringAsFixed(1),
        '₹${(r['otSalaryBasic'] as double).toStringAsFixed(2)}',
        (r['otHours'] as double).toStringAsFixed(1),
        '₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['mealsExpense'] as double).toStringAsFixed(2)}',
        '${r['mealsCount']}',
        '₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['busFare'] as double).toStringAsFixed(2)}',
        '${r['busCount']}',
        '₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalSalary'] as double).toStringAsFixed(2)}',
      ];
    });

    if (rows.isNotEmpty) {
      data.add([
        'TOTAL',
        '-',
        '-',
        '${totals.totalRecords} Recs',
        '-',
        '-',
        '${totals.totalSubContractors} Subs',
        '-',
        '-',
        '-',
        '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
        totals.totalHours.toStringAsFixed(1),
        '₹${totals.totalOtSalaryBasic.toStringAsFixed(2)}',
        totals.totalOtHours.toStringAsFixed(1),
        '₹${totals.totalOtAmount.toStringAsFixed(2)}',
        '₹${totals.totalMealsExpense.toStringAsFixed(2)}',
        '${totals.totalMealsCount}',
        '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
        '₹${totals.totalBusFare.toStringAsFixed(2)}',
        '${totals.totalBusCount}',
        '₹${totals.totalBusAmount.toStringAsFixed(2)}',
        '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
      ]);
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5),  // Sl
      1: const pw.FlexColumnWidth(1.2),  // Co-ordinator
      2: const pw.FlexColumnWidth(1.8),  // Site Code
      3: const pw.FlexColumnWidth(1.2),  // Site Name
      4: const pw.FlexColumnWidth(1.1),  // Supervisor
      5: const pw.FlexColumnWidth(1.2),  // Contractor
      6: const pw.FlexColumnWidth(1.2),  // Worker Name
      7: const pw.FlexColumnWidth(0.6),  // Group
      8: const pw.FlexColumnWidth(0.9),  // Category
      9: const pw.FlexColumnWidth(1.1),  // Basic Wage
      10: const pw.FlexColumnWidth(0.6), // Hrs
      11: const pw.FlexColumnWidth(1.0), // OT Rate
      12: const pw.FlexColumnWidth(0.6), // OT Hrs
      13: const pw.FlexColumnWidth(1.1), // OT Amount
      14: const pw.FlexColumnWidth(1.0), // Meals Exp
      15: const pw.FlexColumnWidth(0.7), // Meals Count
      16: const pw.FlexColumnWidth(1.0), // Meals Total
      17: const pw.FlexColumnWidth(1.0), // Bus Fare
      18: const pw.FlexColumnWidth(0.7), // Bus Count
      19: const pw.FlexColumnWidth(1.0), // Bus Total
      20: const pw.FlexColumnWidth(1.3), // Total Earned Amount
    };

    return _buildPdfBase(
      'SITE LABOUR DETAILS REPORT',
      headers,
      data,
      columnWidths: columnWidths,
      pageFormat: PdfPageFormat.a3.landscape,
      totals: totals,
    );
  }

  // 2. Attendance PDF
  Future<pw.Document> _buildAttendancePDFDocument() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);
    final currentGroups = _filteredSiteGroups;

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          final List<pw.Widget> content = [];
          content.add(pw.Text('SITE LABOUR ATTENDANCE REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)));
          content.add(pw.Text('Period: ${_dateRangeText()}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)));
          content.add(pw.SizedBox(height: 12));

          int totalAttendanceWorkers = 0;

          for (final site in currentGroups) {
            content.add(pw.Text('${site.siteName} (${site.siteCode})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
            for (final sup in site.supervisors) {
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: pw.Text('Supervisor: ${sup.supervisor}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ));
              
              final headers = ['Date', 'Co-ordinator', 'Category', 'Type', 'Sub Contractor', 'WorkersCount', 'OT Details', 'Remarks'];
              final data = sup.rows.map((row) {
                return [
                  row['date']?.toString() ?? '-',
                  row['coordinator']?.toString() ?? '-',
                  row['categoryType']?.toString() ?? '-',
                  row['labourType']?.toString() ?? '-',
                  row['subContractor']?.toString() ?? '-',
                  row['workerCount']?.toString() ?? '0',
                  row['otDetails']?.toString() ?? '-',
                  row['remarks']?.toString() ?? '-',
                ];
              }).toList();

              if (sup.rows.isNotEmpty) {
                int totalSupWorkers = sup.rows.fold(0, (sum, r) {
                  final wc = r['workerCount'];
                  if (wc is int) return sum + wc;
                  return sum + (int.tryParse(wc?.toString() ?? '') ?? 0);
                });
                totalAttendanceWorkers += totalSupWorkers;
                data.add(['TOTAL', '-', '-', '-', '${sup.rows.length} Entries', '$totalSupWorkers Workers', '-', '-']);
              }

              content.add(pw.Table.fromTextArray(
                context: context,
                headers: headers,
                headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 6),
                data: data,
              ));
              content.add(pw.SizedBox(height: 8));
            }
            content.add(pw.SizedBox(height: 12));
          }

          if (currentGroups.isNotEmpty) {
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.blue900, width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL ATTENDANCE WORKERS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('$totalAttendanceWorkers Workers', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ),
            );
          }

          return content;
        },
      ),
    );
    return pdf;
  }

  // 3. Daily Wage PDF
  Future<pw.Document> _buildDWPDFDocument() {
    final rows = _filteredReportData;
    final totals = _ReportTotals.fromRows(rows);
    final headers = ['Sl', 'Date', 'Co-ordinator', 'Site Name', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hrs', 'OT Hrs', 'OT Amt', 'Meals', 'Bus', 'Total Wages', 'Supervisor'];
    final data = List<List<String>>.generate(rows.length, (index) {
      final r = rows[index];
      return [
        '${index + 1}',
        r['date']?.toString() ?? '-',
        r['coordinatorName']?.toString() ?? r['coordinator']?.toString() ?? '-',
        r['siteName']?.toString() ?? '-',
        r['workerName']?.toString() ?? '-',
        r['category']?.toString() ?? '-',
        '₹${(r['salaryBasic'] as double).toStringAsFixed(2)}',
        r['attendanceType']?.toString() ?? '-',
        ((r['hours'] as double).toStringAsFixed(1)),
        ((r['otHours'] as double).toStringAsFixed(1)),
        '₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalSalary'] as double).toStringAsFixed(2)}',
        r['supervisorName']?.toString() ?? '-',
      ];
    });

    if (rows.isNotEmpty) {
      data.add([
        'TOTAL',
        '${totals.totalRecords} Recs',
        '-',
        '-',
        '-',
        '-',
        '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
        '-',
        (totals.totalHours.toStringAsFixed(1)),
        (totals.totalOtHours.toStringAsFixed(1)),
        '₹${totals.totalOtAmount.toStringAsFixed(2)}',
        '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
        '₹${totals.totalBusAmount.toStringAsFixed(2)}',
        '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
        '-',
      ]);
    }
    return _buildPdfBase('DAILY WAGE LABOUR REPORT', headers, data, totals: totals);
  }

  // 4. Sub Contractor PDF
  Future<pw.Document> _buildSCPDFDocument() {
    final rows = _filteredReportData;
    final totals = _ReportTotals.fromRows(rows);
    final headers = ['Sl', 'Date', 'Co-ordinator', 'Site Name', 'Contractor', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hrs', 'OT Hrs', 'OT Amt', 'Meals', 'Bus', 'Total Earned', 'Supervisor'];
    final data = List<List<String>>.generate(rows.length, (index) {
      final r = rows[index];
      return [
        '${index + 1}',
        r['date']?.toString() ?? '-',
        r['coordinatorName']?.toString() ?? r['coordinator']?.toString() ?? '-',
        r['siteName']?.toString() ?? '-',
        r['subContractor']?.toString() ?? '-',
        r['workerName']?.toString() ?? '-',
        r['category']?.toString() ?? '-',
        '₹${(r['salaryBasic'] as double).toStringAsFixed(2)}',
        r['attendanceType']?.toString() ?? '-',
        ((r['hours'] as double).toStringAsFixed(1)),
        ((r['otHours'] as double).toStringAsFixed(1)),
        '₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}',
        '₹${(r['totalSalary'] as double).toStringAsFixed(2)}',
        r['supervisorName']?.toString() ?? '-',
      ];
    });

    if (rows.isNotEmpty) {
      data.add([
        'TOTAL',
        '${totals.totalRecords} Recs',
        '-',
        '-',
        '${totals.totalSubContractors} Subs',
        '-',
        '-',
        '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
        '-',
        (totals.totalHours.toStringAsFixed(1)),
        (totals.totalOtHours.toStringAsFixed(1)),
        '₹${totals.totalOtAmount.toStringAsFixed(2)}',
        '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
        '₹${totals.totalBusAmount.toStringAsFixed(2)}',
        '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
        '-',
      ]);
    }
    return _buildPdfBase('SUB CONTRACTOR LABOUR DETAILS REPORT', headers, data, totals: totals);
  }

  // 5. Worker on Site PDF
  Future<pw.Document> _buildPresencePDFDocument() {
    final rows = _filteredReportData;
    final headers = ['Sub Contractor Name', 'Site Code', 'Labour Type'];
    final allocations = _getWorkerOnSiteAllocations(rows);
    final List<List<String>> data = [];

    for (final alloc in allocations) {
      for (int i = 0; i < alloc.sites.length; i++) {
        final site = alloc.sites[i];
        data.add([
          i == 0 ? alloc.subContractor : '',
          site.siteId,
          site.labourType,
        ]);
      }
    }

    if (allocations.isNotEmpty) {
      int totalSites = allocations.fold(0, (sum, a) => sum + a.sites.length);
      data.add(['TOTAL', '${allocations.length} Subs', '$totalSites Sites']);
    }
    return _buildPdfBase('WORKERS ON SITE REPORT', headers, data);
  }

  // 6. Sub Contractor Bill PDF
  Future<pw.Document> _buildBillPDFDocument() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    final rows = _filteredReportData;
    final totals = _ReportTotals.fromRows(rows);
    final periodText = 'FROM ${startDate != null ? DateFormat('dd/MMM/yy').format(startDate!).toUpperCase() : '-'} TO ${endDate != null ? DateFormat('dd/MMM/yy').format(endDate!).toUpperCase() : '-'}';
    final reportDate = DateFormat('dd-MMM-yy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (context) {
          final detailHeaders = ['Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker', 'Category', 'Hrs', 'OT Hrs', 'Basic Wage', 'Std Amt', 'OT Amt', 'Meals', 'Bus', 'Total Bill'];
          
          final detailData = List<List<String>>.generate(rows.length, (index) {
            final r = rows[index];
            final ot = (r['otTotalAmount'] as num? ?? 0).toDouble();
            final total = (r['totalSalary'] as num? ?? 0).toDouble();
            final stdAmt = total - ot;
            final hrs = (r['hours'] as num? ?? 0).toDouble();
            final otHrs = (r['otHours'] as num? ?? 0).toDouble();
            final meals = (r['totalMealsAmount'] as num? ?? 0).toDouble();
            final bus = (r['totalBusAmount'] as num? ?? 0).toDouble();

            return [
              '${index + 1}',
              _formatDateString(r['date']?.toString()),
              r['siteName']?.toString() ?? '-',
              r['subContractor']?.toString() ?? '-',
              r['workerName']?.toString() ?? '-',
              r['category']?.toString() ?? '-',
              hrs.toStringAsFixed(1),
              otHrs.toStringAsFixed(1),
              '₹${(r['salaryBasic'] as double).toStringAsFixed(2)}',
              '₹${stdAmt.toStringAsFixed(2)}',
              '₹${ot.toStringAsFixed(2)}',
              '₹${meals.toStringAsFixed(2)}',
              '₹${bus.toStringAsFixed(2)}',
              '₹${total.toStringAsFixed(2)}',
            ];
          });

          if (rows.isNotEmpty) {
            detailData.add([
              'TOTAL',
              '${totals.totalRecords} Recs',
              '-',
              '${totals.totalSubContractors} Subs',
              '-', '-',
              totals.totalHours.toStringAsFixed(1),
              totals.totalOtHours.toStringAsFixed(1),
              '₹${totals.totalBasicSalary.toStringAsFixed(2)}',
              '₹${totals.totalStdAmount.toStringAsFixed(2)}',
              '₹${totals.totalOtAmount.toStringAsFixed(2)}',
              '₹${totals.totalMealsAmount.toStringAsFixed(2)}',
              '₹${totals.totalBusAmount.toStringAsFixed(2)}',
              '₹${totals.totalEarnedSalary.toStringAsFixed(2)}',
            ]);
          }

          final double totalAmountVal = totals.totalBasicSalary + totals.totalOtAmount;
          final double totalExpenseVal = totals.totalMealsAmount + totals.totalBusAmount;
          final double grandTotalVal = totals.totalEarnedSalary;

          return [
            pw.Center(
              child: pw.Text(
                'SUB - CONTRACTOR BILL REPORT',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report Date: $reportDate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('Period: $periodText', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              context: context,
              headers: detailHeaders,
              headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 6),
              data: detailData,
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blue900, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GRAND TOTAL SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 2),
                      pw.Text('Filtered Records: ${totals.totalRecords} Recs | Subs: ${totals.totalSubContractors}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Total Amount: ₹${totalAmountVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.SizedBox(height: 2),
                          pw.Text('Total Expense: ₹${totalExpenseVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                        ],
                      ),
                      pw.SizedBox(width: 16),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue900,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('GRAND TOTAL', style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
                            pw.Text('₹${grandTotalVal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  // Helper file shares
  Future<void> _shareFile(List<int> bytes, String filename, String mimeType) async {
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Export failed: Empty data bytes.'), backgroundColor: errorColor),
      );
      return;
    }

    if (kIsWeb) {
      try {
        downloadFileWeb(Uint8List.fromList(bytes), filename, mimeType);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Web download failed: $e'), backgroundColor: errorColor),
        );
      }
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        
        // Save the file using await file.writeAsBytes(bytes, flush: true)
        await file.writeAsBytes(bytes, flush: true);
        
        // Validate the implementation
        final fileExists = await file.exists();
        final fileSize = fileExists ? await file.length() : 0;
        
        print('PDF Bytes: ${bytes.length}');
        print('File Exists: $fileExists');
        print('File Size: $fileSize');
        print('File Path: ${file.path}');
        
        if (bytes.isNotEmpty && fileExists && fileSize > 0) {
          // Open the file using OpenFile
          final result = await OpenFile.open(file.path);
          debugPrint('OpenFile Result: ${result.message}');
          
          // Trigger the share dialog to allow user to copy/save to system folders
          final box = context.findRenderObject() as RenderBox?;
          Rect sharePositionOrigin;
          if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
            sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
          } else {
            final mediaQuery = MediaQuery.maybeOf(context);
            final size = mediaQuery?.size ?? const Size(300, 300);
            sharePositionOrigin = Rect.fromLTWH(0, 0, size.width, size.height / 2);
          }

          await Share.shareXFiles(
            [XFile(file.path)],
            text: filename,
            sharePositionOrigin: sharePositionOrigin,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification failed: Written file is empty ($fileSize bytes).'),
                backgroundColor: errorColor,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Exception during export: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save or open file: $e'), backgroundColor: errorColor),
          );
        }
      }
    }
  }


}

class _SiteGroup {
  final String siteCode;
  final String siteName;
  final int totalCount;
  final List<_SupervisorGroup> supervisors;
  _SiteGroup({required this.siteCode, required this.siteName, required this.totalCount, required this.supervisors});
}

class _SupervisorGroup {
  final String supervisor;
  final int totalCount;
  final List<Map<String, dynamic>> rows;
  _SupervisorGroup({required this.supervisor, required this.totalCount, required this.rows});
}

class _DropdownOption {
  final String id;
  final String label;
  const _DropdownOption({required this.id, required this.label});
}

class _SubContractorAllocation {
  final String subContractor;
  final List<_SiteAllocationItem> sites;
  _SubContractorAllocation({required this.subContractor, required this.sites});
}

class _SiteAllocationItem {
  final String siteId;
  final String labourType;
  _SiteAllocationItem({required this.siteId, required this.labourType});
}

class _ExportPreviewDialogContent extends StatefulWidget {
  final String format;
  final String reportType;
  final Future<pw.Document> Function() buildPdfDoc;
  final String reportName;
  final Future<void> Function() onDownload;
  final List<List<String>> tableData;
  final Color primaryColor;

  const _ExportPreviewDialogContent({
    required this.format,
    required this.reportType,
    required this.buildPdfDoc,
    required this.reportName,
    required this.onDownload,
    required this.tableData,
    required this.primaryColor,
  });

  @override
  State<_ExportPreviewDialogContent> createState() => _ExportPreviewDialogContentState();
}

class _ExportPreviewDialogContentState extends State<_ExportPreviewDialogContent> {
  bool _isLoading = true;
  Uint8List? _pdfBytes;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  Future<void> _loadPreviewData() async {
    try {
      if (widget.format == 'pdf') {
        final doc = await widget.buildPdfDoc();
        final bytes = await doc.save();
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading preview: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.format.toUpperCase()} Preview";
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Preview Body
        Flexible(
          child: Container(
            color: Colors.grey.shade100,
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
            child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : widget.format == 'pdf'
                    ? (_pdfBytes != null
                        ? PdfPreview(
                            build: (format) => _pdfBytes!,
                            allowPrinting: false,
                            allowSharing: false,
                            canChangeOrientation: false,
                            canChangePageFormat: false,
                            canDebug: false,
                            maxPageWidth: 800,
                            pdfPreviewPageDecoration: BoxDecoration(
                              color: Colors.grey.shade100,
                            ),
                            loadingWidget: Center(
                              child: CircularProgressIndicator(color: widget.primaryColor),
                            ),
                          )
                        : const Center(child: Text('Error generating PDF preview')))
                    : _buildTabularPreview(),
          ),
        ),
        const Divider(height: 1),
        
        // Actions Footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cancel Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
              
              if (!_isLoading) ...[
                const SizedBox(width: 12),
                // Download Button
                ElevatedButton(
                  onPressed: () async {
                    final localBytes = _pdfBytes;
                    if (localBytes == null && widget.format == 'pdf') return;

                    setState(() => _isLoading = true);
                    try {
                      await widget.onDownload();
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('Error during download/save: $e');
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32), // Premium Green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Download'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabularPreview() {
    if (widget.tableData.isEmpty) {
      return const Center(child: Text('No preview data available'));
    }
    final headers = widget.tableData.first;
    final rawRows = widget.tableData.sublist(1);
    final colCount = headers.length;

    final rows = rawRows.map((row) {
      if (row.length == colCount) return row;
      if (row.length < colCount) {
        return [...row, ...List.filled(colCount - row.length, '')];
      }
      return row.sublist(0, colCount);
    }).toList();

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: widget.primaryColor.withValues(alpha: 0.08)),
                  children: headers.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      h,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  )).toList(),
                ),
                ...rows.map((row) => TableRow(
                  children: row.map((cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      cell,
                      style: const TextStyle(fontSize: 11),
                    ),
                  )).toList(),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteAttendanceCardItem extends StatefulWidget {
  final _SiteGroup site;
  final String searchQuery;

  const _SiteAttendanceCardItem({
    required this.site,
    required this.searchQuery,
  });

  @override
  State<_SiteAttendanceCardItem> createState() => _SiteAttendanceCardItemState();
}

class _SiteAttendanceCardItemState extends State<_SiteAttendanceCardItem> {
  bool _isExpanded = true;

  String _cleanSiteName(String name) {
    return name.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final searchQuery = widget.searchQuery;

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      final siteMatch =
          site.siteCode.toLowerCase().contains(q) ||
          site.siteName.toLowerCase().contains(q);
      final hasMatch = site.supervisors.any((sup) =>
          sup.supervisor.toLowerCase().contains(q) ||
          sup.rows.any((r) =>
              (r['subContractor']?.toString().toLowerCase().contains(q) ??
                  false) ||
              (r['categoryType']?.toString().toLowerCase().contains(q) ??
                  false)));
      if (!siteMatch && !hasMatch) return const SizedBox.shrink();
    }

    const primaryColor = Color(0xFFD84315);
    const primaryLight = Color(0xFFE64A19);
    const cardColor = Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner (tappable to expand/collapse)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isExpanded ? 0 : 12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, primaryLight],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: Radius.circular(_isExpanded ? 0 : 12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanSiteName(site.siteName.isNotEmpty ? site.siteName : site.siteCode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Total: ${site.totalCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          // Attendance Table Body (Single detailed attendance register per site)
          if (_isExpanded)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowHeight: 40,
                dataRowHeight: 44,
                headingRowColor: WidgetStateProperty.all(
                  primaryColor.withValues(alpha: 0.08),
                ),
                columns: const [
                  DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Co-ordinator', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Site Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Supervisor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('CT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('LT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Sub.Contractor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Nos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                  DataColumn(label: Text('OT/ST Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: primaryColor))),
                ],
                rows: _buildRegisterRows(site),
              ),
            ),
        ],
      ),
    );
  }

  List<DataRow> _buildRegisterRows(_SiteGroup site) {
    final rows = <DataRow>[];
    bool firstSiteRow = true;
    int sNoCounter = 1;
    int grandTotalWorkers = 0;

    for (final sup in site.supervisors) {
      for (int i = 0; i < sup.rows.length; i++) {
        final r = sup.rows[i];
        final showSupervisor = i == 0;
        final workerCnt = (r['workerCount'] as int? ?? 0);
        grandTotalWorkers += workerCnt;

        final isLastRowOfSite = (sup == site.supervisors.last) && (i == sup.rows.length - 1);

        rows.add(DataRow(
          cells: [
            DataCell(Text('$sNoCounter', style: const TextStyle(fontSize: 11))),
            DataCell(Text(_formatDate(r['date']?.toString()), style: const TextStyle(fontSize: 11))),
            DataCell(Text(r['coordinator']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
            DataCell(Text(firstSiteRow ? site.siteCode : '', style: TextStyle(fontSize: 11, fontWeight: firstSiteRow ? FontWeight.w600 : FontWeight.normal))),
            DataCell(Text(showSupervisor ? sup.supervisor : '', style: TextStyle(fontSize: 11, fontWeight: showSupervisor ? FontWeight.w600 : FontWeight.normal))),
            DataCell(Text(r['categoryType']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
            DataCell(Text(r['labourType']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
            DataCell(Text(r['subContractor']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
            DataCell(Text('$workerCnt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            DataCell(Text(isLastRowOfSite ? '$grandTotalWorkers' : '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD84315)))),
            DataCell(Text(r['otDetails']?.toString() ?? '-', style: const TextStyle(fontSize: 10))),
          ],
        ));
        firstSiteRow = false;
        sNoCounter++;
      }
    }
    return rows;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
    return raw;
  }
}
