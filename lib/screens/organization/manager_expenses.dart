import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/services/expense_service.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';
import 'package:ideal_cst/screens/organization/components/custom_calendar.dart';

class ManagerExpenses extends StatefulWidget {
  const ManagerExpenses({super.key});

  @override
  _ManagerExpensesState createState() => _ManagerExpensesState();
}

class _ManagerExpensesState extends State<ManagerExpenses> {
  final Color mainColor = const Color(0xFF003768);

  String? selectedSiteId;
  String? selectedSupervisorId;
  String? selectedProjectPhase;
  DateTime selectedDate = DateTime.now();

  List<String> siteIds = [];
  bool isLoadingSites = true;
  bool isLoadingSiteDetails = false;
  bool isSubmitting = false;

  final billNoController = TextEditingController();
  final billVendorController = TextEditingController();
  final billAmountController = TextEditingController();
  final supervisorController = TextEditingController();
  final projectPhaseController = TextEditingController();

  List<Map<String, String>> bills = [];

  @override
  void initState() {
    super.initState();
    _loadSiteIds();
  }

  @override
  void dispose() {
    billNoController.dispose();
    billVendorController.dispose();
    billAmountController.dispose();
    supervisorController.dispose();
    projectPhaseController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteIds() async {
    setState(() {
      isLoadingSites = true;
    });
    try {
      final Set<String> fetchedSiteIds = {};

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .get();
        for (var doc in snapshot.docs) {
          final site = doc.data()['site']?.toString() ?? doc.id;
          if (site.isNotEmpty) {
            fetchedSiteIds.add(site);
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
          final site = doc.data()['siteId']?.toString() ?? doc.id;
          if (site.isNotEmpty) {
            fetchedSiteIds.add(site);
          }
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      siteIds = fetchedSiteIds.toList()..sort();
    } catch (e) {
      debugPrint('Error loading site IDs: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSites = false;
        });
      }
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    if (!mounted) return;
    setState(() {
      isLoadingSiteDetails = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('site', isEqualTo: siteId)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final supervisor = data['supervisor'] as String?;
        final projectStage = data['projectStage'] as String?;
        setState(() {
          selectedSupervisorId = supervisor;
          selectedProjectPhase = projectStage;
          supervisorController.text = supervisor ?? '';
          projectPhaseController.text = projectStage ?? '';
          isLoadingSiteDetails = false;
        });
      } else {
        setState(() {
          selectedSupervisorId = null;
          selectedProjectPhase = null;
          supervisorController.clear();
          projectPhaseController.clear();
          isLoadingSiteDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingSiteDetails = false;
        });
      }
    }
  }

  void _addBill() {
    if (billNoController.text.isNotEmpty &&
        billVendorController.text.isNotEmpty &&
        billAmountController.text.isNotEmpty) {
      setState(() {
        bills.add({
          'billNo': billNoController.text,
          'billDate': DateFormat('dd/MM/yy').format(selectedDate),
          'billVendor': billVendorController.text,
          'billAmount': '₹ ${billAmountController.text}',
        });

        billNoController.clear();
        billVendorController.clear();
        billAmountController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all bill fields before adding.')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      bills.clear();
      billNoController.clear();
      billVendorController.clear();
      billAmountController.clear();
      selectedSiteId = null;
      selectedSupervisorId = null;
      selectedProjectPhase = null;
      supervisorController.clear();
      projectPhaseController.clear();
      selectedDate = DateTime.now();
    });
  }

  Future<void> _submitExpenseData() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });

    if (selectedSiteId == null ||
        selectedSupervisorId == null ||
        selectedProjectPhase == null ||
        bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details and add at least one bill.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isSubmitting = false;
      });
      return;
    }

    try {
      String projectName = '';
      try {
        final projectSnap = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .where('site', isEqualTo: selectedSiteId)
            .limit(1)
            .get();
        if (projectSnap.docs.isNotEmpty) {
          projectName = projectSnap.docs.first.data()['projectName'] ?? '';
        }
      } catch (_) {}

      final dateStr = DateFormat('ddMMyyyy').format(selectedDate);
      final newDocId = '${selectedSiteId}_$dateStr';
      final entryRef = FirebaseFirestore.instance
          .collection('managerEntries')
          .doc(newDocId);

      final entrySnap = await entryRef.get();
      List<dynamic> existingBills = [];
      double existingTotal = 0;
      if (entrySnap.exists) {
        final data = entrySnap.data() as Map<String, dynamic>;
        existingBills = data['bills'] ?? [];
        existingTotal = (data['totalAmount'] ?? 0).toDouble();
      }

      double newTotal = 0;
      final newBillsData = bills.map((bill) {
        double amount = 0;
        try {
          amount = double.parse(
            bill['billAmount']!.replaceAll(RegExp(r'[^0-9.]'), ''),
          );
        } catch (_) {}
        newTotal += amount;
        return {
          'billNo': bill['billNo'],
          'billVendor': bill['billVendor'],
          'billAmount': amount,
          'billDate': Timestamp.fromDate(selectedDate),
          'billCopy': 'billURL',
        };
      }).toList();

      final allBills = [...existingBills, ...newBillsData];
      final totalAmountUpdated = existingTotal + newTotal;
      final entry = {
        'siteId': selectedSiteId,
        'supervisorName': selectedSupervisorId,
        'projectStage': selectedProjectPhase,
        'projectName': projectName,
        'entryDate': Timestamp.now(),
        'bills': allBills,
        'totalAmount': totalAmountUpdated,
      };

      await entryRef.set(entry);

      double mgrExpenseTotalAmount = 0;
      final allEntrySnap = await entryRef.get();
      if (allEntrySnap.exists) {
        final data = allEntrySnap.data() as Map<String, dynamic>;
        final billsList = data['bills'] as List<dynamic>? ?? [];
        for (var bill in billsList) {
          final amt = (bill['billAmount'] ?? 0).toDouble();
          mgrExpenseTotalAmount += amt;
        }
      }

      final summary = {
        'date': selectedDate.toIso8601String(),
        'mgrExpenseTotalAmount': mgrExpenseTotalAmount,
        'projectName': projectName,
        'projectStage': selectedProjectPhase ?? '',
        'siteId': selectedSiteId ?? '',
      };

      await FirebaseFirestore.instance
          .collection('managerExpenseSummary')
          .doc(newDocId)
          .set(summary);

      await ExpenseService.updateTotalMgrExpenseForSite(selectedSiteId!);

      _resetForm();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 16),
              Text(
                'Manager expense data submitted successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving data. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
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
                  'Manager',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Expenses',
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

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
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

  Widget _buildBillTable() {
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No bills added yet.',
            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(mainColor),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          columns: const [
            DataColumn(label: Text('Bill No')),
            DataColumn(label: Text('Bill Date')),
            DataColumn(label: Text('Bill Vendor')),
            DataColumn(label: Text('Bill Amount')),
            DataColumn(label: Text('Action')),
          ],
          rows: bills
              .asMap()
              .entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.value['billNo']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(entry.value['billDate']!)),
                    DataCell(Text(entry.value['billVendor']!)),
                    DataCell(Text(entry.value['billAmount']!, style: TextStyle(color: mainColor, fontWeight: FontWeight.bold))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            bills.removeAt(entry.key);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
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
                        // SECTION 1: Site & Project Info
                        _buildSectionTitle('Site ID *'),
                        const SizedBox(height: 8),
                        isLoadingSites
                            ? const Center(child: CircularProgressIndicator())
                            : CustomDropdown<String>(
                                hintText: 'Select Site ID',
                                value: selectedSiteId,
                                mainColor: mainColor,
                                items: siteIds
                                    .map(
                                      (site) => DropdownMenuItem<String>(
                                        value: site,
                                        child: Text(
                                          site,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E1E2D),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedSiteId = value;
                                  });
                                  if (value != null) {
                                    _loadSiteDetails(value);
                                  }
                                },
                              ),
                        const SizedBox(height: 20),

                        // Supervisor ID (Auto-filled)
                        _buildSectionTitle('Supervisor ID'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: supervisorController,
                            readOnly: true,
                            style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                            decoration: _inputDecoration(hintText: 'Auto-filled supervisor ID'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Project Phase (Auto-filled)
                        _buildSectionTitle('Project Phase'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: projectPhaseController,
                            readOnly: true,
                            style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                            decoration: _inputDecoration(hintText: 'Auto-filled project phase'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Custom Calendar Component
                        CustomCalendar(
                          selectedDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          mainColor: mainColor,
                          labelText: 'Expense Date *',
                          onDateSelected: (picked) {
                            setState(() {
                              selectedDate = picked;
                            });
                          },
                        ),
                        const SizedBox(height: 28),

                        // SECTION 2: Add Bill Form
                        Row(
                          children: [
                            Icon(Icons.receipt_long, color: mainColor),
                            const SizedBox(width: 8),
                            _buildSectionTitle('Add Bill Details'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bill No
                        _buildSectionTitle('Bill No *'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: billNoController,
                            style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                            decoration: _inputDecoration(hintText: 'Enter bill number'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bill Vendor
                        _buildSectionTitle('Bill Vendor *'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: billVendorController,
                            style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                            decoration: _inputDecoration(hintText: 'Enter vendor name'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bill Amount
                        _buildSectionTitle('Bill Amount *'),
                        const SizedBox(height: 8),
                        _buildTextFieldContainer(
                          child: TextFormField(
                            controller: billAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                            decoration: _inputDecoration(hintText: 'Enter amount').copyWith(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 14, right: 8),
                                child: Text(
                                  '₹',
                                  style: TextStyle(fontSize: 20, color: mainColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Add Bill Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addBill,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'ADD BILL TO LIST',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // SECTION 3: Bills Table
                        _buildSectionTitle('Bills List'),
                        const SizedBox(height: 10),
                        _buildBillTable(),
                        const SizedBox(height: 28),

                        // Action Buttons
                        Column(
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
                                onPressed: isSubmitting ? null : _submitExpenseData,
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'SUBMIT MANAGER EXPENSES',
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
                                    onPressed: isSubmitting ? null : _resetForm,
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
