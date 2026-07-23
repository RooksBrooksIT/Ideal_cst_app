import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ProjectStageConfig extends StatefulWidget {
  const ProjectStageConfig({super.key});

  @override
  State<ProjectStageConfig> createState() => _ProjectStageConfigState();
}

class _ProjectStageConfigState extends State<ProjectStageConfig> {
  final Color primaryColor = ManagerTheme.primaryColor;
  final TextEditingController _stageController = TextEditingController();
  final FocusNode _stageFocusNode = FocusNode();
  String? _selectedStage;

  Future<void> _addStageToFirestore(String stage) async {
    try {
      await FirebaseFirestore.instance.collection('projectStages').add({
        'projectStage': stage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage added successfully!')),
      );
      setState(() {
        _selectedStage = stage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding stage: $e')),
      );
    }
  }

  void _showAddStageDialog() {
    _stageController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Project Stage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: TextField(
            controller: _stageController,
            focusNode: _stageFocusNode,
            decoration: InputDecoration(
              hintText: 'Enter stage name',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            autofocus: true,
          ),
          actions: [
            ManagerTheme.buildDialogCancelButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
            ),
            ManagerTheme.buildDialogButton(
              label: 'Add',
              onPressed: () {
                final name = _stageController.text.trim();
                if (name.isNotEmpty) {
                  _addStageToFirestore(name);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStageFromFirestore(String stage) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .where('projectStage', isEqualTo: stage)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage deleted successfully!')),
      );

      setState(() {
        _selectedStage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting stage: $e')),
      );
    }
  }

  void _confirmDeleteStage() {
    if (_selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a stage to delete')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Stage', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "$_selectedStage"?'),
          actions: [
            ManagerTheme.buildDialogCancelButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
            ),
            ManagerTheme.buildDialogButton(
              label: 'Delete',
              backgroundColor: Colors.red[700],
              onPressed: () {
                Navigator.of(context).pop();
                _deleteStageFromFirestore(_selectedStage!);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _stageController.dispose();
    _stageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 218, 238, 220),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildStageCard(context),
                    const SizedBox(height: 20),
                    _buildExistingStagesSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Project Configuration',
      title: 'Project Stage Setup',
    );
  }

  Widget _buildStageCard(BuildContext context) {
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
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.flag_rounded, color: Colors.red, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Project Stage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select or define project stage benchmarks',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Stage',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projectStages')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final uniqueStages = <String>{};
                    final dropdownItems = <DropdownMenuItem<String>>[];

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['projectStage']?.toString() ?? '';
                      if (name.isNotEmpty && uniqueStages.add(name)) {
                        dropdownItems.add(
                          DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                    }

                    String? safeSelectedStage =
                        (_selectedStage != null && uniqueStages.contains(_selectedStage))
                            ? _selectedStage
                            : null;

                    return CustomDropdown<String>(
                      value: safeSelectedStage,
                      hintText: 'Select project stage',
                      items: dropdownItems,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStage = newValue;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _showAddStageDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
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
          if (_selectedStage != null) ...[
            const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ManagerTheme.buildPrimaryButton(
                  label: 'Delete Selected Stage',
                  icon: Icons.delete_outline,
                  color: Colors.red[700],
                  onPressed: _confirmDeleteStage,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingStagesSection(BuildContext context) {
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
              Icon(Icons.flag, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Existing Project Stages',
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
            stream: FirebaseFirestore.instance.collection('projectStages').snapshots(),
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
                      'No project stages added yet.',
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
                  final name = data['projectStage']?.toString() ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.red, size: 18),
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
