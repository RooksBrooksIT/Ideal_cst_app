import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sub_contractor.dart';
import '../models/worker.dart';
import '../services/workforce_service.dart';
import 'supervisor/sub_contractor_workers_screen.dart';

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
      appBar: AppBar(
        title: const Text(
          "Sub Contractor Management",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showAddEditSubContractorDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.85),
              primaryColor.withOpacity(0.55),
            ],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : StreamBuilder<List<SubContractor>>(
                stream: _workforceService.getSubContractorsBySupervisor(
                  widget.supervisorId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error loading contractors: ${snapshot.error}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No Sub Contractors yet',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  final contractors = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contractors.length,
                    itemBuilder: (context, index) {
                      final contractor = contractors[index];
                      final normType = SubContractor.normaliseLabourType(contractor.labourType);
                      final isDailyWage = normType == 'Daily Wages';
                      final typeBgColor = isDailyWage ? const Color(0xFFE3F2FD) : const Color(0xFFF3E5F5);
                      final typeFgColor = isDailyWage ? const Color(0xFF1565C0) : const Color(0xFF7B1FA2);
                      final typeBorderColor = isDailyWage ? const Color(0xFF90CAF9) : const Color(0xFFCE93D8);
                      final displayTypeLabel = isDailyWage ? 'Daily Wage' : 'Sub Contractor';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: typeBorderColor, width: 1),
                        ),
                        elevation: 4,
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SubContractorWorkersScreen(
                                      subContractor: contractor,
                                      supervisorId: widget.supervisorId,
                                      supervisorName: widget.supervisorName,
                                    ),
                              ),
                            );
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: typeBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isDailyWage ? Icons.payments_outlined : Icons.engineering, color: typeFgColor),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${contractor.name} (${contractor.contractorId})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: typeBorderColor, width: 0.8),
                                ),
                                child: Text(
                                  displayTypeLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeFgColor),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(contractor.category),
                              Text('Mobile: ${contractor.mobileNumber}'),
                              Text(
                                'Assigned Sites: ${contractor.assignedSiteIds.length}',
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
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
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle_status',
                                child: Text(
                                  contractor.isActive
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSubContractorDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
  final TextEditingController _notesController = TextEditingController();
  String? _selectedCategory;
  String _selectedGroup = 'Daily Wages';
  List<String> _selectedSiteIds = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingLabours = true;
  List<Map<String, dynamic>> _labours = [];
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

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
      _selectedGroup = _normaliseLabourType(c.labourType);
      _selectedSiteIds = List.from(c.assignedSiteIds);
      _selectedDate = c.joiningDate;
    }
  }

  String _normaliseLabourType(String? value) {
    switch (value) {
      case 'Sub Contractor':
      case 'Sub Contract':
        return 'Sub Contractor';
      case 'Daily Wages':
      case 'Daily Wage':
        return 'Daily Wages';
      default:
        return 'Daily Wages';
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
        controller: _scrollController,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _errorMessage = null),
                        child: const Icon(Icons.close, color: Colors.red, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Contractor Name *',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a mobile number';
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                    return 'Mobile number must be exactly 10 digits';
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
                value: _selectedGroup,
                items: const ['Daily Wages', 'Sub Contractor']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedGroup = value!;
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

  void _setError(String message) {
    setState(() => _errorMessage = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _saveContractor() async {
    setState(() => _errorMessage = null);

    final name = _nameController.text.trim();
    final mobileNumber = _mobileController.text.trim();

    if (name.isEmpty) {
      _setError('Please enter Contractor Name.');
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      _setError('Please select a Category.');
      return;
    }

    if (mobileNumber.isEmpty) {
      _setError('Please enter Mobile Number.');
      return;
    }

    if (mobileNumber.length != 10 || !RegExp(r'^\d{10}$').hasMatch(mobileNumber)) {
      _setError('Mobile number must be exactly 10 digits.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _setError('Please fix the highlighted errors in the form.');
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
      labourType: _selectedGroup,
      salaryType: _selectedGroup,
      salaryRate: double.tryParse(_salaryRateController.text) ?? 0.0,
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
    _scrollController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _salaryRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
