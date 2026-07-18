import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AddLabourEntryModal extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final String date;
  final List<Map<String, dynamic>> existingEntries;
  final Function(Map<String, dynamic>) onWorkerAdded;

  const AddLabourEntryModal({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    required this.existingEntries,
    required this.onWorkerAdded,
  });

  @override
  _AddLabourEntryModalState createState() => _AddLabourEntryModalState();
}

class _AddLabourEntryModalState extends State<AddLabourEntryModal> {
  final Color primaryColor = const Color(0xFF0b3470);
  bool _isSaving = false;
  final TextEditingController searchController = TextEditingController();
  final TextEditingController workerNameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController aadhaarController = TextEditingController();
  final TextEditingController inTimeController = TextEditingController();
  final TextEditingController outTimeController = TextEditingController();
  final TextEditingController otHoursController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  String? selectedContractor;
  String selectedCategory = 'Mason';
  String selectedLabourType = 'Daily Wage';
  String selectedAttendanceType = 'Full Day';
  bool isAddingNewWorker = false;
  List<DocumentSnapshot> workers = [];
  List<DocumentSnapshot> filteredWorkers = [];
  List<DocumentSnapshot> contractors = [];
  List<DocumentSnapshot> filteredContractors = [];
  DocumentSnapshot? selectedWorker;

  final List<String> categories = [
    'Mason',
    'Mason Helper',
    'Carpenter',
    'Electrician',
    'Painter',
    'Watchman',
    'Driver',
    'Operator',
  ];
  final List<String> labourTypes = ['Daily Wage', 'Sub Contractor'];
  bool _isLoadingLabours = true;
  List<Map<String, dynamic>> _labours = [];
  Set<String> _workerIdsOnOtherSitesToday = {};
  final List<String> attendanceTypes = [
    'Full Day',
    'Half Day',
    'Early Out',
    'Overtime',
    'Absent',
    'Leave',
    'Night Shift',
  ];

  @override
  void initState() {
    super.initState();
    loadWorkers();
    loadContractors();
    _loadLabours();
    _loadWorkersOnOtherSitesToday();
    searchController.addListener(filterWorkers);
  }

  List<String> _parseAssignedSiteIds(Map<String, dynamic> data) {
    final raw = data['assignedSiteIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((id) => id.isNotEmpty).toList();
    }
    final legacySiteId = data['siteId']?.toString();
    if (legacySiteId != null && legacySiteId.isNotEmpty) {
      return [legacySiteId];
    }
    return [];
  }

  /// Unassigned workers/SCs can be picked on any site; once assigned to a site
  /// they only appear on that site until transferred.
  bool _isVisibleForCurrentSite(Map<String, dynamic> data) {
    final assigned = _parseAssignedSiteIds(data);
    if (assigned.isEmpty) return true;
    return assigned.contains(widget.siteId);
  }

  bool _isBlockedOnAnotherSiteToday(String docId) {
    return _workerIdsOnOtherSitesToday.contains(docId);
  }

  Future<void> _loadWorkersOnOtherSitesToday() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('daily_labour_entries')
          .where('date', isEqualTo: widget.date)
          .where('supervisorId', isEqualTo: widget.supervisorId)
          .get();

