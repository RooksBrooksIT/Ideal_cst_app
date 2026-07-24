import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class AddLabourEntryModal extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final String date;
  final List<Map<String, dynamic>> existingEntries;
  final Function(Map<String, dynamic>) onWorkerAdded;
  final Map<String, dynamic>? initialWorker;

  const AddLabourEntryModal({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    required this.existingEntries,
    required this.onWorkerAdded,
    this.initialWorker,
  });

  @override
  _AddLabourEntryModalState createState() => _AddLabourEntryModalState();
}

class _AddLabourEntryModalState extends State<AddLabourEntryModal> {
  final Color primaryColor = const Color(0xFF4527A0);
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

  Set<String> selectedWorkerIds = {};
  Map<String, DocumentSnapshot> selectedWorkerDocs = {};
  bool isMultiSelectMode = false;

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

    _initializeData();
    searchController.addListener(filterWorkers);
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadLabours(),
      _loadWorkersOnOtherSitesToday(),
    ]);
    await Future.wait([
      loadWorkers(),
      loadContractors(),
    ]);
    _prefillFromInitialWorker();
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

      if (!mounted) return;
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
          .toList()
        ..sort((a, b) => (a['designation'] ?? '').toString().trim().toLowerCase().compareTo((b['designation'] ?? '').toString().trim().toLowerCase()));

      if (!mounted) return;
      setState(() {
        _labours = uniqueLabours;
        _isLoadingLabours = false;
      });
    } catch (e) {
      debugPrint('Error loading labours: $e');
      if (mounted) {
        setState(() {
          _isLoadingLabours = false;
        });
      }
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

      if (!mounted) return;
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
          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }
          seenNames.add(name);
          return true;
        }).toList();

        contractors.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final nameA = (dataA['contractorName'] ?? dataA['name'] ?? '').toString().trim().toLowerCase();
          final nameB = (dataB['contractorName'] ?? dataB['name'] ?? '').toString().trim().toLowerCase();
          return nameA.compareTo(nameB);
        });

        filteredContractors = List.from(contractors);

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

      if (!mounted) return;
      setState(() {
        workers = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }
          return true;
        }).toList();

        workers.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final nameA = (dataA['workerName'] ?? dataA['name'] ?? '').toString().trim().toLowerCase();
          final nameB = (dataB['workerName'] ?? dataB['name'] ?? '').toString().trim().toLowerCase();
          return nameA.compareTo(nameB);
        });

        filteredWorkers = List.from(workers);
        filterWorkers();
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }


  void _prefillFromInitialWorker() {
    if (widget.initialWorker != null) {
      final w = widget.initialWorker!;
      setState(() {
        selectedAttendanceType = w['attendanceType'] ?? 'Full Day';
        inTimeController.text = w['inTime'] ?? '';
        outTimeController.text = w['outTime'] ?? '';
        otHoursController.text = (w['otHours'] ?? '').toString();
        remarksController.text = w['remarks'] ?? '';
        
        final isContractor = w['isContractor'] == true ||
            (w['labourType'] == 'Sub Contractor' &&
                (w['contractor'] == null ||
                    w['contractor'].toString().isEmpty ||
                    w['contractor'] == w['workerName']));
                    
        isAddingNewWorker = false;
        
        final workerId = w['workerId']?.toString();
        if (workerId != null && workerId.isNotEmpty) {
          final allAvailable = [...workers, ...contractors];
          final index = allAvailable.indexWhere((doc) => doc.id == workerId);
          if (index != -1) {
            selectedWorker = allAvailable[index];
            selectedWorkerIds = {workerId};
            selectedWorkerDocs = {workerId: allAvailable[index]};
          }
        }
      });
    }
  }

  void _toggleWorkerSelection(DocumentSnapshot doc) {
    final id = doc.id;
    setState(() {
      if (selectedWorkerIds.contains(id)) {
        selectedWorkerIds.remove(id);
        selectedWorkerDocs.remove(id);
        if (selectedWorkerIds.isEmpty) {
          isMultiSelectMode = false;
          selectedWorker = null;
        } else {
          selectedWorker = selectedWorkerDocs.values.last;
        }
      } else {
        isMultiSelectMode = true;
        selectedWorkerIds.add(id);
        selectedWorkerDocs[id] = doc;
        selectedWorker = doc;
      }
    });
    _recalculateOtHours();
  }

  void _selectAllVisibleWorkers() {
    setState(() {
      isMultiSelectMode = true;
      for (final doc in filteredWorkers) {
        selectedWorkerIds.add(doc.id);
        selectedWorkerDocs[doc.id] = doc;
      }
      for (final doc in filteredContractors) {
        selectedWorkerIds.add(doc.id);
        selectedWorkerDocs[doc.id] = doc;
      }
      if (selectedWorkerDocs.isNotEmpty) {
        selectedWorker = selectedWorkerDocs.values.first;
      }
    });
    _recalculateOtHours();
  }

  void _clearWorkerSelection() {
    setState(() {
      selectedWorkerIds.clear();
      selectedWorkerDocs.clear();
      selectedWorker = null;
      isMultiSelectMode = false;
    });
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

      filteredWorkers.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final nameA = (dataA['workerName'] ?? dataA['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (dataB['workerName'] ?? dataB['name'] ?? '').toString().trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      filteredContractors.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final nameA = (dataA['contractorName'] ?? dataA['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (dataB['contractorName'] ?? dataB['name'] ?? '').toString().trim().toLowerCase();
        return nameA.compareTo(nameB);
      });
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
    final double defaultHrsToUse = defaultHours > 0 ? defaultHours : 8.0;
    final double hourlyRate = basicSalary / defaultHrsToUse;
    final double overtimeRateToUse = (overtimeRate != null && overtimeRate > 0)
        ? overtimeRate
        : (hourlyRate > 0 ? hourlyRate * 1.5 : 0.0);

    double regularHours = hoursWorked > defaultHrsToUse
        ? defaultHrsToUse
        : hoursWorked;
    final automaticOvertimeHours = hoursWorked > defaultHrsToUse
        ? hoursWorked - defaultHrsToUse
        : 0.0;
    final overtimeHours = automaticOvertimeHours > otHours
        ? automaticOvertimeHours
        : otHours;

    double regularSalary;
    if (hoursWorked == 0 || hoursWorked >= defaultHrsToUse) {
      regularSalary = basicSalary;
    } else {
      regularSalary = regularHours * hourlyRate;
    }

    double overtimeSalary = overtimeHours * overtimeRateToUse;
    double totalSalary = regularSalary + overtimeSalary;

    return {
      'basicSalary': basicSalary,
      'defaultHours': defaultHrsToUse,
      'hoursWorked': hoursWorked,
      'overtimeHours': overtimeHours,
      'overtimeRate': overtimeRateToUse,
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
        setState(() {
          controller.text = "$hour:$minute $period";
          _recalculateOtHours();
        });
      }
    }
  }

  Future<void> addWorkerEntry() async {
    if (!isAddingNewWorker && selectedWorkerDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one person.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isAddingNewWorker &&
        (workerNameController.text.trim().isEmpty ||
            mobileController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill required worker details (Name & Mobile).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final inTime = inTimeController.text.trim();
    final outTime = outTimeController.text.trim();

    if (inTime.isEmpty || outTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both In Time and Out Time for all selected people before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final otHoursInput = otHoursController.text.trim();
    final otHoursValue = otHoursInput.isEmpty
        ? "0 Hours"
        : "$otHoursInput Hours";
    final otHoursNumber = double.tryParse(otHoursInput) ?? 0.0;
    final remarks = remarksController.text.trim();

    double hoursWorked = 0.0;
    if (inTime.isNotEmpty && outTime.isNotEmpty) {
      hoursWorked = calculateHoursWorked(inTime, outTime);
    }

    final docId = '${widget.siteId}_${widget.date}';
    final attendanceDocRef = FirebaseFirestore.instance
        .collection('daily_labour_entries')
        .doc(docId);

    final batch = FirebaseFirestore.instance.batch();
    final List<Map<String, dynamic>> createdEntries = [];
    final List<Map<String, dynamic>> updatedList = List.from(widget.existingEntries);

    if (isAddingNewWorker) {
      if (workerNameController.text.trim().isEmpty ||
          mobileController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields')),
        );
        return;
      }

      DocumentSnapshot? selectedContractorDoc;
      if (selectedContractor != null) {
        final contractorQuery = await FirebaseFirestore.instance
            .collection('contractors')
            .where('contractorName', isEqualTo: selectedContractor)
            .limit(1)
            .get();
        if (contractorQuery.docs.isNotEmpty) {
          selectedContractorDoc = contractorQuery.docs.first;
        } else {
          final subContractorQuery = await FirebaseFirestore.instance
              .collection('sub_contractors')
              .where('name', isEqualTo: selectedContractor)
              .limit(1)
              .get();
          if (subContractorQuery.docs.isNotEmpty) {
            selectedContractorDoc = subContractorQuery.docs.first;
          }
        }
      }

      final selectedLabour = _labours.firstWhere(
        (labour) => labour['designation'] == selectedCategory,
        orElse: () => {'salary': 0, 'defaultHours': 8.0},
      );
      final basicSalary = (selectedLabour['salary'] is num)
          ? selectedLabour['salary'].toDouble()
          : 0.0;
      final defaultHours = (selectedLabour['defaultHours'] is num)
          ? selectedLabour['defaultHours'].toDouble()
          : 8.0;

      final workerData = {
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

        final salaryData = calculateSalary(
          basicSalary: basicSalary,
          defaultHours: defaultHours,
          hoursWorked: hoursWorked,
          otHours: otHoursNumber,
          overtimeRate: 0.0,
        );

        final entry = <String, dynamic>{
          ...workerData,
          'attendanceType': selectedAttendanceType,
          'inTime': inTime,
          'outTime': outTime,
          'otHours': otHoursValue,
          'dayValue': calculateDayValue(),
          'remarks': remarks,
          'siteId': widget.siteId,
          'siteName': widget.siteName,
          'supervisorId': widget.supervisorId,
          'supervisorName': widget.supervisorName,
          'date': widget.date,
          'savedAt': FieldValue.serverTimestamp(),
          'mealsCount': widget.initialWorker?['mealsCount'] ?? 0,
          'mealsAmount': widget.initialWorker?['mealsAmount'] ?? 0,
          'busCount': widget.initialWorker?['busCount'] ?? 0,
          'busAmount': widget.initialWorker?['busAmount'] ?? 0,
          'basicSalary': salaryData['basicSalary'],
          'defaultHours': salaryData['defaultHours'],
          'hoursWorked': salaryData['hoursWorked'],
          'overtimeHours': salaryData['overtimeHours'],
          'overtimeRate': salaryData['overtimeRate'],
          'overtimeAmount': salaryData['overtimeAmount'],
          'totalSalary': salaryData['totalSalary'],
        };

        batch.set(attendanceDocRef.collection('workers').doc(docRef.id), entry, SetOptions(merge: true));
        createdEntries.add(entry);

        final existingIndex = updatedList.indexWhere((w) => w['workerId'] == docRef.id);
        if (existingIndex >= 0) {
          updatedList[existingIndex] = entry;
        } else {
          updatedList.add(entry);
        }
      } catch (e) {
        debugPrint('Error adding new worker: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding worker: $e')));
        }
        return;
      }
    } else {
      if (selectedWorkerDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one worker')),
        );
        return;
      }

      for (final doc in selectedWorkerDocs.values) {
        final data = doc.data() as Map<String, dynamic>;
        final isContractor =
            doc.reference.parent.id == 'contractors' ||
            doc.reference.parent.id == 'sub_contractors';

        Map<String, dynamic> workerData;
        double basicSalary = 0.0;
        double defaultHours = 8.0;
        double overtimeRate = 0.0;

        if (isContractor) {
          workerData = {
            'workerId': doc.id,
            'workerName': data['contractorName'] ?? data['name'] ?? 'Unknown',
            'mobile': data['mobileNumber'] ?? data['mobile'] ?? '',
            'category': data['category'] ?? '',
            'contractorName': data['contractorName'] ?? data['name'] ?? '',
            'contractorId': doc.id,
            'supervisorName': data['supervisorName'] ?? widget.supervisorName,
            'supervisorId': data['supervisorId'] ?? widget.supervisorId,
            'labourType': 'Sub Contractor',
            'isContractor': true,
          };
          basicSalary = (data['basicSalary'] as num?)?.toDouble() ??
              (data['salaryRate'] as num?)?.toDouble() ??
              (data['rate'] as num?)?.toDouble() ??
              (data['salary'] as num?)?.toDouble() ??
              0.0;
          defaultHours = (data['defaultHours'] as num?)?.toDouble() ?? 8.0;
          overtimeRate = (data['overtimeRate'] as num?)?.toDouble() ?? 0.0;
        } else {
          workerData = {
            'workerId': doc.id,
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
          basicSalary = (data['basicSalary'] as num?)?.toDouble() ??
              (data['salaryRate'] as num?)?.toDouble() ??
              (data['rate'] as num?)?.toDouble() ??
              (data['salary'] as num?)?.toDouble() ??
              0.0;
          defaultHours = (data['defaultHours'] as num?)?.toDouble() ?? 8.0;
          overtimeRate = (data['overtimeRate'] as num?)?.toDouble() ?? 0.0;
        }

        final workerId = doc.id;

        final subContractorId = workerData['contractorId']?.toString() ?? '';
        if (subContractorId.isNotEmpty) {
          try {
            final scDoc = await FirebaseFirestore.instance
                .collection('sub_contractors')
                .doc(subContractorId)
                .get();
            if (scDoc.exists) {
              final scData = scDoc.data();
              if (scData != null) {
                final otR = (scData['overtimeRate'] as num?)?.toDouble();
                if (otR != null && otR > 0) overtimeRate = otR;
                if (basicSalary == 0.0) {
                  final rate = scData['salaryRate'] ?? scData['basicSalary'] ?? scData['rate'] ?? scData['salary'];
                  if (rate is num) basicSalary = rate.toDouble();
                  else if (rate is String) basicSalary = double.tryParse(rate) ?? 0.0;
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching subcontractor details: $e');
          }
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
          'remarks': remarks,
          'siteId': widget.siteId,
          'siteName': widget.siteName,
          'supervisorId': widget.supervisorId,
          'supervisorName': widget.supervisorName,
          'date': widget.date,
          'savedAt': FieldValue.serverTimestamp(),
          'mealsCount': widget.initialWorker?['mealsCount'] ?? 0,
          'mealsAmount': widget.initialWorker?['mealsAmount'] ?? 0,
          'busCount': widget.initialWorker?['busCount'] ?? 0,
          'busAmount': widget.initialWorker?['busAmount'] ?? 0,
          'basicSalary': salaryData['basicSalary'],
          'defaultHours': salaryData['defaultHours'],
          'hoursWorked': salaryData['hoursWorked'],
          'overtimeHours': salaryData['overtimeHours'],
          'overtimeRate': salaryData['overtimeRate'],
          'overtimeAmount': salaryData['overtimeAmount'],
          'totalSalary': salaryData['totalSalary'],
        };

        batch.set(attendanceDocRef.collection('workers').doc(workerId), entry, SetOptions(merge: true));
        batch.update(doc.reference, {
          'assignedSiteIds': [widget.siteId],
        });

        createdEntries.add(entry);

        final existingIndex = updatedList.indexWhere((w) => w['workerId'] == workerId);
        if (existingIndex >= 0) {
          updatedList[existingIndex] = entry;
        } else {
          updatedList.add(entry);
        }
      }
    }

    setState(() => _isSaving = true);

    try {
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

      if (mounted) setState(() => _isSaving = false);
      if (!mounted) return;

      final count = createdEntries.length;
      final msg = count > 1
          ? '$count Labour entries saved successfully.'
          : 'Labour entry saved successfully.';

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
                Text(
                  msg,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

      for (final entry in createdEntries) {
        widget.onWorkerAdded(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving labour entry: $e');
      if (mounted) setState(() => _isSaving = false);
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
      builder: (context, scrollController) => Material(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _buildToggle(),
                      const SizedBox(height: 16),
                      
                      if (!isAddingNewWorker)
                        _buildSelectWorkerSection()
                      else
                        _buildNewWorkerForm(),
                        
                      const SizedBox(height: 16),
                      _buildAttendanceDetails(),
                      const SizedBox(height: 100), // padding for bottom button
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Builder(
                builder: (context) {
                  final bool hasSelectedPerson = isAddingNewWorker
                      ? (workerNameController.text.trim().isNotEmpty && mobileController.text.trim().isNotEmpty)
                      : selectedWorkerDocs.isNotEmpty;
                  final bool hasTimeEntered = inTimeController.text.trim().isNotEmpty && outTimeController.text.trim().isNotEmpty;
                  final bool isFormComplete = hasSelectedPerson && hasTimeEntered;

                  return Container(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 16, top: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : addWorkerEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFormComplete ? primaryColor : primaryColor.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              (!isAddingNewWorker && selectedWorkerDocs.length > 1)
                                  ? 'Save ${selectedWorkerDocs.length} Entries'
                                  : 'Save Entry',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.initialWorker != null ? 'Edit Labour Entry' : 'Add Labour Entry',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: 'Select Existing',
              isActive: !isAddingNewWorker,
              onTap: () => setState(() => isAddingNewWorker = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: 'Add New',
              isActive: isAddingNewWorker,
              onTap: () => setState(() => isAddingNewWorker = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String title, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? primaryColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectWorkerSection() {
    final hasSelection = selectedWorkerIds.isNotEmpty;
    final selectionCount = selectedWorkerIds.length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasSelection || isMultiSelectMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$selectionCount ${selectionCount == 1 ? "Person" : "People"} Selected',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                      ),
                    ),
                    InkWell(
                      onTap: _selectAllVisibleWorkers,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('Select All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _clearWorkerSelection,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('Clear', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search Worker / Contractor',
                helperText: 'Tip: Long-press any person to select multiple',
                helperStyle: TextStyle(fontSize: 11, color: Colors.indigo.shade600, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredWorkers.isEmpty && filteredContractors.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No results found')))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (filteredWorkers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('WORKERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      ...filteredWorkers.map((doc) => _buildWorkerTile(doc, isWorker: true)),
                    ],
                    if (filteredContractors.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                        child: Text('SUB CONTRACTORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      ...filteredContractors.map((doc) => _buildWorkerTile(doc, isWorker: false)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerTile(DocumentSnapshot doc, {required bool isWorker}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = isWorker 
        ? (data['workerName'] ?? data['name'] ?? 'Unknown')
        : (data['contractorName'] ?? data['name'] ?? 'Unknown');
        
    final subContractor = isWorker 
        ? (data['contractorName'] ?? data['subContractorName'] ?? data['contractor'] ?? 'None')
        : 'Self';
        
    final category = isWorker 
        ? (data['category'] ?? data['workerType'] ?? 'Uncategorized')
        : 'Sub Contractor';
        
    final isSelected = selectedWorkerIds.contains(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Row(
            children: [
              Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.black87))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isWorker ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isWorker ? 'Worker' : 'Sub',
                  style: TextStyle(color: isWorker ? Colors.blue.shade700 : Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text('$category • Sub: $subContractor', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          trailing: isSelected
              ? Icon(isMultiSelectMode ? Icons.check_box_rounded : Icons.check_circle, color: primaryColor)
              : Icon(isMultiSelectMode ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked, color: Colors.grey),
          onLongPress: () {
            _toggleWorkerSelection(doc);
          },
          onTap: () {
            if (isMultiSelectMode) {
              _toggleWorkerSelection(doc);
            } else {
              setState(() {
                selectedWorker = doc;
                selectedWorkerIds = {doc.id};
                selectedWorkerDocs = {doc.id: doc};
              });
              _recalculateOtHours();
            }
          },
        ),
      ),
    );
  }

  Widget _buildNewWorkerForm() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Worker Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(controller: workerNameController, label: 'Worker Name'),
            const SizedBox(height: 12),
            _buildTextField(controller: mobileController, label: 'Mobile Number', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildTextField(controller: aadhaarController, label: 'Aadhaar Number (Optional)'),
            const SizedBox(height: 12),
            _isLoadingLabours
                ? const Center(child: CircularProgressIndicator())
                : _buildDropdown(
                    value: selectedCategory,
                    items: _labours.map((l) => l['designation'].toString()).toList(),
                    label: 'Category',
                    onChanged: (v) {
                      setState(() => selectedCategory = v!);
                      _recalculateOtHours();
                    },
                  ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: (() {
                final names = contractors.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['contractorName'] ?? data['name'])?.toString();
                }).whereType<String>().toList();
                return (selectedContractor != null && names.contains(selectedContractor)) ? selectedContractor : null;
              })(),
              items: contractors.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['contractorName'] ?? data['name'] ?? 'Unknown').toString();
              }).toList(),
              label: 'Sub-Contractor',
              onChanged: (v) => setState(() => selectedContractor = v),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: selectedLabourType,
              items: labourTypes,
              label: 'Labour Type',
              onChanged: (v) => setState(() => selectedLabourType = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceDetails() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance & Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDropdown(
              value: selectedAttendanceType,
              items: attendanceTypes,
              label: 'Attendance Type',
              onChanged: (v) => setState(() => selectedAttendanceType = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField(controller: inTimeController, label: 'In Time', icon: Icons.access_time, readOnly: true, onTap: () => _selectTime(context, inTimeController))),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(controller: outTimeController, label: 'Out Time', icon: Icons.access_time, readOnly: true, onTap: () => _selectTime(context, outTimeController))),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(controller: otHoursController, label: 'OT Hours', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _buildTextField(controller: remarksController, label: 'Remarks (Optional)', maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        suffixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    final sortedItems = List<String>.from(items.toSet())
      ..sort((a, b) => a.trim().toLowerCase().compareTo(b.trim().toLowerCase()));

    return CustomDropdown<String>(
      value: value,
      hintText: label,
      mainColor: primaryColor,
      items: sortedItems.map((t) {
        return DropdownMenuItem<String>(
          value: t,
          child: Text(t, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
