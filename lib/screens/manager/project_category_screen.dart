import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ProjectCategoryScreen extends StatefulWidget {
  const ProjectCategoryScreen({super.key});

  @override
  State<ProjectCategoryScreen> createState() => _ProjectCategoryScreenState();
}

class _ProjectCategoryScreenState extends State<ProjectCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = ManagerTheme.primaryColor;
  final TextEditingController _categoryController = TextEditingController();
  final FocusNode _categoryFocusNode = FocusNode();
  String? _selectedCategory;

  Future<void> _addCategoryToFirestore(String category) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectCategories')
          .orderBy('projectCategoryId', descending: true)
          .limit(1)
          .get();

      int nextId = 1;
      if (snapshot.docs.isNotEmpty) {
        final lastId = snapshot.docs.first['projectCategoryId'];
        if (lastId is int) {
          nextId = lastId + 1;
        } else if (lastId is String) {
          nextId = (int.tryParse(lastId) ?? 0) + 1;
        }
      }

      await FirebaseFirestore.instance.collection('projectCategories').add({
        'projectCategory': category,
        'projectCategoryId': nextId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
      setState(() {
        _selectedCategory = category;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    }
  }

  void _showAddCategoryDialog() {
    _categoryController.clear();
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
                'Add New Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: TextField(
            controller: _categoryController,
            focusNode: _categoryFocusNode,
            decoration: InputDecoration(
              hintText: 'Enter category name',
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
              backgroundColor: ManagerTheme.logoutButtonColor,
              onPressed: () {
                final category = _categoryController.text.trim();
                if (category.isNotEmpty) {
                  _addCategoryToFirestore(category);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategoryFromFirestore(String category) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectCategories')
          .where('projectCategory', isEqualTo: category)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully!')),
      );

      setState(() {
        _selectedCategory = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    }
  }

  void _confirmDeleteCategory() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category to delete')),
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
          title: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "$_selectedCategory"?'),
          actions: [
            ManagerTheme.buildDialogCancelButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
            ),
            ManagerTheme.buildDialogButton(
              label: 'Delete',
              backgroundColor: ManagerTheme.logoutButtonColor,
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCategoryFromFirestore(_selectedCategory!);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Project Configuration',
      title: 'Project Category Setup',
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
              _buildCategorySelectionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelectionCard() {
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('projectCategories').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final categories = docs
                  .map((doc) => doc['projectCategory'] as String)
                  .toSet()
                  .toList();

              return CustomDropdown<String>(
                value: _selectedCategory,
                labelText: 'Select Project Category',
                prefixIcon: Icons.folder,
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ManagerTheme.buildCircularButton(
                icon: Icons.add,
                label: 'New',
                backgroundColor: ManagerTheme.logoutButtonColor,
                onPressed: _showAddCategoryDialog,
              ),
              ManagerTheme.buildCircularButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                backgroundColor: _selectedCategory != null
                    ? ManagerTheme.logoutButtonColor
                    : Colors.grey.shade400,
                onPressed: _selectedCategory != null ? _confirmDeleteCategory : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