      final blocked = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final entrySiteId = data['siteId']?.toString();
        final workerId = data['workerId']?.toString();
        if (workerId != null &&
            entrySiteId != null &&
            entrySiteId.isNotEmpty &&
            entrySiteId != widget.siteId) {
          blocked.add(workerId);
        }
      }

      setState(() {
        _workerIdsOnOtherSitesToday = blocked;
      });
      filterWorkers();
    } catch (e) {
      debugPrint('Error loading other-site assignments: $e');
    }
  }

  Future<void> _loadLabours() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('labours')
          .get();
      final laboursData = snapshot.docs
          .map(
            (doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'designation': (data['designation']?.toString()) ?? 'Uncategorized',
                'salary': data['salary'] ?? 0.0,
                'defaultHours': (data['defaultHours'] is num) 
                    ? (data['defaultHours'] as num).toDouble() 
                    : 8.0,
              };
            },
          )
          .toList();

      final uniqueDesignations = <String, Map<String, dynamic>>{};
      for (var labour in laboursData) {
        final designation = labour['designation'];
        if (!uniqueDesignations.containsKey(designation)) {
          uniqueDesignations[designation] = {
            'salary': labour['salary'],
            'defaultHours': labour['defaultHours'],
          };
        }
      }

      final uniqueLabours = uniqueDesignations.entries
          .map(
            (entry) => {
              'designation': entry.key,
              'salary': entry.value['salary'],
              'defaultHours': entry.value['defaultHours'],
            },
          )
          .toList();

      setState(() {
        _labours = uniqueLabours;
        _isLoadingLabours = false;
      });
    } catch (e) {
      debugPrint('Error loading labours: $e');
      setState(() {
        _isLoadingLabours = false;
      });
    }
  }

  Future<void> loadContractors() async {
    try {
      // 1. Fetch from 'contractors' collection
      QuerySnapshot contractorsSnap = await FirebaseFirestore.instance
          .collection('contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .get();

      if (contractorsSnap.docs.isEmpty) {
        contractorsSnap = await FirebaseFirestore.instance
            .collection('contractors')
            .where('supervisorId', isEqualTo: widget.supervisorId)
            .get();
      }

      // 2. Fetch from 'sub_contractors' collection
      QuerySnapshot subContractorsSnap = await FirebaseFirestore.instance
          .collection('sub_contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .get();

      if (subContractorsSnap.docs.isEmpty) {
        subContractorsSnap = await FirebaseFirestore.instance
            .collection('sub_contractors')
            .where('supervisorId', isEqualTo: widget.supervisorId)
            .get();
      }

      setState(() {
        // Step 1: Merge by document ID to remove exact duplicate docs
        final allDocsMap = <String, DocumentSnapshot>{};
        for (var doc in contractorsSnap.docs) {
          allDocsMap[doc.id] = doc;
        }
        for (var doc in subContractorsSnap.docs) {
          allDocsMap[doc.id] = doc;
        }

        // Step 2: Further deduplicate by contractorName so the dropdown
        // never gets two items with the same string value.
        final seenNames = <String>{};
        contractors = allDocsMap.values.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['contractorName'] ?? data['name'] ?? '')
              .toString()
              .trim();
          if (name.isEmpty || seenNames.contains(name)) return false;
          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
          seenNames.add(name);
          return true;
        }).toList();
        filteredContractors = contractors;

        // Set initial selection only if valid
        if (contractors.isNotEmpty) {
          final firstData = contractors.first.data() as Map<String, dynamic>;
          final firstName = (firstData['contractorName'] ?? firstData['name'])
              ?.toString();
          selectedContractor = firstName;
        } else {
          selectedContractor = null;
        }
        filterWorkers();
      });
    } catch (e) {
      debugPrint('Error loading contractors: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    workerNameController.dispose();
    mobileController.dispose();
    aadhaarController.dispose();
    inTimeController.dispose();
    outTimeController.dispose();
    otHoursController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> loadWorkers() async {
    try {
      // First try by supervisorName
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('workers')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .get();

      // If no results, try by supervisorId
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('workers')
            .where('supervisorId', isEqualTo: widget.supervisorId)
            .get();
      }

      setState(() {
        workers = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
          return true;
        }).toList();
        filteredWorkers = workers;
        filterWorkers();
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }

  void filterWorkers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredWorkers = workers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name =
            (data['workerName'] ?? data['name'])?.toString().toLowerCase() ??
            '';
        final mobile =
            (data['mobile'] ?? data['mobileNumber'])
                ?.toString()
                .toLowerCase() ??
            '';
        final matchesSearch = name.contains(query) || mobile.contains(query);
        if (!matchesSearch) return false;
        if (!_isVisibleForCurrentSite(data)) return false;
        if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
        return true;
      }).toList();

      filteredContractors = contractors.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name =
            (data['contractorName'] ?? data['name'])
                ?.toString()
                .toLowerCase() ??
            '';
        final mobile =
            (data['mobileNumber'] ?? data['mobile'])
                ?.toString()
                .toLowerCase() ??
            '';
        final matchesSearch = name.contains(query) || mobile.contains(query);
        if (!matchesSearch) return false;
        if (!_isVisibleForCurrentSite(data)) return false;
        if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
        return true;
      }).toList();
    });
  }

  double calculateDayValue() {
    switch (selectedAttendanceType) {
      case 'Full Day':
      case 'Night Shift':
        return 1.0;
      case 'Half Day':
        return 0.5;
      case 'Early Out':
        return 0.75;
      default:
        return 0.0;
    }
  }

  double calculateHoursWorked(String inTime, String outTime) {
    try {
      final List<String> inParts = inTime.split(' ');
      final List<String> outParts = outTime.split(' ');

      final inTimePart = inParts[0];
      final inPeriod = inParts[1].toUpperCase();
      final outTimePart = outParts[0];
      final outPeriod = outParts[1].toUpperCase();

      final inHourMin = inTimePart.split(':');
      final outHourMin = outTimePart.split(':');

      int inHour = int.parse(inHourMin[0]);
      int inMin = int.parse(inHourMin[1]);

      int outHour = int.parse(outHourMin[0]);
      int outMin = int.parse(outHourMin[1]);

      if (inPeriod == 'PM' && inHour != 12) {
        inHour += 12;
      }
      if (outPeriod == 'PM' && outHour != 12) {
        outHour += 12;
      }
      if (inPeriod == 'AM' && inHour == 12) {
        inHour = 0;
      }
      if (outPeriod == 'AM' && outHour == 12) {
        outHour = 0;
      }

      int inTotalMinutes = inHour * 60 + inMin;
      int outTotalMinutes = outHour * 60 + outMin;

      int totalMinutesWorked;

      if (outTotalMinutes >= inTotalMinutes) {
        totalMinutesWorked = outTotalMinutes - inTotalMinutes;
      } else {
        totalMinutesWorked = (24 * 60 - inTotalMinutes) + outTotalMinutes;
      }

      return totalMinutesWorked / 60.0;
    } catch (e) {
      debugPrint('Error calculating hours: $e');
      return 0.0;
    }
  }

  double _configuredDefaultHours() {
    if (isAddingNewWorker) {
      final labour = _labours.firstWhere(
        (item) => item['designation'] == selectedCategory,
        orElse: () => const {'defaultHours': 8.0},
      );
      return (labour['defaultHours'] as num?)?.toDouble() ?? 8.0;
    }

    final data = selectedWorker?.data();
    if (data is Map<String, dynamic>) {
      return (data['defaultHours'] as num?)?.toDouble() ?? 8.0;
    }
    return 8.0;
  }

  /// Keeps the OT input in sync with the selected worker's configured hours.
  void _recalculateOtHours() {
    final inTime = inTimeController.text.trim();
    final outTime = outTimeController.text.trim();
    if (inTime.isEmpty || outTime.isEmpty) {
      otHoursController.text = '0';
      return;
    }

    final hoursWorked = calculateHoursWorked(inTime, outTime);
    final overtimeHours = hoursWorked > _configuredDefaultHours()
        ? hoursWorked - _configuredDefaultHours()
        : 0.0;
    otHoursController.text = overtimeHours == 0
        ? '0'
        : overtimeHours.toStringAsFixed(2);
  }

  Map<String, double> calculateSalary({
    required double basicSalary,
    required double defaultHours,
    required double hoursWorked,
    required double otHours,
    double? overtimeRate,
  }) {
    final double hourlyRate = basicSalary / defaultHours;
    final double overtimeRateToUse = overtimeRate ?? hourlyRate * 1.5;

    double regularHours = hoursWorked > defaultHours
        ? defaultHours
        : hoursWorked;
    final automaticOvertimeHours = hoursWorked > defaultHours
        ? hoursWorked - defaultHours
        : 0.0;
    // OT is populated from the time fields. Keep manually entered OT working
    // for entries without times, without double-counting calculated OT.
    final overtimeHours = automaticOvertimeHours > otHours
        ? automaticOvertimeHours
        : otHours;

    double regularSalary = regularHours * hourlyRate;
    double overtimeSalary = overtimeHours * overtimeRateToUse;
    double totalSalary = regularSalary + overtimeSalary;

    return {
      'basicSalary': basicSalary,
      'defaultHours': defaultHours,
      'hoursWorked': hoursWorked,
      'overtimeHours': overtimeHours,
      'overtimeAmount': overtimeSalary,
      'totalSalary': totalSalary,
    };
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (mounted) {
        final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
        controller.text = "$hour:$minute $period";
        _recalculateOtHours();
      }
    }
  }

  Future<void> addWorkerEntry() async {
    Map<String, dynamic>? workerData;
    DocumentSnapshot? selectedContractorDoc;
    double basicSalary = 0.0;
    double defaultHours = 8.0;
    double overtimeRate = 0.0;

    if (selectedContractor != null) {
      // Find the contractor document
      final contractorQuery = await FirebaseFirestore.instance
          .collection('contractors')
          .where('contractorName', isEqualTo: selectedContractor)
          .limit(1)
          .get();
      if (contractorQuery.docs.isNotEmpty) {
        selectedContractorDoc = contractorQuery.docs.first;
      }
    }

    if (isAddingNewWorker) {
      if (workerNameController.text.trim().isEmpty ||
          mobileController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields')),
        );
        return;
      }

      // Get basic salary and default hours from labours collection for category
      final selectedLabour = _labours.firstWhere(
        (labour) => labour['designation'] == selectedCategory,
        orElse: () => {'salary': 0, 'defaultHours': 8.0},
      );
      basicSalary = (selectedLabour['salary'] is num)
          ? selectedLabour['salary'].toDouble()
          : 0.0;
      defaultHours = (selectedLabour['defaultHours'] is num)
          ? selectedLabour['defaultHours'].toDouble()
          : 8.0;

      workerData = {
        'workerName': workerNameController.text.trim(),
        'mobile': mobileController.text.trim(),
        'aadhaar': aadhaarController.text.trim(),
        'category': selectedCategory,
        'contractorName': selectedContractor,
        'contractorId': selectedContractorDoc?.id,
        'supervisorName': widget.supervisorName,
        'supervisorId': widget.supervisorId,
        'labourType': selectedLabourType,
        'basicSalary': basicSalary,
        'defaultHours': defaultHours,
        'assignedSiteIds': [widget.siteId],
      };

      try {
        final docRef = await FirebaseFirestore.instance
            .collection('workers')
            .add(workerData);
        workerData['workerId'] = docRef.id;
      } catch (e) {
        debugPrint('Error adding worker: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding worker: $e')));
        }
        return;
      }
    } else {
      if (selectedWorker == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a worker')));
        return;
      }

      final data = selectedWorker!.data() as Map<String, dynamic>;
      final isContractor =
          selectedWorker!.reference.parent.id == 'contractors' ||
          selectedWorker!.reference.parent.id == 'sub_contractors';

      if (isContractor) {
        workerData = {
          'workerId': selectedWorker!.id,
          'workerName': data['contractorName'] ?? data['name'] ?? 'Unknown',
          'mobile': data['mobileNumber'] ?? data['mobile'] ?? '',
          'category': data['category'] ?? '',
          'contractorName': data['contractorName'] ?? data['name'] ?? '',
          'contractorId': selectedWorker!.id,
          'supervisorName': data['supervisorName'] ?? widget.supervisorName,
          'supervisorId': data['supervisorId'] ?? widget.supervisorId,
          'labourType': 'Sub Contractor',
          'isContractor': true,
        };
        basicSalary = (data['basicSalary'] as num?)?.toDouble() ?? 0.0;
        defaultHours = (data['defaultHours'] as num?)?.toDouble() ?? 8.0;
        overtimeRate = (data['overtimeRate'] as num?)?.toDouble() ?? 0.0;
      } else {
        workerData = {
          'workerId': selectedWorker!.id,
          'workerName': data['workerName'] ?? data['name'] ?? 'Unknown',
          'mobile': data['mobile'] ?? data['mobileNumber'] ?? '',
          'category': data['workerType'] ?? data['category'] ?? '',
          'contractorName':
              data['contractorName'] ??
              data['subContractorName'] ??
              data['contractor'] ??
              '',
          'contractorId': data['contractorId'] ?? data['subContractorId'] ?? '',
          'supervisorName': data['supervisorName'] ?? widget.supervisorName,
          'supervisorId': data['supervisorId'] ?? widget.supervisorId,
          'labourType': data['labourType'] ?? 'Daily Wage',
          'isContractor': false,
        };
        basicSalary = (data['basicSalary'] as num?)?.toDouble() ?? 0.0;
        defaultHours = (data['defaultHours'] as num?)?.toDouble() ?? 8.0;
        overtimeRate = (data['overtimeRate'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final workerId = (workerData['workerId'] as String?)?.isNotEmpty == true
        ? workerData['workerId'] as String
        : DateTime.now().millisecondsSinceEpoch.toString();

    final otHoursInput = otHoursController.text.trim();
    final otHoursValue = otHoursInput.isEmpty
        ? "0 Hours"
        : "$otHoursInput Hours";
    final otHoursNumber = double.tryParse(otHoursInput) ?? 0.0;

    final inTime = inTimeController.text.trim();
    final outTime = outTimeController.text.trim();
    double hoursWorked = 0.0;
    if (inTime.isNotEmpty && outTime.isNotEmpty) {
      hoursWorked = calculateHoursWorked(inTime, outTime);
    }

    final salaryData = calculateSalary(
      basicSalary: basicSalary,
      defaultHours: defaultHours,
      hoursWorked: hoursWorked,
      otHours: otHoursNumber,
      overtimeRate: overtimeRate,
    );

    final entry = <String, dynamic>{
      ...workerData,
      'workerId': workerId,
      'attendanceType': selectedAttendanceType,
      'inTime': inTime,
      'outTime': outTime,
      'otHours': otHoursValue,
      'dayValue': calculateDayValue(),
      'remarks': remarksController.text.trim(),
      'siteId': widget.siteId,
      'siteName': widget.siteName,
      'supervisorId': widget.supervisorId,
      'supervisorName': widget.supervisorName,
      'date': widget.date,
      'savedAt': FieldValue.serverTimestamp(),
      // New fields for meals and bus fare with defaults
      'mealsCount': 0,
      'mealsAmount': 0,
      'busCount': 0,
      'busAmount': 0,
      // New salary calculation fields
      'basicSalary': salaryData['basicSalary'],
      'defaultHours': salaryData['defaultHours'],
      'hoursWorked': salaryData['hoursWorked'],
      'overtimeHours': salaryData['overtimeHours'],
      'overtimeAmount': salaryData['overtimeAmount'],
      'totalSalary': salaryData['totalSalary'],
    };

    setState(() => _isSaving = true);

    try {
      final docId = '${widget.siteId}_${widget.date}';
      final attendanceDocRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);

      final batch = FirebaseFirestore.instance.batch();

      // 1. Save to attendance/{docId}/workers subcollection
      batch.set(attendanceDocRef.collection('workers').doc(workerId), entry);

      // Assign worker / sub-contractor to this site (single-site assignment)
      if (!isAddingNewWorker && selectedWorker != null) {
        batch.update(selectedWorker!.reference, {
          'assignedSiteIds': [widget.siteId],
        });
      }

      // 2. Save flat doc to daily_labour_entries
      final flatDocId = '${widget.siteId}_${widget.date}_$workerId';
      batch.set(
        FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc(flatDocId),
        entry,
      );

      // 3. Compute updated summary and touch parent attendance doc
      // Filter out existing entry for this worker if it was already added to prevent duplicates in count
      final updatedList =
          widget.existingEntries
              .where((w) => w['workerId'] != workerId)
              .toList()
            ..add(entry);

      int fullDay = 0;
      int halfDay = 0;
      int earlyOut = 0;
      int absent = 0;
      int leave = 0;
      double totalOT = 0;
      double effectiveLabour = 0;

      for (final worker in updatedList) {
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
      }

      batch.set(attendanceDocRef, {
        'siteId': widget.siteId,
        'siteName': widget.siteName,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'date': widget.date,
        'totalWorkers': updatedList.length,
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

      setState(() => _isSaving = false);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Labour entry saved successfully.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );

      widget.onWorkerAdded(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving labour entry: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Labour Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Toggle between existing and new worker
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isAddingNewWorker = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isAddingNewWorker
                                ? primaryColor
                                : Colors.grey[200],
                            foregroundColor: !isAddingNewWorker
                                ? Colors.white
                                : Colors.grey[800],
                          ),
                          child: const Text('Select Worker'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isAddingNewWorker = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAddingNewWorker
                                ? primaryColor
                                : Colors.grey[200],
                            foregroundColor: isAddingNewWorker
                                ? Colors.white
                                : Colors.grey[800],
                          ),
                          child: const Text('Add New Worker'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!isAddingNewWorker) ...[
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Worker or Sub Contractor',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child:
                          (filteredWorkers.isEmpty &&
                              filteredContractors.isEmpty)
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No results found'),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                if (filteredWorkers.isNotEmpty) ...[
                                  Container(
                                    color: Colors.grey.shade100,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: const Text(
                                      'WORKERS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  ...filteredWorkers.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['workerName'] ??
                                        data['name'] ??
                                        'Unknown';
                                    final subContractor =
                                        data['contractorName'] ??
                                        data['subContractorName'] ??
                                        data['contractor'] ??
                                        'None';
                                    final category =
                                        data['category'] ??
                                        data['workerType'] ??
                                        'Uncategorized';
                                    return ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              border: Border.all(
                                                color: Colors.blue.shade200,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Worker',
                                              style: TextStyle(
                                                color: Colors.blue.shade900,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '$category • Sub Contractor: $subContractor',
                                      ),
                                      trailing: selectedWorker?.id == doc.id
                                          ? Icon(
                                              Icons.check_circle,
                                              color: primaryColor,
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          selectedWorker = doc;
                                        });
                                        _recalculateOtHours();
                                      },
                                    );
                                  }).toList(),
                                ],
                                if (filteredContractors.isNotEmpty) ...[
                                  Container(
                                    color: Colors.grey.shade100,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: const Text(
                                      'SUB CONTRACTORS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  ...filteredContractors.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['contractorName'] ??
                                        data['name'] ??
                                        'Unknown';
                                    return ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              border: Border.all(
                                                color: Colors.orange.shade200,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Sub Contractor',
                                              style: TextStyle(
                                                color: Colors.orange.shade900,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: const Text(
                                        'Sub Contractor (Self)',
                                      ),
                                      trailing: selectedWorker?.id == doc.id
                                          ? Icon(
                                              Icons.check_circle,
                                              color: primaryColor,
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          selectedWorker = doc;
                                        });
                                        _recalculateOtHours();
                                      },
                                    );
                                  }).toList(),
                                ],
                              ],
                            ),
                    ),
                  ] else ...[
                    TextField(
                      controller: workerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Worker Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aadhaarController,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingLabours
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            value: selectedCategory,
                            items: _labours.map<DropdownMenuItem<String>>((labour) {
                              return DropdownMenuItem<String>(
                                value: labour['designation'],
                                child: Text(labour['designation']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value!;
                              });
                              _recalculateOtHours();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                          ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // Guard: only pass value if it exists in the unique items list
                      value: (() {
                        final names = contractors
                            .map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return (data['contractorName'] ?? data['name'])
                                  ?.toString();
                            })
                            .whereType<String>()
                            .toList();
                        return (selectedContractor != null &&
                                names.contains(selectedContractor))
                            ? selectedContractor
                            : null;
                      })(),
                      items: contractors.map<DropdownMenuItem<String>>((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name =
                            (data['contractorName'] ??
                                    data['name'] ??
                                    'Unknown')
                                .toString();
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedContractor = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Sub-Contractor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLabourType,
                      items: labourTypes.map<DropdownMenuItem<String>>((t) {
                        return DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLabourType = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Labour Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Attendance Type
                  const Text(
                    'Attendance Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedAttendanceType,
                    items: attendanceTypes.map<DropdownMenuItem<String>>((t) {
                      return DropdownMenuItem<String>(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAttendanceType = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Attendance Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inTimeController,
                    readOnly: true,
                    onTap: () => _selectTime(context, inTimeController),
                    decoration: const InputDecoration(
                      labelText: 'In Time (e.g. 08:00 AM)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: outTimeController,
                    readOnly: true,
                    onTap: () => _selectTime(context, outTimeController),
                    decoration: const InputDecoration(
                      labelText: 'Out Time (e.g. 05:00 PM)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otHoursController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'OT Hours',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : addWorkerEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Add Entry',
                              style: TextStyle(fontSize: 18),
                            ),
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
}
