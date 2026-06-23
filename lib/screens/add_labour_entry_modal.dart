import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddLabourEntryModal extends StatefulWidget {
  final String siteId;
  final String supervisorId;
  final String supervisorName;
  final Function(Map<String, dynamic>) onWorkerAdded;

  const AddLabourEntryModal({
    super.key,
    required this.siteId,
    required this.supervisorId,
    required this.supervisorName,
    required this.onWorkerAdded,
  });

  @override
  _AddLabourEntryModalState createState() => _AddLabourEntryModalState();
}

class _AddLabourEntryModalState extends State<AddLabourEntryModal> {
  final Color primaryColor = const Color(0xFF0b3470);
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
    searchController.addListener(filterWorkers);
  }

  Future<void> loadContractors() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .get();

      // If no results by name, try by supervisor ID
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('contractors')
            .where('supervisorId', isEqualTo: widget.supervisorId)
            .get();
      }

      setState(() {
        contractors = querySnapshot.docs;
        if (contractors.isNotEmpty) {
          final firstContractorData =
              contractors.first.data() as Map<String, dynamic>;
          selectedContractor = firstContractorData['contractorName'];
        }
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
        workers = querySnapshot.docs;
        filteredWorkers = workers;
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
        final name = data['workerName']?.toString().toLowerCase() ?? '';
        final mobile = data['mobile']?.toString().toLowerCase() ?? '';
        return name.contains(query) || mobile.contains(query);
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

  Future<void> addWorkerEntry() async {
    Map<String, dynamic>? workerData;
    DocumentSnapshot? selectedContractorDoc;
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
      if (workerNameController.text.isEmpty || mobileController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill required fields')),
        );
        return;
      }

      workerData = {
        'workerName': workerNameController.text,
        'mobile': mobileController.text,
        'aadhaar': aadhaarController.text,
        'category': selectedCategory,
        'contractorName': selectedContractor,
        'contractorId': selectedContractorDoc?.id,
        'supervisorName': widget.supervisorName,
        'supervisorId': widget.supervisorId,
        'labourType': selectedLabourType,
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
      workerData = {
        'workerId': selectedWorker!.id,
        'workerName': data['workerName'],
        'mobile': data['mobile'],
        'category': data['category'],
        'contractorName': data['contractorName'],
        'contractorId': data['contractorId'],
        'supervisorName': data['supervisorName'],
        'supervisorId': data['supervisorId'],
        'labourType': data['labourType'],
      };
    }

    final entry = {
      ...workerData!,
      'attendanceType': selectedAttendanceType,
      'inTime': inTimeController.text,
      'outTime': outTimeController.text,
      'otHours': double.tryParse(otHoursController.text) ?? 0.0,
      'dayValue': calculateDayValue(),
      'remarks': remarksController.text,
    };

    widget.onWorkerAdded(entry);
    if (mounted) Navigator.pop(context);
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
                        labelText: 'Search Worker',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: filteredWorkers.isEmpty
                          ? const Center(child: Text('No workers found'))
                          : ListView.builder(
                              itemCount: filteredWorkers.length,
                              itemBuilder: (context, index) {
                                final doc = filteredWorkers[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(data['workerName'] ?? 'Unknown'),
                                  subtitle: Text(
                                    '${data['category'] ?? ''} • ${data['contractor'] ?? ''}',
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
                                  },
                                );
                              },
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
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories.map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedContractor,
                      items: contractors.map<DropdownMenuItem<String>>((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: data['contractorName'] as String?,
                          child: Text(data['contractorName'] ?? 'Unknown'),
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
                    decoration: const InputDecoration(
                      labelText: 'In Time (e.g. 08:00 AM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: outTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Out Time (e.g. 05:00 PM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otHoursController,
                    keyboardType: TextInputType.number,
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
                      onPressed: addWorkerEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
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
