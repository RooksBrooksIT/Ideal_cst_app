import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sub_contractor.dart';
import '../models/worker.dart';
import '../services/workforce_service.dart';
import 'sub_contractor_workers_screen.dart';

final WorkforceService _workforceService = WorkforceService();

class SubContractorManagementScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SubContractorManagementScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _SubContractorManagementScreenState createState() =>
      _SubContractorManagementScreenState();
}

class _SubContractorManagementScreenState
    extends State<SubContractorManagementScreen> {
  final Color primaryColor = const Color(0xFF0b3470);
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
      builder: (context) => _SubContractorFormDialog(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        sites: sites,
        contractor: contractor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Sub Contractor Management",
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
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _showAddEditSubContractorDialog(),
              icon: Icon(Icons.add, color: primaryColor),
              tooltip: 'Add Sub Contractor',
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : StreamBuilder<List<SubContractor>>(
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
                        Icon(Icons.engineering_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No Sub Contractors Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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
                final contractors = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: contractors.length,
                  itemBuilder: (context, index) {
                    final contractor = contractors[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: InkWell(
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
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.handyman, color: Colors.blue.shade700, size: 28),
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
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          contractor.category,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
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
                                      const PopupMenuItem(value: 'delete', child: Text('Delete account', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
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
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
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
      salaryType: contractor.salaryType,
      salaryRate: contractor.salaryRate,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _workforceService.deleteSubContractor(id);
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SubContractorFormDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, dynamic>> sites;
  final SubContractor? contractor;

  const _SubContractorFormDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.sites,
    this.contractor,
  });

  @override
  __SubContractorFormDialogState createState() =>
      __SubContractorFormDialogState();
}

class __SubContractorFormDialogState extends State<_SubContractorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _salaryRateController = TextEditingController();
  final TextEditingController _overtimeRateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.contractor == null
            ? 'Add Sub Contractor'
            : 'Edit Sub Contractor',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Contractor Name *',
                ),
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
                      value: _selectedCategory,
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
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSalaryType,
                items: const ['Daily Wages', 'Sub Contract']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedSalaryType = value!;
                }),
                decoration: const InputDecoration(labelText: 'Group *'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryRateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Salary Rate (Auto-filled)',
                  suffixText: 'Auto',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _overtimeRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Overtime Rate (per Hour) *',
                  suffixText: '₹/hr',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an overtime rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
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
                    selectedColor: const Color(0xFF0b3470).withOpacity(0.2),
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
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
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
          onPressed: () => _saveContractor(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0b3470),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveContractor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
