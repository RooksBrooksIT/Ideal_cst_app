import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/models/sub_contractor.dart';
import 'package:ideal_cst/services/workforce_service.dart';
import 'package:ideal_cst/screens/supervisor/sub_contractor_workers_screen.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

final WorkforceService _workforceService = WorkforceService();

class WorkersManagementScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const WorkersManagementScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<WorkersManagementScreen> createState() => _WorkersManagementScreenState();
}

class _WorkersManagementScreenState extends State<WorkersManagementScreen> {
  final Color primaryColor = const Color(0xFF4527A0);
  bool isLoading = true;
  List<Map<String, dynamic>> sites = [];

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

  void _showAddEditSubContractorDialog([SubContractor? contractor]) {
    showDialog(
      context: context,
      builder: (context) => _WorkersManagementFormDialog(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        sites: sites,
        contractor: contractor,
      ),
    );
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
                child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Workers',
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
        InkWell(
          onTap: () => _showAddEditSubContractorDialog(),
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
      backgroundColor: const Color.fromARGB(255, 213, 207, 232), // Light primary color background matching dashboard
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'All Sub Contractors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<SubContractor>>(
                        stream: _workforceService.getSubContractorsBySupervisor(
                          widget.supervisorId,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                "Error loading contractors: ${snapshot.error}",
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.engineering_outlined, size: 80, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Sub Contractors Yet',
                                    style: TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to add a new sub contractor',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            );
                          }
                          final contractors = List<SubContractor>.from(snapshot.data!)
                            ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
                          return ListView.builder(
                            itemCount: contractors.length,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemBuilder: (context, index) {
                              final contractor = contractors[index];
                              return _buildModernContractorCard(contractor);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernContractorCard(SubContractor contractor) {
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
                builder: (context) => SubContractorWorkersScreen(
                  subContractor: contractor,
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.handyman, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractor.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E1E2D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              contractor.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showAddEditSubContractorDialog(contractor);
                            break;
                          case 'delete':
                            _showDeleteConfirmationDialog(contractor.id!);
                            break;
                          case 'toggle_status':
                            _toggleContractorStatus(contractor);
                            break;
                        }
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Text(contractor.isActive ? 'Deactivate account' : 'Activate account'),
                        ),
                        const PopupMenuItem(
                          value: 'delete', 
                          child: Text('Delete account', style: TextStyle(color: Colors.red)),
                        ),
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
                      _buildInfoChip(Icons.phone, contractor.mobileNumber),
                      _buildInfoChip(Icons.location_city, '${contractor.assignedSiteIds.length} Sites'),
                      _buildInfoChip(
                        Icons.circle,
                        contractor.isActive ? 'Active' : 'Inactive',
                        color: contractor.isActive ? Colors.green : Colors.red,
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

  Future<void> _toggleContractorStatus(SubContractor contractor) async {
    final updated = SubContractor(
      id: contractor.id,
      name: contractor.name,
      contractorId: contractor.contractorId,
      category: contractor.category,
      mobileNumber: contractor.mobileNumber,
      address: contractor.address,
      labourType: contractor.labourType,
      salaryType: contractor.salaryType,
      salaryRate: contractor.salaryRate,
      overtimeRate: contractor.overtimeRate,
      assignedSiteIds: contractor.assignedSiteIds,
      isActive: !contractor.isActive,
      joiningDate: contractor.joiningDate,
      notes: contractor.notes,
      supervisorId: contractor.supervisorId,
      supervisorName: contractor.supervisorName,
    );
    await _workforceService.updateSubContractor(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sub Contractor ${!updated.isActive ? "Deactivated" : "Activated"}',
          ),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Sub Contractor?'),
        content: const Text(
          'Are you sure you want to delete this sub contractor? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await _workforceService.deleteSubContractor(id);
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _WorkersManagementFormDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, dynamic>> sites;
  final SubContractor? contractor;

  const _WorkersManagementFormDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.sites,
    this.contractor,
  });

  @override
  State<_WorkersManagementFormDialog> createState() => _WorkersManagementFormDialogState();
}

class _WorkersManagementFormDialogState extends State<_WorkersManagementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _salaryRateController = TextEditingController();
  final TextEditingController _overtimeRateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Color primaryColor = const Color(0xFF4527A0);
  
  String? _selectedCategory;
  String _selectedSalaryType = 'Daily Wages';
  List<String> _selectedSiteIds = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingLabours = true;
  List<Map<String, dynamic>> _labours = [];

  @override
  void initState() {
    super.initState();
    _loadLabours();
    if (widget.contractor != null) {
      final c = widget.contractor!;
      _nameController.text = c.name;
      _mobileController.text = c.mobileNumber;
      _addressController.text = c.address ?? '';
      _salaryRateController.text = c.salaryRate.toString();
      _notesController.text = c.notes ?? '';
      _selectedCategory = c.category;
      _selectedSalaryType = c.salaryType;
      _selectedSiteIds = List.from(c.assignedSiteIds);
      _selectedDate = c.joiningDate;
      _overtimeRateController.text = c.overtimeRate.toString();
    } else {
      _overtimeRateController.text = '0.0';
    }
  }

  Future<void> _loadLabours() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('labours')
          .get();
      final laboursData = snapshot.docs
          .map(
            (doc) => {
              'designation': doc['designation'].toString(),
              'salary': doc['salary'],
            },
          )
          .toList();

      final uniqueDesignations = <String, dynamic>{};
      for (var labour in laboursData) {
        final designation = labour['designation'];
        if (!uniqueDesignations.containsKey(designation)) {
          uniqueDesignations[designation] = labour['salary'];
        }
      }

      final uniqueLabours = uniqueDesignations.entries
          .map((entry) => {'designation': entry.key, 'salary': entry.value})
          .toList()
        ..sort((a, b) => (a['designation'] ?? '').toString().trim().toLowerCase().compareTo((b['designation'] ?? '').toString().trim().toLowerCase()));

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

  void _onCategoryChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _selectedCategory = newValue;
        final selectedLabour = _labours.firstWhere(
          (labour) => labour['designation'] == newValue,
          orElse: () => {'salary': 0},
        );
        final salaryValue = selectedLabour['salary'];
        final salaryStr = salaryValue is num
            ? salaryValue.toString()
            : salaryValue.toString();
        _salaryRateController.text = salaryStr;
      });
    }
  }
  
  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
                  widget.contractor == null ? 'Add Sub Contractor' : 'Edit Sub Contractor',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Contractor Name *'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: _buildInputDecoration('Address'),
                ),
                const SizedBox(height: 16),
                CustomDropdown<String>(
                  value: _selectedSalaryType,
                  hintText: 'Group *',
                  mainColor: primaryColor,
                  items: const ['Daily Wages', 'Sub Contract']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedSalaryType = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _salaryRateController,
                        readOnly: true,
                        decoration: _buildInputDecoration('Salary Rate (Auto)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _overtimeRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _buildInputDecoration('OT Rate/hr *'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Assigned Sites', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.sites.map((site) {
                    final isSelected = _selectedSiteIds.contains(site['id']);
                    final siteName = site['siteName'] ?? site['Site Name'] ?? site['id'];
                    return FilterChip(
                      label: Text(siteName, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
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
                      selectedColor: primaryColor,
                      backgroundColor: Colors.grey.shade100,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: primaryColor),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Joining Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                        Icon(Icons.calendar_today, size: 18, color: primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: _buildInputDecoration('Notes'),
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
                      onPressed: _saveContractor,
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

  Future<void> _saveContractor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final mobileNumber = _mobileController.text.trim();
    final duplicateQuery = await FirebaseFirestore.instance
        .collection('sub_contractors')
        .where('mobileNumber', isEqualTo: mobileNumber)
        .get();
        
    bool isDuplicate = false;
    for (var doc in duplicateQuery.docs) {
      if (widget.contractor == null || doc.id != widget.contractor!.id) {
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
          const SnackBar(content: Text('A sub contractor with this mobile number already exists!')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sub Contractor Creation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(widget.contractor == null 
            ? 'Are you sure you want to add this sub contractor?' 
            : 'Are you sure you want to update this sub contractor?'),
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

    final contractorId = widget.contractor != null
        ? widget.contractor!.contractorId
        : await _workforceService.generateSubContractorId();

    final newContractor = SubContractor(
      id: widget.contractor?.id,
      name: _nameController.text.trim(),
      contractorId: contractorId,
      category: _selectedCategory!,
      mobileNumber: _mobileController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      labourType: SubContractor.normaliseLabourType(_selectedSalaryType),
      salaryType: _selectedSalaryType,
      salaryRate: double.tryParse(_salaryRateController.text) ?? 0.0,
      overtimeRate: double.tryParse(_overtimeRateController.text) ?? 0.0,
      assignedSiteIds: List.from(_selectedSiteIds),
      isActive: true,
      joiningDate: _selectedDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
    );

    if (widget.contractor == null) {
      await _workforceService.createSubContractor(newContractor);
    } else {
      await _workforceService.updateSubContractor(newContractor);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub Contractor saved successfully!')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _salaryRateController.dispose();
    _overtimeRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
