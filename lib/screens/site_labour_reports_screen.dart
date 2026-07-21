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

class SiteLabourReportsScreen extends StatefulWidget {
  const SiteLabourReportsScreen({super.key});

  @override
  State<SiteLabourReportsScreen> createState() => _SiteLabourReportsScreenState();
}

class _SiteLabourReportsScreenState extends State<SiteLabourReportsScreen> {
  // Colors & Design
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLight = const Color(0xFF1a4a8c);
  final Color accentColor = const Color(0xFF4a86e8);
  final Color bgColor = const Color(0xFFf0f4f9);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF1e293b);
  final Color mutedColor = const Color(0xFF64748b);
  final Color successColor = const Color(0xFF16a34a);
  final Color errorColor = const Color(0xFFdc2626);

  // List of report types
  final List<String> reportTypes = [
    'Site Labour Details Report',
    'Site Labour Attendance Report',
    'Daily Wage Report',
    'Sub Contractor Report',
    'Worker on Site Report',
    'Sub Contractor Bill Report',
  ];
  String selectedReportType = 'Site Labour Details Report';

  // Filters State
  DateTime? startDate;
  DateTime? endDate;
  String? selectedSiteId;
  String? selectedSiteName;
  String? selectedSupervisorName;
  String? selectedSubContractorName;
  String? selectedLabourType = 'All';

  // Bill Details for exports
  final TextEditingController _billNoController = TextEditingController(text: 'BILL-2026-001');
  final TextEditingController _workTypeController = TextEditingController(text: 'Contract Work');
  final TextEditingController _narrationController = TextEditingController(text: 'Outer back side plastering work (Maintenance) courtyard glass cutting work');

  // Dropdown list data
  List<_DropdownOption> siteOptions = [];
  List<_DropdownOption> supervisorOptions = [];
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
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = now;
    endDate = now;
    _loadFilterData().then((_) {
      _generateReport();
    });
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _workTypeController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  // Load Dropdown Options
  Future<void> _loadFilterData() async {
    setState(() => isLoadingFilters = true);
    try {
      final results = await Future.wait([
        _fetchSites(),
        _fetchSupervisors(),
        _fetchContractors(),
      ]);
      setState(() {
        siteOptions = results[0];
        supervisorOptions = results[1];
        contractorOptions = results[2];
        isLoadingFilters = false;
      });
    } catch (_) {
      setState(() => isLoadingFilters = false);
    }
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
      final now = DateTime.now();
      startDate = now;
      endDate = now;
      selectedSiteId = null;
      selectedSiteName = null;
      selectedSupervisorName = null;
      selectedSubContractorName = null;
      selectedLabourType = 'All';
      searchQuery = '';
    });
    _generateReport();
  }

  // Unified Query logic
  Future<void> _generateReport() async {
    setState(() {
      isLoading = true;
      reportGenerated = true;
    });

    try {
      final startStr = startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : null;
      final endStr = endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : null;

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('daily_labour_entries');

      if (selectedSiteId != null) {
        query = query.where('siteId', isEqualTo: selectedSiteId);
      }
      if (startStr != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startStr);
      }
      if (endStr != null) {
        query = query.where('date', isLessThanOrEqualTo: endStr);
      }

      final snap = await query.get();
      List<Map<String, dynamic>> entries = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_docId'] = d.id;
        return data;
      }).toList();

      // Merge site_labour_reports if attendance report is active
      if (selectedReportType == 'Site Labour Attendance Report') {
        try {
          Query<Map<String, dynamic>> altQuery = FirebaseFirestore.instance.collection('site_labour_reports');
          if (startStr != null) {
            altQuery = altQuery.where('date', isGreaterThanOrEqualTo: startStr);
          }
          if (endStr != null) {
            altQuery = altQuery.where('date', isLessThanOrEqualTo: endStr);
          }
          final altSnap = await altQuery.get();
          for (final d in altSnap.docs) {
            final data = Map<String, dynamic>.from(d.data());
            data['_docId'] = d.id;
            data['siteId'] = data['siteCode'] ?? data['siteId'];
            data['supervisorName'] = data['supervisor'] ?? data['supervisorName'];
            data['category'] = data['categoryType'] ?? data['category'];
            data['labourType'] = data['labourType'];
            data['contractorName'] = data['subContractor'] ?? data['contractorName'];
            entries.add(data);
          }
        } catch (_) {}
      }

      // Fetch subcontractors salary mappings
      final subContractorsSnap = await FirebaseFirestore.instance.collection('sub_contractors').get();
      final subContractorSalaryById = <String, double>{};
      final subContractorSalaryByName = <String, double>{};
      for (final doc in subContractorsSnap.docs) {
        final data = doc.data();
        final salary = data['salaryRate'] ?? data['basicSalary'] ?? data['salary'];
        final salaryValue = salary is num ? salary.toDouble() : double.tryParse(salary?.toString() ?? '') ?? 0.0;
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

      // Client-side Filters
      if (selectedSupervisorName != null) {
        entries = entries.where((e) => (e['supervisorName']?.toString() ?? '') == selectedSupervisorName).toList();
      }
      if (selectedSubContractorName != null) {
        entries = entries.where((e) {
          final sc = (e['contractorName'] ?? e['subContractorName'] ?? e['contractor'] ?? '').toString().trim();
          return sc == selectedSubContractorName;
        }).toList();
      }
      if (selectedLabourType != null && selectedLabourType != 'All') {
        entries = entries.where((e) {
          final lt = (e['labourType'] ?? e['salaryType'])?.toString().trim().toLowerCase() ?? '';
          final isDW = lt == 'dw' || lt.contains('daily');
          if (selectedLabourType == 'Daily Wage (DW)') return isDW;
          if (selectedLabourType == 'Sub Contractor (SC)') return !isDW;
          return true;
        }).toList();
      }

      // Report-specific processing
      _processReportData(entries, subContractorSalaryById, subContractorSalaryByName);

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: errorColor),
        );
      }
    }
  }

  void _processReportData(
    List<Map<String, dynamic>> entries,
    Map<String, double> subContractorSalaryById,
    Map<String, double> subContractorSalaryByName,
  ) {
    final List<Map<String, dynamic>> rows = [];
    double costTotal = 0;
    double mealsAmountTotal = 0;
    int mealsCountTotal = 0;
    double busAmountTotal = 0;
    int busCountTotal = 0;

    for (final e in entries) {
      final siteId = e['siteId']?.toString() ?? '-';
      final siteName = e['siteName']?.toString() ?? '-';
      final subContractor = (e['contractorName'] ?? e['subContractorName'] ?? e['contractor'] ?? '-').toString().trim();
      final labourType = (e['labourType'] ?? e['salaryType'])?.toString().trim().toLowerCase() ?? '';
      final isDW = labourType == 'dw' || labourType.contains('daily');
      final group = isDW ? 'DW' : 'SC';
      final category = e['category']?.toString() ?? '-';
      final workerName = (e['workerName'] ?? e['name'] ?? '-').toString();
      final date = e['date']?.toString() ?? '-';

      final subContractorSalary = group == 'SC'
          ? (subContractorSalaryById[e['contractorId']?.toString()] ??
                subContractorSalaryByName[subContractor.toLowerCase()] ??
                0.0)
          : 0.0;

      final entrySalaryBasic = (e['basicSalary'] as num?)?.toDouble() ??
          (e['salaryBasic'] as num?)?.toDouble() ??
          (e['rate'] as num?)?.toDouble() ??
          0.0;
      final salaryBasic = entrySalaryBasic > 0
          ? entrySalaryBasic
          : (group == 'SC' && subContractorSalary > 0 ? subContractorSalary : 0.0);
      final hoursWorked = (e['hoursWorked'] as num?)?.toDouble() ?? (e['hours'] as num?)?.toDouble() ?? 0.0;
      final otHours = e['otHours'] ?? e['overtimeHours'];
      final doubleOtHours = otHours is num ? otHours.toDouble() : double.tryParse(otHours?.toString().split(' ').first ?? '0.0') ?? 0.0;
      final defaultHrs = (e['defaultHours'] as num?)?.toDouble() ?? 8.0;

      double basicHours;
      if (hoursWorked > doubleOtHours) {
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

      final recordedTotalSalary = (e['totalSalary'] as num?)?.toDouble() ?? (e['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final overtimeAmt = (e['overtimeAmount'] as num?)?.toDouble() ?? (e['otAmount'] as num?)?.toDouble() ?? 0.0;
      final mealsCount = (e['mealsCount'] as num?)?.toInt() ?? 0;
      final mealsAmount = (e['mealsAmount'] as num?)?.toDouble() ?? 0.0;
      final totalMealsAmt = mealsCount * mealsAmount;

      final busCount = (e['busCount'] as num?)?.toInt() ?? 0;
      final busAmount = (e['busAmount'] as num?)?.toDouble() ?? 0.0;
      final totalBusAmt = busCount * busAmount;

      final totalSalary = (recordedTotalSalary >= (salaryBasic + overtimeAmt) && recordedTotalSalary > 0)
          ? recordedTotalSalary
          : (salaryBasic + overtimeAmt + totalMealsAmt + totalBusAmt);
      double otRate = (e['overtimeRate'] as num?)?.toDouble() ??
          (e['otRate'] as num?)?.toDouble() ??
          (e['otSalaryBasic'] as num?)?.toDouble() ??
          0.0;
      if (otRate == 0.0) {
        if (doubleOtHours > 0 && overtimeAmt > 0) {
          otRate = overtimeAmt / doubleOtHours;
        } else if (salaryBasic > 0 && defaultHrs > 0) {
          otRate = (salaryBasic / defaultHrs) * 1.5;
        }
      }

      rows.add({
        'siteId': siteId,
        'siteName': siteName,
        'subContractor': subContractor,
        'workerName': workerName,
        'group': group,
        'category': category,
        'labourCount': 1,
        'salaryBasic': salaryBasic,
        'totalSalary': totalSalary,
        'hours': basicHours,
        'otSalaryBasic': otRate,
        'otTotalAmount': overtimeAmt,
        'mealsExpense': mealsAmount,
        'mealsCount': mealsCount,
        'totalMealsAmount': totalMealsAmt,
        'busFare': busAmount,
        'busCount': busCount,
        'totalBusAmount': totalBusAmt,
        'otHours': doubleOtHours,
        'date': date,
        'attendanceType': e['attendanceType']?.toString() ?? 'Full Day',
        'inTime': e['inTime']?.toString() ?? '',
        'outTime': e['outTime']?.toString() ?? '',
        'supervisorName': e['supervisorName']?.toString() ?? '-',
        'remarks': e['remarks']?.toString() ?? '',
      });

      costTotal += totalSalary;
      mealsAmountTotal += totalMealsAmt;
      mealsCountTotal += mealsCount;
      busAmountTotal += totalBusAmt;
      busCountTotal += busCount;
    }

    // Now filter according to specific report requirements
    if (selectedReportType == 'Daily Wage Report') {
      reportData = rows.where((r) => r['group'] == 'DW').toList();
    } else if (selectedReportType == 'Sub Contractor Report') {
      reportData = rows.where((r) => r['group'] == 'SC').toList();
    } else if (selectedReportType == 'Worker on Site Report') {
      // Physical presence: filter active workers
      reportData = rows.where((r) => r['attendanceType'] != 'Absent' && r['attendanceType'] != 'Leave').toList();
    } else {
      reportData = rows;
    }

    // Update Totals Based on final lists
    totalWorkers = reportData.length;
    totalLabourCost = reportData.fold(0.0, (sum, r) => sum + (r['totalSalary'] as double));
    totalMealsAmount = reportData.fold(0.0, (sum, r) => sum + (r['totalMealsAmount'] as double));
    totalMealsCount = reportData.fold(0, (sum, r) => sum + (r['mealsCount'] as int));
    totalBusAmount = reportData.fold(0.0, (sum, r) => sum + (r['totalBusAmount'] as double));
    totalBusCount = reportData.fold(0, (sum, r) => sum + (r['busCount'] as int));

    // Secondary processing for attendance report
    _buildAttendanceGroupData(entries);

    // Secondary processing for subcontractor bill report
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
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 32),
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
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Site Labour Reports',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
      ),
      centerTitle: true,
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _showDownloadOptionsSheet,
          tooltip: 'Export Report',
        ),
      ],
    );
  }

  Widget _buildReportSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedReportType,
        dropdownColor: cardColor,
        isExpanded: true,
        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: 'Report Type',
          labelStyle: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.normal),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
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
      ),
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
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: mutedColor),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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

    return DropdownButtonFormField<String>(
      initialValue: validValue,
      isExpanded: true,
      dropdownColor: cardColor,
      style: TextStyle(color: textColor, fontSize: 13),
      hint: Text('Select $label', style: TextStyle(color: mutedColor, fontSize: 12)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: mutedColor),
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All', style: TextStyle(color: mutedColor)),
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
              Expanded(child: _buildDateField('From Date', startDate, (d) => setState(() { startDate = d; _generateReport(); }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDateField('To Date', endDate, (d) => setState(() { endDate = d; _generateReport(); }))),
            ],
          ),
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
              Expanded(child: _buildDynamicDropdown(label: 'Sub Contractor', options: contractorOptions, value: selectedSubContractorName, onChanged: (opt) => setState(() { selectedSubContractorName = opt?.id; _generateReport(); }))),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedLabourType,
                  isExpanded: true,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Labour Type',
                    labelStyle: TextStyle(fontSize: 12, color: mutedColor),
                    filled: true,
                    fillColor: bgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
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





  // ── Result Area Routing ──────────────────────────────────────────────────
  Widget _buildResultArea() {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    if (reportGenerated && reportData.isEmpty && siteGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: _buildEmptyState(),
      );
    }

    // Client-side search filters
    List<Map<String, dynamic>> filteredRows = reportData;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filteredRows = reportData.where((row) {
        return (row['workerName']?.toString().toLowerCase().contains(q) ?? false) ||
            (row['subContractor']?.toString().toLowerCase().contains(q) ?? false) ||
            (row['siteName']?.toString().toLowerCase().contains(q) ?? false) ||
            (row['category']?.toString().toLowerCase().contains(q) ?? false) ||
            (row['supervisorName']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }

    Widget reportWidget;
    switch (selectedReportType) {
      case 'Site Labour Details Report':
        reportWidget = _buildDetailsTable(filteredRows);
        break;
      case 'Site Labour Attendance Report':
        reportWidget = _buildAttendanceList();
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
        if (filteredRows.isNotEmpty || siteGroups.isNotEmpty)
          _buildSummaryKpiBanner(filteredRows),
        reportWidget,
      ],
    );
  }

  Widget _buildSummaryKpiBanner(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'REPORT TOTALS & SUMMARY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totals.totalRecords} Records',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 9, color: mutedColor, fontWeight: FontWeight.w500),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.bold,
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
    final List<DataRow> dataRows = List.generate(rows.length, (index) {
      final r = rows[index];
      return DataRow(cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(r['siteId']?.toString() ?? '-')),
        DataCell(Text(r['siteName']?.toString() ?? '-')),
        DataCell(Text(r['subContractor']?.toString() ?? '-')),
        DataCell(Text(r['workerName']?.toString() ?? '-')),
        DataCell(Text(r['group']?.toString() ?? '-')),
        DataCell(Text(r['category']?.toString() ?? '-')),
        DataCell(Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}')),
        DataCell(Text((r['hours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(r['otSalaryBasic'] as double).toStringAsFixed(2)}')),
        DataCell(Text((r['otHours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['mealsExpense'] as double).toStringAsFixed(2)}')),
        DataCell(Text('${r['mealsCount']}')),
        DataCell(Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['busFare'] as double).toStringAsFixed(2)}')),
        DataCell(Text('${r['busCount']}')),
        DataCell(Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalSalary'] as double).toStringAsFixed(2)}')),
      ]);
    });

    if (rows.isNotEmpty) {
      dataRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(Text('${totals.totalSubContractors} Subs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalOtSalaryBasic.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalMealsExpense.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${totals.totalMealsCount}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBusFare.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${totals.totalBusCount}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(primaryColor),
          columns: _headersToColumns([
            'Sl', 'Site Code', 'Site Name', 'Contractor', 'Worker Name', 'Group',
            'Category', 'Basic Wage', 'Hrs', 'OT Rate', 'OT Hrs', 'OT Amount',
            'Meals Exp', 'Meals Count', 'Meals Total', 'Bus Fare', 'Bus Count', 'Bus Total',
            'Total Earned Amount'
          ]),
          rows: dataRows,
        ),
      ),
    );
  }

  // ── 2. Attendance List Layout (Grouped Site/Supervisor) ──────────────────
  Widget _buildAttendanceList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: siteGroups.length,
      itemBuilder: (context, index) {
        final site = siteGroups[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: cardColor,
          elevation: 2,
          child: ExpansionTile(
            title: Text(site.siteName, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
            subtitle: Text('Site ID: ${site.siteCode} • ${site.totalCount} Workers Total'),
            children: site.supervisors.map((sup) {
              final List<DataRow> supRows = sup.rows.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['date']?.toString() ?? '-')),
                  DataCell(Text(row['categoryType']?.toString() ?? '-')),
                  DataCell(Text(row['labourType']?.toString() ?? '-')),
                  DataCell(Text(row['subContractor']?.toString() ?? '-')),
                  DataCell(Text(row['workerCount']?.toString() ?? '0')),
                  DataCell(Text(row['otDetails']?.toString() ?? '-')),
                  DataCell(Text(row['remarks']?.toString() ?? '-')),
                ]);
              }).toList();

              if (sup.rows.isNotEmpty) {
                int totalSupWorkers = sup.rows.fold(0, (sum, r) {
                  final wc = r['workerCount'];
                  if (wc is int) return sum + wc;
                  return sum + (int.tryParse(wc?.toString() ?? '') ?? 0);
                });
                supRows.add(
                  DataRow(
                    color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
                    cells: [
                      DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                      const DataCell(Text('-')),
                      const DataCell(Text('-')),
                      DataCell(Text('${sup.rows.length} Entries', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('$totalSupWorkers Workers', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                      const DataCell(Text('-')),
                      const DataCell(Text('-')),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Card(
                  color: bgColor,
                  child: ExpansionTile(
                    title: Text('Supervisor: ${sup.supervisor}', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: Text('${sup.rows.length} Allocations'),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 10,
                          columns: _headersToColumns(['Date', 'Category', 'Type', 'Sub Contractor', 'Workers', 'OT Details', 'Remarks']),
                          rows: supRows,
                        ),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── 3. Daily Wage Table Layout ───────────────────────────────────────────
  Widget _buildDailyWageTable(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    final List<DataRow> dataRows = List.generate(rows.length, (index) {
      final r = rows[index];
      return DataRow(cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(r['date']?.toString() ?? '-')),
        DataCell(Text(r['siteName']?.toString() ?? '-')),
        DataCell(Text(r['workerName']?.toString() ?? '-')),
        DataCell(Text(r['category']?.toString() ?? '-')),
        DataCell(Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}')),
        DataCell(Text(r['attendanceType']?.toString() ?? '-')),
        DataCell(Text((r['hours'] as double).toStringAsFixed(1))),
        DataCell(Text((r['otHours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalSalary'] as double).toStringAsFixed(2)}')),
        DataCell(Text(r['supervisorName']?.toString() ?? '-')),
        DataCell(Text(r['remarks']?.toString() ?? '-')),
      ]);
    });

    if (rows.isNotEmpty) {
      dataRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(primaryColor),
          columns: _headersToColumns([
            'Sl', 'Date', 'Site Name', 'Worker Name', 'Category', 'Basic Rate',
            'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Wages', 'Supervisor', 'Remarks'
          ]),
          rows: dataRows,
        ),
      ),
    );
  }

  // ── 4. Sub Contractor Table Layout ───────────────────────────────────────
  Widget _buildSubContractorTable(List<Map<String, dynamic>> rows) {
    final totals = _ReportTotals.fromRows(rows);
    final List<DataRow> dataRows = List.generate(rows.length, (index) {
      final r = rows[index];
      return DataRow(cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(r['date']?.toString() ?? '-')),
        DataCell(Text(r['siteName']?.toString() ?? '-')),
        DataCell(Text(r['subContractor']?.toString() ?? '-')),
        DataCell(Text(r['workerName']?.toString() ?? '-')),
        DataCell(Text(r['category']?.toString() ?? '-')),
        DataCell(Text('₹${(r['salaryBasic'] as double).toStringAsFixed(2)}')),
        DataCell(Text(r['attendanceType']?.toString() ?? '-')),
        DataCell(Text((r['hours'] as double).toStringAsFixed(1))),
        DataCell(Text((r['otHours'] as double).toStringAsFixed(1))),
        DataCell(Text('₹${(r['otTotalAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalMealsAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalBusAmount'] as double).toStringAsFixed(2)}')),
        DataCell(Text('₹${(r['totalSalary'] as double).toStringAsFixed(2)}')),
        DataCell(Text(r['supervisorName']?.toString() ?? '-')),
        DataCell(Text(r['remarks']?.toString() ?? '-')),
      ]);
    });

    if (rows.isNotEmpty) {
      dataRows.add(
        DataRow(
          color: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
          cells: [
            DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
            DataCell(Text('${totals.totalRecords} Recs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(Text('${totals.totalSubContractors} Subs', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(Text('₹${totals.totalBasicSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(const Text('-')),
            DataCell(Text(totals.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totals.totalOtHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalOtAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalMealsAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalBusAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${totals.totalEarnedSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(primaryColor),
          columns: _headersToColumns([
            'Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker Name', 'Category', 'Basic Rate',
            'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Amount', 'Supervisor', 'Remarks'
          ]),
          rows: dataRows,
        ),
      ),
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

    final List<DataRow> summaryRows = billGroupedData.map((row) {
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

    if (billGroupedData.isNotEmpty) {
      int sumManDays = billGroupedData.fold(0, (sum, r) => sum + (r['count'] as int? ?? 0));
      double sumStdHrs = billGroupedData.fold(0.0, (sum, r) => sum + (r['stdHours'] as double? ?? 0));
      double sumOtHrs = billGroupedData.fold(0.0, (sum, r) => sum + (r['otHours'] as double? ?? 0));
      double sumStdAmt = billGroupedData.fold(0.0, (sum, r) => sum + (r['stdAmount'] as double? ?? 0));
      double sumOtAmt = billGroupedData.fold(0.0, (sum, r) => sum + (r['otAmount'] as double? ?? 0));
      double sumMealsAmt = billGroupedData.fold(0.0, (sum, r) => sum + (r['mealsAmount'] as double? ?? 0));
      double sumBusAmt = billGroupedData.fold(0.0, (sum, r) => sum + (r['busAmount'] as double? ?? 0));
      double sumNetBill = billGroupedData.fold(0.0, (sum, r) => sum + (r['netAmount'] as double? ?? 0));

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

  List<_SubContractorAllocation> _getWorkerOnSiteAllocations() {
    final Map<String, Set<String>> subConToSites = {};
    for (final r in reportData) {
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
    } else if (selectedReportType == 'Site Labour Attendance Report') {
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
    final totals = _ReportTotals.fromRows(reportData);

    if (selectedReportType == 'Site Labour Details Report') {
      result.add(['Sl', 'Site Code', 'Site Name', 'Sub Contractor', 'Worker Name', 'Group', 'Category', 'Basic Wage', 'Total Earned', 'Hours', 'OT Basic', 'OT Amount', 'Meals Exp', 'Meals Count', 'Meals Total', 'Bus Fare', 'Bus Count', 'Bus Total']);
      for (int i = 0; i < reportData.length; i++) {
        final r = reportData[i];
        result.add([
          (i + 1).toString(),
          (r['siteId'] ?? '').toString(),
          (r['siteName'] ?? '').toString(),
          (r['subContractor'] ?? '').toString(),
          (r['workerName'] ?? '').toString(),
          (r['group'] ?? '').toString(),
          (r['category'] ?? '').toString(),
          (r['salaryBasic'] ?? '').toString(),
          (r['totalSalary'] ?? '').toString(),
          (r['hours'] ?? '').toString(),
          (r['otSalaryBasic'] ?? '').toString(),
          (r['otTotalAmount'] ?? '').toString(),
          (r['mealsExpense'] ?? '').toString(),
          (r['mealsCount'] ?? '').toString(),
          (r['totalMealsAmount'] ?? '').toString(),
          (r['busFare'] ?? '').toString(),
          (r['busCount'] ?? '').toString(),
          (r['totalBusAmount'] ?? '').toString(),
        ]);
      }
      if (reportData.isNotEmpty) {
        result.add([
          'TOTAL',
          '${totals.totalRecords} Recs',
          '-',
          '${totals.totalSubContractors} Subs',
          '-',
          '-',
          '-',
          totals.totalBasicSalary.toStringAsFixed(2),
          totals.totalEarnedSalary.toStringAsFixed(2),
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtSalaryBasic.toStringAsFixed(2),
          totals.totalOtAmount.toStringAsFixed(2),
          totals.totalMealsExpense.toStringAsFixed(2),
          totals.totalMealsCount.toString(),
          totals.totalMealsAmount.toStringAsFixed(2),
          totals.totalBusFare.toStringAsFixed(2),
          totals.totalBusCount.toString(),
          totals.totalBusAmount.toStringAsFixed(2),
        ]);
      }
    } else if (selectedReportType == 'Site Labour Attendance Report') {
      result.add(['Site Code', 'Site Name', 'Supervisor', 'Category', 'Type', 'Sub Contractor', 'Date', 'Workers', 'OT Details', 'Remarks']);
      int totalAttWorkers = 0;
      for (final site in siteGroups) {
        for (final sup in site.supervisors) {
          for (final row in sup.rows) {
            final wc = row['workerCount'];
            if (wc is int) {
              totalAttWorkers += wc;
            } else {
              totalAttWorkers += (int.tryParse(wc?.toString() ?? '') ?? 0);
            }
            result.add([
              (row['siteCode'] ?? '').toString(),
              (row['siteName'] ?? '').toString(),
              (row['supervisor'] ?? '').toString(),
              (row['categoryType'] ?? '').toString(),
              (row['labourType'] ?? '').toString(),
              (row['subContractor'] ?? '').toString(),
              (row['date'] ?? '').toString(),
              (row['workerCount'] ?? '').toString(),
              (row['otDetails'] ?? '').toString(),
              (row['remarks'] ?? '').toString(),
            ]);
          }
        }
      }
      if (siteGroups.isNotEmpty) {
        result.add(['TOTAL', '-', '-', '-', '-', '-', '-', '$totalAttWorkers Workers', '-', '-']);
      }
    } else if (selectedReportType == 'Daily Wage Report') {
      result.add(['Sl', 'Date', 'Site Name', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Wages', 'Supervisor', 'Remarks']);
      for (int i = 0; i < reportData.length; i++) {
        final r = reportData[i];
        result.add([
          (i + 1).toString(),
          (r['date'] ?? '').toString(),
          (r['siteName'] ?? '').toString(),
          (r['workerName'] ?? '').toString(),
          (r['category'] ?? '').toString(),
          (r['salaryBasic'] ?? '').toString(),
          (r['attendanceType'] ?? '').toString(),
          (r['hours'] ?? '').toString(),
          (r['otHours'] ?? '').toString(),
          (r['otTotalAmount'] ?? '').toString(),
          (r['totalMealsAmount'] ?? '').toString(),
          (r['totalBusAmount'] ?? '').toString(),
          (r['totalSalary'] ?? '').toString(),
          (r['supervisorName'] ?? '').toString(),
          (r['remarks'] ?? '').toString(),
        ]);
      }
      if (reportData.isNotEmpty) {
        result.add([
          'TOTAL',
          '${totals.totalRecords} Recs',
          '-',
          '-',
          '-',
          totals.totalBasicSalary.toStringAsFixed(2),
          '-',
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtHours.toStringAsFixed(1),
          totals.totalOtAmount.toStringAsFixed(2),
          totals.totalMealsAmount.toStringAsFixed(2),
          totals.totalBusAmount.toStringAsFixed(2),
          totals.totalEarnedSalary.toStringAsFixed(2),
          '-',
          '-',
        ]);
      }
    } else if (selectedReportType == 'Sub Contractor Report') {
      result.add(['Sl', 'Date', 'Site Name', 'Sub Contractor', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hours', 'OT Hours', 'OT Amount', 'Meals', 'Bus', 'Total Amount', 'Supervisor', 'Remarks']);
      for (int i = 0; i < reportData.length; i++) {
        final r = reportData[i];
        result.add([
          (i + 1).toString(),
          (r['date'] ?? '').toString(),
          (r['siteName'] ?? '').toString(),
          (r['subContractor'] ?? '').toString(),
          (r['workerName'] ?? '').toString(),
          (r['category'] ?? '').toString(),
          (r['salaryBasic'] ?? '').toString(),
          (r['attendanceType'] ?? '').toString(),
          (r['hours'] ?? '').toString(),
          (r['otHours'] ?? '').toString(),
          (r['otTotalAmount'] ?? '').toString(),
          (r['totalMealsAmount'] ?? '').toString(),
          (r['totalBusAmount'] ?? '').toString(),
          (r['totalSalary'] ?? '').toString(),
          (r['supervisorName'] ?? '').toString(),
          (r['remarks'] ?? '').toString(),
        ]);
      }
      if (reportData.isNotEmpty) {
        result.add([
          'TOTAL',
          '${totals.totalRecords} Recs',
          '-',
          '${totals.totalSubContractors} Subs',
          '-',
          '-',
          totals.totalBasicSalary.toStringAsFixed(2),
          '-',
          totals.totalHours.toStringAsFixed(1),
          totals.totalOtHours.toStringAsFixed(1),
          totals.totalOtAmount.toStringAsFixed(2),
          totals.totalMealsAmount.toStringAsFixed(2),
          totals.totalBusAmount.toStringAsFixed(2),
          totals.totalEarnedSalary.toStringAsFixed(2),
          '-',
          '-',
        ]);
      }
    } else if (selectedReportType == 'Worker on Site Report') {
      result.add(['Sub Contractor Name', 'Site Code', 'Labour Type']);
      final allocations = _getWorkerOnSiteAllocations();
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
      }
    } else if (selectedReportType == 'Sub Contractor Bill Report') {
      result.add(['Sl', 'Date', 'Worker Name', 'No', 'Nature', 'Salary', 'Amount', 'Hrs', 'OT', 'Food', 'B Fare', 'Total']);
      for (int i = 0; i < reportData.length; i++) {
        final r = reportData[i];
        final ot = r['otTotalAmount'] as double;
        final total = r['totalSalary'] as double;
        final stdAmt = total - ot;
        final hrs = r['otHours'] as double;
        final meals = r['totalMealsAmount'] as double;
        final bus = r['totalBusAmount'] as double;
        result.add([
          (i + 1).toString(),
          _formatDateString(r['date']?.toString()),
          (r['category'] ?? '-').toString(),
          '1',
          (r['attendanceType'] ?? 'Regular').toString(),
          (r['salaryBasic'] ?? '').toString(),
          stdAmt.toString(),
          hrs.toString(),
          ot.toString(),
          meals.toString(),
          bus.toString(),
          total.toString(),
        ]);
      }
      if (reportData.isNotEmpty) {
        result.add([
          'TOTAL',
          '${totals.totalRecords} Recs',
          '-',
          '-',
          '-',
          totals.totalBasicSalary.toStringAsFixed(2),
          totals.totalStdAmount.toStringAsFixed(2),
          totals.totalOtHours.toStringAsFixed(1),
          totals.totalOtAmount.toStringAsFixed(2),
          totals.totalMealsAmount.toStringAsFixed(2),
          totals.totalBusAmount.toStringAsFixed(2),
          totals.totalEarnedSalary.toStringAsFixed(2),
        ]);
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
  Future<void> _exportActiveReport(String format) async {
    if (selectedReportType == 'Site Labour Details Report') {
      if (format == 'pdf') await _exportDetailsPDF();
      if (format == 'excel') await _exportDetailsExcel();
      if (format == 'csv') await _exportDetailsCSV();
    } else if (selectedReportType == 'Site Labour Attendance Report') {
      if (format == 'pdf') await _exportAttendancePDF();
      if (format == 'excel') await _exportAttendanceExcel();
      if (format == 'csv') await _exportAttendanceCSV();
    } else if (selectedReportType == 'Daily Wage Report') {
      if (format == 'pdf') await _exportDWPDF();
      if (format == 'excel') await _exportDWExcel();
      if (format == 'csv') await _exportDWCSV();
    } else if (selectedReportType == 'Sub Contractor Report') {
      if (format == 'pdf') await _exportSCPDF();
      if (format == 'excel') await _exportSCExcel();
      if (format == 'csv') await _exportSCCSV();
    } else if (selectedReportType == 'Worker on Site Report') {
      if (format == 'pdf') await _exportPresencePDF();
      if (format == 'excel') await _exportPresenceExcel();
      if (format == 'csv') await _exportPresenceCSV();
    } else if (selectedReportType == 'Sub Contractor Bill Report') {
      if (format == 'pdf') await _exportBillPDF();
      if (format == 'excel') await _exportBillExcel();
      if (format == 'csv') await _exportBillCSV();
    }
  }

  String _dateRangeText() {
    final startStr = startDate != null ? DateFormat('dd MMM yyyy').format(startDate!) : '-';
    final endStr = endDate != null ? DateFormat('dd MMM yyyy').format(endDate!) : '-';
    return '$startStr to $endStr';
  }

  // PDF Generators (layout print preview)
  Future<void> _exportDetailsPDF() async {
    final pdf = await _buildDetailsPDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Details_Report');
  }

  Future<void> _exportAttendancePDF() async {
    final pdf = await _buildAttendancePDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Attendance_Report');
  }

  Future<void> _exportDWPDF() async {
    final pdf = await _buildDWPDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Daily_Wage_Report');
  }

  Future<void> _exportSCPDF() async {
    final pdf = await _buildSCPDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Sub_Contractor_Report');
  }

  Future<void> _exportPresencePDF() async {
    final pdf = await _buildPresencePDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Presence_Report');
  }

  Future<void> _exportBillPDF() async {
    final pdf = await _buildBillPDFDocument();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Sub_Contractor_Bill_Report');
  }

  // Generic PDF layouts
  Future<pw.Document> _buildPdfBase(String title, List<String> headers, List<List<String>> tableData) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
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
          return [
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              headers: headers,
              headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              data: tableData,
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  // 1. Details PDF
  Future<pw.Document> _buildDetailsPDFDocument() {
    final totals = _ReportTotals.fromRows(reportData);
    final headers = [
      'Sl', 'Site Code', 'Site Name', 'Contractor', 'Worker Name', 'Group',
      'Category', 'Basic Wage', 'Hrs', 'OT Rate', 'OT Hrs', 'OT Amount',
      'Meals Exp', 'Meals Count', 'Meals Total', 'Bus Fare', 'Bus Count', 'Bus Total',
      'Total Earned Amount'
    ];
    final data = List<List<String>>.generate(reportData.length, (index) {
      final r = reportData[index];
      return [
        '${index + 1}',
        r['siteId']?.toString() ?? '-',
        r['siteName']?.toString() ?? '-',
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

    if (reportData.isNotEmpty) {
      data.add([
        'TOTAL',
        '${totals.totalRecords} Recs',
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
    return _buildPdfBase('SITE LABOUR DETAILS REPORT', headers, data);
  }

  // 2. Attendance PDF
  Future<pw.Document> _buildAttendancePDFDocument() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

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

          for (final site in siteGroups) {
            content.add(pw.Text('${site.siteName} (${site.siteCode})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
            for (final sup in site.supervisors) {
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: pw.Text('Supervisor: ${sup.supervisor}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ));
              
              final headers = ['Date', 'Category', 'Type', 'Sub Contractor', 'WorkersCount', 'OT Details', 'Remarks'];
              final data = sup.rows.map((row) {
                return [
                  row['date']?.toString() ?? '-',
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
                data.add(['TOTAL', '-', '-', '${sup.rows.length} Entries', '$totalSupWorkers Workers', '-', '-']);
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
          return content;
        },
      ),
    );
    return pdf;
  }

  // 3. Daily Wage PDF
  Future<pw.Document> _buildDWPDFDocument() {
    final totals = _ReportTotals.fromRows(reportData);
    final headers = ['Sl', 'Date', 'Site Name', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hrs', 'OT Hrs', 'OT Amt', 'Meals', 'Bus', 'Total Wages', 'Supervisor'];
    final data = List<List<String>>.generate(reportData.length, (index) {
      final r = reportData[index];
      return [
        '${index + 1}',
        r['date']?.toString() ?? '-',
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

    if (reportData.isNotEmpty) {
      data.add([
        'TOTAL',
        '${totals.totalRecords} Recs',
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
    return _buildPdfBase('DAILY WAGE LABOUR REPORT', headers, data);
  }

  // 4. Sub Contractor PDF
  Future<pw.Document> _buildSCPDFDocument() {
    final totals = _ReportTotals.fromRows(reportData);
    final headers = ['Sl', 'Date', 'Site Name', 'Contractor', 'Worker Name', 'Category', 'Basic Rate', 'Attendance', 'Hrs', 'OT Hrs', 'OT Amt', 'Meals', 'Bus', 'Total Earned', 'Supervisor'];
    final data = List<List<String>>.generate(reportData.length, (index) {
      final r = reportData[index];
      return [
        '${index + 1}',
        r['date']?.toString() ?? '-',
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

    if (reportData.isNotEmpty) {
      data.add([
        'TOTAL',
        '${totals.totalRecords} Recs',
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
    return _buildPdfBase('SUB CONTRACTOR LABOUR DETAILS REPORT', headers, data);
  }

  // 5. Worker on Site PDF
  Future<pw.Document> _buildPresencePDFDocument() {
    final headers = ['Sub Contractor Name', 'Site Code', 'Labour Type'];
    final allocations = _getWorkerOnSiteAllocations();
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

    final periodText = 'FROM ${startDate != null ? DateFormat('dd/MMM/yy').format(startDate!).toUpperCase() : '-'} TO ${endDate != null ? DateFormat('dd/MMM/yy').format(endDate!).toUpperCase() : '-'}';
    final reportDate = DateFormat('dd-MMM-yy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (context) {
          final detailHeaders = ['Date', 'Labour', 'No', 'Nature', 'Salary', 'Amount', 'Hrs', 'OT', 'Food', 'B Fare', 'Total'];
          
          double sumNo = 0;
          double sumAmt = 0;
          double sumHrs = 0;
          double sumOT = 0;
          double sumFood = 0;
          double sumBus = 0;
          double sumTotal = 0;

          final detailData = List<List<String>>.generate(reportData.length, (index) {
            final r = reportData[index];
            final ot = r['otTotalAmount'] as double;
            final total = r['totalSalary'] as double;
            final stdAmt = total - ot;
            final hrs = r['otHours'] as double;
            final meals = r['totalMealsAmount'] as double;
            final bus = r['totalBusAmount'] as double;

            sumNo += 1;
            sumAmt += stdAmt;
            sumHrs += hrs;
            sumOT += ot;
            sumFood += meals;
            sumBus += bus;
            sumTotal += total;

            return [
              _formatDateString(r['date']?.toString()),
              r['category']?.toString() ?? '-',
              '1',
              r['attendanceType']?.toString() ?? 'Regular',
              ((r['salaryBasic'] as double).toStringAsFixed(2)),
              (stdAmt.toStringAsFixed(2)),
              (hrs.toStringAsFixed(1)),
              (ot.toStringAsFixed(2)),
              (meals.toStringAsFixed(2)),
              (bus.toStringAsFixed(2)),
              (total.toStringAsFixed(2)),
            ];
          });

          // Add Totals row
          detailData.add([
            'Total',
            '',
            (sumNo.toStringAsFixed(0)),
            '',
            '',
            (sumAmt.toStringAsFixed(2)),
            (sumHrs.toStringAsFixed(1)),
            (sumOT.toStringAsFixed(2)),
            (sumFood.toStringAsFixed(2)),
            (sumBus.toStringAsFixed(2)),
            (sumTotal.toStringAsFixed(2)),
          ]);

          return [
            pw.Center(
              child: pw.Text(
                'SUB - CONTRACTOR\'S BILL',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                ),
                child: pw.Text(
                  _workTypeController.text.toUpperCase(),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Bill No: ${_billNoController.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('Date: $reportDate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(periodText, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Contractor Name: ${selectedSubContractorName ?? 'All'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('Site: ${selectedSiteName ?? 'All'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Work Narration: ${_narrationController.text}', style: const pw.TextStyle(fontSize: 8.5)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              context: context,
              headers: detailHeaders,
              headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 6),
              data: detailData,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 30),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('QS: .....................................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Supervisor: .............................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Ac/Asst: ................................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Contractor: .............................', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sr.Mgr: .................................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('PM / SE: ................................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('AO: .....................................', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('CE: .....................................', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
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
          await Share.shareXFiles([XFile(file.path)], text: filename);
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

  // 1. Details Excel / CSV
  Future<void> _exportDetailsExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Details Report'];
    sheet.appendRow([
      excel.TextCellValue('Sl'), excel.TextCellValue('Site Code'), excel.TextCellValue('Site Name'),
      excel.TextCellValue('Sub Contractor'), excel.TextCellValue('Worker Name'), excel.TextCellValue('Group'),
      excel.TextCellValue('Category'), excel.TextCellValue('Basic Wage'), excel.TextCellValue('Total Earned'),
      excel.TextCellValue('Hours'), excel.TextCellValue('OT Basic'), excel.TextCellValue('OT Amount'),
      excel.TextCellValue('Meals Exp'), excel.TextCellValue('Meals Count'), excel.TextCellValue('Meals Total'),
      excel.TextCellValue('Bus Fare'), excel.TextCellValue('Bus Count'), excel.TextCellValue('Bus Total')
    ]);

    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      sheet.appendRow([
        excel.IntCellValue(i + 1),
        excel.TextCellValue(r['siteId']?.toString() ?? '-'),
        excel.TextCellValue(r['siteName']?.toString() ?? '-'),
        excel.TextCellValue(r['subContractor']?.toString() ?? '-'),
        excel.TextCellValue(r['workerName']?.toString() ?? '-'),
        excel.TextCellValue(r['group']?.toString() ?? '-'),
        excel.TextCellValue(r['category']?.toString() ?? '-'),
        excel.DoubleCellValue(r['salaryBasic']),
        excel.DoubleCellValue(r['totalSalary']),
        excel.DoubleCellValue(r['hours']),
        excel.DoubleCellValue(r['otSalaryBasic']),
        excel.DoubleCellValue(r['otTotalAmount']),
        excel.DoubleCellValue(r['mealsExpense']),
        excel.IntCellValue(r['mealsCount']),
        excel.DoubleCellValue(r['totalMealsAmount']),
        excel.DoubleCellValue(r['busFare']),
        excel.IntCellValue(r['busCount']),
        excel.DoubleCellValue(r['totalBusAmount']),
      ]);
    }
    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Site_Labour_Details_Report.xlsx', 'application/vnd.ms-excel');
  }

  Future<void> _exportDetailsCSV() async {
    final csv = StringBuffer();
    csv.writeln('Sl,Site Code,Site Name,Sub Contractor,Worker Name,Group,Category,Basic Wage,Total Earned,Hours,OT Basic,OT Amount,Meals Exp,Meals Count,Meals Total,Bus Fare,Bus Count,Bus Total');
    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      csv.writeln([
        i + 1, r['siteId'], r['siteName'], r['subContractor'], r['workerName'], r['group'], r['category'],
        r['salaryBasic'], r['totalSalary'], r['hours'], r['otSalaryBasic'], r['otTotalAmount'],
        r['mealsExpense'], r['mealsCount'], r['totalMealsAmount'], r['busFare'], r['busCount'], r['totalBusAmount']
      ].join(','));
    }
    await _shareFile(csv.toString().codeUnits, 'Site_Labour_Details_Report.csv', 'text/csv');
  }

  // 2. Attendance Excel / CSV
  Future<void> _exportAttendanceExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Attendance Report'];
    sheet.appendRow([
      excel.TextCellValue('Site Code'), excel.TextCellValue('Site Name'), excel.TextCellValue('Supervisor'),
      excel.TextCellValue('Category'), excel.TextCellValue('Type'), excel.TextCellValue('Sub Contractor'),
      excel.TextCellValue('Date'), excel.TextCellValue('Workers'), excel.TextCellValue('OT Details'), excel.TextCellValue('Remarks')
    ]);

    for (final site in siteGroups) {
      for (final sup in site.supervisors) {
        for (final row in sup.rows) {
          sheet.appendRow([
            excel.TextCellValue(row['siteCode']?.toString() ?? ''),
            excel.TextCellValue(row['siteName']?.toString() ?? ''),
            excel.TextCellValue(row['supervisor']?.toString() ?? ''),
            excel.TextCellValue(row['categoryType']?.toString() ?? ''),
            excel.TextCellValue(row['labourType']?.toString() ?? ''),
            excel.TextCellValue(row['subContractor']?.toString() ?? ''),
            excel.TextCellValue(row['date']?.toString() ?? ''),
            excel.IntCellValue(row['workerCount'] as int),
            excel.TextCellValue(row['otDetails']?.toString() ?? ''),
            excel.TextCellValue(row['remarks']?.toString() ?? ''),
          ]);
        }
      }
    }
    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Site_Labour_Attendance_Report.xlsx', 'application/vnd.ms-excel');
  }

  Future<void> _exportAttendanceCSV() async {
    final csv = StringBuffer();
    csv.writeln('Site Code,Site Name,Supervisor,Category,Type,Sub Contractor,Date,Workers,OT Details,Remarks');
    for (final site in siteGroups) {
      for (final sup in site.supervisors) {
        for (final row in sup.rows) {
          csv.writeln([
            row['siteCode'], row['siteName'], row['supervisor'], row['categoryType'], row['labourType'],
            row['subContractor'], row['date'], row['workerCount'], row['otDetails'], row['remarks']
          ].join(','));
        }
      }
    }
    await _shareFile(csv.toString().codeUnits, 'Site_Labour_Attendance_Report.csv', 'text/csv');
  }

  // 3. Daily Wage Excel / CSV
  Future<void> _exportDWExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Daily Wage Report'];
    sheet.appendRow([
      excel.TextCellValue('Sl'), excel.TextCellValue('Date'), excel.TextCellValue('Site Name'), excel.TextCellValue('Worker Name'),
      excel.TextCellValue('Category'), excel.TextCellValue('Basic Rate'), excel.TextCellValue('Attendance'),
      excel.TextCellValue('Hours'), excel.TextCellValue('OT Hours'), excel.TextCellValue('OT Amount'),
      excel.TextCellValue('Meals'), excel.TextCellValue('Bus'), excel.TextCellValue('Total Wages'), excel.TextCellValue('Supervisor'), excel.TextCellValue('Remarks')
    ]);

    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      sheet.appendRow([
        excel.IntCellValue(i + 1),
        excel.TextCellValue(r['date']?.toString() ?? '-'),
        excel.TextCellValue(r['siteName']?.toString() ?? '-'),
        excel.TextCellValue(r['workerName']?.toString() ?? '-'),
        excel.TextCellValue(r['category']?.toString() ?? '-'),
        excel.DoubleCellValue(r['salaryBasic']),
        excel.TextCellValue(r['attendanceType']?.toString() ?? '-'),
        excel.DoubleCellValue(r['hours']),
        excel.DoubleCellValue(r['otHours']),
        excel.DoubleCellValue(r['otTotalAmount']),
        excel.DoubleCellValue(r['totalMealsAmount']),
        excel.DoubleCellValue(r['totalBusAmount']),
        excel.DoubleCellValue(r['totalSalary']),
        excel.TextCellValue(r['supervisorName']?.toString() ?? '-'),
        excel.TextCellValue(r['remarks']?.toString() ?? '-'),
      ]);
    }
    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Daily_Wage_Report.xlsx', 'application/vnd.ms-excel');
  }

  Future<void> _exportDWCSV() async {
    final csv = StringBuffer();
    csv.writeln('Sl,Date,Site Name,Worker Name,Category,Basic Rate,Attendance,Hours,OT Hours,OT Amount,Meals,Bus,Total Wages,Supervisor,Remarks');
    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      csv.writeln([
        i + 1, r['date'], r['siteName'], r['workerName'], r['category'], r['salaryBasic'], r['attendanceType'],
        r['hours'], r['otHours'], r['otTotalAmount'], r['totalMealsAmount'], r['totalBusAmount'], r['totalSalary'],
        r['supervisorName'], r['remarks']
      ].join(','));
    }
    await _shareFile(csv.toString().codeUnits, 'Daily_Wage_Report.csv', 'text/csv');
  }

  // 4. Sub Contractor Excel / CSV
  Future<void> _exportSCExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Sub Contractor Report'];
    sheet.appendRow([
      excel.TextCellValue('Sl'), excel.TextCellValue('Date'), excel.TextCellValue('Site Name'), excel.TextCellValue('Sub Contractor'),
      excel.TextCellValue('Worker Name'), excel.TextCellValue('Category'), excel.TextCellValue('Basic Rate'),
      excel.TextCellValue('Attendance'), excel.TextCellValue('Hours'), excel.TextCellValue('OT Hours'), excel.TextCellValue('OT Amount'),
      excel.TextCellValue('Meals'), excel.TextCellValue('Bus'), excel.TextCellValue('Total Amount'), excel.TextCellValue('Supervisor'), excel.TextCellValue('Remarks')
    ]);

    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      sheet.appendRow([
        excel.IntCellValue(i + 1),
        excel.TextCellValue(r['date']?.toString() ?? '-'),
        excel.TextCellValue(r['siteName']?.toString() ?? '-'),
        excel.TextCellValue(r['subContractor']?.toString() ?? '-'),
        excel.TextCellValue(r['workerName']?.toString() ?? '-'),
        excel.TextCellValue(r['category']?.toString() ?? '-'),
        excel.DoubleCellValue(r['salaryBasic']),
        excel.TextCellValue(r['attendanceType']?.toString() ?? '-'),
        excel.DoubleCellValue(r['hours']),
        excel.DoubleCellValue(r['otHours']),
        excel.DoubleCellValue(r['otTotalAmount']),
        excel.DoubleCellValue(r['totalMealsAmount']),
        excel.DoubleCellValue(r['totalBusAmount']),
        excel.DoubleCellValue(r['totalSalary']),
        excel.TextCellValue(r['supervisorName']?.toString() ?? '-'),
        excel.TextCellValue(r['remarks']?.toString() ?? '-'),
      ]);
    }
    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Sub_Contractor_Report.xlsx', 'application/vnd.ms-excel');
  }

  Future<void> _exportSCCSV() async {
    final csv = StringBuffer();
    csv.writeln('Sl,Date,Site Name,Sub Contractor,Worker Name,Category,Basic Rate,Attendance,Hours,OT Hours,OT Amount,Meals,Bus,Total Amount,Supervisor,Remarks');
    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      csv.writeln([
        i + 1, r['date'], r['siteName'], r['subContractor'], r['workerName'], r['category'], r['salaryBasic'],
        r['attendanceType'], r['hours'], r['otHours'], r['otTotalAmount'], r['totalMealsAmount'], r['totalBusAmount'],
        r['totalSalary'], r['supervisorName'], r['remarks']
      ].join(','));
    }
    await _shareFile(csv.toString().codeUnits, 'Sub_Contractor_Report.csv', 'text/csv');
  }

  // 5. Worker on Site Excel / CSV
  Future<void> _exportPresenceExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Presence Report'];
    sheet.appendRow([
      excel.TextCellValue('Sub Contractor Name'),
      excel.TextCellValue('Site Code'),
      excel.TextCellValue('Labour Type')
    ]);

    final allocations = _getWorkerOnSiteAllocations();
    for (final alloc in allocations) {
      for (int i = 0; i < alloc.sites.length; i++) {
        final site = alloc.sites[i];
        sheet.appendRow([
          excel.TextCellValue(i == 0 ? alloc.subContractor : ''),
          excel.TextCellValue(site.siteId),
          excel.TextCellValue(site.labourType),
        ]);
      }
    }
    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Worker_Presence_Report.xlsx', 'application/vnd.ms-excel');
  }

  Future<void> _exportPresenceCSV() async {
    final csv = StringBuffer();
    csv.writeln('Sub Contractor Name,Site Code,Labour Type');
    final allocations = _getWorkerOnSiteAllocations();
    for (final alloc in allocations) {
      for (int i = 0; i < alloc.sites.length; i++) {
        final site = alloc.sites[i];
        csv.writeln([
          '"${i == 0 ? alloc.subContractor : ''}"',
          '"${site.siteId}"',
          '"${site.labourType}"',
        ].join(','));
      }
    }
    await _shareFile(csv.toString().codeUnits, 'Worker_Presence_Report.csv', 'text/csv');
  }

  // 6. Sub Contractor Bill Excel / CSV
  Future<void> _exportBillExcel() async {
    final excelDoc = excel.Excel.createExcel();
    final sheet = excelDoc['Sub-Contractor Bill'];
    
    sheet.merge(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), excel.TextCellValue('SUB - CONTRACTOR\'S BILL'));
    
    sheet.merge(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), excel.TextCellValue('Work Type: ${_workTypeController.text.toUpperCase()}'));

    final periodText = 'FROM ${startDate != null ? DateFormat('dd/MMM/yy').format(startDate!).toUpperCase() : '-'} TO ${endDate != null ? DateFormat('dd/MMM/yy').format(endDate!).toUpperCase() : '-'}';
    sheet.merge(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2), excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 2));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2), excel.TextCellValue(periodText));

    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4), excel.TextCellValue('Bill No: ${_billNoController.text}'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 4), excel.TextCellValue('Date: ${DateFormat('dd-MMM-yy').format(DateTime.now())}'));

    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5), excel.TextCellValue('Contractor Name: ${selectedSubContractorName ?? 'All'}'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 5), excel.TextCellValue('Site: ${selectedSiteName ?? 'All'}'));

    sheet.merge(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6), excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 6));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6), excel.TextCellValue('Work Narration: ${_narrationController.text}'));

    final detailHeaders = ['Date', 'Labour', 'No', 'Nature', 'Salary', 'Amount', 'Hrs', 'OT', 'Food', 'B Fare', 'Total'];
    for (int col = 0; col < detailHeaders.length; col++) {
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 8), excel.TextCellValue(detailHeaders[col]));
    }

    int startRow = 9;
    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      final ot = r['otTotalAmount'] as double;
      final total = r['totalSalary'] as double;
      final stdAmt = total - ot;
      final hrs = r['otHours'] as double;
      final meals = r['totalMealsAmount'] as double;
      final bus = r['totalBusAmount'] as double;
      
      final rowIdx = startRow + i;
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx), excel.TextCellValue(_formatDateString(r['date']?.toString())));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx), excel.TextCellValue(r['category']?.toString() ?? '-'));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx), excel.IntCellValue(1));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx), excel.TextCellValue(r['attendanceType']?.toString() ?? 'Regular'));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx), excel.DoubleCellValue(r['salaryBasic']));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx), excel.DoubleCellValue(stdAmt));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx), excel.DoubleCellValue(hrs));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx), excel.DoubleCellValue(ot));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx), excel.DoubleCellValue(meals));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIdx), excel.DoubleCellValue(bus));
      sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIdx), excel.DoubleCellValue(total));
    }

    final totalRowIdx = startRow + reportData.length;
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx), excel.TextCellValue('Total'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(C10:C$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(F10:F$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(G10:G$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(H10:H$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(I10:I$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(J10:J$totalRowIdx)'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: totalRowIdx), excel.TextCellValue('=SUM(K10:K$totalRowIdx)'));

    final sigRow1Idx = totalRowIdx + 3;
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sigRow1Idx), excel.TextCellValue('QS: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sigRow1Idx), excel.TextCellValue('Supervisor: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: sigRow1Idx), excel.TextCellValue('Ac/Asst: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: sigRow1Idx), excel.TextCellValue('Contractor: ....................'));

    final sigRow2Idx = totalRowIdx + 5;
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sigRow2Idx), excel.TextCellValue('Sr.Mgr: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sigRow2Idx), excel.TextCellValue('PM / SE: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: sigRow2Idx), excel.TextCellValue('AO: ....................'));
    sheet.updateCell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: sigRow2Idx), excel.TextCellValue('CE: ....................'));

    final bytes = excelDoc.save();
    if (bytes != null) await _shareFile(bytes, 'Sub_Contractor_Bill_Report.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  String _formatDateString(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == '-') return '-';
    try {
      final parsed = DateTime.parse(rawDate);
      return DateFormat('dd-MMM-yy').format(parsed);
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _exportBillCSV() async {
    final csv = StringBuffer();
    // For CSV, write summary section first, then detail breakdown
    csv.writeln('--- SUB CONTRACTOR INVOICE BILLING SUMMARY ---');
    csv.writeln('Sub Contractor,Man-Days,Std Hours,OT Hours,Std Amount,OT Amount,Meals,Bus,Net Bill');
    for (final row in billGroupedData) {
      csv.writeln([
        row['name'], row['count'], row['stdHours'], row['otHours'], row['stdAmount'], row['otAmount'],
        row['mealsAmount'], row['busAmount'], row['netAmount']
      ].join(','));
    }
    csv.writeln('\n--- DETAILED ALLOCATIONS BREAKDOWN ---');
    csv.writeln('Sl,Date,Site Name,Sub Contractor,Worker Name,Category,Std Hours,OT Hours,Basic Rate,Std Amount,OT Amount,Meals,Bus,Total Bill');
    for (int i = 0; i < reportData.length; i++) {
      final r = reportData[i];
      final ot = r['otTotalAmount'] as double;
      final total = r['totalSalary'] as double;
      final stdAmt = total - ot;
      csv.writeln([
        i + 1, r['date'], r['siteName'], r['subContractor'], r['workerName'], r['category'],
        r['hours'], r['otHours'], r['salaryBasic'], stdAmt, ot, r['totalMealsAmount'], r['totalBusAmount'], total
      ].join(','));
    }
    await _shareFile(csv.toString().codeUnits, 'Sub_Contractor_Bill_Report.csv', 'text/csv');
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
    final rows = widget.tableData.sublist(1);
    
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
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
    );
  }
}
