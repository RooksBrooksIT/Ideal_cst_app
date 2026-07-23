import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class WorkersConfigPage extends StatefulWidget {
  final String? supervisorId;
  final String? supervisorName;
  final String? contractorId;
  final String? contractorName;

  const WorkersConfigPage({
    super.key,
    this.supervisorId,
    this.supervisorName,
    this.contractorId,
    this.contractorName,
  });

  @override
  _WorkersConfigPageState createState() => _WorkersConfigPageState();
}

class _WorkersConfigPageState extends State<WorkersConfigPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers for Create New Worker tab
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  String? _selectedDesignation;
  String? _selectedContractor;
  bool _isSalaryEditable = false;

  // Editing controllers for Workers List tab
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, bool> _isEditing = {};

  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _contractors = [];

  Stream<QuerySnapshot<Map<String, dynamic>>> get _contractorsStream {
    if (widget.supervisorId != null) {
      return _firestore
          .collection('contractors')
          .where('supervisorId', isEqualTo: widget.supervisorId)
          .snapshots();
    }
    if (widget.supervisorName != null) {
      return _firestore
          .collection('contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .snapshots();
    }
    return _firestore.collection('contractors').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _workersStream {
    Query query = _firestore.collection('workersConfig');
    if (widget.contractorId != null) {
      query = query.where('contractorId', isEqualTo: widget.contractorId);
    } else if (widget.supervisorId != null) {
      query = query.where('supervisorId', isEqualTo: widget.supervisorId);
    } else if (widget.supervisorName != null) {
      query = query.where('supervisorName', isEqualTo: widget.supervisorName);
    }
    return query.orderBy('workerId').snapshots()
        as Stream<QuerySnapshot<Map<String, dynamic>>>;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDesignations();
    _loadContractors();
    _joiningDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    // If contractorId/contractorName is provided, set selected contractor by default
    if (widget.contractorId != null || widget.contractorName != null) {
      setState(() {
        _selectedContractor = widget.contractorId;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _joiningDateController.dispose();
    _salaryController.dispose();
    // Dispose all editing controllers
    for (var controller in _editingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDesignations() async {
    try {
      final querySnapshot = await _firestore.collection('labours').get();
      setState(() {
        _designations = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'designation': data['designation'] ?? '',
            'salary': data['salary']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading designations: $e');
    }
  }

  Future<void> _loadContractors() async {
    try {
      final snapshot = await _contractorsStream.first;
      setState(() {
        _contractors = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'contractorId': doc.id,
            'contractorName':
                data['contractorName']?.split('_').first ?? doc.id,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading contractors: $e');
    }
  }

  Future<String> _getNextWorkerId() async {
    try {
      final querySnapshot = await _firestore
          .collection('workersConfig')
          .orderBy('workerId', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'WC001';
      }

      final lastWorker = querySnapshot.docs.first;
      final lastWorkerId = lastWorker['workerId'] as String? ?? 'WC000';

      // Extract number and increment
      final numberStr = lastWorkerId.replaceAll('WC', '');
      final nextNumber = int.parse(numberStr) + 1;

      return 'WC${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating worker ID: $e');
      return 'WC001';
    }
  }

  Future<void> _createWorker() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDesignation == null ||
        _salaryController.text.isEmpty ||
        (widget.contractorId == null && _selectedContractor == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final workerId = await _getNextWorkerId();

      // Find contractor name from contractorId
      String? contractorName = widget.contractorName;
      if (contractorName == null && _selectedContractor != null) {
        final contractorDoc = _contractors.firstWhere(
          (c) => c['contractorId'] == _selectedContractor,
          orElse: () => {},
        );
        contractorName = contractorDoc['contractorName'] as String?;
      }

      await _firestore.collection('workersConfig').doc(workerId).set({
        'workerId': workerId,
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'designation': _selectedDesignation,
        'salary': _salaryController.text,
        'joiningDate': _joiningDateController.text,
        'address': _addressController.text,
        'contractorId': widget.contractorId ?? _selectedContractor,
        'contractorName': contractorName,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _salaryController.clear();
      _joiningDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      setState(() {
        _selectedDesignation = null;
        _isSalaryEditable = false;
        if (widget.contractorId == null) {
          _selectedContractor = null;
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker created successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating worker: $e')));
    }
  }

  Future<void> _updateWorker(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await _firestore
          .collection('workersConfig')
          .doc(docId)
          .update(updatedData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating worker: $e')));
    }
  }

  Future<void> _deleteWorker(String docId) async {
    try {
      await _firestore.collection('workersConfig').doc(docId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting worker: $e')));
    }
  }

  void _startEditing(String docId, Map<String, dynamic> workerData) {
    setState(() {
      _isEditing[docId] = true;
      // Initialize editing controllers with current data
      _editingControllers['${docId}_name'] = TextEditingController(
        text: workerData['name'] ?? '',
      );
      _editingControllers['${docId}_phone'] = TextEditingController(
        text: workerData['phoneNumber'] ?? '',
      );
      _editingControllers['${docId}_address'] = TextEditingController(
        text: workerData['address'] ?? '',
      );
      _editingControllers['${docId}_joiningDate'] = TextEditingController(
        text: workerData['joiningDate'] ?? '',
      );
      _editingControllers['${docId}_salary'] = TextEditingController(
        text: workerData['salary']?.toString() ?? '',
      );
    });
  }

  void _cancelEditing(String docId) {
    setState(() {
      _isEditing[docId] = false;
      // Dispose editing controllers for this worker
      _editingControllers.remove('${docId}_name')?.dispose();
      _editingControllers.remove('${docId}_phone')?.dispose();
      _editingControllers.remove('${docId}_address')?.dispose();
      _editingControllers.remove('${docId}_joiningDate')?.dispose();
      _editingControllers.remove('${docId}_salary')?.dispose();
    });
  }

  void _saveEditing(String docId) {
    final updatedData = {
      'name': _editingControllers['${docId}_name']?.text ?? '',
      'phoneNumber': _editingControllers['${docId}_phone']?.text ?? '',
      'address': _editingControllers['${docId}_address']?.text ?? '',
      'joiningDate': _editingControllers['${docId}_joiningDate']?.text ?? '',
      'salary': _editingControllers['${docId}_salary']?.text ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _updateWorker(docId, updatedData);
    _cancelEditing(docId);
  }

  Future<void> _selectDate(BuildContext context, String docId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _editingControllers['${docId}_joiningDate']?.text = DateFormat(
          'yyyy-MM-dd',
        ).format(picked);
      });
    }
  }

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Worker Management',
      title: 'Workers Configuration',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 218, 238, 220),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _buildHeader(context),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: ManagerTheme.primaryColor,
                labelColor: ManagerTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(text: 'Create New Worker'),
                  Tab(text: 'Workers List'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Create New Worker Tab
                  _buildCreateWorkerTab(),
                  // Workers List Tab
                  _buildWorkersListTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateWorkerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Add New Worker',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ManagerTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextFieldWithIcon(
                    controller: _nameController,
                    labelText: 'Name *',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _phoneController,
                    labelText: 'Phone Number *',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  if (widget.contractorId == null)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: CustomDropdown<String>(
                          value: _selectedContractor,
                          labelText: 'Sub-Contractor *',
                          prefixIcon: Icons.person_outline,
                          items: _contractors.isNotEmpty
                              ? _contractors.map<DropdownMenuItem<String>>((
                                  contractor,
                                ) {
                                  final contractorId =
                                      contractor['id']?.toString() ?? '';
                                  final contractorName =
                                      contractor['name']?.toString() ??
                                      '';

                                  return DropdownMenuItem<String>(
                                    value: contractorId.isEmpty
                                        ? null
                                        : contractorId,
                                    child: Text(
                                      contractorName.isEmpty
                                          ? 'Unknown'
                                          : '$contractorName ($contractorId)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList()
                              : [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('No Contractors Available'),
                                  ),
                                ],
                          onChanged: (val) {
                            setState(() {
                              _selectedContractor = val;
                            });
                          },
                        ),
                      ),
                    ),
                  if (widget.contractorId != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contractor: ${widget.contractorName ?? widget.contractorId}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  CustomDropdown<String>(
                    value: _selectedDesignation,
                    labelText: 'Designation *',
                    prefixIcon: Icons.work,
                    items: _designations.isNotEmpty
                        ? _designations.map<DropdownMenuItem<String>>((
                            designation,
                          ) {
                            final designationValue =
                                designation['designation']?.toString() ??
                                '';
                            final salaryValue =
                                designation['salary']?.toString() ?? '';

                            return DropdownMenuItem<String>(
                              value: designationValue.isEmpty
                                  ? null
                                  : designationValue,
                              child: Text(designationValue),
                              onTap: () {
                                setState(() {
                                  _salaryController.text = salaryValue;
                                  _isSalaryEditable = false;
                                });
                              },
                            );
                          }).toList()
                        : [],
                    onChanged: (value) {
                      setState(() {
                        _selectedDesignation = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  _buildSalaryField(),
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _joiningDateController,
                    labelText: 'Joining Date',
                    icon: Icons.calendar_today,
                    isReadOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _joiningDateController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _addressController,
                    labelText: 'Address',
                    icon: Icons.location_on,
                    maxLines: 3,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createWorker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ManagerTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Create Worker',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _isSalaryEditable
              ? Colors.blue.shade300
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _salaryController,
              decoration: InputDecoration(
                labelText: 'Salary *',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                icon: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.attach_money, color: Colors.grey.shade600),
                ),
              ),
              keyboardType: TextInputType.number,
              readOnly: !_isSalaryEditable,
              style: TextStyle(
                color: _isSalaryEditable ? Colors.black : Colors.grey.shade700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isSalaryEditable ? Icons.lock_open : Icons.edit,
              color: _isSalaryEditable ? ManagerTheme.primaryColor : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isSalaryEditable = !_isSalaryEditable;
                if (_isSalaryEditable) {
                  // When enabling edit, ensure the field is focused
                  Future.delayed(Duration(milliseconds: 100), () {
                    FocusScope.of(context).requestFocus(FocusNode());
                    Future.delayed(Duration(milliseconds: 100), () {
                      // You might want to show keyboard here if needed
                    });
                  });
                }
              });
            },
            tooltip: _isSalaryEditable ? 'Lock salary field' : 'Edit salary',
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          icon: Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(icon, color: Colors.black),
          ),
        ),
        readOnly: isReadOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
      ),
    );
  }

  Widget _buildWorkersListTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _workersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final workers = snapshot.data!.docs;

        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No workers found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final doc = workers[index];
            final data = doc.data();
            final docId = doc.id;
            final workerId = data['workerId'] ?? docId;
            final isEditing = _isEditing[docId] ?? false;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Worker ID Header
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'ID: $workerId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      if (isEditing) _buildEditableFields(docId, data),
                      if (!isEditing) _buildReadOnlyFields(data),

                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isEditing) ...[
                            _buildActionButton(
                              icon: Icons.edit,
                              color: Colors.blue,
                              onPressed: () => _startEditing(docId, data),
                              label: 'Edit',
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              color: Colors.red,
                              onPressed: () => _showDeleteDialog(docId),
                              label: 'Delete',
                            ),
                          ],
                          if (isEditing) ...[
                            _buildActionButton(
                              icon: Icons.cancel,
                              color: Colors.grey,
                              onPressed: () => _cancelEditing(docId),
                              label: 'Cancel',
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.save,
                              color: Colors.green,
                              onPressed: () => _saveEditing(docId),
                              label: 'Save',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildReadOnlyFields(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                data['name'] ?? '',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildInfoRow(Icons.phone, data['phoneNumber'] ?? ''),
        _buildInfoRow(Icons.work, '${data['designation'] ?? ''}'),
        _buildInfoRow(Icons.attach_money, data['salary']?.toString() ?? ''),
        _buildInfoRow(Icons.calendar_today, data['joiningDate'] ?? ''),
        if (data['address'] != null && data['address'].isNotEmpty)
          _buildInfoRow(Icons.location_on, data['address'] ?? ''),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(String docId, Map<String, dynamic> data) {
    return Column(
      children: [
        _buildEditableField(
          controller: _editingControllers['${docId}_name']!,
          label: 'Name',
          icon: Icons.person,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_phone']!,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_joiningDate']!,
          label: 'Joining Date',
          icon: Icons.calendar_today,
          isReadOnly: true,
          onTap: () => _selectDate(context, docId),
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_salary']!,
          label: 'Salary',
          icon: Icons.attach_money,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_address']!,
          label: 'Address',
          icon: Icons.location_on,
          maxLines: 2,
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.work, size: 16, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Designation: ${data['designation'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 44, 88, 172)),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          icon: Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              icon,
              size: 18,
              color: const Color.fromARGB(255, 16, 54, 124),
            ),
          ),
        ),
        readOnly: isReadOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
      ),
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Delete Worker'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this worker? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteWorker(docId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
