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
  };

  @override
  void initState() {
    super.initState();
    loadData();
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

    for (final worker in workersList) {
      final type = worker['attendanceType'];
      final dayValue = worker['dayValue'] ?? 0.0;
      final otHours = worker['otHours'] ?? 0.0;

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

    setState(() {
      summary = {
        'fullDay': fullDay,
        'halfDay': halfDay,
        'earlyOut': earlyOut,
        'absent': absent,
        'leave': leave,
        'totalOT': totalOT,
        'effectiveLabour': effectiveLabour,
      };
    });
  }

  Future<void> saveAttendance() async {
    try {
      final docId = '${widget.siteId}_$today';
      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      // Set main attendance doc
      batch.set(docRef, {
        'siteId': widget.siteId,
        'siteName': widget.siteName,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'date': today,
        'weather': weatherController.text,
        'notes': notesController.text,
        'totalWorkers': workersList.length,
        'effectiveLabourCount': summary['effectiveLabour'],
        'totalOTHours': summary['totalOT'],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Delete existing workers and add new ones
      final workersSnapshot = await docRef.collection('workers').get();
      for (final doc in workersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      for (final worker in workersList) {
        final workerId =
            worker['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        final workerDocRef = docRef.collection('workers').doc(workerId);
        final workerData = Map<String, dynamic>.from(worker);
        workerData.remove('id');
        batch.set(workerDocRef, workerData);
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully!')),
      );
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
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
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        onWorkerAdded: (worker) {
          setState(() {
            workersList.add(worker);
          });
          calculateSummary();
        },
      ),
    );
  }

  void editWorker(int index) {
    // TODO: Implement edit worker functionality
  }

  void deleteWorker(int index) {
    setState(() {
      workersList.removeAt(index);
    });
    calculateSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Labour Entry'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: saveAttendance),
        ],
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
                          widget.siteName,
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
                          decoration: const InputDecoration(
                            labelText: 'Weather (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
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
                else
                  ...workersList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final worker = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          worker['workerName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${worker['category'] ?? ''} • ${worker['contractor'] ?? ''}',
                            ),
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
                  }).toList(),
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
                        _buildSummaryRow(
                          'Effective Labour',
                          summary['effectiveLabour'].toString(),
                          primaryColor,
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
