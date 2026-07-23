import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/models/sub_contractor.dart';
import 'package:ideal_cst/models/worker.dart';
import 'package:ideal_cst/models/worker_transfer.dart';
import 'package:ideal_cst/services/workforce_service.dart';
import 'worker_details_screen.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';


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
  final Color primaryColor = const Color(0xFF4527A0);
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Workers for', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  widget.subContractor.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D), letterSpacing: -0.5),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: () => _showAddEditWorkerDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 213, 207, 232),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    // Metrics Row
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
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search workers by name or ID...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                      ),
                      onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                    ),
                    const SizedBox(height: 12),

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
                                  Icon(Icons.group_off_outlined, size: 80, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('No workers yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
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

                            return matchesSearch;
                          }).toList()
                            ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));

                          if (workers.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('No matching workers found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
                            itemCount: workers.length,
                            itemBuilder: (context, index) {
                              final worker = workers[index];
                              return _buildModernWorkerCard(worker);
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernWorkerCard(Worker worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
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
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: worker.photoUrl != null ? NetworkImage(worker.photoUrl!) : null,
                      child: worker.photoUrl == null ? Icon(Icons.person, color: primaryColor, size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E1E2D)),
                          ),
                          const SizedBox(height: 4),
                          Text('ID: ${worker.workerId}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text(worker.workerType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                              ),
                              const SizedBox(width: 8),
                              if (worker.labourType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text(worker.labourType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
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
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoChip(Icons.phone, worker.mobileNumber),
                      _buildInfoChip(Icons.business_center, worker.workerType),
                      _buildInfoChip(
                        Icons.circle,
                        worker.isActive ? 'Active' : 'Inactive',
                        color: worker.isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTopMetricChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
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
  final Color primaryColor = const Color(0xFF4527A0);
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
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

  InputDecoration _buildInputDecoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.worker == null ? 'Add Worker' : 'Edit Worker',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Worker Name *'),
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
                    : CustomDropdown<String>(
                        value: _selectedCategory,
                        hintText: 'Category *',
                        mainColor: primaryColor,
                        items: (_labours.map<String>((l) => l['designation'].toString()).toSet().toList()
                          ..sort((a, b) => a.trim().toLowerCase().compareTo(b.trim().toLowerCase())))
                            .map((designation) {
                          return DropdownMenuItem<String>(
                            value: designation,
                            child: Text(designation),
                          );
                        }).toList(),
                        onChanged: _onCategoryChanged,
                      ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration('Mobile Number *'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a mobile number';
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                      return 'Please enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyContactController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration('Emergency Contact'),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                        return 'Please enter a valid 10-digit number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomDropdown<String>(
                  value: _selectedLabourType,
                  hintText: 'Labour Type *',
                  mainColor: primaryColor,
                  items: const ['Daily Wage', 'Sub contract']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedLabourType = value!;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _basicSalaryController,
                  readOnly: true,
                  decoration: _buildInputDecoration('Basic Salary (Auto-filled)', suffixText: 'Auto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _defaultHoursController,
                  readOnly: true,
                  decoration: _buildInputDecoration('Default Working Hours (Auto-filled)', suffixText: 'hrs'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _overtimeRateController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Overtime Rate'),
                ),
                const SizedBox(height: 16),
                const Text('Assigned Sites', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
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
                      selectedColor: primaryColor.withValues(alpha: 0.15),
                      checkmarkColor: primaryColor,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Joining Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 20),
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
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Worker', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeColor: primaryColor,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveWorker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

    final mobileNumber = _mobileController.text.trim();
    final duplicateQuery = await FirebaseFirestore.instance
        .collection('workers')
        .where('mobileNumber', isEqualTo: mobileNumber)
        .get();
        
    bool isDuplicate = false;
    for (var doc in duplicateQuery.docs) {
      if (widget.worker == null || doc.id != widget.worker!.id) {
        final data = doc.data();
        if (data['isDeleted'] != true) {
           isDuplicate = true;
           break;
        }
      }
    }

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A worker with this mobile number already exists!')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Worker Creation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(widget.worker == null 
            ? 'Are you sure you want to add this worker?' 
            : 'Are you sure you want to update this worker?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
      aadharNumber: null,
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
