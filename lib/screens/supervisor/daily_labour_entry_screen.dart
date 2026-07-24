import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/screens/supervisor/add_labour_entry_modal.dart';
import 'package:ideal_cst/screens/supervisor/site_progress_screen.dart';
import 'package:ideal_cst/screens/supervisor/material_request_form.dart';

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
  final Color primaryColor = const Color(0xFF4527A0);
  final TextEditingController coordinatorController = TextEditingController();
  final TextEditingController weatherController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final FocusNode weatherFocusNode = FocusNode();
  final FocusNode notesFocusNode = FocusNode();
  
  bool isSavingCoordinator = false;
  
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
  }

  @override
  void dispose() {
    coordinatorController.dispose();
    weatherController.dispose();
    notesController.dispose();
    weatherFocusNode.dispose();
    notesFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await loadAttendance();
    calculateSummary();
    setState(() {
      isLoading = false;
    });
  }

  int totalAssignedSiteWorkers = 0;
  bool isAttendanceCompleted = false;

  Future<void> loadAttendance() async {
    try {
      final docId = '${widget.siteId}_$today';
      
      // Load coordinator and other details
      final mainDoc = await FirebaseFirestore.instance
          .collection('daily_labour_entries')
          .doc(docId)
          .get();
          
      if (mainDoc.exists) {
         final data = mainDoc.data()!;
         coordinatorController.text = data['coordinatorName'] ?? '';
         weatherController.text = data['weather'] ?? '';
         notesController.text = data['notes'] ?? '';
      }

      // Fetch workers from daily_labour_entries first
      var workersSnapshot = await FirebaseFirestore.instance
          .collection('daily_labour_entries')
          .doc(docId)
          .collection('workers')
          .get();
          
      // Fallback to attendance collection for older entries
      if (workersSnapshot.docs.isEmpty) {
        workersSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(docId)
            .collection('workers')
            .get();
            
        final attendanceDoc = await FirebaseFirestore.instance.collection('attendance').doc(docId).get();
        if (attendanceDoc.exists) {
            final attendanceData = attendanceDoc.data()!;
            if (weatherController.text.isEmpty) weatherController.text = attendanceData['weather'] ?? '';
            if (notesController.text.isEmpty) notesController.text = attendanceData['notes'] ?? '';
        }
      }

      // Fetch total assigned site workers
      int siteWorkersCount = 0;
      try {
        final workersSnap = await FirebaseFirestore.instance.collection('workers').get();
        final activeWorkersOnSite = workersSnap.docs.where((doc) {
          final data = doc.data();
          if (data['isDeleted'] == true || data['isActive'] == false) return false;
          final assigned = data['assignedSiteIds'];
          if (assigned is List && assigned.map((e) => e.toString()).contains(widget.siteId)) {
            return true;
          }
          return data['siteId']?.toString() == widget.siteId;
        }).toList();

        final scSnap = await FirebaseFirestore.instance.collection('sub_contractors').get();
        final activeScOnSite = scSnap.docs.where((doc) {
          final data = doc.data();
          if (data['isDeleted'] == true || data['isActive'] == false) return false;
          final assigned = data['assignedSiteIds'];
          if (assigned is List && assigned.map((e) => e.toString()).contains(widget.siteId)) {
            return true;
          }
          return data['siteId']?.toString() == widget.siteId;
        }).toList();

        siteWorkersCount = activeWorkersOnSite.length + activeScOnSite.length;
      } catch (e) {
        debugPrint('Error loading site workers count: $e');
      }

      setState(() {
        totalAssignedSiteWorkers = siteWorkersCount;
        workersList = workersSnapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
        workersList.sort((a, b) {
          final nameA = (a['workerName'] ?? a['name'] ?? '').toString().trim().toLowerCase();
          final nameB = (b['workerName'] ?? b['name'] ?? '').toString().trim().toLowerCase();
          return nameA.compareTo(nameB);
        });
        isAttendanceCompleted = (totalAssignedSiteWorkers > 0 && workersList.length >= totalAssignedSiteWorkers);
      });
      
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

  Future<void> _saveHeaderInfo() async {
    final coordinator = coordinatorController.text.trim();
    final weather = weatherController.text.trim();
    final notes = notesController.text.trim();
    
    setState(() => isSavingCoordinator = true);
    
    try {
      final docId = '${widget.siteId}_$today';
      await FirebaseFirestore.instance.collection('daily_labour_entries').doc(docId).set({
        'coordinatorName': coordinator,
        'weather': weather,
        'notes': notes,
        'siteId': widget.siteId,
        'siteName': widget.siteName,
        'date': today,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Details saved successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('Error saving details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save details'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => isSavingCoordinator = false);
      }
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
            isAttendanceCompleted = (totalAssignedSiteWorkers > 0 && workersList.length >= totalAssignedSiteWorkers);
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
          .collection('daily_labour_entries')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      for (final worker in updatedWorkers) {
        final workerId = worker['workerId'];
        if (workerId == null) continue;

        // Update daily_labour_entries/{docId}/workers subcollection
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

  Future<void> confirmAndDeleteWorker(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Entry'),
          content: const Text('Are you sure you want to delete this entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteWorker(index);
    }
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
      final dailyEntriesDocRef = FirebaseFirestore.instance
          .collection('daily_labour_entries')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      // 1. Delete from nested subcollections
      batch.delete(docRef.collection('workers').doc(workerId));
      batch.delete(dailyEntriesDocRef.collection('workers').doc(workerId));

      // 2. Delete from flat daily_labour_entries collection if present
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
        isAttendanceCompleted = (totalAssignedSiteWorkers > 0 && workersList.length >= totalAssignedSiteWorkers);
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


  Widget _buildPageHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Daily Labour Entry',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(today),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: primaryColor, 
                        onPrimary: Colors.white,
                        onSurface: Colors.black, 
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (selectedDate != null) {
                // Formatting date for dart logic
                String y = selectedDate.year.toString();
                String m = selectedDate.month.toString().padLeft(2, '0');
                String d = selectedDate.day.toString().padLeft(2, '0');
                
                setState(() {
                  today = '$y-$m-$d';
                  todayFormatted = '$d/$m/$y';
                  isLoading = true;
                  workersList.clear();
                  coordinatorController.clear();
                  weatherController.clear();
                  notesController.clear();
                });
                loadData();
              }
            },
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
              child: Icon(Icons.calendar_month, color: primaryColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 213, 207, 232),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  _buildPageHeader(context),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildHeaderSection(),
                              const SizedBox(height: 24),
                              _buildLabourListSection(),
                              const SizedBox(height: 24),
                              _buildMealsEntrySection(),
                              const SizedBox(height: 24),
                              _buildSummarySection(),
                              const SizedBox(height: 40),
                            ]),
                          ),
                        ),
                      ],
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: coordinatorController,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: 'Project Coordinator',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSavingCoordinator ? null : _saveHeaderInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSavingCoordinator
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            if (isAttendanceCompleted || (totalAssignedSiteWorkers > 0 && workersList.length >= totalAssignedSiteWorkers))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Attendance Recorded (${workersList.length}/$totalAssignedSiteWorkers)',
                      style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
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
    final String labourTypeLabel = worker['labourType']?.toString() ?? (isContractor ? 'Sub Contractor' : 'Daily Wage');
    final String attendanceLabel = worker['attendanceType']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => editWorker(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isContractor ? Colors.orange.shade50 : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isContractor ? Icons.engineering : Icons.person,
                      color: isContractor ? Colors.orange.shade700 : Colors.blue.shade700,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        worker['workerName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (worker['labourType'] == 'Sub Contractor' || isContractor)
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              labourTypeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (worker['labourType'] == 'Sub Contractor' || isContractor)
                                    ? Colors.orange.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          if (attendanceLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: attendanceLabel == 'Full Day' ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                attendanceLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: attendanceLabel == 'Full Day' ? Colors.green.shade700 : Colors.grey.shade700,
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF0b3470), size: 20),
                      onPressed: () => editWorker(index),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Entry',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => confirmAndDeleteWorker(index),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Entry',
                    ),
                  ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Daily Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Key KPI Highlight Block: Effective Labour & Additional Expenses
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Effective Labour',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3730A3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary['effectiveLabour'].toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${summary['totalAdditionalExpense'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Attendance & OT Breakdown Rows
          _buildSummaryRow('Full Day', summary['fullDay'].toString(), const Color(0xFF15803D), bgTint: const Color(0xFFDCFCE7)),
          _buildSummaryRow('Half Day', summary['halfDay'].toString(), const Color(0xFFB45309), bgTint: const Color(0xFFFEF3C7)),
          _buildSummaryRow('Early Out', summary['earlyOut'].toString(), const Color(0xFF7E22CE), bgTint: const Color(0xFFF3E8FF)),
          _buildSummaryRow('Absent', summary['absent'].toString(), const Color(0xFFB91C1C), bgTint: const Color(0xFFFEE2E2)),
          _buildSummaryRow('Leave', summary['leave'].toString(), const Color(0xFF475569), bgTint: const Color(0xFFF1F5F9)),
          _buildSummaryRow('Total OT Hours', summary['totalOT'].toString(), const Color(0xFF0D9488), bgTint: const Color(0xFFCCFBF1)),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Expenses Breakdown Rows
          _buildSummaryRow('Meals (Count)', summary['totalMealsCount'].toString(), const Color(0xFFC2410C), bgTint: const Color(0xFFFFEDD5)),
          _buildSummaryRow('Meals (Expense)', '₹${summary['totalMealsExpense'].toStringAsFixed(2)}', const Color(0xFFC2410C), bgTint: const Color(0xFFFFEDD5)),
          _buildSummaryRow('Bus Fare (Trips)', summary['totalBusCount'].toString(), const Color(0xFF1D4ED8), bgTint: const Color(0xFFDBEAFE)),
          _buildSummaryRow('Bus Fare (Expense)', '₹${summary['totalBusExpense'].toStringAsFixed(2)}', const Color(0xFF1D4ED8), bgTint: const Color(0xFFDBEAFE)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {Color? bgTint, bool isBold = false, bool isLarge = false}) {
    final Color actualBgTint = bgTint ?? color.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isLarge ? 15 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: actualBgTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: isLarge ? 16 : 14,
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
                          final mealsCountStr = _mealsCountController.text.trim();
                          final mealsAmountStr = _mealsAmountController.text.trim();
                          final busCountStr = _busCountController.text.trim();
                          final busAmountStr = _busAmountController.text.trim();

                          final mealsCount = int.tryParse(mealsCountStr) ?? 0;
                          final mealsAmount = double.tryParse(mealsAmountStr) ?? 0.0;
                          final busCount = int.tryParse(busCountStr) ?? 0;
                          final busAmount = double.tryParse(busAmountStr) ?? 0.0;

                          if (mealsCount <= 0 && mealsAmount <= 0 && busCount <= 0 && busAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter at least one expense entry (Meals or Bus Fare) before saving.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (mealsAmount > 0 && mealsCount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter No of Meals when specifying Meals Amount.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (mealsCount > 0 && mealsAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter Meals Amount when specifying No of Meals.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (busAmount > 0 && busCount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter No of Trips when specifying Bus Fare Amount.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (busCount > 0 && busAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter Bus Fare Amount when specifying No of Trips.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => _isSaving = true);
                          final index = _updatedWorkers.indexWhere((w) => w['workerId'] == _selectedWorkerId);
                          if (index != -1) {
                            _updatedWorkers[index] = {
                              ..._updatedWorkers[index],
                              'mealsCount': mealsCount,
                              'mealsAmount': mealsAmount,
                              'busCount': busCount,
                              'busAmount': busAmount,
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
