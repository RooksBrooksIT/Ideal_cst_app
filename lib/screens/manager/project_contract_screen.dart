import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ProjectContractScreen extends StatefulWidget {
  const ProjectContractScreen({super.key});

  @override
  _ProjectContractScreenState createState() => _ProjectContractScreenState();
}

class _ProjectContractScreenState extends State<ProjectContractScreen> {
  // Constants for styling
  static const double _cardCornerRadius = 28.0;
  static const double _elementPadding = 24.0;
  static const Color _primaryColor = ManagerTheme.primaryColor;
  static const Color _secondaryColor = Colors.white;
  static const Color _errorColor = Colors.redAccent;
  static const Color _successColor = Colors.green;

  final TextEditingController _newContractTypeController =
      TextEditingController();

  String? _selectedContractType;
  List<String> _contractTypes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchContractTypes();
    });
  }

  @override
  void dispose() {
    _newContractTypeController.dispose();
    super.dispose();
  }

  /// Fetch all contract types from Firestore
  Future<void> _fetchContractTypes() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('projectContracts').get();
      if (!mounted) return;
      setState(() {
        _contractTypes = querySnapshot.docs
            .map((doc) => doc['projectContract'] as String)
            .toSet()
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          message: 'Failed to fetch contract types: ${e.toString()}',
          isError: true);
    }
  }

  /// Get Firestore Doc ID from contract type
  Future<String?> _getContractTypeDocId(String contractType) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('projectContracts')
          .where('projectContract', isEqualTo: contractType)
          .limit(1)
          .get();
      if (!mounted) return null;
      return querySnapshot.docs.isEmpty ? null : querySnapshot.docs.first.id;
    } catch (e) {
      if (!mounted) return null;
      _showSnackBar(
          message: 'Error locating contract: ${e.toString()}', isError: true);
      return null;
    }
  }

  /// Delete selected contract type with confirmation
  Future<void> _deleteSelectedContractType() async {
    if (_selectedContractType == null) {
      if (!mounted) return;
      _showSnackBar(
        message: 'Please select a contract type to delete',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to permanently delete the contract type '
          '"${_selectedContractType!}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'DELETE',
              style: TextStyle(color: _errorColor),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final docId = await _getContractTypeDocId(_selectedContractType!);
      if (!mounted) return; // Check again as getContractTypeDocId is async
      if (docId == null) {
        _showSnackBar(
            message: 'Contract type not found in database', isError: true);
        return;
      }

      await FirebaseFirestore.instance
          .collection('projectContracts')
          .doc(docId)
          .delete();

      if (!mounted) return;
      await _fetchContractTypes();
      if (!mounted) return;

      setState(() => _selectedContractType = null);
      _showSnackBar(
          message: 'Contract type deleted successfully', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(message: 'Deletion failed: ${e.toString()}', isError: true);
    }
  }

  /// Snackbar helper
  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show dialog to add a new contract type
  void _showAddContractTypeModal() {
    _newContractTypeController.clear();
    bool isDuplicate = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_elementPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Contract Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newContractTypeController,
                      decoration: InputDecoration(
                        labelText: 'Contract Type Name',
                        labelStyle: TextStyle(
                          color: _primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          isDuplicate = _contractTypes
                              .map((type) => type.toLowerCase())
                              .contains(value.trim().toLowerCase());
                        });
                      },
                    ),
                    if (isDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'This contract type already exists',
                          style: TextStyle(
                            color: _errorColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                        ManagerTheme.buildDialogCancelButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        ManagerTheme.buildDialogButton(
                          label: 'SAVE',
                          icon: Icons.save,
                          backgroundColor: isDuplicate ? Colors.grey : null,
                          onPressed: isDuplicate
                              ? null
                              : () async {
                                  final newType =
                                      _newContractTypeController.text.trim();
                                  if (newType.isEmpty) return;

                                  try {
                                    final querySnapshot =
                                        await FirebaseFirestore.instance
                                            .collection('projectContracts')
                                            .get();

                                    if (!mounted) return;

                                    int maxId = querySnapshot.docs.fold(0,
                                        (prev, doc) {
                                      final docId = doc.id;
                                      if (docId.startsWith('CT')) {
                                        final idNumber = int.tryParse(
                                                docId.substring(2)) ??
                                            0;
                                        return idNumber > prev
                                            ? idNumber
                                            : prev;
                                      }
                                      return prev;
                                    });

                                    final newDocId =
                                        'CT${(maxId + 1).toString().padLeft(3, '0')}';

                                    await FirebaseFirestore.instance
                                        .collection('projectContracts')
                                        .doc(newDocId)
                                        .set({'projectContract': newType});

                                    if (!mounted) return;

                                    Navigator.of(context).pop();
                                    await _fetchContractTypes();
                                    if (!mounted) return;
                                    setState(() =>
                                        _selectedContractType = newType);

                                    _showSnackBar(
                                        message:
                                            'Contract type added successfully',
                                        isError: false);
                                  } catch (e) {
                                    if (!mounted) return;
                                    _showSnackBar(
                                        message: 'Failed to add: $e',
                                        isError: true);
                                  }
                                },
                        ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Project Configuration',
      title: 'Contract Type Setup',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 218, 238, 220),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildContractSelectionSection(context),
              const SizedBox(height: 20),
              _buildExistingContractsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractSelectionSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomDropdown<String>(
                  value: _selectedContractType,
                  labelText: 'Select Contract Type',
                  prefixIcon: Icons.assignment,
                  items: _contractTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedContractType = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _showAddContractTypeModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (_selectedContractType != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _deleteSelectedContractType,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text(
                  'Delete Selected Contract Type',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingContractsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: _primaryColor, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Existing Contract Types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('projectContracts').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No contract types added yet.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['projectContract']?.toString() ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment, color: _primaryColor, size: 18),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
