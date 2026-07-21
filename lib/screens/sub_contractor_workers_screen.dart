import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sub_contractor.dart';
import '../models/worker.dart';
import '../models/worker_transfer.dart';
import '../services/workforce_service.dart';
import 'worker_details_screen.dart';
import 'daily_attendance_screen.dart';

final WorkforceService _workforceService = WorkforceService();

class SubContractorWorkersScreen extends StatefulWidget {
  final SubContractor subContractor;
  final String supervisorId;
  final String supervisorName;

  const SubContractorWorkersScreen({
    super.key,
    required this.subContractor,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _SubContractorWorkersScreenState createState() =>
      _SubContractorWorkersScreenState();
}

class _SubContractorWorkersScreenState
    extends State<SubContractorWorkersScreen> {
  final Color primaryColor = const Color(0xFF0b3470);
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<Map<String, dynamic>> sites = [];
  String searchQuery = '';
  String? selectedCategory;
  String? selectedStatus;
  String? selectedSiteId;
  String? selectedLabourType;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await loadSites();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadSites() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .where('Supervisor ID', isEqualTo: widget.supervisorId)
            .get();
      }
      setState(() {
        sites = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading sites: $e');
    }
  }

  void _showAddEditWorkerDialog([Worker? worker]) {
    showDialog(
      context: context,
      builder: (context) => _WorkerFormDialog(
        subContractor: widget.subContractor,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        sites: sites,
        worker: worker,
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FiltersBottomSheet(
        selectedCategory: selectedCategory,
        selectedStatus: selectedStatus,
        selectedSiteId: selectedSiteId,
        selectedLabourType: selectedLabourType,
        sites: sites,
        onApply: (category, status, siteId, labourType) {
          setState(() {
            selectedCategory = category;
            selectedStatus = status;
            selectedSiteId = siteId;
            selectedLabourType = labourType;
          });
        },
      ),
    );
  }

  void _showTransferWorkerDialog(Worker worker) {
    showDialog(
      context: context,
      builder: (context) => _TransferWorkerDialog(
        worker: worker,
        subContractor: widget.subContractor,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        sites: sites,
      ),
    );
  }

  String getSiteName(String siteId) {
    final site = sites.firstWhere(
      (s) => s['id'] == siteId,
      orElse: () => {'id': siteId, 'siteName': siteId},
    );
    return site['siteName'] ?? site['Site Name'] ?? siteId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Worker Management",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: Icon(Icons.calendar_today, color: Colors.blue.shade700),
              tooltip: 'Daily Attendance',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyAttendanceScreen(
                      supervisorId: widget.supervisorId,
                      supervisorName: widget.supervisorName,
                      sites: sites,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: Icon(Icons.filter_list, color: Colors.grey.shade700),
              tooltip: 'Filter',
              onPressed: _showFilters,
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // Sub Contractor Detail Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.engineering, color: primaryColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.subContractor.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${widget.subContractor.contractorId}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTopMetricChip(Icons.category, widget.subContractor.category, Colors.orange),
                            const SizedBox(width: 12),
                            StreamBuilder<List<Worker>>(
                              stream: _workforceService.getWorkersBySubContractor(widget.subContractor.id!),
                              builder: (context, snapshot) {
                                final count = snapshot.hasData ? snapshot.data!.length : 0;
                                return _buildTopMetricChip(Icons.people, '$count Workers', Colors.blue);
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildTopMetricChip(Icons.location_on, '${widget.subContractor.assignedSiteIds.length} Sites', Colors.teal),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search workers by name or ID...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                // Filter Tags
                if (selectedSiteId != null || selectedCategory != null || selectedStatus != null || selectedLabourType != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Filters: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                          if (selectedSiteId != null)
                            _buildFilterChip(getSiteName(selectedSiteId!), () { setState(() { selectedSiteId = null; }); }),
                          if (selectedCategory != null)
                            _buildFilterChip(selectedCategory!, () { setState(() { selectedCategory = null; }); }),
                          if (selectedStatus != null)
                            _buildFilterChip(selectedStatus!, () { setState(() { selectedStatus = null; }); }),
                          if (selectedLabourType != null)
                            _buildFilterChip(selectedLabourType!, () { setState(() { selectedLabourType = null; }); }),
                        ],
                      ),
                    ),
                  ),
                // Worker List
                Expanded(
                  child: StreamBuilder<List<Worker>>(
                    stream: _workforceService.getWorkersBySubContractor(widget.subContractor.id!),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error loading workers: ${snapshot.error}", style: TextStyle(color: Colors.red.shade700)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_off_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No workers yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            ],
                          ),
                        );
                      }
                      
                      final workers = snapshot.data!.where((worker) {
                        final matchesSearch = searchQuery.isEmpty ||
                            worker.name.toLowerCase().contains(searchQuery) ||
                            worker.workerId.toLowerCase().contains(searchQuery) ||
                            worker.mobileNumber.contains(searchQuery) ||
                            worker.workerType.toLowerCase().contains(searchQuery);

                        final matchesCategory = selectedCategory == null || worker.workerType == selectedCategory;
                        final matchesStatus = selectedStatus == null || (selectedStatus == 'Active' ? worker.isActive : !worker.isActive);
                        final matchesSite = selectedSiteId == null || worker.assignedSiteIds.contains(selectedSiteId);
                        final matchesLabourType = selectedLabourType == null || worker.labourType == selectedLabourType;

                        return matchesSearch && matchesCategory && matchesStatus && matchesSite && matchesLabourType;
                      }).toList();

                      if (workers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No matching workers found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: worker.photoUrl != null ? NetworkImage(worker.photoUrl!) : null,
                                child: worker.photoUrl == null ? Icon(Icons.person, color: Colors.blue.shade700) : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      worker.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                    ),
                                  ),
                                  if (worker.labourType.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: Text(worker.labourType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${worker.workerId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.category, size: 12, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text(worker.workerType, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        const SizedBox(width: 12),
                                        Icon(Icons.circle, size: 10, color: worker.isActive ? Colors.green : Colors.red),
                                        const SizedBox(width: 4),
                                        Text(worker.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'view':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => WorkerDetailsScreen(
                                            worker: worker,
                                            supervisorId: widget.supervisorId,
                                            supervisorName: widget.supervisorName,
                                          ),
                                        ),
                                      );
                                      break;
                                    case 'edit':
                                      _showAddEditWorkerDialog(worker);
                                      break;
                                    case 'delete':
                                      _showDeleteConfirmationDialog(worker.id!);
                                      break;
                                    case 'toggle_status':
                                      _toggleWorkerStatus(worker);
                                      break;
                                    case 'transfer':
                                      _showTransferWorkerDialog(worker);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'transfer', child: Text('Transfer')),
                                  PopupMenuItem(
                                    value: 'toggle_status',
                                    child: Text(worker.isActive ? 'Deactivate' : 'Activate'),
                                  ),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditWorkerDialog(),
        backgroundColor: primaryColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTopMetricChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: primaryColor)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: Icon(Icons.close, size: 14, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWorkerStatus(Worker worker) async {
    final updated = Worker(
      id: worker.id,
      name: worker.name,
      workerId: worker.workerId,
      workerType: worker.workerType,
      labourType: worker.labourType,
      basicSalary: worker.basicSalary,
      overtimeRate: worker.overtimeRate,
      mobileNumber: worker.mobileNumber,
      emergencyContact: worker.emergencyContact,
      aadharNumber: worker.aadharNumber,
      bankAccountDetails: worker.bankAccountDetails,
      joiningDate: worker.joiningDate,
      isActive: !worker.isActive,
      subContractorId: worker.subContractorId,
      subContractorName: worker.subContractorName,
      supervisorId: worker.supervisorId,
      supervisorName: worker.supervisorName,
      assignedSiteIds: worker.assignedSiteIds,
      photoUrl: worker.photoUrl,
      documentUrls: worker.documentUrls,
    );
    await _workforceService.updateWorker(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Worker ${!updated.isActive ? "Deactivated" : "Activated"}',
          ),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Worker?'),
        content: const Text(
          'Are you sure you want to delete this worker? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _workforceService.softDeleteWorker(
                id,
                widget.supervisorName,
              );
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _WorkerFormDialog extends StatefulWidget {
  final SubContractor subContractor;
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, dynamic>> sites;
  final Worker? worker;

  const _WorkerFormDialog({
    required this.subContractor,
    required this.supervisorId,
    required this.supervisorName,
    required this.sites,
    this.worker,
  });

  @override
  __WorkerFormDialogState createState() => __WorkerFormDialogState();
}

class __WorkerFormDialogState extends State<_WorkerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _basicSalaryController = TextEditingController();
  final TextEditingController _overtimeRateController = TextEditingController();
  final TextEditingController _defaultHoursController = TextEditingController();
  String? _selectedCategory;
  String _selectedLabourType = 'Daily Wage';
  List<String> _selectedSiteIds = [];
  DateTime _selectedDate = DateTime.now();
  bool _isActive = true;
  bool _isLoadingLabours = true;
  List<Map<String, dynamic>> _labours = [];

  @override
  void initState() {
    super.initState();
    _loadLabours();
    if (widget.worker != null) {
      final w = widget.worker!;
      _nameController.text = w.name;
      _mobileController.text = w.mobileNumber;
      _emergencyContactController.text = w.emergencyContact ?? '';
      _aadharController.text = w.aadharNumber ?? '';
      _basicSalaryController.text = w.basicSalary.toString();
      _overtimeRateController.text = w.overtimeRate.toString();
      _defaultHoursController.text = w.defaultHours.toString() ?? '8.0';
      _selectedCategory = w.workerType;
      _selectedLabourType = w.labourType;
      _selectedSiteIds = List.from(w.assignedSiteIds);
      _selectedDate = w.joiningDate;
      _isActive = w.isActive;
    }
  }

  Future<void> _loadLabours() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('labours')
          .get();
      final laboursData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'designation': (data['designation']?.toString()) ?? 'Uncategorized',
          'salary': data['salary'] ?? 0.0,
          'defaultHours': (data['defaultHours'] is num)
              ? (data['defaultHours'] as num).toDouble()
              : 8.0,
        };
      }).toList();

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

  void _onCategoryChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _selectedCategory = newValue;
        final selectedLabour = _labours.firstWhere(
          (labour) => labour['designation'] == newValue,
          orElse: () => {'salary': 0, 'defaultHours': 8.0},
        );
        final salaryValue = selectedLabour['salary'];
        final salaryStr = salaryValue is num
            ? salaryValue.toString()
            : salaryValue.toString();
        _basicSalaryController.text = salaryStr;
        final defaultHoursValue = selectedLabour['defaultHours'];
        final defaultHoursStr = defaultHoursValue is num
            ? defaultHoursValue.toString()
            : defaultHoursValue.toString();
        _defaultHoursController.text = defaultHoursStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.worker == null ? 'Add Worker' : 'Edit Worker'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Worker Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _isLoadingLabours
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      items: _labours.map<DropdownMenuItem<String>>((labour) {
                        return DropdownMenuItem(
                          value: labour['designation'],
                          child: Text(labour['designation']),
                        );
                      }).toList(),
                      onChanged: _onCategoryChanged,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aadharController,
                decoration: const InputDecoration(labelText: 'Aadhar Number'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedLabourType,
                items: const ['Daily Wage', 'Sub contract']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedLabourType = value!;
                }),
                decoration: const InputDecoration(labelText: 'Labour Type *'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select a labour type'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _basicSalaryController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Basic Salary (Auto-filled)',
                  suffixText: 'Auto',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defaultHoursController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Default Working Hours (Auto-filled)',
                  suffixText: 'hrs',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _overtimeRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Overtime Rate'),
              ),
              const SizedBox(height: 12),
              const Text('Assigned Sites'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.sites.map((site) {
                  final isSelected = _selectedSiteIds.contains(site['id']);
                  final siteName =
                      site['siteName'] ?? site['Site Name'] ?? site['id'];
                  return FilterChip(
                    label: Text(siteName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSiteIds.add(site['id']);
                        } else {
                          _selectedSiteIds.remove(site['id']);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF0b3470).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF0b3470),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Joining Date'),
                subtitle: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                activeThumbColor: const Color(0xFF0b3470),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _saveWorker(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0b3470),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveWorker() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSiteIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one site!')),
      );
      return;
    }

    final workerId = widget.worker != null
        ? widget.worker!.workerId
        : await _workforceService.generateWorkerId();

    final newWorker = Worker(
      id: widget.worker?.id,
      name: _nameController.text.trim(),
      workerId: workerId,
      workerType: _selectedCategory!,
      labourType: _selectedLabourType,
      basicSalary: double.tryParse(_basicSalaryController.text) ?? 0.0,
      overtimeRate: double.tryParse(_overtimeRateController.text) ?? 0.0,
      defaultHours: double.tryParse(_defaultHoursController.text) ?? 8.0,
      mobileNumber: _mobileController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      aadharNumber: _aadharController.text.trim().isEmpty
          ? null
          : _aadharController.text.trim(),
      bankAccountDetails: null,
      joiningDate: _selectedDate,
      isActive: _isActive,
      subContractorId: widget.subContractor.id,
      subContractorName: widget.subContractor.name,
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
      assignedSiteIds: List.from(_selectedSiteIds),
      photoUrl: widget.worker?.photoUrl,
      documentUrls: widget.worker?.documentUrls,
    );

    if (widget.worker == null) {
      await _workforceService.createWorker(newWorker);
    } else {
      await _workforceService.updateWorker(newWorker);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker saved successfully!')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emergencyContactController.dispose();
    _aadharController.dispose();
    _basicSalaryController.dispose();
    _overtimeRateController.dispose();
    super.dispose();
  }
}

class _FiltersBottomSheet extends StatefulWidget {
  final String? selectedCategory;
  final String? selectedStatus;
  final String? selectedSiteId;
  final String? selectedLabourType;
  final List<Map<String, dynamic>> sites;
  final Function(String?, String?, String?, String?) onApply;

