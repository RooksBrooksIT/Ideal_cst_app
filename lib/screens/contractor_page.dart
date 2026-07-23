import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'workers_config_page.dart';

class ContractorPage extends StatefulWidget {
  final String? supervisorId;
  final String? supervisorName;

  const ContractorPage({super.key, this.supervisorId, this.supervisorName});

  @override
  State<ContractorPage> createState() => _ContractorPageState();
}

class _ContractorPageState extends State<ContractorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedProjectField;
  String? _editingContractorId;
  List<String> _selectedSiteIds = [];
  bool _isSaving = false;

  static const Color primaryColor = Color(0xFF0b3470);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _contractorsStream {
    if (widget.supervisorId != null) {
      return FirebaseFirestore.instance
          .collection('contractors')
          .where('supervisorId', isEqualTo: widget.supervisorId)
          .orderBy('contractorId')
          .snapshots();
    }
    if (widget.supervisorName != null) {
      return FirebaseFirestore.instance
          .collection('contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .orderBy('contractorId')
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('contractors')
        .orderBy('contractorId')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _sitesStream {
    if (widget.supervisorId != null) {
      return FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .snapshots();
    }
    if (widget.supervisorName != null) {
      return FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('siteSupervisorMap')
        .snapshots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _numberController.clear();
    _addressController.clear();
    _selectedProjectField = null;
    _editingContractorId = null;
    _selectedSiteIds = [];
  }

  void _editContractor(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingContractorId = doc.id;
      _nameController.text = data['contractorName']?.split('_').first ?? '';
      _numberController.text = data['contactNo'] ?? '';
      _addressController.text = data['contactAddress'] ?? '';
      _selectedProjectField = data['contractorField'];
      _selectedSiteIds = List<String>.from(data['assignedSiteIds'] ?? []);
    });
  }

  Future<void> _deleteContractor(String contractorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contractor'),
        content: const Text('Are you sure you want to delete this contractor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contractor deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectField == null) return;

    setState(() => _isSaving = true);
    try {
      final supervisorId = widget.supervisorId;
      final supervisorName = widget.supervisorName;

      final data = {
        'contactAddress': _addressController.text.trim(),
        'contactNo': _numberController.text.trim(),
        'contractorField': _selectedProjectField!,
        'contractorName':
            '${_nameController.text.trim()}_${_selectedProjectField ?? ''}',
        'supervisorName': supervisorName,
        'supervisorId': supervisorId,
        'assignedSiteIds': _selectedSiteIds,
      };

      if (_editingContractorId != null) {
        await FirebaseFirestore.instance
            .collection('contractors')
            .doc(_editingContractorId)
            .update(data);
      } else {
        final contractorId = await _generateNextContractorId();
        data['contractorId'] = contractorId;
        await FirebaseFirestore.instance
            .collection('contractors')
            .doc(contractorId)
            .set(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingContractorId != null
                ? 'Contractor updated successfully'
                : 'Contractor added successfully',
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String> _generateNextContractorId() async {
    final snap = await FirebaseFirestore.instance
        .collection('contractors')
        .orderBy('contractorId', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 'CT001';
    final lastId = (snap.docs.first['contractorId'] as String?) ?? 'CT000';
    final numPart = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'CT${(numPart + 1).toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          _editingContractorId != null
              ? "Edit Contractor"
              : "Manage Sub-Contractors",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 3,
        shadowColor: Colors.black38,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Input form and buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Contractor illustration / avatar
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: primaryColor.withOpacity(0.15),
                      child: Icon(
                        Icons.engineering,
                        color: primaryColor,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProjectFieldDropdown(),
                    const SizedBox(height: 20),
                    _textField(
                      controller: _nameController,
                      label: "Contractor Name",
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Please enter name"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _textField(
                      controller: _numberController,
                      label: "Contact Number",
                      maxLength: 10,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter contractor number";
                        }
                        if (value.length != 10) {
                          return "Contact number must be 10 digits";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _textField(
                      controller: _addressController,
                      label: "Address",
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Please enter address"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildSiteMultiSelect(),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => _resetForm(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "Reset",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _onSavePressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 6,
                              shadowColor: primaryColor.withOpacity(0.6),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      _editingContractorId != null
                                          ? "Update"
                                          : "Save",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            // Section 2: Contractors table
            Text(
              "Your Sub-Contractors",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _contractorsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        'Error loading contractors',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: Text('No contractors found.')),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        primaryColor.withOpacity(0.12),
                      ),
                      headingTextStyle: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      columnSpacing: 24,
                      dataRowHeight: 64,
                      columns: const [
                        DataColumn(label: Text('S.No.')),
                        DataColumn(label: Text('Contractor Name')),
                        DataColumn(label: Text('Project Stage')),
                        DataColumn(label: Text('Assigned Sites')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: List<DataRow>.generate(docs.length, (index) {
                        final data = docs[index].data();
                        final siteIds = List<String>.from(
                          data['assignedSiteIds'] ?? [],
                        );
                        final contractorId = docs[index].id;
                        final contractorName =
                            (data['contractorName'] as String?)
                                ?.split('_')
                                .first ??
                            '';
                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(contractorName)),
                            DataCell(Text(data['contractorField'] ?? '')),
                            DataCell(
                              siteIds.isEmpty
                                  ? const Text(
                                      'None',
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  : Text(
                                      '${siteIds.length} site${siteIds.length > 1 ? 's' : ''}',
                                    ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.people,
                                      color: primaryColor,
                                    ),
                                    tooltip: 'Manage Workers',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              WorkersConfigPage(
                                                supervisorId:
                                                    widget.supervisorId,
                                                supervisorName:
                                                    widget.supervisorName,
                                                contractorId: contractorId,
                                                contractorName: contractorName,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _editContractor(docs[index]),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _deleteContractor(docs[index].id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
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

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryColor, width: 2.5),
        ),
      ),
    );
  }

  Widget _buildProjectFieldDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('projectStages')
          .orderBy('projectStage')
          .snapshots(),
      builder: (context, snapshot) {
        final stages =
            snapshot.data?.docs
                .map((d) => d.data()['projectStage'])
                .whereType<String>()
                .toSet()
                .toList() ??
            [];
        final currentValue = stages.contains(_selectedProjectField)
            ? _selectedProjectField
            : null;
        return DropdownButtonFormField<String>(
          value: currentValue,
          decoration: InputDecoration(
            labelText: "Project Stage",
            labelStyle: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: primaryColor, width: 2.5),
            ),
          ),
          items: stages
              .map(
                (stage) => DropdownMenuItem(value: stage, child: Text(stage)),
              )
              .toList(),
          onChanged: stages.isNotEmpty
              ? (v) => setState(() => _selectedProjectField = v)
              : null,
          validator: (v) => v == null ? "Please select a project stage" : null,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          dropdownColor: Colors.white,
        );
      },
    );
  }

  Widget _buildSiteMultiSelect() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sitesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        final siteDocs = snapshot.data?.docs ?? [];
        if (siteDocs.isEmpty) {
          return const Text('No sites available to assign');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign Sites',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: siteDocs.map((siteDoc) {
                final siteData = siteDoc.data();
                final siteId = siteDoc.id;
                final siteName =
                    siteData['siteName'] ?? siteData['Site Name'] ?? siteId;
                final isSelected = _selectedSiteIds.contains(siteId);
                return FilterChip(
                  label: Text(siteName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSiteIds.add(siteId);
                      } else {
                        _selectedSiteIds.remove(siteId);
                      }
                    });
                  },
                  selectedColor: primaryColor.withOpacity(0.2),
                  checkmarkColor: primaryColor,
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
