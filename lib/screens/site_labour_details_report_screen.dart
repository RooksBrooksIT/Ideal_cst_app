import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel_community/excel_community.dart' as excel;

class SiteLabourDetailsReportScreen extends StatefulWidget {
  const SiteLabourDetailsReportScreen({super.key});

  @override
  State<SiteLabourDetailsReportScreen> createState() =>
      _SiteLabourDetailsReportScreenState();
}

class _SiteLabourDetailsReportScreenState
    extends State<SiteLabourDetailsReportScreen> {
  // ── Colours ──────────────────────────────────────────────────────────────
  final Color primaryColor = const Color(0xFF0b3470);
  final Color primaryLight = const Color(0xFF1a4a8c);
  final Color accentColor = const Color(0xFF4a86e8);
  final Color bgColor = const Color(0xFFf0f4f9);
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF1e293b);
  final Color mutedColor = const Color(0xFF64748b);
  final Color successColor = const Color(0xFF16a34a);
  final Color errorColor = const Color(0xFFdc2626);

  // ── Filter state ──────────────────────────────────────────────────────────
  DateTime? startDate;
  DateTime? endDate;

  // Dynamic dropdown data
  List<_DropdownOption> siteOptions = [];
  List<_DropdownOption> supervisorOptions = [];
  List<_DropdownOption> subContractorOptions = [];
  List<_DropdownOption> categoryOptions = [];

  // Selected filter values (id/name based)
  String? selectedSiteId;
  String? selectedSiteName;
  String? selectedSupervisorName;
  String? selectedSubContractorName;
  String? selectedCategory;

  bool isLoadingFilters = true;
  bool isLoading = false;
  bool reportGenerated = true; // auto-generate on load
  bool showFilters = false; // controls filter panel expansion
  String searchQuery = ''; // search bar query

  // ── Result state ──────────────────────────────────────────────────────────
  int totalWorkers = 0;
  double totalLabourCost = 0.0;
  List<Map<String, dynamic>> reportData = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = now;
    endDate = now;
    _loadFilterData().then((_) {
      _generateReport(); // auto-generate report on load
    });
  }

  /// Fetch all dynamic dropdown options from Firestore in parallel.
  Future<void> _loadFilterData() async {
    setState(() => isLoadingFilters = true);
    try {
      final results = await Future.wait([_fetchSites()]);
      setState(() {
        siteOptions = results[0];
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
    // Pull unique supervisor names from siteSupervisorMap
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

  Future<List<_DropdownOption>> _fetchSubContractors() async {
    // Merge from contractors + sub_contractors collections
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

  Future<List<_DropdownOption>> _fetchCategories() async {
    // Pull unique category values from daily_labour_entries
    final snap = await FirebaseFirestore.instance
        .collection('daily_labour_entries')
        .get();
    final cats = <String>{};
    for (final doc in snap.docs) {
      final cat = doc.data()['category']?.toString();
      if (cat != null && cat.trim().isNotEmpty) cats.add(cat.trim());
    }
    final sorted = cats.toList()..sort();
    return sorted.map((c) => _DropdownOption(id: c, label: c)).toList();
  }

  // ── Report generation ─────────────────────────────────────────────────────
  // New state variables for additional totals
  double totalMealsAmount = 0.0;
  int totalMealsCount = 0;
  double totalBusAmount = 0.0;
  int totalBusCount = 0;

  Future<void> _generateReport() async {
    setState(() {
      isLoading = true;
      reportGenerated = true;
    });

    try {
      // Build date strings for comparison
      final startStr = startDate != null
          ? DateFormat('yyyy-MM-dd').format(startDate!)
          : null;
      final endStr = endDate != null
          ? DateFormat('yyyy-MM-dd').format(endDate!)
          : null;

      // Query daily_labour_entries (flat collection)
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'daily_labour_entries',
      );

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

      // SC attendance entries may not carry a salary because the contractor
      // master stores it as `salaryRate`. Load that master data once so the
      // report can display and total the subcontractor's labour cost.
      final subContractorsSnap = await FirebaseFirestore.instance
          .collection('sub_contractors')
          .get();
      final subContractorSalaryById = <String, double>{};
      final subContractorSalaryByName = <String, double>{};
      for (final doc in subContractorsSnap.docs) {
        final data = doc.data();
        final salary =
            data['salaryRate'] ?? data['basicSalary'] ?? data['salary'];
        final salaryValue = salary is num
            ? salary.toDouble()
            : double.tryParse(salary?.toString() ?? '') ?? 0.0;
        final name = (data['name'] ?? data['contractorName'])
            ?.toString()
            .trim();
        final contractorId = data['contractorId']?.toString().trim();
        subContractorSalaryById[doc.id] = salaryValue;
        if (contractorId != null && contractorId.isNotEmpty) {
          subContractorSalaryById[contractorId] = salaryValue;
        }
        if (name != null && name.isNotEmpty) {
          subContractorSalaryByName[name.toLowerCase()] = salaryValue;
        }
      }

      List<Map<String, dynamic>> entries = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_docId'] = d.id;
        return data;
      }).toList();

      // Calculate overall totals
      double costTotal = 0;
      double mealsAmountTotal = 0;
      int mealsCountTotal = 0;
      double busAmountTotal = 0;
      int busCountTotal = 0;

      // Keep one report row for every source entry.  In particular, SC and DW
      // are classifications of a labour record, not keys for combining records.
      final List<Map<String, dynamic>> reportRows = [];

      for (final e in entries) {
        final siteId = e['siteId']?.toString() ?? '-';
        final siteName = e['siteName']?.toString() ?? '-';
        final subContractor =
            (e['contractorName']?.toString() ??
            e['subContractorName']?.toString() ??
            '-');
        final labourType =
            (e['labourType'] ?? e['salaryType'])?.toString().trim().toLowerCase() ??
            '';
        final group =
            labourType == 'dw' || labourType.contains('daily') ? 'DW' : 'SC';
        final category = e['category']?.toString() ?? '-';
        // Worker Name belongs to the attendance record. It must not be
        // replaced with the subcontractor name for SC workers.
        final workerName = (e['workerName'] ?? e['name'] ?? '-').toString();
        final subContractorSalary = group == 'SC'
            ? (subContractorSalaryById[e['contractorId']?.toString()] ??
                  subContractorSalaryByName[subContractor.toLowerCase()] ??
                  0.0)
            : 0.0;

        // Extract fields from entry
        final entrySalaryBasic = (e['basicSalary'] as num?)?.toDouble() ?? 0.0;
        final salaryBasic =
            group == 'SC' && subContractorSalary > 0
                ? subContractorSalary
                : entrySalaryBasic;
        final hoursWorked = (e['hoursWorked'] as num?)?.toDouble() ?? 0.0;
        final recordedTotalSalary =
            (e['totalSalary'] as num?)?.toDouble() ?? 0.0;
        final totalSalary =
            group == 'SC' && recordedTotalSalary == 0 && subContractorSalary > 0
                ? subContractorSalary
                : recordedTotalSalary;
        final overtimeAmt = (e['overtimeAmount'] as num?)?.toDouble() ?? 0.0;
        final otRate = (e['overtimeRate'] as num?)?.toDouble() ?? 0.0;

        final mealsCount = (e['mealsCount'] as num?)?.toInt() ?? 0;
        final mealsAmount = (e['mealsAmount'] as num?)?.toDouble() ?? 0.0;
        final totalMealsAmount = mealsCount * mealsAmount;

        final busCount = (e['busCount'] as num?)?.toInt() ?? 0;
        final busAmount = (e['busAmount'] as num?)?.toDouble() ?? 0.0;
        final totalBusAmount = busCount * busAmount;

        reportRows.add({
          'siteId': siteId,
          'siteName': siteName,
          'subContractor': subContractor,
          'workerName': workerName,
          'group': group,
          'category': category,
          'labourCount': 1,
          'salaryBasic': salaryBasic,
          'totalSalary': totalSalary,
          'hours': hoursWorked,
          'otSalaryBasic': otRate,
          'otTotalAmount': overtimeAmt,
          'mealsExpense': mealsAmount,
          'mealsCount': mealsCount,
          'totalMealsAmount': totalMealsAmount,
          'busFare': busAmount,
          'busCount': busCount,
          'totalBusAmount': totalBusAmount,
          'otHours': e['otHours'] ?? e['overtimeHours'],
        });

        // Overall totals
        costTotal += totalSalary;
        mealsAmountTotal += totalMealsAmount;
        mealsCountTotal += mealsCount;
        busAmountTotal += totalBusAmount;
        busCountTotal += busCount;
      }

      setState(() {
        reportData = reportRows;
        totalWorkers = entries.length;
        totalLabourCost = costTotal;
        totalMealsAmount = mealsAmountTotal;
        totalMealsCount = mealsCountTotal;
        totalBusAmount = busAmountTotal;
        totalBusCount = busCountTotal;
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchAndFilterBar(),
                      const SizedBox(height: 12),
                      if (showFilters) ...[
                        _buildFiltersCard(),
                        const SizedBox(height: 12),
                        _buildGenerateButton(),
                        const SizedBox(height: 12),
                      ],
                      _buildSummaryRow(),
                      const SizedBox(height: 12),
                      Flexible(fit: FlexFit.loose, child: _buildResultArea()),
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
                hintText: 'Search workers...',
                hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: mutedColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
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
            onPressed: () {
              setState(() {
                showFilters = !showFilters;
              });
            },
          ),
        ),
      ],
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Site Labour Details Report',
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
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _generatePDF,
          tooltip: 'Download PDF',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _shareReport,
          tooltip: 'Share Report',
        ),
      ],
    );
  }

  // ── Filters card ──────────────────────────────────────────────────────────
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
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  startDate,
                  (d) => setState(() => startDate = d),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  endDate,
                  (d) => setState(() => endDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDynamicDropdown(
            label: 'Site',
            options: siteOptions,
            value: selectedSiteId,
            onChanged: (opt) => setState(() {
              selectedSiteId = opt?.id;
              selectedSiteName = opt?.label;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onChanged,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: ColorScheme.light(primary: primaryColor)),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.25)),
          ),
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: mutedColor,
          ),
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
    // If still loading filters show a shimmer-like placeholder
    if (isLoadingFilters) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: mutedColor),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
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

    // Ensure value is valid in the options list
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
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

  // ── Summary row ───────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                icon: Icons.people_alt_outlined,
                label: 'Total Workers',
                value: '$totalWorkers',
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryTile(
                icon: Icons.currency_rupee_outlined,
                label: 'Total Labour Cost',
                value: '₹${totalLabourCost.toStringAsFixed(2)}',
                color: successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                icon: Icons.restaurant,
                label: 'Total Meals Amount',
                value: '₹${totalMealsAmount.toStringAsFixed(2)}',
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryTile(
                icon: Icons.directions_bus,
                label: 'Total Bus Amount',
                value: '₹${totalBusAmount.toStringAsFixed(2)}',
                color: Colors.blue.shade700,
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
                  onPressed: isLoading ? null : _generatePDF,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Generate PDF',
                    style: TextStyle(
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
                  onPressed: isLoading ? null : _showExportOptions,
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
                    'Export',
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

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
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

  // ── Generate button ───────────────────────────────────────────────────────
  Widget _buildGenerateButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _generateReport,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.summarize_outlined, size: 18),
        label: Text(
          isLoading ? 'Generating...' : 'GENERATE REPORT',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  // ── Result area ───────────────────────────────────────────────────────────
  Widget _buildResultArea() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    // Only show empty state AFTER user has generated a report
    if (reportGenerated && reportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No data available.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your filters and generate again.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Empty before first generation → show nothing
    if (!reportGenerated) return const SizedBox.shrink();

    // Apply search filter first
    List<Map<String, dynamic>> filteredReportData = reportData;
    if (searchQuery.isNotEmpty) {
      filteredReportData = reportData.where((entry) {
        final subContractor =
            entry['subContractor']?.toString().toLowerCase() ?? '';
        final workerName = entry['workerName']?.toString().toLowerCase() ?? '';
        final siteName = entry['siteName']?.toString().toLowerCase() ?? '';
        final category = entry['category']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return subContractor.contains(query) ||
            workerName.contains(query) ||
            siteName.contains(query) ||
            category.contains(query);
      }).toList();
    }

    // If after search we have no results
    if (searchQuery.isNotEmpty && filteredReportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$searchQuery".',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ],
        ),
      );
    }

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
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: DataTable(
              columnSpacing: 12,
              dataRowHeight: 56,
              headingRowHeight: 48,
              headingRowColor: WidgetStateProperty.all(primaryColor),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor.withValues(alpha: 0.08);
                }
                return null;
              }),
              dividerThickness: 1,
              columns: const [
                DataColumn(
                  label: Text(
                    'Sl. No.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Site Code',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Site Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Sub Contractor',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Worker Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Group',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Type / Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Labour Count',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Salary (Basic)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Total Salary',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Hours',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'OT Salary (Basic)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'OT Total Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Meals Expense',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Meals Count',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Total Meals Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Bus Fare',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Bus Count',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Total Bus Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: List.generate(filteredReportData.length, (index) {
                final entry = filteredReportData[index];
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['siteId']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['siteName']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['subContractor']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['workerName']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['group']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['category']?.toString() ?? '-',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        entry['labourCount']?.toString() ?? '0',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['salaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['totalSalary'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(entry['hours'] as double?)?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['otSalaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['otTotalAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['mealsExpense'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        (entry['mealsCount'] as int?)?.toString() ?? '0',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['totalMealsAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['busFare'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        (entry['busCount'] as int?)?.toString() ?? '0',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${(entry['totalBusAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard(
    String siteId,
    String siteName,
    List<Map<String, dynamic>> entries,
  ) {
    // Compute site totals
    double siteOT = 0;
    double siteCost = 0;
    for (final e in entries) {
      final otRaw = e['otHours'];
      if (otRaw is num) siteOT += otRaw.toDouble();
      if (otRaw is String)
        siteOT += double.tryParse(otRaw.split(' ').first) ?? 0;
      siteCost += (e['totalAmount'] as num?)?.toDouble() ?? 0;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card header ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_city_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            siteName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Site ID: $siteId',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${entries.length} Workers',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Worker entries ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: entries.asMap().entries.map((mapEntry) {
                final i = mapEntry.key;
                final e = mapEntry.value;
                return _buildWorkerRow(e, isLast: i == entries.length - 1);
              }).toList(),
            ),
          ),

          // ── Totals footer ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              border: Border(
                top: BorderSide(
                  color: primaryColor.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFooterStat(
                  Icons.people_outline,
                  '${entries.length}',
                  'Workers',
                ),
                _buildFooterDivider(),
                _buildFooterStat(
                  Icons.access_time_outlined,
                  '${siteOT.toStringAsFixed(1)} h',
                  'Total OT',
                ),
                _buildFooterDivider(),
                _buildFooterStat(
                  Icons.currency_rupee,
                  '₹${siteCost.toStringAsFixed(2)}',
                  'Labour Cost',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerRow(Map<String, dynamic> e, {required bool isLast}) {
    final workerName = e['workerName']?.toString() ?? '-';
    final supervisor = e['supervisorName']?.toString() ?? '-';
    final category = e['category']?.toString() ?? '-';
    final contractor = e['contractorName']?.toString();
    final attendanceType = e['attendanceType']?.toString() ?? '-';
    final otRaw = e['otHours'];
    final otDisplay = otRaw is String
        ? otRaw
        : (otRaw is num ? '${otRaw.toStringAsFixed(1)} Hours' : '0 Hours');
    final inTime = e['inTime']?.toString() ?? '';
    final outTime = e['outTime']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + attendance badge
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                child: Text(
                  workerName.isNotEmpty ? workerName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  workerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),
              _buildBadge(attendanceType),
            ],
          ),
          const SizedBox(height: 8),

          // Details grid
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildDetailChip(Icons.supervisor_account_outlined, supervisor),
              _buildDetailChip(Icons.work_outline, category),
              if (contractor != null && contractor.isNotEmpty)
                _buildDetailChip(Icons.handshake_outlined, contractor),
              if (inTime.isNotEmpty)
                _buildDetailChip(Icons.login_outlined, 'In: $inTime'),
              if (outTime.isNotEmpty)
                _buildDetailChip(Icons.logout_outlined, 'Out: $outTime'),
              _buildDetailChip(Icons.more_time_outlined, 'OT: $otDisplay'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String type) {
    Color badgeColor;
    switch (type) {
      case 'Full Day':
      case 'Night Shift':
        badgeColor = successColor;
        break;
      case 'Half Day':
      case 'Early Out':
        badgeColor = const Color(0xFFd97706);
        break;
      case 'Absent':
        badgeColor = errorColor;
        break;
      default:
        badgeColor = mutedColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: mutedColor),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: mutedColor)),
      ],
    );
  }

  Widget _buildFooterStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: mutedColor)),
      ],
    );
  }

  Widget _buildFooterDivider() {
    return Container(
      height: 28,
      width: 1,
      color: primaryColor.withValues(alpha: 0.15),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Calculate overall totals
    double totalOTHours = 0;
    for (final entry in reportData) {
      final otRaw = entry['otHours'];
      if (otRaw is num) {
        totalOTHours += otRaw.toDouble();
      } else if (otRaw is String) {
        totalOTHours += double.tryParse(otRaw.split(' ').first) ?? 0.0;
      }
    }

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SITE LABOUR DETAILS REPORT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(now)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (startDate != null && endDate != null)
                      pw.Text(
                        'Period: ${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    if (selectedSiteName != null)
                      pw.Text(
                        'Site: $selectedSiteName',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential - For Internal Use Only',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          // Build the main table with all data
          final List<List<String>>
          tableData = List<List<String>>.generate(reportData.length, (index) {
            final e = reportData[index];
            final slNo = (index + 1).toString();
            final siteId = e['siteId']?.toString() ?? '-';
            final siteName = e['siteName']?.toString() ?? '-';
            final subContractorName = e['subContractor']?.toString() ?? '-';
            final workerName = e['workerName']?.toString() ?? '-';
            final group = e['group']?.toString() ?? '-';
            final category = e['category']?.toString() ?? '-';
            final labourCount = e['labourCount']?.toString() ?? '0';
            final salaryBasic =
                '₹${(e['salaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final totalSalary =
                '₹${(e['totalSalary'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final hours =
                '${(e['hours'] as double?)?.toStringAsFixed(1) ?? '0.0'}';
            final otSalaryBasic =
                '₹${(e['otSalaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final otTotalAmount =
                '₹${(e['otTotalAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final mealsExpense =
                '₹${(e['mealsExpense'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final mealsCount = e['mealsCount']?.toString() ?? '0';
            final totalMealsAmount =
                '₹${(e['totalMealsAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final busFare =
                '₹${(e['busFare'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            final busCount = e['busCount']?.toString() ?? '0';
            final totalBusAmount =
                '₹${(e['totalBusAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}';
            return [
              slNo,
              siteId,
              siteName,
              subContractorName,
              workerName,
              group,
              category,
              labourCount,
              salaryBasic,
              totalSalary,
              hours,
              otSalaryBasic,
              otTotalAmount,
              mealsExpense,
              mealsCount,
              totalMealsAmount,
              busFare,
              busCount,
              totalBusAmount,
            ];
          });

          return [
            // Grand summary at top
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'GRAND TOTAL WORKERS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$totalWorkers',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL OT HOURS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${totalOTHours.toStringAsFixed(1)}h',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL LABOUR COST',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${totalLabourCost.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL MEALS AMOUNT',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${totalMealsAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL BUS AMOUNT',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${totalBusAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Main table
            pw.Table.fromTextArray(
              context: context,
              headers: [
                'Sl. No.',
                'Site Code',
                'Site Name',
                'Sub Contractor',
                'Worker Name',
                'Group',
                'Type / Category',
                'Labour Count',
                'Salary (Basic)',
                'Total Salary',
                'Hours',
                'OT Salary (Basic)',
                'OT Total Amount',
                'Meals Expense',
                'Meals Count',
                'Total Meals Amount',
                'Bus Fare',
                'Bus Count',
                'Total Bus Amount',
              ],
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight,
                11: pw.Alignment.centerRight,
                12: pw.Alignment.centerRight,
                13: pw.Alignment.centerRight,
                14: pw.Alignment.centerRight,
                15: pw.Alignment.centerRight,
                16: pw.Alignment.centerRight,
                17: pw.Alignment.centerRight,
                18: pw.Alignment.centerRight,
              },
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              rowDecoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              cellStyle: pw.TextStyle(fontSize: 6),
              data: tableData,
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> _generatePDF() async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to generate PDF')),
      );
      return;
    }

    try {
      final pdf = await _buildPdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<void> _shareReport() async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No report data to share')));
      return;
    }

    try {
      final pdf = await _buildPdfDocument();
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/site_labour_report.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing report: $e')));
      }
    }
  }

  Future<void> _exportExcel() async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No report data to export')));
      return;
    }

    try {
      final excel.Excel excelDoc = excel.Excel.createExcel();
      final excel.Sheet sheet = excelDoc['Site Labour Report'];

      // Headers
      sheet.appendRow([
        excel.TextCellValue('Sl. No.'),
        excel.TextCellValue('Site Code'),
        excel.TextCellValue('Site Name'),
        excel.TextCellValue('Sub Contractor'),
        excel.TextCellValue('Worker Name'),
        excel.TextCellValue('Group'),
        excel.TextCellValue('Type / Category'),
        excel.TextCellValue('Labour Count'),
        excel.TextCellValue('Salary (Basic)'),
        excel.TextCellValue('Total Salary'),
        excel.TextCellValue('Hours'),
        excel.TextCellValue('OT Salary (Basic)'),
        excel.TextCellValue('OT Total Amount'),
        excel.TextCellValue('Meals Expense'),
        excel.TextCellValue('Meals Count'),
        excel.TextCellValue('Total Meals Amount'),
        excel.TextCellValue('Bus Fare'),
        excel.TextCellValue('Bus Count'),
        excel.TextCellValue('Total Bus Amount'),
      ]);

      for (int i = 0; i < reportData.length; i++) {
        final entry = reportData[i];
        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(entry['siteId']?.toString() ?? '-'),
          excel.TextCellValue(entry['siteName']?.toString() ?? '-'),
          excel.TextCellValue(entry['subContractor']?.toString() ?? '-'),
          excel.TextCellValue(entry['workerName']?.toString() ?? '-'),
          excel.TextCellValue(entry['group']?.toString() ?? '-'),
          excel.TextCellValue(entry['category']?.toString() ?? '-'),
          excel.IntCellValue((entry['labourCount'] as int?) ?? 0),
          excel.TextCellValue(
            '₹${(entry['salaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.TextCellValue(
            '₹${(entry['totalSalary'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.TextCellValue(
            '${(entry['hours'] as double?)?.toStringAsFixed(1) ?? '0.0'}',
          ),
          excel.TextCellValue(
            '₹${(entry['otSalaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.TextCellValue(
            '₹${(entry['otTotalAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.TextCellValue(
            '₹${(entry['mealsExpense'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.IntCellValue((entry['mealsCount'] as int?) ?? 0),
          excel.TextCellValue(
            '₹${(entry['totalMealsAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.TextCellValue(
            '₹${(entry['busFare'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
          excel.IntCellValue((entry['busCount'] as int?) ?? 0),
          excel.TextCellValue(
            '₹${(entry['totalBusAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
        ]);
      }

      // Add totals row
      sheet.appendRow([
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue('Grand Total:'),
        excel.TextCellValue(''),
        excel.TextCellValue('₹${totalLabourCost.toStringAsFixed(2)}'),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue('₹${totalMealsAmount.toStringAsFixed(2)}'),
        excel.TextCellValue(''),
        excel.TextCellValue(''),
        excel.TextCellValue('₹${totalBusAmount.toStringAsFixed(2)}'),
      ]);

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/site_labour_report_$timestamp.xlsx');
      final List<int>? fileBytes = excelDoc.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
      }
    }
  }

  Future<void> _exportCSV() async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No report data to export')));
      return;
    }

    try {
      final StringBuffer csvBuffer = StringBuffer();

      // Headers
      csvBuffer.writeln(
        'Sl. No.,Site Code,Site Name,Sub Contractor,Worker Name,Group,Type / Category,Labour Count,Salary (Basic),Total Salary,Hours,OT Salary (Basic),OT Total Amount,Meals Expense,Meals Count,Total Meals Amount,Bus Fare,Bus Count,Total Bus Amount',
      );

      for (int i = 0; i < reportData.length; i++) {
        final entry = reportData[i];
        csvBuffer.writeln(
          [
            i + 1,
            '"${entry['siteId']?.toString().replaceAll('"', '""') ?? '-'}"',
            '"${entry['siteName']?.toString().replaceAll('"', '""') ?? '-'}"',
            '"${entry['subContractor']?.toString().replaceAll('"', '""') ?? '-'}"',
            '"${entry['workerName']?.toString().replaceAll('"', '""') ?? '-'}"',
            '"${entry['group']?.toString().replaceAll('"', '""') ?? '-'}"',
            '"${entry['category']?.toString().replaceAll('"', '""') ?? '-'}"',
            entry['labourCount']?.toString() ?? '0',
            '"₹${(entry['salaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            '"₹${(entry['totalSalary'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            '"${(entry['hours'] as double?)?.toStringAsFixed(1) ?? '0.0'}"',
            '"₹${(entry['otSalaryBasic'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            '"₹${(entry['otTotalAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            '"₹${(entry['mealsExpense'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            entry['mealsCount']?.toString() ?? '0',
            '"₹${(entry['totalMealsAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            '"₹${(entry['busFare'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
            entry['busCount']?.toString() ?? '0',
            '"₹${(entry['totalBusAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}"',
          ].join(','),
        );
      }

      // Add totals row
      csvBuffer.writeln(
        [
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'Grand Total:',
          '',
          '"₹${totalLabourCost.toStringAsFixed(2)}"',
          '',
          '',
          '',
          '',
          '',
          '"₹${totalMealsAmount.toStringAsFixed(2)}"',
          '',
          '',
          '"₹${totalBusAmount.toStringAsFixed(2)}"',
        ].join(','),
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/site_labour_report_$timestamp.csv');
      await file.writeAsString(csvBuffer.toString());
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
      }
    }
  }

  Future<void> _showExportOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export as Excel (.xlsx)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Export as CSV (.csv)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportCSV();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper model ──────────────────────────────────────────────────────────────
class _DropdownOption {
  final String id;
  final String label;
  const _DropdownOption({required this.id, required this.label});
}
