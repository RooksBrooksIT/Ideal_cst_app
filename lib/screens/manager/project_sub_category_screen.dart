import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ProjectSubCategoryScreen extends StatefulWidget {
  const ProjectSubCategoryScreen({super.key});

  @override
  State<ProjectSubCategoryScreen> createState() => _ProjectSubCategoryScreenState();
}

class _ProjectSubCategoryScreenState extends State<ProjectSubCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = ManagerTheme.primaryColor;
  final TextEditingController _subCategoryController = TextEditingController();
  final FocusNode _subCategoryFocusNode = FocusNode();
  String? _selectedSubCategory;

  Future<String> _getNextSubCategoryId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectSubCategories')
          .orderBy('subCategoryId', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'PSC001';
      } else {
        final lastId = snapshot.docs.first['subCategoryId'] as String;
        final numericPart = int.parse(lastId.replaceAll(RegExp(r'[^0-9]'), ''));
        final nextId = numericPart + 1;
        return 'PSC${nextId.toString().padLeft(3, '0')}';
      }
    } catch (e) {
      return 'PSC001';
    }
  }

  Future<void> _addSubCategoryToFirestore(String subCategory) async {
    try {
      final nextId = await _getNextSubCategoryId();
      await FirebaseFirestore.instance.collection('projectSubCategories').add({
        'subCategoryName': subCategory,
        'subCategoryId': nextId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub category added successfully!')),
      );
      setState(() {
        _selectedSubCategory = subCategory;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding sub category: $e')),
      );
    }
  }

  void _showAddSubCategoryDialog() {
    _subCategoryController.clear();
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
                'Add Sub Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: TextField(
            controller: _subCategoryController,
            focusNode: _subCategoryFocusNode,
            decoration: InputDecoration(
              hintText: 'Enter sub category name',
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
                final name = _subCategoryController.text.trim();
                if (name.isNotEmpty) {
                  _addSubCategoryToFirestore(name);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSubCategoryFromFirestore(String subCategory) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectSubCategories')
          .where('subCategoryName', isEqualTo: subCategory)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub category deleted successfully!')),
      );

      setState(() {
        _selectedSubCategory = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting sub category: $e')),
      );
    }
  }

  void _confirmDeleteSubCategory() {
    if (_selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sub category to delete')),
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
          title: const Text('Delete Sub Category', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "$_selectedSubCategory"?'),
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
                _deleteSubCategoryFromFirestore(_selectedSubCategory!);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _subCategoryController.dispose();
    _subCategoryFocusNode.dispose();
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
                    _buildSubCategoryCard(context),
                    const SizedBox(height: 20),
                    _buildExistingSubCategoriesSection(context),
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
      title: 'Sub Category Setup',
    );
  }

  Widget _buildSubCategoryCard(BuildContext context) {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.subtitles_rounded, color: primaryColor, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Sub Category Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E2D),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure your sub-category settings',
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
              'Select Sub Category',
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
                        .collection('projectSubCategories')
                        .orderBy('subCategoryId')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final uniqueSubCategories = <String>{};
                      final dropdownItems = <DropdownMenuItem<String>>[];

                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['subCategoryName']?.toString() ?? '';
                        if (name.isNotEmpty && uniqueSubCategories.add(name)) {
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

                      String? safeSelectedSubCategory =
                          (_selectedSubCategory != null &&
                                  uniqueSubCategories.contains(_selectedSubCategory))
                              ? _selectedSubCategory
                              : null;

                      return CustomDropdown<String>(
                        value: safeSelectedSubCategory,
                        hintText: 'Select sub category',
                        items: dropdownItems,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSubCategory = newValue;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _showAddSubCategoryDialog,
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
            if (_selectedSubCategory != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ManagerTheme.buildPrimaryButton(
                  label: 'Delete Selected Sub Category',
                  icon: Icons.delete_outline,
                  color: Colors.red[700],
                  onPressed: _confirmDeleteSubCategory,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingSubCategoriesSection(BuildContext context) {
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
              Icon(Icons.format_list_bulleted_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Existing Sub Categories',
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
            stream: FirebaseFirestore.instance
                .collection('projectSubCategories')
                .orderBy('subCategoryId')
                .snapshots(),
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
                      'No sub categories added yet.',
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
                  final name = data['subCategoryName']?.toString() ?? '';
                  final id = data['subCategoryId']?.toString() ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.subtitles, color: primaryColor, size: 18),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ID: $id',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
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