  const _FiltersBottomSheet({
    this.selectedCategory,
    this.selectedStatus,
    this.selectedSiteId,
    this.selectedLabourType,
    required this.sites,
    required this.onApply,
  });

  @override
  __FiltersBottomSheetState createState() => __FiltersBottomSheetState();
}

class __FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedSiteId;
  String? _selectedLabourType;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedStatus = widget.selectedStatus;
    _selectedSiteId = widget.selectedSiteId;
    _selectedLabourType = widget.selectedLabourType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Categories')),
              DropdownMenuItem(value: 'Mason', child: Text('Mason')),
              DropdownMenuItem(value: 'Painter', child: Text('Painter')),
              DropdownMenuItem(value: 'Helper', child: Text('Helper')),
              DropdownMenuItem(
                value: 'Electrician',
                child: Text('Electrician'),
              ),
              DropdownMenuItem(value: 'Carpenter', child: Text('Carpenter')),
              DropdownMenuItem(value: 'Plumber', child: Text('Plumber')),
              DropdownMenuItem(value: 'Welder', child: Text('Welder')),
              DropdownMenuItem(value: 'Bar Bender', child: Text('Bar Bender')),
              DropdownMenuItem(value: 'Operator', child: Text('Operator')),
            ],
            onChanged: (value) => setState(() {
              _selectedCategory = value;
            }),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Statuses')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) => setState(() {
              _selectedStatus = value;
            }),
            decoration: const InputDecoration(labelText: 'Status'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedSiteId,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sites')),
              ...widget.sites.map((site) {
                final siteName =
                    site['siteName'] ?? site['Site Name'] ?? site['id'];
                return DropdownMenuItem(
                  value: site['id'],
                  child: Text(siteName),
                );
              }),
            ],
            onChanged: (value) => setState(() {
              _selectedSiteId = value;
            }),
            decoration: const InputDecoration(labelText: 'Site'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedLabourType,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Labour Types')),
              DropdownMenuItem(value: 'Daily Wage', child: Text('Daily Wage')),
              DropdownMenuItem(
                value: 'Sub contract',
                child: Text('Sub Contract'),
              ),
            ],
            onChanged: (value) => setState(() {
              _selectedLabourType = value;
            }),
            decoration: const InputDecoration(labelText: 'Labour Type'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _selectedStatus = null;
                      _selectedSiteId = null;
                      _selectedLabourType = null;
                    });
                    widget.onApply(null, null, null, null);
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _selectedCategory,
                      _selectedStatus,
                      _selectedSiteId,
                      _selectedLabourType,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0b3470),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransferWorkerDialog extends StatefulWidget {
  final Worker worker;
  final SubContractor subContractor;
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, dynamic>> sites;

  const _TransferWorkerDialog({
    required this.worker,
    required this.subContractor,
    required this.supervisorId,
    required this.supervisorName,
    required this.sites,
  });

  @override
  __TransferWorkerDialogState createState() => __TransferWorkerDialogState();
}

