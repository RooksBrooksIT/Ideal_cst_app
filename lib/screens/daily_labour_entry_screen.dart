import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/screens/add_labour_entry_modal.dart';
import 'package:ideal_cst/screens/site_progress_screen.dart';
import 'package:ideal_cst/screens/material_request_form.dart';

class DailyLabourEntryScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String siteId;
  final String siteName;

  const DailyLabourEntryScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.siteId,
    required this.siteName,
  });

  @override
  _DailyLabourEntryScreenState createState() => _DailyLabourEntryScreenState();
}

class _DailyLabourEntryScreenState extends State<DailyLabourEntryScreen> {
  final Color primaryColor = const Color(0xFF0b3470);
  final TextEditingController weatherController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final FocusNode weatherFocusNode = FocusNode();
  final FocusNode notesFocusNode = FocusNode();
  List<Map<String, dynamic>> workersList = [];
  bool isLoading = true;
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String todayFormatted = DateFormat('dd/MM/yyyy').format(DateTime.now());

  Map<String, dynamic> summary = {
    'fullDay': 0,
    'halfDay': 0,
    'earlyOut': 0,
    'absent': 0,
    'leave': 0,
    'totalOT': 0,
    'effectiveLabour': 0.0,
    'totalMealsCount': 0,
    'totalMealsExpense': 0.0,
    'totalBusCount': 0,
    'totalBusExpense': 0.0,
    'totalAdditionalExpense': 0.0,
  };

  @override
  void initState() {
    super.initState();
    loadData();
    weatherFocusNode.addListener(() {
      if (!weatherFocusNode.hasFocus) {
        saveWeatherAndNotes();
      }
    });
    notesFocusNode.addListener(() {
      if (!notesFocusNode.hasFocus) {
        saveWeatherAndNotes();
      }
    });
  }

