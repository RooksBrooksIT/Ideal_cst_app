import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';
import 'package:ideal_cst/screens/organization/components/custom_calendar.dart';

class SitePaymentScreen extends StatefulWidget {
  const SitePaymentScreen({super.key});

  @override
  _SitePaymentScreenState createState() => _SitePaymentScreenState();
}

class _SitePaymentScreenState extends State<SitePaymentScreen> {
  final Color mainColor = const Color(0xFF003768);

  // Site list for dropdown (list of {id, display})
  List<Map<String, String>> siteList = [];

  String? selectedSiteId;
  String supervisor = '';
  int amount = 0;
  DateTime? selectedDate;
  final TextEditingController amountController = TextEditingController();

  // Project Stage Dropdown
  List<String> projectStages = [];
  String? selectedProjectStage;

  // Payment Period
  int selectedPaymentYear = DateTime.now().year;
  int selectedPaymentMonth = DateTime.now().month;
  int? selectedPaymentWeekIndex;

  List<int> paymentYears = List.generate(
    5,
    (index) => DateTime.now().year - 2 + index,
  );

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

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _fetchSiteIds();
    _fetchProjectStages();
  }

  Future<void> _fetchProjectStages() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Project stages query timeout',
                const Duration(seconds: 10),
              );
            },
          );

      if (!mounted) return;

      setState(() {
        projectStages = snapshot.docs
            .map((doc) => (doc.data()['projectStage'] ?? '').toString())
            .where((stage) => stage.isNotEmpty)
            .toList();
      });
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching project stages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load project stages')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching project stages: $e');
    }
  }

  Future<void> _fetchSiteIds() async {
    try {
      final Map<String, String> mergedSiteMap = {};

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final display = (data['site'] ?? doc.id).toString();
          if (display.isNotEmpty) {
            mergedSiteMap[display] = display;
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorMap: $e');
      }

      try {
        final projectsSnap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        for (var doc in projectsSnap.docs) {
          final data = doc.data();
          final display = (data['siteId'] ?? doc.id).toString();
          if (display.isNotEmpty) {
            mergedSiteMap[display] = display;
          }
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      if (!mounted) return;

      final sortedKeys = mergedSiteMap.keys.toList()..sort();

      setState(() {
        siteList = sortedKeys.map((k) => {'id': k, 'display': k}).toList();
      });
    } catch (e) {
      debugPrint('Error fetching site IDs: $e');
    }
  }

  Future<void> _fetchSupervisorForSite(String siteId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .doc(siteId)
          .get();
      if (doc.exists) {
        setState(() {
          supervisor = doc.data()?['supervisor'] ?? '';
          amount = (doc.data()?['amount'] ?? 0).toInt();
          amountController.text = amount == 0 ? '' : amount.toString();
        });
      } else {
        setState(() {
          supervisor = '';
          amount = 0;
          amountController.text = '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching supervisor: $e');
    }
  }

  void resetForm() {
    setState(() {
      selectedSiteId = null;
      supervisor = '';
      amount = 0;
      amountController.text = '';
      selectedDate = DateTime.now();
      selectedProjectStage = null;
      selectedPaymentWeekIndex = null;
      selectedPaymentYear = DateTime.now().year;
      selectedPaymentMonth = DateTime.now().month;
    });
  }

  Future<void> _submitPayment() async {
    if (selectedSiteId == null ||
        supervisor.isEmpty ||
        amount <= 0 ||
        selectedProjectStage == null ||
        selectedPaymentWeekIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields including week selection!',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final siteMap = siteList.firstWhere(
        (s) => s['id'] == selectedSiteId,
        orElse: () => {'display': selectedSiteId!},
      );
      final siteDisplay = siteMap['display'] ?? selectedSiteId!;
      String projectName = '';
      if (siteDisplay.contains('_')) {
        final parts = siteDisplay.split('_');
        if (parts.length > 1) {
          projectName = parts.sublist(1).join('_');
        }
      }
      if (projectName.isEmpty) projectName = siteDisplay;

      final date = selectedDate ?? DateTime.now();
      final year = date.year;
      final monthStr = DateFormat('MMM').format(date);
      final weekIndex = selectedPaymentWeekIndex! + 1;
      final paymentPeriod = '${year}_${monthStr}_Week$weekIndex';
      final docId = '${siteDisplay}_$paymentPeriod';

      final paymentDocRef = FirebaseFirestore.instance
          .collection('siteSupervisorPayments')
          .doc(docId);

      final paymentDocSnap = await paymentDocRef.get();
      List<dynamic> payments = [];
      if (paymentDocSnap.exists) {
        final data = paymentDocSnap.data();
        payments = List.from(data?['payments'] ?? []);
      }

      final paymentDateStr = DateFormat('yyyy-MM-dd').format(date);
      final existingIndex = payments.indexWhere(
        (p) => p['paymentDate'] == paymentDateStr,
      );

      if (existingIndex >= 0) {
        payments[existingIndex]['paymentAmount'] = amount;
      } else {
        payments.add({'paymentDate': paymentDateStr, 'paymentAmount': amount});
      }

      int newTotal = payments.fold(
        0,
        (int sum, p) => sum + ((p['paymentAmount'] ?? 0) as int),
      );

      await paymentDocRef.set({
        'paymentAmount': newTotal,
        'payments': payments,
        'paymentPeriod': paymentPeriod,
        'projectName': projectName,
        'projectStage': selectedProjectStage,
        'siteId': siteDisplay,
        'supervisorName': supervisor,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment Added Successfully!'),
          backgroundColor: mainColor,
          duration: const Duration(seconds: 2),
        ),
      );

      resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
                  'Site Payment',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Entry',
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

  @override
  Widget build(BuildContext context) {
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
                        _buildSectionTitle('Site ID *'),
                        const SizedBox(height: 8),
                        CustomDropdown<String>(
                          hintText: 'Select Site ID',
                          value: selectedSiteId,
                          mainColor: mainColor,
                          items: siteList.map((site) {
                            return DropdownMenuItem<String>(
                              value: site['id'],
                              child: Text(
                                site['display'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E1E2D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              selectedSiteId = value;
                              supervisor = '';
                              amount = 0;
                              amountController.text = '';
                            });
                            if (value != null) {
                              await _fetchSupervisorForSite(value);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Supervisor (auto-filled)
                        _buildSectionTitle('Supervisor *'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            readOnly: true,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: mainColor,
                            ),
                            decoration: _inputDecoration().copyWith(
                              hintText: 'Auto-filled supervisor',
                            ),
                            controller: TextEditingController(text: supervisor),
                            key: ValueKey(supervisor),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount
                        _buildSectionTitle('Amount *'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: mainColor,
                            ),
                            decoration: _inputDecoration().copyWith(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 14, right: 8),
                                child: Text(
                                  '₹',
                                  style: TextStyle(fontSize: 20, color: mainColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              hintText: 'Enter amount',
                            ),
                            onChanged: (value) {
                              setState(() {
                                amount = int.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Project Stage Dropdown
                        _buildSectionTitle('Project Stage *'),
                        const SizedBox(height: 8),
                        CustomDropdown<String>(
                          hintText: 'Select Project Stage',
                          value: selectedProjectStage,
                          mainColor: mainColor,
                          items: projectStages.map((stage) {
                            return DropdownMenuItem<String>(
                              value: stage,
                              child: Text(
                                stage,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E1E2D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedProjectStage = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Year and Month
                        _buildSectionTitle('Year and Month *'),
                        const SizedBox(height: 8),
                        isSmallScreen ? _buildYearMonthColumn() : _buildYearMonthRow(),
                        const SizedBox(height: 20),

                        // Weeks Selection
                        _buildWeeksSection(),
                        const SizedBox(height: 20),

                        // Date Picker (only show if week is selected)
                        if (selectedPaymentWeekIndex != null) _buildDatePickerSection(),

                        const SizedBox(height: 28),

                        // Action Buttons
                        _buildActionButtons(isSmallScreen),

                        const SizedBox(height: 16),
                        Text(
                          '* indicates required fields',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildYearMonthRow() {
    return Row(
      children: [
        Expanded(
          child: CustomDropdown<int>(
            hintText: 'Year',
            value: selectedPaymentYear,
            mainColor: mainColor,
            items: paymentYears.map((y) => DropdownMenuItem<int>(
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
                  selectedPaymentYear = value;
                  selectedPaymentWeekIndex = null;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomDropdown<int>(
            hintText: 'Month',
            value: selectedPaymentMonth,
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
                  selectedPaymentMonth = value;
                  selectedPaymentWeekIndex = null;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearMonthColumn() {
    return Column(
      children: [
        CustomDropdown<int>(
          hintText: 'Year',
          value: selectedPaymentYear,
          mainColor: mainColor,
          items: paymentYears.map((y) => DropdownMenuItem<int>(
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
                selectedPaymentYear = value;
                selectedPaymentWeekIndex = null;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        CustomDropdown<int>(
          hintText: 'Month',
          value: selectedPaymentMonth,
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
                selectedPaymentMonth = value;
                selectedPaymentWeekIndex = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildWeeksSection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Week *'),
        const SizedBox(height: 8),
        weeks.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No weeks available for selected month',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(weeks.length, (i) {
                  final week = weeks[i];
                  final startDate = DateFormat('MMM dd').format(week.first);
                  final endDate = DateFormat('MMM dd').format(week.last);
                  final isSelected = selectedPaymentWeekIndex == i;

                  return ChoiceChip(
                    label: Text(
                      'Week ${i + 1}\n($startDate - $endDate)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : mainColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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
                        selectedPaymentWeekIndex = i;
                        selectedDate = week.first;
                      });
                    },
                  );
                }),
              ),
      ],
    );
  }

  Widget _buildDatePickerSection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final weekDays = weeks[selectedPaymentWeekIndex!];

    return CustomCalendar(
      selectedDate: selectedDate,
      firstDate: weekDays.first,
      lastDate: weekDays.last,
      mainColor: mainColor,
      labelText: 'Select Date within Week',
      availableRangeText:
          'Available dates: ${DateFormat('MMM dd').format(weekDays.first)} - ${DateFormat('MMM dd').format(weekDays.last)}',
      onDateSelected: (picked) {
        setState(() {
          selectedDate = picked;
        });
      },
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _submitPayment,
            child: const Text(
              'ADD PAYMENT',
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: mainColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: resetForm,
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
    );
  }
}