class __TransferWorkerDialogState extends State<_TransferWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _selectedSiteId;
  String? _selectedSubContractorId;
  List<SubContractor> _subContractors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubContractors();
  }

  Future<void> _loadSubContractors() async {
    try {
      final snapshot = await _workforceService
          .getSubContractorsBySupervisor(widget.supervisorId)
          .first;
      setState(() {
        _subContractors = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sub contractors: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getSiteName(String siteId) {
    final site = widget.sites.firstWhere(
      (s) => s['id'] == siteId,
      orElse: () => {'id': siteId, 'siteName': siteId},
    );
    return site['siteName'] ?? site['Site Name'] ?? siteId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Worker'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current: ${widget.worker.name}'),
                    const SizedBox(height: 16),
                    Text(
                      'From: ${widget.subContractor.name} (${widget.worker.assignedSiteIds.map(_getSiteName).join(', ')})',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedSubContractorId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Select Sub Contractor'),
                        ),
                        ..._subContractors.map((sc) {
                          return DropdownMenuItem(
                            value: sc.id,
                            child: Text(
                              '${sc.name} (${sc.contractorId})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedSubContractorId = value;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'To Sub Contractor',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedSiteId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Select Site'),
                        ),
                        ...widget.sites.map((site) {
                          final siteName =
                              site['siteName'] ??
                              site['Site Name'] ??
                              site['id'];
                          return DropdownMenuItem(
                            value: site['id'],
                            child: Text(
                              siteName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedSiteId = value;
                      }),
                      decoration: const InputDecoration(labelText: 'To Site'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_selectedSubContractorId == null || _selectedSiteId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select sub contractor and site'),
                ),
              );
              return;
            }
            final targetSubContractor = _subContractors.firstWhere(
              (sc) => sc.id == _selectedSubContractorId,
            );
            final transfer = WorkerTransfer(
              workerId: widget.worker.workerId,
              workerName: widget.worker.name,
              fromSiteId: widget.worker.assignedSiteIds.isNotEmpty
                  ? widget.worker.assignedSiteIds.first
                  : '',
              fromSiteName: widget.worker.assignedSiteIds.isNotEmpty
                  ? _getSiteName(widget.worker.assignedSiteIds.first)
                  : 'N/A',
              fromSubContractorId: widget.worker.subContractorId,
              fromSubContractorName: widget.worker.subContractorName,
              toSiteId: _selectedSiteId!,
              toSiteName: _getSiteName(_selectedSiteId!),
              toSubContractorId: targetSubContractor.id,
              toSubContractorName: targetSubContractor.name,
              transferDate: DateTime.now(),
              reason: _reasonController.text,
              approvedBy: widget.supervisorName,
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
            );
            await _workforceService.createWorkerTransfer(transfer);
            // Update worker's details
            final updatedWorker = Worker(
              id: widget.worker.id,
              name: widget.worker.name,
              workerId: widget.worker.workerId,
              workerType: widget.worker.workerType,
              labourType: widget.worker.labourType,
              basicSalary: widget.worker.basicSalary,
              overtimeRate: widget.worker.overtimeRate,
              mobileNumber: widget.worker.mobileNumber,
              emergencyContact: widget.worker.emergencyContact,
              aadharNumber: widget.worker.aadharNumber,
              bankAccountDetails: widget.worker.bankAccountDetails,
              joiningDate: widget.worker.joiningDate,
              isActive: widget.worker.isActive,
              subContractorId: targetSubContractor.id,
              subContractorName: targetSubContractor.name,
              supervisorId: widget.supervisorId,
              supervisorName: widget.supervisorName,
              assignedSiteIds: [_selectedSiteId!],
              photoUrl: widget.worker.photoUrl,
              documentUrls: widget.worker.documentUrls,
            );
            await _workforceService.updateWorker(updatedWorker);
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Worker transferred successfully'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0b3470),
          ),
          child: const Text('Transfer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
