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

  void openMealsBusFareModal() {
    showDialog(
      context: context,
      builder: (context) => _MealsBusFareDialog(
        workersList: workersList,
        onUpdate: (updatedWorkers) {
          setState(() {
            workersList = updatedWorkers;
          });
          calculateSummary();
          _saveMealsBusFare(updatedWorkers);
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
    // TODO: Implement edit worker functionality
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
      appBar: AppBar(
        title: const Text('Daily Labour Entry'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Site Info Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (widget.siteName.trim().isEmpty ||
                                  widget.siteName == 'Unknown Site')
                              ? widget.siteId.split('_').first
                              : widget.siteName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supervisor: ${widget.supervisorName}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Date: $todayFormatted',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: weatherController,
                          focusNode: weatherFocusNode,
                          onTapOutside: (event) {
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Weather (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          focusNode: notesFocusNode,
                          onTapOutside: (event) {
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add Labour Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openAddLabourModal,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Labour Entry',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Meals & Bus Fare Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openMealsBusFareModal,
                    icon: const Icon(Icons.restaurant, color: Colors.white),
                    label: const Text(
                      'Meals & Bus Fare',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Workers List
                const Text(
                  'Labour Entries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (workersList.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No labour entries yet')),
                    ),
                  )
                else ...[
                  // 1. Workers Section
                  if (workersList.any(
                    (w) =>
                        !(w['isContractor'] == true ||
                            (w['labourType'] == 'Sub Contractor' &&
                                (w['contractor'] == null ||
                                    w['contractor'].toString().isEmpty ||
                                    w['contractor'] == w['workerName']))),
                  )) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Workers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...workersList
                        .asMap()
                        .entries
                        .where((entry) {
                          final w = entry.value;
                          final isContractor =
                              w['isContractor'] == true ||
                              (w['labourType'] == 'Sub Contractor' &&
                                  (w['contractor'] == null ||
                                      w['contractor'].toString().isEmpty ||
                                      w['contractor'] == w['workerName']));
                          return !isContractor;
                        })
                        .map((entry) {
                          final index = entry.key;
                          final worker = entry.value;
                          return _buildLabourEntryCard(index, worker, false);
                        })
                        .toList(),
                  ],

                  // 2. Sub Contractors Section
                  if (workersList.any(
                    (w) =>
                        w['isContractor'] == true ||
                        (w['labourType'] == 'Sub Contractor' &&
                            (w['contractor'] == null ||
                                w['contractor'].toString().isEmpty ||
                                w['contractor'] == w['workerName'])),
                  )) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Sub Contractors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...workersList
                        .asMap()
                        .entries
                        .where((entry) {
                          final w = entry.value;
                          final isContractor =
                              w['isContractor'] == true ||
                              (w['labourType'] == 'Sub Contractor' &&
                                  (w['contractor'] == null ||
                                      w['contractor'].toString().isEmpty ||
                                      w['contractor'] == w['workerName']));
                          return isContractor;
                        })
                        .map((entry) {
                          final index = entry.key;
                          final worker = entry.value;
                          return _buildLabourEntryCard(index, worker, true);
                        })
                        .toList(),
                  ],
                ],
                const SizedBox(height: 16),

                // Summary Card
                Card(
                  color: primaryColor.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          'Full Day',
                          summary['fullDay'].toString(),
                          Colors.green,
                        ),
                        _buildSummaryRow(
                          'Half Day',
                          summary['halfDay'].toString(),
                          Colors.orange,
                        ),
                        _buildSummaryRow(
                          'Early Out',
                          summary['earlyOut'].toString(),
                          Colors.purple,
                        ),
                        _buildSummaryRow(
                          'Absent',
                          summary['absent'].toString(),
                          Colors.red,
                        ),
                        _buildSummaryRow(
                          'Leave',
                          summary['leave'].toString(),
                          Colors.grey,
                        ),
                        _buildSummaryRow(
                          'Total OT Hours',
                          summary['totalOT'].toString(),
                          Colors.teal,
                        ),
                        const Divider(),
                        const Text(
                          'Additional Expenses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Meals Count',
                          summary['totalMealsCount'].toString(),
                          Colors.orange,
                        ),
                        _buildSummaryRow(
                          'Meals Expense',
                          '₹${summary['totalMealsExpense'].toStringAsFixed(2)}',
                          Colors.orange,
                        ),
                        _buildSummaryRow(
                          'Bus Count',
                          summary['totalBusCount'].toString(),
                          Colors.blue,
                        ),
                        _buildSummaryRow(
                          'Bus Fare Expense',
                          '₹${summary['totalBusExpense'].toStringAsFixed(2)}',
                          Colors.blue,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'Effective Labour',
                          summary['effectiveLabour'].toString(),
                          primaryColor,
                          isBold: true,
                        ),
                        _buildSummaryRow(
                          'Total Additional Expense',
                          '₹${summary['totalAdditionalExpense'].toStringAsFixed(2)}',
                          Colors.red,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
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
                        icon: const Icon(Icons.bar_chart, color: Colors.white),
                        label: const Text(
                          'Site Progress',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
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
                        icon: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Material Request',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildLabourEntryCard(
    int index,
    Map<String, dynamic> worker,
    bool isContractor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                worker['workerName'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isContractor
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                border: Border.all(
                  color: isContractor
                      ? Colors.orange.shade200
                      : Colors.blue.shade200,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isContractor ? 'Sub Contractor' : 'Worker',
                style: TextStyle(
                  color: isContractor
                      ? Colors.orange.shade900
                      : Colors.blue.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isContractor) ...[
              Text(
                '${worker['category'] ?? worker['workerType'] ?? ''} • Sub Contractor (Self)',
              ),
            ] else ...[
              if ((worker['category'] != null &&
                      worker['category'].toString().isNotEmpty) ||
                  (worker['workerType'] != null &&
                      worker['workerType'].toString().isNotEmpty))
                Text(
                  worker['category']?.toString() ??
                      worker['workerType']?.toString() ??
                      '',
                ),
              Text(
                'Sub Contractor: ${worker['contractorName'] ?? worker['contractor'] ?? 'None'}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
            Text(
              '${worker['attendanceType']} • Day Value: ${worker['dayValue']}',
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => editWorker(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteWorker(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsBusFareDialog extends StatefulWidget {
  final List<Map<String, dynamic>> workersList;
  final Function(List<Map<String, dynamic>>) onUpdate;

  const _MealsBusFareDialog({
    required this.workersList,
    required this.onUpdate,
  });

  @override
  __MealsBusFareDialogState createState() => __MealsBusFareDialogState();
}

class __MealsBusFareDialogState extends State<_MealsBusFareDialog> {
  late List<Map<String, dynamic>> _updatedWorkers;
  final Color _primaryColor = const Color(0xFF0b3470);
  String? _selectedSubContractorName;
  String? _selectedWorkerId; // Use workerId instead of Map
  late TextEditingController _mealsCountController;
  late TextEditingController _mealsAmountController;
  late TextEditingController _busCountController;
  late TextEditingController _busAmountController;

  // Get selectedWorker
  Map<String, dynamic>? get _selectedWorker {
    if (_selectedWorkerId == null) return null;
    return _updatedWorkers.firstWhere(
      (w) => w['workerId'] == _selectedWorkerId,
    );
  }

  @override
  void initState() {
    super.initState();
    _mealsCountController = TextEditingController();
    _mealsAmountController = TextEditingController();
    _busCountController = TextEditingController();
    _busAmountController = TextEditingController();

    // Initialize with existing data
    _updatedWorkers = widget.workersList.map((worker) {
      final mealsCountRaw = worker['mealsCount'] ?? 0;
      final mealsCount = mealsCountRaw is num ? mealsCountRaw.toInt() : 0;
      final busCountRaw = worker['busCount'] ?? 0;
      final busCount = busCountRaw is num ? busCountRaw.toInt() : 0;

      final mealsAmountRaw = worker['mealsAmount'] ?? 0;
      final mealsAmount = mealsAmountRaw is num
          ? mealsAmountRaw.toDouble()
          : 0.0;
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

  // Helper to get unique sub-contractors
  List<String> _getSubContractors() {
    final contractors = <String>{};
    for (final worker in _updatedWorkers) {
      final isContractor =
          worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName;
      if (isContractor) {
        contractorName = worker['workerName'] ?? 'Unknown Contractor';
      } else {
        contractorName =
            worker['contractorName'] ?? worker['contractor'] ?? 'General';
      }
      contractors.add(contractorName);
    }
    return contractors.toList()..sort();
  }

  // Helper to get workers for selected sub-contractor
  List<Map<String, dynamic>> _getWorkersForSelectedSubContractor() {
    if (_selectedSubContractorName == null) return [];
    final workers = <Map<String, dynamic>>[];
    final contractors = <Map<String, dynamic>>[];
    for (final worker in _updatedWorkers) {
      final isContractor =
          worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName;
      if (isContractor) {
        contractorName = worker['workerName'] ?? 'Unknown Contractor';
      } else {
        contractorName =
            worker['contractorName'] ?? worker['contractor'] ?? 'General';
      }

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

  // Load existing values when worker is selected
  void _loadWorkerData() {
    final worker = _selectedWorker;
    if (worker != null) {
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
    final subContractors = _getSubContractors();
    final workersForSubContractor = _getWorkersForSelectedSubContractor();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 550),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meals & Bus Fare',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sub Contractor Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSubContractorName,
                      decoration: const InputDecoration(
                        labelText: 'Select Sub Contractor',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: subContractors.map((name) {
                        return DropdownMenuItem(value: name, child: Text(name));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSubContractorName = value;
                          _selectedWorkerId = null;
                          _loadWorkerData();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Worker Dropdown
                    if (_selectedSubContractorName != null)
                      DropdownButtonFormField<String>(
                        value: _selectedWorkerId,
                        decoration: const InputDecoration(
                          labelText: 'Select Worker',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: workersForSubContractor
                            .map<DropdownMenuItem<String>>((worker) {
                              final isContractor =
                                  worker['isContractor'] == true ||
                                  (worker['labourType'] == 'Sub Contractor' &&
                                      (worker['contractor'] == null ||
                                          worker['contractor']
                                              .toString()
                                              .isEmpty ||
                                          worker['contractor'] ==
                                              worker['workerName']));
                              final label = isContractor
                                  ? '${worker['workerName']} (Sub Contractor)'
                                  : worker['workerName'] ?? 'Unknown Worker';

                              return DropdownMenuItem(
                                value: worker['workerId'],
                                child: Text(label),
                              );
                            })
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWorkerId = value;
                            _loadWorkerData();
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    // Expense Input Section
                    if (_selectedWorker != null)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Meals Section
                              const Text(
                                'Meals',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _mealsCountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'No of Meals',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _mealsAmountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Meals Amount',
                                        prefixText: '₹',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Bus Fare Section
                              const Text(
                                'Bus Fare',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _busCountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'No of Trips',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _busAmountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Bus Fare Amount',
                                        prefixText: '₹',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Save button for this entry
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_selectedWorkerId != null) {
                                      // Update the worker in _updatedWorkers
                                      final index = _updatedWorkers.indexWhere(
                                        (w) =>
                                            w['workerId'] == _selectedWorkerId,
                                      );
                                      if (index != -1) {
                                        setState(() {
                                          _updatedWorkers[index] = {
                                            ..._updatedWorkers[index],
                                            'mealsCount':
                                                int.tryParse(
                                                  _mealsCountController.text,
                                                ) ??
                                                0,
                                            'mealsAmount':
                                                double.tryParse(
                                                  _mealsAmountController.text,
                                                ) ??
                                                0,
                                            'busCount':
                                                int.tryParse(
                                                  _busCountController.text,
                                                ) ??
                                                0,
                                            'busAmount':
                                                double.tryParse(
                                                  _busAmountController.text,
                                                ) ??
                                                0,
                                          };
                                          // Clear worker selection, keep sub-contractor selected
                                          _selectedWorkerId = null;
                                          _loadWorkerData();
                                        });
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save for this Worker',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
            const SizedBox(height: 16),
            // Final Save button to close modal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onUpdate(_updatedWorkers);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
