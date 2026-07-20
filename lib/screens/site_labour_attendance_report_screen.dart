// ignore: avoid_web_libraries_in_flutter
import 'package:ideal_cst/utils/web_download_stub.dart'
    if (dart.library.html) 'package:ideal_cst/utils/web_download.dart';
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
import 'package:excel_community/excel_community.dart' as excel;

/// Site Labour Attendance Report — register-style layout matching the
/// physical Site Labour Details sheet (site → supervisor → labour rows).
class SiteLabourAttendanceReportScreen extends StatefulWidget {
  const SiteLabourAttendanceReportScreen({super.key});

  @override
  State<SiteLabourAttendanceReportScreen> createState() =>
      _SiteLabourAttendanceReportScreenState();
}

class _SiteLabourAttendanceReportScreenState
    extends State<SiteLabourAttendanceReportScreen> {
  // ── Theme ──────────────────────────────────────────────────────────────────
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLight = const Color(0xFF1a4a8c);
  final Color bgColor = const Color(0xFFf0f4f9);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF1e293b);
  final Color mutedColor = const Color(0xFF64748b);
  final Color successColor = const Color(0xFF16a34a);
  final Color errorColor = const Color(0xFFdc2626);

  // ── Filters ──────────────────────────────────────────────────────────────
  DateTime? selectedDate;
  DateTime? startDate;
  DateTime? endDate;

  List<_DropdownOption> siteOptions = [];
  List<_DropdownOption> supervisorOptions = [];
  List<_DropdownOption> contractorOptions = [];
  final List<_DropdownOption> labourTypeOptions = [
    _DropdownOption(id: 'DW', label: 'Daily Wage (DW)'),
    _DropdownOption(id: 'SC', label: 'Sub Contractor (SC)'),
  ];

  String? selectedSiteId;
  String? selectedSupervisor;
  String? selectedContractor;
  String? selectedLabourType;

  bool isLoadingFilters = true;
  bool isLoading = false;
  bool reportGenerated = false;
  bool showFilters = false;
  String searchQuery = '';

  // ── Pagination ───────────────────────────────────────────────────────────
  int currentPage = 0;
  static const int rowsPerPage = 20;

  // ── Report data ──────────────────────────────────────────────────────────
  List<_SiteGroup> siteGroups = [];
  List<Map<String, dynamic>> flatRows = [];
  List<Map<String, dynamic>> contractorTotals = [];
  List<Map<String, dynamic>> dailySummary = [];

  int totalSites = 0;
  int totalSupervisors = 0;
  int totalContractors = 0;
  int totalLabourCount = 0;
  double totalOtHours = 0;
  double totalStHours = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = now;
    startDate = now;
    endDate = now;
    _loadFilterData().then((_) => _generateReport());
  }

  // ── Data helpers ───────────────────────────────────────────────────────────
  String _labourTypeAbbr(String? raw) {
    final v = raw?.toLowerCase() ?? '';
    if (v.contains('sub') || v == 'sc') return 'SC';
    return 'DW';
  }

  double _parseOtHours(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.split(' ').first.trim()) ?? 0;
    }
    return 0;
  }

  String _buildOtStDetails(Map<String, dynamic> e) {
    final out = e['outTime']?.toString().trim() ?? '';
    final inTime = e['inTime']?.toString().trim() ?? '';
    final ot = _parseOtHours(e['overtimeHours'] ?? e['otHours']);
    final attendance = e['attendanceType']?.toString() ?? '';
    final parts = <String>[];
    if (out.isNotEmpty) parts.add('$out out');
    if (inTime.isNotEmpty && attendance == 'Night Shift') {
      parts.add('$inTime to');
    }
    if (ot > 0) parts.add('${ot.toStringAsFixed(1)} Hrs');
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  String _subContractorName(Map<String, dynamic> e) {
    return (e['contractorName']?.toString() ??
            e['subContractorName']?.toString() ??
            e['contractor']?.toString() ??
            '-')
        .trim();
  }

  // ── Filter loading ─────────────────────────────────────────────────────────
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
    final snap =
        await FirebaseFirestore.instance.collection('siteSupervisorMap').get();
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

  // ── Report generation ──────────────────────────────────────────────────────
  Future<void> _generateReport() async {
    setState(() {
      isLoading = true;
      reportGenerated = true;
      currentPage = 0;
    });

    try {
      if (selectedDate != null) {
        startDate = selectedDate;
        endDate = selectedDate;
      }

      final startStr = startDate != null
          ? DateFormat('yyyy-MM-dd').format(startDate!)
          : null;
      final endStr = endDate != null
          ? DateFormat('yyyy-MM-dd').format(endDate!)
          : null;

      // Query daily_labour_entries (primary data source)
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('daily_labour_entries');

      if (selectedSiteId != null) {
        query = query.where('siteId', isEqualTo: selectedSiteId);
      }
      if (startStr != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startStr);
      }
      if (endStr != null) {
        query = query.where('date', isLessThanOrEqualTo: endStr);
      }

      final results = await Future.wait([
        query.get(),
        FirebaseFirestore.instance.collection('siteSupervisorMap').get(),
        FirebaseFirestore.instance.collection('supervisor').get(),
      ]);
      final snap = results[0];
      final siteSupervisorMapSnap = results[1];
      final supervisorCollectionSnap = results[2];

      // Build siteId → supervisorName lookup from siteSupervisorMap
      final siteIdToSupervisorName = <String, String>{};
      for (final doc in siteSupervisorMapSnap.docs) {
        final data = doc.data();
        final sId = (data['siteId'] ?? doc.id)?.toString().trim();
        final supName = data['supervisor']?.toString().trim();
        if (sId != null && sId.isNotEmpty && supName != null && supName.isNotEmpty) {
          siteIdToSupervisorName[sId] = supName;
        }
      }

      // Build supervisorUserName → coordinatorName lookup from supervisor collection
      final supervisorNameToCoordinator = <String, String>{};
      for (final doc in supervisorCollectionSnap.docs) {
        final data = doc.data();
        final userName = data['UserName']?.toString().trim();
        final coordName = data['CoordinatorName']?.toString().trim();
        if (userName != null && userName.isNotEmpty && coordName != null && coordName.isNotEmpty) {
          supervisorNameToCoordinator[userName.toLowerCase()] = coordName;
        }
      }

      List<Map<String, dynamic>> entries = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_docId'] = d.id;
        return data;
      }).toList();

      // Also merge site_labour_reports if present
      try {
        Query<Map<String, dynamic>> altQuery =
            FirebaseFirestore.instance.collection('site_labour_reports');
        if (startStr != null) {
          altQuery =
              altQuery.where('date', isGreaterThanOrEqualTo: startStr);
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
          data['contractorName'] =
              data['subContractor'] ?? data['contractorName'];
          entries.add(data);
        }
      } catch (_) {}

      // Client-side filters
      if (selectedSupervisor != null) {
        entries = entries
            .where((e) =>
                (e['supervisorName']?.toString() ?? '') == selectedSupervisor)
            .toList();
      }
      if (selectedContractor != null) {
        entries = entries
            .where((e) => _subContractorName(e) == selectedContractor)
            .toList();
      }
      if (selectedLabourType != null) {
        entries = entries
            .where((e) =>
                _labourTypeAbbr(e['labourType']?.toString()) ==
                selectedLabourType)
            .toList();
      }

      _buildGroupedReport(
        entries,
        siteIdToSupervisorName,
        supervisorNameToCoordinator,
      );
      setState(() => isLoading = false);
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

  void _buildGroupedReport(
    List<Map<String, dynamic>> entries,
    Map<String, String> siteIdToSupervisorName,
    Map<String, String> supervisorNameToCoordinator,
  ) {
    // Group: site → supervisor → (category + labourType + contractor)
    final siteMap = <String, Map<String, dynamic>>{};
    final contractorMap = <String, int>{};
    final dailyMap = <String, int>{};
    final supervisorSet = <String>{};
    final contractorSet = <String>{};

    double otTotal = 0;
    double stTotal = 0;

    for (final e in entries) {
      final siteId = e['siteId']?.toString() ?? '-';
      final siteName = e['siteName']?.toString() ?? siteId;
      final supervisor = e['supervisorName']?.toString() ?? '-';
      final category = e['category']?.toString() ?? '-';
      final lt = _labourTypeAbbr(e['labourType']?.toString());
      final contractor = _subContractorName(e);
      final date = e['date']?.toString() ?? '-';
      final rowKey =
          '$siteId|$supervisor|$category|$lt|$contractor|$date';

      supervisorSet.add(supervisor);
      if (contractor != '-') contractorSet.add(contractor);
      contractorMap[contractor] = (contractorMap[contractor] ?? 0) + 1;
      dailyMap[date] = (dailyMap[date] ?? 0) + 1;

      final ot = _parseOtHours(e['overtimeHours'] ?? e['otHours']);
      final hoursWorked = (e['hoursWorked'] as num?)?.toDouble() ?? 0;
      final attendance = e['attendanceType']?.toString() ?? '';
      otTotal += ot;
      if (attendance == 'Night Shift') stTotal += hoursWorked;

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

      final supervisors =
          site['supervisors'] as Map<String, Map<String, dynamic>>;
      if (!supervisors.containsKey(supervisor)) {
        supervisors[supervisor] = {
          'supervisor': supervisor,
          'rows': <String, Map<String, dynamic>>{},
          'totalCount': 0,
        };
      }

      final sup = supervisors[supervisor]!;
      sup['totalCount'] = (sup['totalCount'] as int) + 1;

      // Resolve coordinator name
      final supervisorUserName = siteIdToSupervisorName[siteId] ?? supervisor;
      final coordinator =
          supervisorNameToCoordinator[supervisorUserName.toLowerCase()] ?? '-';

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
          'otDetails': _buildOtStDetails(e),
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

      final newOtDetail = _buildOtStDetails(e);
      if (newOtDetail != '-' && row['otDetails']?.toString() != newOtDetail) {
        final existing = row['otDetails']?.toString() ?? '';
        if (existing.isEmpty || existing == '-') {
          row['otDetails'] = newOtDetail;
        }
      }
      final remark = e['remarks']?.toString().trim() ?? '';
      if (remark.isNotEmpty) {
        final existingRemarks = row['remarks']?.toString() ?? '';
        if (!existingRemarks.contains(remark)) {
          row['remarks'] = existingRemarks.isEmpty
              ? remark
              : '$existingRemarks; $remark';
        }
      }
    }

    // Build site groups
    final groups = <_SiteGroup>[];
    final allFlat = <Map<String, dynamic>>[];

    for (final siteEntry in siteMap.values) {
      final supervisors =
          siteEntry['supervisors'] as Map<String, Map<String, dynamic>>;
      final supGroups = <_SupervisorGroup>[];

      for (final supEntry in supervisors.values) {
        final rowsMap =
            supEntry['rows'] as Map<String, Map<String, dynamic>>;
        final rows = rowsMap.values.map((r) {
          final row = Map<String, dynamic>.from(r);
          row['totalCount'] = supEntry['totalCount'];
          allFlat.add(row);
          return row;
        }).toList();

        supGroups.add(_SupervisorGroup(
          supervisor: supEntry['supervisor'] as String,
          totalCount: supEntry['totalCount'] as int,
          rows: rows,
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

    contractorTotals = contractorMap.entries
        .map((e) => {'name': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    dailySummary = dailyMap.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    siteGroups = groups;
    flatRows = allFlat;
    totalSites = siteMap.length;
    totalSupervisors = supervisorSet.length;
    totalContractors = contractorSet.length;
    totalLabourCount = entries.length;
    totalOtHours = otTotal;
    totalStHours = stTotal;
  }

  List<Map<String, dynamic>> _filteredFlatRows() {
    if (searchQuery.isEmpty) return flatRows;
    final q = searchQuery.toLowerCase();
    return flatRows.where((r) {
      return (r['siteCode']?.toString().toLowerCase().contains(q) ?? false) ||
          (r['siteName']?.toString().toLowerCase().contains(q) ?? false) ||
          (r['supervisor']?.toString().toLowerCase().contains(q) ?? false) ||
          (r['categoryType']?.toString().toLowerCase().contains(q) ?? false) ||
          (r['subContractor']?.toString().toLowerCase().contains(q) ?? false) ||
          (r['remarks']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchAndFilterBar(),
                      const SizedBox(height: 12),
                      if (showFilters) ...[
                        _buildFiltersCard(),
                        const SizedBox(height: 12),
                      ],
                      _buildSummaryCards(),
                      const SizedBox(height: 12),
                      if (contractorTotals.isNotEmpty) ...[
                        _buildContractorTotals(),
                        const SizedBox(height: 12),
                      ],
                      if (dailySummary.isNotEmpty) ...[
                        _buildDailySummary(),
                        const SizedBox(height: 12),
                      ],
                      _buildResultArea(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Site Labour Attendance Report',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 17,
        ),
      ),
      centerTitle: true,
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: _shareReport,
          tooltip: 'Share Report',
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search site, supervisor, contractor...',
                hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: mutedColor),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (q) => setState(() {
                searchQuery = q;
                currentPage = 0;
              }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: showFilters ? primaryColor : mutedColor,
            ),
            onPressed: () => setState(() => showFilters = !showFilters),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            'Date',
            selectedDate,
            (d) => setState(() => selectedDate = d),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'From Date',
                  startDate,
                  (d) => setState(() {
                    startDate = d;
                    selectedDate = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateField(
                  'To Date',
                  endDate,
                  (d) => setState(() {
                    endDate = d;
                    selectedDate = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDynamicDropdown(
            label: 'Site',
            options: siteOptions,
            value: selectedSiteId,
            onChanged: (opt) =>
                setState(() => selectedSiteId = opt?.id),
          ),
          const SizedBox(height: 10),
          _buildDynamicDropdown(
            label: 'Supervisor',
            options: supervisorOptions,
            value: selectedSupervisor,
            onChanged: (opt) =>
                setState(() => selectedSupervisor = opt?.id),
          ),
          const SizedBox(height: 10),
          _buildDynamicDropdown(
            label: 'Contractor',
            options: contractorOptions,
            value: selectedContractor,
            onChanged: (opt) =>
                setState(() => selectedContractor = opt?.id),
          ),
          const SizedBox(height: 10),
          _buildDynamicDropdown(
            label: 'Labour Type',
            options: labourTypeOptions,
            value: selectedLabourType,
            onChanged: (opt) =>
                setState(() => selectedLabourType = opt?.id),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: mutedColor),
          filled: true,
          fillColor: bgColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          suffixIcon: Icon(Icons.calendar_today, size: 18, color: mutedColor),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yyyy').format(date) : '—',
          style: TextStyle(
            fontSize: 13,
            color: date != null ? textColor : mutedColor,
          ),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text('Loading…', style: TextStyle(fontSize: 12, color: mutedColor)),
          ],
        ),
      );
    }

    final validValue = options.any((o) => o.id == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: validValue,
      isExpanded: true,
      dropdownColor: cardColor,
      style: TextStyle(color: textColor, fontSize: 13),
      hint: Text(
        'Select $label',
        style: TextStyle(color: mutedColor, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: mutedColor),
        filled: true,
        fillColor: bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.25)),
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All', style: TextStyle(color: mutedColor)),
        ),
        ...options.map(
          (opt) => DropdownMenuItem<String>(
            value: opt.id,
            child: Text(opt.label, overflow: TextOverflow.ellipsis),
          ),
        ),
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

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                Icons.location_city_outlined,
                'Total Sites',
                '$totalSites',
                primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryTile(
                Icons.supervisor_account_outlined,
                'Total Supervisors',
                '$totalSupervisors',
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                Icons.engineering_outlined,
                'Total Contractors',
                '$totalContractors',
                Colors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryTile(
                Icons.people_alt_outlined,
                'Total Labour Count',
                '$totalLabourCount',
                successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryTile(
                Icons.access_time_outlined,
                'Total OT Hours',
                totalOtHours.toStringAsFixed(1),
                Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryTile(
                Icons.nightlight_outlined,
                'Total ST Hours',
                totalStHours.toStringAsFixed(1),
                Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _generateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.summarize_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    isLoading ? 'Generating...' : 'GENERATE REPORT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: isLoading || flatRows.isEmpty
                      ? null
                      : _showDownloadReportOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.file_download,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Download Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractorTotals() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contractor-wise Totals',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contractorTotals.take(12).map((c) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  '${c['name']}: ${c['count']}',
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Manpower Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dailySummary.map((d) {
              final dateStr = d['date']?.toString() ?? '';
              final formatted = dateStr.length >= 10
                  ? DateFormat('dd/MM/yyyy')
                      .format(DateTime.tryParse(dateStr) ?? DateTime.now())
                  : dateStr;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: successColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '$formatted: ${d['count']} workers',
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea() {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (reportGenerated && flatRows.isEmpty) {
      return _emptyState('No data available.', 'Try adjusting your filters.');
    }

    if (!reportGenerated) return const SizedBox.shrink();

    final filtered = _filteredFlatRows();
    if (searchQuery.isNotEmpty && filtered.isEmpty) {
      return _emptyState(
        'No results found for "$searchQuery".',
        'Try a different search term.',
      );
    }

    final totalPages = (filtered.length / rowsPerPage).ceil();
    final pageRows = filtered
        .skip(currentPage * rowsPerPage)
        .take(rowsPerPage)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Site-grouped register view
        ...siteGroups.map(_buildSiteRegisterCard),
        const SizedBox(height: 16),
        // Flat paginated table
        _buildFlatTable(pageRows),
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          _buildPagination(totalPages, filtered.length),
        ],
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteRegisterCard(_SiteGroup site) {
    // Filter site groups when search is active
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
          // Site header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryLight],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
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
                        'Site Code: ${site.siteCode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (site.siteName != site.siteCode)
                        Text(
                          site.siteName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
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
              ],
            ),
          ),
          // Register table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 10,
              headingRowHeight: 40,
              dataRowHeight: 44,
              headingRowColor: WidgetStateProperty.all(
                primaryColor.withValues(alpha: 0.08),
              ),
              columns: [
                _col('S.No'),
                _col('Date'),
                _col('Co-ordinator'),
                _col('Site Code'),
                _col('Supervisor'),
                _col('CT'),
                _col('LT'),
                _col('Sub.Contractor'),
                _col('Nos'),
                _col('Total'),
                _col('OT/ST Details'),
              ],
              rows: _buildRegisterRows(site),
            ),
          ),
        ],
      ),
    );
  }

  static DataColumn _col(String label) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: Color(0xFF0b3470),
        ),
      ),
    );
  }

  List<DataRow> _buildRegisterRows(_SiteGroup site) {
    final rows = <DataRow>[];
    bool firstSiteRow = true;
    int sNoCounter = 1;
    for (final sup in site.supervisors) {
      for (int i = 0; i < sup.rows.length; i++) {
        final r = sup.rows[i];
        final showSupervisor = i == 0;
        rows.add(DataRow(
          cells: [
            DataCell(Text(
              '$sNoCounter',
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              _formatDate(r['date']?.toString()),
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              r['coordinator']?.toString() ?? '-',
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              firstSiteRow ? site.siteCode : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: firstSiteRow ? FontWeight.w600 : FontWeight.normal,
              ),
            )),
            DataCell(Text(
              showSupervisor ? sup.supervisor : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: showSupervisor ? FontWeight.w600 : FontWeight.normal,
              ),
            )),
            DataCell(Text(
              r['categoryType']?.toString() ?? '-',
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              r['labourType']?.toString() ?? '-',
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              r['subContractor']?.toString() ?? '-',
              style: const TextStyle(fontSize: 11),
            )),
            DataCell(Text(
              '${r['workerCount'] ?? 0}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(Text(
              i == sup.rows.length - 1 ? '${sup.totalCount}' : '',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0b3470),
              ),
            )),
            DataCell(Text(
              r['otDetails']?.toString() ?? '-',
              style: const TextStyle(fontSize: 10),
            )),
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

  Widget _buildFlatTable(List<Map<String, dynamic>> pageRows) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Detailed Labour Register',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 10,
              headingRowHeight: 44,
              dataRowHeight: 48,
              headingRowColor: WidgetStateProperty.all(primaryColor),
              columns: const [
                DataColumn(label: Text('S.No', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Co-ordinator', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Site Code', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Supervisor', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('CT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('LT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Sub.Contractor', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Nos', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Total', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('OT/ST Details', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
              rows: pageRows.asMap().entries.map((entry) {
                final idx = entry.key;
                final r = entry.value;
                final globalIdx = currentPage * rowsPerPage + idx + 1;
                return DataRow(cells: [
                  DataCell(Text('$globalIdx', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(_formatDate(r['date']?.toString()), style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['coordinator']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['siteCode']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['supervisor']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['categoryType']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['labourType']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['subContractor']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${r['workerCount'] ?? 0}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${r['totalCount'] ?? '-'}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(r['otDetails']?.toString() ?? '-', style: const TextStyle(fontSize: 10))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, int totalRows) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 0
              ? () => setState(() => currentPage--)
              : null,
          icon: const Icon(Icons.chevron_left),
          color: primaryColor,
        ),
        Text(
          'Page ${currentPage + 1} of $totalPages ($totalRows rows)',
          style: TextStyle(fontSize: 13, color: mutedColor),
        ),
        IconButton(
          onPressed: currentPage < totalPages - 1
              ? () => setState(() => currentPage++)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: primaryColor,
        ),
      ],
    );
  }

  // ── Export helpers (register layout) ───────────────────────────────────────
  static const List<String> _registerHeaders = [
    'S.No',
    'Date',
    'Co-ordinator',
    'Site Code',
    'Supervisor',
    'CT',
    'LT',
    'Sub.Contractor',
    'Nos',
    'Total',
    'OT/ST Details',
  ];

  String _reportTitle() {
    if (startDate != null &&
        endDate != null &&
        startDate == endDate) {
      return 'Site Labour Details - ${DateFormat('dd.MM.yyyy').format(startDate!)}-1';
    }
    if (startDate != null && endDate != null) {
      return 'Site Labour Details - ${DateFormat('dd.MM.yyyy').format(startDate!)} to ${DateFormat('dd.MM.yyyy').format(endDate!)}';
    }
    return 'Site Labour Details Report';
  }

  String _reportFileSuffix() {
    if (startDate != null) {
      return DateFormat('yyyy-MM-dd').format(startDate!);
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  List<_SiteGroup> _filteredSiteGroups() {
    if (searchQuery.isEmpty) return siteGroups;
    final q = searchQuery.toLowerCase();
    return siteGroups.where((site) {
      final siteMatch =
          site.siteCode.toLowerCase().contains(q) ||
          site.siteName.toLowerCase().contains(q);
      final hasMatch = site.supervisors.any((sup) =>
          sup.supervisor.toLowerCase().contains(q) ||
          sup.rows.any((r) =>
              (r['subContractor']?.toString().toLowerCase().contains(q) ??
                  false) ||
              (r['categoryType']?.toString().toLowerCase().contains(q) ??
                  false) ||
              (r['remarks']?.toString().toLowerCase().contains(q) ?? false)));
      return siteMatch || hasMatch;
    }).toList();
  }

  List<_RegisterExportRow> _buildRegisterExportRows() {
    final rows = <_RegisterExportRow>[];
    final groups = _filteredSiteGroups();

    for (final site in groups) {
      bool firstSiteRow = true;
      for (final sup in site.supervisors) {
        for (int i = 0; i < sup.rows.length; i++) {
          final r = sup.rows[i];
          final isLastInSupervisor = i == sup.rows.length - 1;
          rows.add(_RegisterExportRow(
            date: _formatDate(r['date']?.toString()),
            coordinator: r['coordinator']?.toString() ?? '-',
            siteCode: firstSiteRow ? site.siteCode : '',
            supervisor: i == 0 ? sup.supervisor : '',
            categoryType: r['categoryType']?.toString() ?? '-',
            labourType: r['labourType']?.toString() ?? '-',
            subContractor: r['subContractor']?.toString() ?? '-',
            workerCount: (r['workerCount'] as int?) ?? 0,
            totalCount: isLastInSupervisor ? sup.totalCount : null,
            otStDetails: r['otDetails']?.toString() ?? '-',
            remarks: r['remarks']?.toString() ?? '',
            isSiteTotalRow: false,
            siteTotalLabel: '',
            siteTotalValue: 0,
          ));
          firstSiteRow = false;
        }
      }
      // Site subtotal row
      rows.add(_RegisterExportRow(
        date: '',
        coordinator: '',
        siteCode: '',
        supervisor: '',
        categoryType: '',
        labourType: '',
        subContractor: 'Site Total (${site.siteCode})',
        workerCount: site.totalCount,
        totalCount: site.totalCount,
        otStDetails: '',
        remarks: '',
        isSiteTotalRow: true,
        siteTotalLabel: site.siteCode,
        siteTotalValue: site.totalCount,
      ));
    }
    return rows;
  }

  List<String> _registerRowToStrings(_RegisterExportRow row, String sNo) {
    return [
      sNo,
      row.date,
      row.coordinator,
      row.siteCode,
      row.supervisor,
      row.categoryType,
      row.labourType,
      row.subContractor,
      '${row.workerCount}',
      row.totalCount != null ? '${row.totalCount}' : '',
      row.otStDetails,
    ];
  }

  PdfColor get _pdfNavy => const PdfColor.fromInt(0xFF0b3470);

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
        ),
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String text, {
    bool bold = false,
    bool highlight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      color: highlight ? PdfColors.blue50 : null,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPdfSummaryBand() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _pdfStat('Total Sites', '$totalSites'),
          _pdfStat('Total Supervisors', '$totalSupervisors'),
          _pdfStat('Total Contractors', '$totalContractors'),
          _pdfStat('Total Labour', '$totalLabourCount'),
          _pdfStat('Total OT Hrs', totalOtHours.toStringAsFixed(1)),
          _pdfStat('Total ST Hrs', totalStHours.toStringAsFixed(1)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRegisterTable(List<_RegisterExportRow> exportRows) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _pdfNavy),
        children: _registerHeaders.map(_pdfHeaderCell).toList(),
      ),
      ...exportRows.asMap().entries.map((entry) {
        final idx = entry.key;
        final row = entry.value;
        final sNo = row.isSiteTotalRow ? '' : '${idx + 1}';
        final cells = _registerRowToStrings(row, sNo);
        return pw.TableRow(
          decoration: row.isSiteTotalRow
              ? const pw.BoxDecoration(color: PdfColors.blue100)
              : null,
          children: List.generate(cells.length, (i) {
            return _pdfDataCell(
              cells[i],
              bold: row.isSiteTotalRow || i == 8 || i == 9,
              highlight: row.isSiteTotalRow,
            );
          }),
        );
      }),
      // Grand total footer
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue200),
        children: [
          _pdfDataCell('GRAND TOTAL', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('', bold: true),
          _pdfDataCell('$totalLabourCount', bold: true),
          _pdfDataCell('$totalLabourCount', bold: true),
          _pdfDataCell(
            'OT: ${totalOtHours.toStringAsFixed(1)}h | ST: ${totalStHours.toStringAsFixed(1)}h',
            bold: true,
          ),
        ],
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5), // S.No
        1: const pw.FlexColumnWidth(1.0), // Date
        2: const pw.FlexColumnWidth(1.4), // Co-ordinator
        3: const pw.FlexColumnWidth(1.1), // Site Code
        4: const pw.FlexColumnWidth(1.4), // Supervisor
        5: const pw.FlexColumnWidth(0.7), // CT
        6: const pw.FlexColumnWidth(0.6), // LT
        7: const pw.FlexColumnWidth(1.5), // Sub.Contractor
        8: const pw.FlexColumnWidth(0.5), // Nos
        9: const pw.FlexColumnWidth(0.5), // Total
        10: const pw.FlexColumnWidth(1.6), // OT/ST Details
      },
      children: tableRows,
    );
  }

  // ── Export & Print ─────────────────────────────────────────────────────────
  Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();
    final exportRows = _buildRegisterExportRows();
    final dateRange = startDate != null && endDate != null
        ? '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}'
        : '';

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              _reportTitle(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _pdfNavy,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Site Labour Attendance Report  |  Period: $dateRange',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 10),
          _buildPdfSummaryBand(),
          pw.SizedBox(height: 12),
          _buildPdfRegisterTable(exportRows),
        ],
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );
    return pdf;
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = await _buildPdfDocument();
    return Uint8List.fromList(await doc.save());
  }

  Future<Uint8List?> _buildExcelBytes() async {
    final exportRows = _buildRegisterExportRows();
    final excelDoc = excel.Excel.createExcel();
    final defaultName = excelDoc.sheets.keys.first;
    if (defaultName != 'Site Labour Attendance') {
      excelDoc.rename(defaultName, 'Site Labour Attendance');
    }
    final sheet = excelDoc['Site Labour Attendance'];

    // Title block
    sheet.appendRow([
      excel.TextCellValue(_reportTitle()),
    ]);
    sheet.appendRow([
      excel.TextCellValue(
        'Site Labour Attendance Report  |  Period: ${startDate != null && endDate != null ? '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}' : ''}',
      ),
    ]);
    sheet.appendRow([]);

    // Summary row
    sheet.appendRow([
      excel.TextCellValue('SUMMARY'),
      excel.TextCellValue('Sites: $totalSites'),
      excel.TextCellValue('Supervisors: $totalSupervisors'),
      excel.TextCellValue('Contractors: $totalContractors'),
      excel.TextCellValue('Labour: $totalLabourCount'),
      excel.TextCellValue('OT Hrs: ${totalOtHours.toStringAsFixed(1)}'),
      excel.TextCellValue('ST Hrs: ${totalStHours.toStringAsFixed(1)}'),
    ]);
    sheet.appendRow([]);

    // Column headers
    sheet.appendRow(
      _registerHeaders.map((h) => excel.TextCellValue(h)).toList(),
    );

    // Data rows (register layout)
    for (int i = 0; i < exportRows.length; i++) {
      final row = exportRows[i];
      final sNo = row.isSiteTotalRow ? '' : '${i + 1}';
      final cells = _registerRowToStrings(row, sNo);
      sheet.appendRow(
        cells.map((c) => excel.TextCellValue(c)).toList(),
      );
    }

    // Grand total row
    sheet.appendRow([
      excel.TextCellValue('GRAND TOTAL'),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue(''),
      excel.TextCellValue('$totalLabourCount'),
      excel.TextCellValue('$totalLabourCount'),
      excel.TextCellValue(
        'OT: ${totalOtHours.toStringAsFixed(1)}h | ST: ${totalStHours.toStringAsFixed(1)}h',
      ),
    ]);

    // Contractor-wise totals section
    if (contractorTotals.isNotEmpty) {
      sheet.appendRow([]);
      sheet.appendRow([excel.TextCellValue('CONTRACTOR-WISE TOTALS')]);
      for (final c in contractorTotals) {
        sheet.appendRow([
          excel.TextCellValue(c['name']?.toString() ?? ''),
          excel.TextCellValue('${c['count']} workers'),
        ]);
      }
    }

    // Daily manpower summary
    if (dailySummary.isNotEmpty) {
      sheet.appendRow([]);
      sheet.appendRow([excel.TextCellValue('DAILY MANPOWER SUMMARY')]);
      for (final d in dailySummary) {
        final dateStr = d['date']?.toString() ?? '';
        final formatted = dateStr.length >= 10
            ? DateFormat('dd/MM/yyyy')
                .format(DateTime.tryParse(dateStr) ?? DateTime.now())
            : dateStr;
        sheet.appendRow([
          excel.TextCellValue(formatted),
          excel.TextCellValue('${d['count']} workers'),
        ]);
      }
    }

    return excelDoc.encode() != null
        ? Uint8List.fromList(excelDoc.encode()!)
        : null;
  }

  Future<String> _pdfFilePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/site_labour_attendance_${_reportFileSuffix()}.pdf';
  }

  Future<String> _excelFilePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/site_labour_attendance_${_reportFileSuffix()}.xlsx';
  }

  void _showDownloadReportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Download Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined, color: primaryColor),
                title: const Text('Download as PDF'),
                subtitle: Text(
                  'Preview the report, then download',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openPdfPreview();
                },
              ),
              ListTile(
                leading: Icon(Icons.table_chart_outlined, color: successColor),
                title: const Text('Download as Excel'),
                subtitle: Text(
                  'Download .xlsx file directly',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _downloadExcel();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openPdfPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text(
              'PDF Preview',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            children: [
              Expanded(
                child: PdfPreview(
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  maxPageWidth: 900,
                  pdfPreviewPageDecoration: BoxDecoration(
                    color: Colors.grey.shade200,
                  ),
                  loadingWidget: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                  build: (format) => _buildPdfBytes(),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    try {
      final bytes = await _buildPdfBytes();
      final path = await _pdfFilePath();
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(path)],
        subject: _reportTitle(),
        text: 'Site Labour Attendance Report (PDF)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF download failed: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _downloadExcel() async {
    try {
      final bytes = await _buildExcelBytes();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      if (kIsWeb) {
        // Web: trigger browser download via anchor element
        downloadFileWeb(
            bytes,
            'site_labour_attendance_${_reportFileSuffix()}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      } else {
        // Mobile / Desktop: save to temp directory and share
        final path = await _excelFilePath();
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(path)],
          subject: _reportTitle(),
          text: 'Site Labour Attendance Report (Excel)',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel download failed: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  pw.Widget _pdfStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _pdfNavy,
          ),
        ),
      ],
    );
  }

  Future<void> _shareReport() async {
    if (flatRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to share')),
      );
      return;
    }

    try {
      final bytes = await _buildPdfBytes();
      final path = await _pdfFilePath();
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(path)],
        subject: _reportTitle(),
        text: 'Site Labour Attendance Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing report: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _printReport() async {
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _reportTitle(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }
}

// ── Data models ──────────────────────────────────────────────────────────────

class _SiteGroup {
  final String siteCode;
  final String siteName;
  final int totalCount;
  final List<_SupervisorGroup> supervisors;

  _SiteGroup({
    required this.siteCode,
    required this.siteName,
    required this.totalCount,
    required this.supervisors,
  });
}

class _SupervisorGroup {
  final String supervisor;
  final int totalCount;
  final List<Map<String, dynamic>> rows;

  _SupervisorGroup({
    required this.supervisor,
    required this.totalCount,
    required this.rows,
  });
}

class _DropdownOption {
  final String id;
  final String label;
  const _DropdownOption({required this.id, required this.label});
}

class _RegisterExportRow {
  final String date;
  final String coordinator;
  final String siteCode;
  final String supervisor;
  final String categoryType;
  final String labourType;
  final String subContractor;
  final int workerCount;
  final int? totalCount;
  final String otStDetails;
  final String remarks;
  final bool isSiteTotalRow;
  final String siteTotalLabel;
  final int siteTotalValue;

  _RegisterExportRow({
    required this.date,
    required this.coordinator,
    required this.siteCode,
    required this.supervisor,
    required this.categoryType,
    required this.labourType,
    required this.subContractor,
    required this.workerCount,
    this.totalCount,
    required this.otStDetails,
    required this.remarks,
    required this.isSiteTotalRow,
    required this.siteTotalLabel,
    required this.siteTotalValue,
  });
}