  @override
  void dispose() {
    weatherFocusNode.dispose();
    notesFocusNode.dispose();
    weatherController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await loadAttendance();
    calculateSummary();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadAttendance() async {
    try {
      final docId = '${widget.siteId}_$today';
      final doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        weatherController.text = data['weather'] ?? '';
        notesController.text = data['notes'] ?? '';

        final workersSnapshot = await doc.reference.collection('workers').get();
        setState(() {
          workersList = workersSnapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
    }
  }

  void calculateSummary() {
    int fullDay = 0;
    int halfDay = 0;
    int earlyOut = 0;
    int absent = 0;
    int leave = 0;
    double totalOT = 0;
    double effectiveLabour = 0;
    int totalMealsCount = 0;
    double totalMealsExpense = 0.0;
    int totalBusCount = 0;
    double totalBusExpense = 0.0;

    for (final worker in workersList) {
      final type = worker['attendanceType'];
      final dayValue = worker['dayValue'] ?? 0.0;

      final otHoursRaw = worker['otHours'];
      double otHours = 0.0;
      if (otHoursRaw is num) {
        otHours = otHoursRaw.toDouble();
      } else if (otHoursRaw is String) {
        otHours = double.tryParse(otHoursRaw.split(' ').first) ?? 0.0;
      }

      if (type == 'Full Day' || type == 'Night Shift') {
        fullDay++;
      } else if (type == 'Half Day') {
        halfDay++;
      } else if (type == 'Early Out') {
        earlyOut++;
      } else if (type == 'Absent') {
        absent++;
      } else if (type == 'Leave') {
        leave++;
      }

      effectiveLabour += dayValue;
      totalOT += otHours;

      // Calculate meals and bus expenses
      final mealsCountRaw = worker['mealsCount'] ?? 0;
      final mealsCount = mealsCountRaw is num ? mealsCountRaw.toInt() : 0;
      final mealsAmount = (worker['mealsAmount'] is num)
          ? (worker['mealsAmount'] as num).toDouble()
          : (double.tryParse(worker['mealsAmount']?.toString() ?? '0') ?? 0.0);
      final busCountRaw = worker['busCount'] ?? 0;
      final busCount = busCountRaw is num ? busCountRaw.toInt() : 0;
      final busAmount = (worker['busAmount'] is num)
          ? (worker['busAmount'] as num).toDouble()
          : (double.tryParse(worker['busAmount']?.toString() ?? '0') ?? 0.0);

      totalMealsCount += mealsCount;
      totalMealsExpense += mealsAmount;
      totalBusCount += busCount;
      totalBusExpense += busAmount;
    }

    setState(() {
      summary = {
        'fullDay': fullDay,
        'halfDay': halfDay,
        'earlyOut': earlyOut,
        'absent': absent,
        'leave': leave,
        'totalOT': totalOT,
        'effectiveLabour': effectiveLabour,
        'totalMealsCount': totalMealsCount,
        'totalMealsExpense': totalMealsExpense,
        'totalBusCount': totalBusCount,
        'totalBusExpense': totalBusExpense,
        'totalAdditionalExpense': totalMealsExpense + totalBusExpense,
      };
    });
  }

  Future<void> saveWeatherAndNotes() async {
    try {
      final docId = '${widget.siteId}_$today';
      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'siteId': widget.siteId,
        'siteName': widget.siteName,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'date': today,
        'weather': weatherController.text.trim(),
        'notes': notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving weather/notes: $e');
    }
  }

  void openAddLabourModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddLabourEntryModal(
        siteId: widget.siteId,
        siteName: widget.siteName,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        date: today,
        existingEntries: workersList,
        onWorkerAdded: (worker) {
          setState(() {
            // Check if worker was already in list to update instead of add duplicate
            final existingIndex = workersList.indexWhere(
              (w) => w['workerId'] == worker['workerId'],
            );
            if (existingIndex >= 0) {
              workersList[existingIndex] = worker;
            } else {
              workersList.add(worker);
            }
          });
          calculateSummary();
        },
      ),
    );
  }

  Future<void> _saveMealsBusFare(
    List<Map<String, dynamic>> updatedWorkers,
  ) async {
    try {
      final docId = '${widget.siteId}_$today';
      final attendanceDocRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      for (final worker in updatedWorkers) {
        final workerId = worker['workerId'];
        if (workerId == null) continue;

        // Update attendance/{docId}/workers subcollection
        batch.set(
          attendanceDocRef.collection('workers').doc(workerId),
          {
            'mealsCount': worker['mealsCount'] ?? 0,
            'mealsAmount': worker['mealsAmount'] ?? 0,
            'busCount': worker['busCount'] ?? 0,
            'busAmount': worker['busAmount'] ?? 0,
          },
          SetOptions(merge: true),
        );

        // Update daily_labour_entries
        final flatDocId = '${widget.siteId}_${today}_$workerId';
        batch.set(
          FirebaseFirestore.instance
              .collection('daily_labour_entries')
              .doc(flatDocId),
          {
            'mealsCount': worker['mealsCount'] ?? 0,
            'mealsAmount': worker['mealsAmount'] ?? 0,
            'busCount': worker['busCount'] ?? 0,
            'busAmount': worker['busAmount'] ?? 0,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meals & Bus Fare saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving meals & bus fare: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meals & bus fare: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void editWorker(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddLabourEntryModal(
        siteId: widget.siteId,
        siteName: widget.siteName,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        date: today,
        existingEntries: workersList,
        initialWorker: workersList[index],
        onWorkerAdded: (worker) {
          setState(() {
            final existingIndex = workersList.indexWhere(
              (w) => w['workerId'] == worker['workerId'],
            );
            if (existingIndex >= 0) {
              workersList[existingIndex] = worker;
            } else {
              workersList.add(worker);
            }
          });
          calculateSummary();
        },
      ),
    );
  }

  Future<void> deleteWorker(int index) async {
    final worker = workersList[index];
    final workerId = worker['workerId'] ?? worker['id'];
    if (workerId == null) return;

    try {
      final docId = '${widget.siteId}_$today';
      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      // 1. Delete from nested subcollection
      batch.delete(docRef.collection('workers').doc(workerId));

      // 2. Delete from flat daily_labour_entries collection
      batch.delete(
        FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc('${widget.siteId}_${today}_$workerId'),
      );

      // 3. Update the parent attendance summary
      final tempWorkers = List<Map<String, dynamic>>.from(workersList);
      tempWorkers.removeAt(index);

      int fullDay = 0;
      int halfDay = 0;
      int earlyOut = 0;
      int absent = 0;
      int leave = 0;
      double totalOT = 0;
      double effectiveLabour = 0;

      for (final w in tempWorkers) {
        final type = w['attendanceType'];
        final dayValue = w['dayValue'] ?? 0.0;

        final otHoursRaw = w['otHours'];
        double otHours = 0.0;
        if (otHoursRaw is num) {
          otHours = otHoursRaw.toDouble();
        } else if (otHoursRaw is String) {
          otHours = double.tryParse(otHoursRaw.split(' ').first) ?? 0.0;
        }

        if (type == 'Full Day' || type == 'Night Shift') {
          fullDay++;
        } else if (type == 'Half Day') {
          halfDay++;
        } else if (type == 'Early Out') {
          earlyOut++;
        } else if (type == 'Absent') {
          absent++;
        } else if (type == 'Leave') {
          leave++;
        }

        effectiveLabour += dayValue;
        totalOT += otHours;
      }

      batch.set(docRef, {
        'totalWorkers': tempWorkers.length,
        'summary': {
          'fullDay': fullDay,
          'halfDay': halfDay,
          'earlyOut': earlyOut,
          'absent': absent,
          'leave': leave,
          'totalOTHours': totalOT,
          'effectiveLabourCount': effectiveLabour,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      setState(() {
        workersList.removeAt(index);
      });
      calculateSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Labour entry deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting worker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting worker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Labour Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeaderSection(),
                        const SizedBox(height: 24),
                        _buildLabourListSection(),
                        const SizedBox(height: 24),
                        _buildMealsEntrySection(),
                        const SizedBox(height: 24),
                        _buildSummarySection(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (widget.siteName.trim().isEmpty || widget.siteName == 'Unknown Site')
                        ? widget.siteId.split('_').first
                        : widget.siteName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Supervisor: ${widget.supervisorName}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Date: $todayFormatted',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 32),
            TextField(
              controller: weatherController,
              focusNode: weatherFocusNode,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: 'Weather (Optional)',
                prefixIcon: const Icon(Icons.wb_sunny_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              focusNode: notesFocusNode,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabourListSection() {
    final subContractors = workersList.where((w) {
      return w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
    }).toList();

    final directWorkers = workersList.where((w) {
      final isContractor = w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
      return !isContractor;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Labour Entries',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: openAddLabourModal,
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (workersList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No labour entries yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
        else ...[
          if (directWorkers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Direct Workers (${directWorkers.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            ...directWorkers.map((w) {
              final idx = workersList.indexOf(w);
              return _buildLabourEntryCard(idx, w, false);
            }),
            const SizedBox(height: 16),
          ],
          if (subContractors.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Sub Contractors (${subContractors.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            ...subContractors.map((w) {
              final idx = workersList.indexOf(w);
              return _buildLabourEntryCard(idx, w, true);
            }),
          ],
        ]
      ],
    );
  }

  Widget _buildLabourEntryCard(int index, Map<String, dynamic> worker, bool isContractor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => editWorker(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isContractor ? Colors.orange.shade50 : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isContractor ? Icons.engineering : Icons.person,
                      color: isContractor ? Colors.orange.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              worker['workerName'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (worker['labourType'] == 'Sub Contractor' || isContractor)
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              worker['labourType']?.toString() ?? (isContractor ? 'Sub Contractor' : 'Daily Wage'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (worker['labourType'] == 'Sub Contractor' || isContractor)
                                    ? Colors.orange.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: worker['attendanceType'] == 'Full Day' ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              worker['attendanceType']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: worker['attendanceType'] == 'Full Day' ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isContractor
                            ? '${worker['category'] ?? worker['workerType'] ?? ''} • ${worker['labourType'] ?? 'Sub Contractor'} • Self'
                            : '${worker['category'] ?? worker['workerType'] ?? ''} • ${worker['labourType'] ?? 'Daily Wage'} • Sub: ${worker['contractorName'] ?? worker['contractor'] ?? 'None'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => deleteWorker(index),
                  tooltip: 'Delete Entry',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealsEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meals & Bus Fare',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _MealsEntryInlineSection(
          workersList: workersList,
          onUpdate: (updatedWorkers) {
            setState(() {
              workersList = updatedWorkers;
            });
            calculateSummary();
            _saveMealsBusFare(updatedWorkers);
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 0,
      color: primaryColor.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Daily Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSummaryRow('Effective Labour', summary['effectiveLabour'].toString(), primaryColor, isBold: true, isLarge: true),
            const Divider(height: 32),
            _buildSummaryRow('Full Day', summary['fullDay'].toString(), Colors.green),
            _buildSummaryRow('Half Day', summary['halfDay'].toString(), Colors.orange),
            _buildSummaryRow('Early Out', summary['earlyOut'].toString(), Colors.purple),
            _buildSummaryRow('Absent', summary['absent'].toString(), Colors.red),
            _buildSummaryRow('Leave', summary['leave'].toString(), Colors.grey),
            _buildSummaryRow('Total OT Hours', summary['totalOT'].toString(), Colors.teal),
            const Divider(height: 32),
            _buildSummaryRow('Total Additional Expense', '₹${summary['totalAdditionalExpense'].toStringAsFixed(2)}', Colors.red, isBold: true, isLarge: true),
            const SizedBox(height: 12),
            _buildSummaryRow('Meals (Count)', summary['totalMealsCount'].toString(), Colors.orange),
            _buildSummaryRow('Meals (Expense)', '₹${summary['totalMealsExpense'].toStringAsFixed(2)}', Colors.orange),
            _buildSummaryRow('Bus Fare (Trips)', summary['totalBusCount'].toString(), Colors.blue),
            _buildSummaryRow('Bus Fare (Expense)', '₹${summary['totalBusExpense'].toStringAsFixed(2)}', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.bar_chart,
                label: 'Site Progress',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SiteProgressScreen(
                        supervisorId: widget.supervisorId,
                        supervisorName: widget.supervisorName,
                        siteId: widget.siteId,
                        siteName: widget.siteName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.shopping_cart,
                label: 'Material Request',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MaterialRequestForm(
                        supervisorId: widget.supervisorId,
                        supervisorName: widget.supervisorName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealsEntryInlineSection extends StatefulWidget {
  final List<Map<String, dynamic>> workersList;
  final Function(List<Map<String, dynamic>>) onUpdate;

  const _MealsEntryInlineSection({
    required this.workersList,
    required this.onUpdate,
  });

  @override
  __MealsEntryInlineSectionState createState() => __MealsEntryInlineSectionState();
}

class __MealsEntryInlineSectionState extends State<_MealsEntryInlineSection> {
  late List<Map<String, dynamic>> _updatedWorkers;
  final Color _primaryColor = const Color(0xFF0b3470);
  String? _selectedSubContractorName;
  String? _selectedWorkerId;
  late TextEditingController _mealsCountController;
  late TextEditingController _mealsAmountController;
  late TextEditingController _busCountController;
  late TextEditingController _busAmountController;
  bool _isSaving = false;

  Map<String, dynamic>? get _selectedWorker {
    if (_selectedWorkerId == null) return null;
    return _updatedWorkers.firstWhere(
      (w) => w['workerId'] == _selectedWorkerId,
      orElse: () => {},
    );
  }

  @override
  void initState() {
    super.initState();
    _mealsCountController = TextEditingController();
    _mealsAmountController = TextEditingController();
    _busCountController = TextEditingController();
    _busAmountController = TextEditingController();
    _syncWorkers();
  }

  @override
  void didUpdateWidget(_MealsEntryInlineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workersList != oldWidget.workersList) {
      _syncWorkers();
    }
  }

  void _syncWorkers() {
    _updatedWorkers = widget.workersList.map((worker) {
      final mealsCountRaw = worker['mealsCount'] ?? 0;
      final mealsCount = mealsCountRaw is num ? mealsCountRaw.toInt() : 0;
      final busCountRaw = worker['busCount'] ?? 0;
      final busCount = busCountRaw is num ? busCountRaw.toInt() : 0;

      final mealsAmountRaw = worker['mealsAmount'] ?? 0;
      final mealsAmount = mealsAmountRaw is num ? mealsAmountRaw.toDouble() : 0.0;
      final busAmountRaw = worker['busAmount'] ?? 0;
      final busAmount = busAmountRaw is num ? busAmountRaw.toDouble() : 0.0;

      return {
        ...worker,
        'mealsCount': mealsCount,
        'mealsAmount': mealsAmount,
        'busCount': busCount,
        'busAmount': busAmount,
      };
    }).toList();
  }

  @override
  void dispose() {
    _mealsCountController.dispose();
    _mealsAmountController.dispose();
    _busCountController.dispose();
    _busAmountController.dispose();
    super.dispose();
  }

  List<String> _getSubContractors() {
    final contractors = <String>{};
    for (final worker in _updatedWorkers) {
      final isContractor = worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName = isContractor 
          ? (worker['workerName'] ?? 'Unknown Contractor') 
          : (worker['contractorName'] ?? worker['contractor'] ?? 'General');
      contractors.add(contractorName);
    }
    return contractors.toList()..sort();
  }

  List<Map<String, dynamic>> _getWorkersForSelectedSubContractor() {
    if (_selectedSubContractorName == null) return [];
    final workers = <Map<String, dynamic>>[];
    final contractors = <Map<String, dynamic>>[];
    for (final worker in _updatedWorkers) {
      final isContractor = worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName = isContractor 
          ? (worker['workerName'] ?? 'Unknown Contractor') 
          : (worker['contractorName'] ?? worker['contractor'] ?? 'General');

      if (contractorName == _selectedSubContractorName) {
        if (isContractor) {
          contractors.add(worker);
        } else {
          workers.add(worker);
        }
      }
    }
    return [...contractors, ...workers];
  }

  void _loadWorkerData() {
    final worker = _selectedWorker;
    if (worker != null && worker.isNotEmpty) {
      _mealsCountController.text = worker['mealsCount'].toString();
      _mealsAmountController.text = worker['mealsAmount'].toString();
      _busCountController.text = worker['busCount'].toString();
      _busAmountController.text = worker['busAmount'].toString();
    } else {
      _mealsCountController.clear();
      _mealsAmountController.clear();
      _busCountController.clear();
      _busAmountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_updatedWorkers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'Add labour entries first to assign meals and bus fare.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final subContractors = _getSubContractors();
    if (_selectedSubContractorName != null && !subContractors.contains(_selectedSubContractorName)) {
        _selectedSubContractorName = null;
        _selectedWorkerId = null;
    }

    final workersForSubContractor = _getWorkersForSelectedSubContractor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedSubContractorName,
            decoration: InputDecoration(
              labelText: 'Select Sub Contractor',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: subContractors.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSubContractorName = value;
                _selectedWorkerId = null;
                _loadWorkerData();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedSubContractorName != null)
            DropdownButtonFormField<String>(
              initialValue: _selectedWorkerId,
              decoration: InputDecoration(
                labelText: 'Select Worker',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: workersForSubContractor.map<DropdownMenuItem<String>>((worker) {
                final isContractor = worker['isContractor'] == true ||
                    (worker['labourType'] == 'Sub Contractor' &&
                        (worker['contractor'] == null ||
                            worker['contractor'].toString().isEmpty ||
                            worker['contractor'] == worker['workerName']));
                final label = isContractor ? '${worker['workerName']} (Sub Contractor)' : worker['workerName'] ?? 'Unknown Worker';
                return DropdownMenuItem(value: worker['workerId'], child: Text(label));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWorkerId = value;
                  _loadWorkerData();
                });
              },
            ),
          const SizedBox(height: 16),
          if (_selectedWorkerId != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Meals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mealsCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'No of Meals',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _mealsAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text('Bus Fare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'No of Trips',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _busAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        if (_selectedWorkerId != null) {
                          setState(() => _isSaving = true);
                          final index = _updatedWorkers.indexWhere((w) => w['workerId'] == _selectedWorkerId);
                          if (index != -1) {
                            _updatedWorkers[index] = {
                              ..._updatedWorkers[index],
                              'mealsCount': int.tryParse(_mealsCountController.text) ?? 0,
                              'mealsAmount': double.tryParse(_mealsAmountController.text) ?? 0,
                              'busCount': int.tryParse(_busCountController.text) ?? 0,
                              'busAmount': double.tryParse(_busAmountController.text) ?? 0,
                            };
                            widget.onUpdate(_updatedWorkers);
                            _selectedWorkerId = null;
                            _loadWorkerData();
                          }
                          setState(() => _isSaving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Worker Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
