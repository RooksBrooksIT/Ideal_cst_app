import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class DailySitePaymentReportScreen extends StatefulWidget {
  const DailySitePaymentReportScreen({super.key});

  @override
  _DailySitePaymentReportScreenState createState() =>
      _DailySitePaymentReportScreenState();
}

class _DailySitePaymentReportScreenState
    extends State<DailySitePaymentReportScreen> {
  final Color mainColor = const Color(0xFF003768);

  List<String> siteIds = [];
  Map<String, Map<String, String>> siteDetails = {};

  String? selectedSiteId;
  String? selectedProject;
  String? selectedSupervisor;

  final TextEditingController projectController = TextEditingController();
  final TextEditingController supervisorController = TextEditingController();

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  int? selectedWeekIndex;
  List<DateTime> weekDates = [];
  List<Map<String, dynamic>> paymentRecords = [];
  double totalAmount = 0.0;

  List<int> years = List.generate(
    5,
    (index) => DateTime.now().year - 2 + index,
  );

  @override
  void initState() {
    super.initState();
    _fetchSiteIdsAndDetails();
  }

  Future<void> _fetchSiteIdsAndDetails() async {
    try {
      final ids = <String>{};
      final details = <String, Map<String, String>>{};

      // 1. Fetch siteSupervisorPayments
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorPayments')
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final siteId = data['siteId']?.toString();
          if (siteId != null && siteId.isNotEmpty) {
            ids.add(siteId);
            details[siteId] = {
              'project': data['projectName']?.toString() ?? '',
              'supervisor': data['supervisorName']?.toString() ?? '',
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorPayments: $e');
      }

      // 2. Fetch siteSupervisorMap
      try {
        final mapSnap = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .get();
        for (var doc in mapSnap.docs) {
          final data = doc.data();
          final siteId = data['site']?.toString() ?? doc.id;
          if (siteId.isNotEmpty) {
            ids.add(siteId);
            if (!details.containsKey(siteId)) {
              details[siteId] = {
                'project': data['projectName']?.toString() ?? '',
                'supervisor': data['supervisor']?.toString() ?? '',
              };
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorMap: $e');
      }

      // 3. Fetch projects
      try {
        final projectsSnap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        for (var doc in projectsSnap.docs) {
          final data = doc.data();
          final siteId = data['siteId']?.toString() ?? doc.id;
          if (siteId.isNotEmpty) {
            ids.add(siteId);
            if (!details.containsKey(siteId)) {
              details[siteId] = {
                'project': data['projectName']?.toString() ?? '',
                'supervisor': data['supervisor']?.toString() ?? data['supervisorName']?.toString() ?? '',
              };
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      if (mounted) {
        final sortedIds = ids.toList()..sort();
        setState(() {
          siteIds = sortedIds;
          siteDetails = details;
        });
      }
    } catch (e) {
      debugPrint('Error fetching site IDs and details: $e');
    }
  }

  void _updateProjectAndSupervisor() {
    if (selectedSiteId != null && siteDetails.containsKey(selectedSiteId)) {
      selectedProject = siteDetails[selectedSiteId]!['project'];
      selectedSupervisor = siteDetails[selectedSiteId]!['supervisor'];
      projectController.text = selectedProject ?? '';
      supervisorController.text = selectedSupervisor ?? '';
    } else {
      selectedProject = null;
      selectedSupervisor = null;
      projectController.text = '';
      supervisorController.text = '';
    }
  }

  List<List<DateTime>> _getWeeksOfMonth(int year, int month) {
    List<List<DateTime>> weeks = [];
    try {
      DateTime firstDay = DateTime(year, month, 1);
      DateTime lastDayOfMonth = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      int dayOffset = firstDay.weekday - 1;
      DateTime weekStart = firstDay.subtract(Duration(days: dayOffset));

      while (weekStart.isBefore(lastDayOfMonth) ||
          weekStart.isAtSameMomentAs(lastDayOfMonth)) {
        List<DateTime> week = [];

        for (int i = 0; i < 7; i++) {
          DateTime day = weekStart.add(Duration(days: i));
          if (day.month == month && day.year == year) {
            week.add(day);
          }
        }

        if (week.isNotEmpty) {
          weeks.add(week);
        }

        weekStart = weekStart.add(const Duration(days: 7));

        if (weekStart.month > month || (weekStart.month == 1 && month == 12)) {
          break;
        }
      }
    } catch (e) {
      debugPrint('Error calculating weeks of month: $e');
      weeks = [];
    }
    return weeks;
  }

  Future<void> _onWeekSelected(int index) async {
    setState(() {
      selectedWeekIndex = index;
      List<List<DateTime>> weeks = _getWeeksOfMonth(
        selectedYear,
        selectedMonth,
      );
      weekDates = weeks[index];
      paymentRecords = [];
      totalAmount = 0.0;
    });
    await _fetchPaymentsForSelectedPeriod();
  }

  Future<void> _fetchPaymentsForSelectedPeriod() async {
    if (selectedSiteId == null || selectedWeekIndex == null) return;
    String monthStr = DateFormat(
      'MMM',
    ).format(DateTime(selectedYear, selectedMonth));
    String period = '${selectedYear}_${monthStr}_Week${selectedWeekIndex! + 1}';
    final snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorPayments')
        .where('siteId', isEqualTo: selectedSiteId)
        .where('paymentPeriod', isEqualTo: period)
        .get();
    List<Map<String, dynamic>> paymentsList = [];
    double sum = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['payments'] != null && data['payments'] is List) {
        for (var p in data['payments']) {
          if (p is Map<String, dynamic>) {
            paymentsList.add(p);
            sum += double.tryParse(p['paymentAmount'].toString()) ?? 0.0;
          }
        }
      }
    }
    setState(() {
      paymentRecords = paymentsList;
      totalAmount = sum;
    });
  }

  void _onCancel() {
    setState(() {
      selectedSiteId = null;
      selectedProject = null;
      selectedSupervisor = null;
      projectController.text = '';
      supervisorController.text = '';
      selectedMonth = DateTime.now().month;
      selectedYear = DateTime.now().year;
      selectedWeekIndex = null;
      weekDates = [];
      paymentRecords = [];
      totalAmount = 0.0;
    });
  }

  Future<void> _onPrint() async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        theme: pdfTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Site Payment Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Site ID: ${selectedSiteId ?? ''}'),
              pw.Text('Project: ${selectedProject ?? ''}'),
              pw.Text('Supervisor: ${selectedSupervisor ?? ''}'),
              pw.Text(
                'Month: ${DateFormat.MMMM().format(DateTime(0, selectedMonth))}',
              ),
              pw.Text('Year: $selectedYear'),
              pw.Text(
                'Week: ${selectedWeekIndex != null ? selectedWeekIndex! + 1 : ''}',
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF003768),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFFFFFFFF),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Payment',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFFFFFFFF),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...paymentRecords.map((rec) {
                    String dateStr = '';
                    if (rec['paymentDate'] != null) {
                      try {
                        DateTime dt = DateFormat(
                          'yyyy-MM-dd',
                        ).parse(rec['paymentDate']);
                        dateStr = DateFormat('EEE, MMM d, yyyy').format(dt);
                      } catch (e) {
                        dateStr = rec['paymentDate'].toString();
                      }
                    }
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(dateStr),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            rec['paymentAmount']?.toString() ?? '',
                          ),
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          totalAmount.toStringAsFixed(2),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  void dispose() {
    projectController.dispose();
    supervisorController.dispose();
    super.dispose();
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
                  'Site Payment',
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

  Widget _buildTextFieldContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<List<DateTime>> weeks = _getWeeksOfMonth(selectedYear, selectedMonth);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

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
                child: Container(
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
                        // Site ID Dropdown
                        _buildSectionTitle('Site ID'),
                        const SizedBox(height: 8),
                        CustomDropdown<String>(
                          hintText: 'Select Site ID',
                          value: selectedSiteId,
                          mainColor: mainColor,
                          items: siteIds.map((id) => DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E1E2D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSiteId = value;
                              _updateProjectAndSupervisor();
                              selectedWeekIndex = null;
                              weekDates = [];
                              paymentRecords = [];
                              totalAmount = 0.0;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Project (Read-only)
                        _buildSectionTitle('Project'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            readOnly: true,
                            controller: projectController,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: mainColor,
                            ),
                            decoration: _inputDecoration().copyWith(
                              hintText: 'Auto-filled project',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Supervisor (Read-only)
                        _buildSectionTitle('Supervisor'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            readOnly: true,
                            controller: supervisorController,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: mainColor,
                            ),
                            decoration: _inputDecoration().copyWith(
                              hintText: 'Auto-filled supervisor',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Year and Month
                        _buildSectionTitle('Year and Month'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CustomDropdown<int>(
                                hintText: 'Month',
                                value: selectedMonth,
                                mainColor: mainColor,
                                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem<int>(
                                  value: m,
                                  child: Text(
                                    DateFormat.MMMM().format(DateTime(0, m)),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E1E2D),
                                    ),
                                  ),
                                )).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedMonth = value;
                                      selectedWeekIndex = null;
                                      weekDates = [];
                                      paymentRecords = [];
                                      totalAmount = 0.0;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomDropdown<int>(
                                hintText: 'Year',
                                value: selectedYear,
                                mainColor: mainColor,
                                items: years.map((y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(
                                    y.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E1E2D),
                                    ),
                                  ),
                                )).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedYear = value;
                                      selectedWeekIndex = null;
                                      weekDates = [];
                                      paymentRecords = [];
                                      totalAmount = 0.0;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Weeks Selection
                        _buildSectionTitle('Weeks'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(weeks.length, (i) {
                            final isSelected = selectedWeekIndex == i;
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
                              onSelected: (_) {
                                _onWeekSelected(i);
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Payment Details Table
                        if (selectedWeekIndex != null && weekDates.isNotEmpty) ...[
                          _buildSectionTitle('Payments for Week ${selectedWeekIndex! + 1}'),
                          const SizedBox(height: 10),
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: mainColor.withValues(alpha: 0.2),
                              ),
                              color: Colors.white,
                            ),
                            child: Table(
                              border: TableBorder.symmetric(
                                inside: BorderSide(
                                  color: mainColor.withValues(alpha: 0.1),
                                ),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(2),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: mainColor,
                                  ),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'Payment (₹)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ...paymentRecords.map((rec) {
                                  String dateStr = '';
                                  if (rec['paymentDate'] != null) {
                                    try {
                                      DateTime dt = (rec['paymentDate'] is Timestamp)
                                          ? (rec['paymentDate'] as Timestamp).toDate()
                                          : DateFormat('yyyy-MM-dd').parse(rec['paymentDate'].toString());
                                      dateStr = DateFormat('EEE, MMM d, yyyy').format(dt);
                                    } catch (e) {
                                      dateStr = rec['paymentDate'].toString();
                                    }
                                  }
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          dateStr,
                                          style: const TextStyle(
                                            color: Color(0xFF1E1E2D),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '₹${rec['paymentAmount']?.toString() ?? '0'}',
                                          style: TextStyle(
                                            color: mainColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                if (paymentRecords.isNotEmpty)
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: mainColor.withValues(alpha: 0.05),
                                    ),
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E1E2D),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '₹${totalAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: mainColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // Action Buttons
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.print, color: Colors.white),
                                label: const Text(
                                  'EXPORT / PRINT REPORT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (selectedWeekIndex != null && paymentRecords.isNotEmpty)
                                      ? mainColor
                                      : Colors.grey,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                onPressed: (selectedWeekIndex != null && paymentRecords.isNotEmpty)
                                    ? _onPrint
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: mainColor, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _onCancel,
                                    child: Text(
                                      'RESET',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: mainColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
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
