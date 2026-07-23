import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key});

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _updateFormKey = GlobalKey<FormState>();

  // Tab controller
  late TabController _tabController;

  // Selected Firestore document references and values (NEW)
  DocumentReference? selectedCategoryRef;
  String? selectedCategoryName;
  DocumentReference? selectedSubCategoryRef;
  String? selectedSubCategoryName;
  DocumentReference? selectedUnitRef;
  String? selectedUnitName;
  final materialIdController = TextEditingController();
  final materialNameController = TextEditingController();
  final unitPriceController = TextEditingController();
  final descriptionController = TextEditingController();

  // Fetched lists (NEW)
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subCategories = [];
  List<Map<String, dynamic>> units = [];

  // Loading states (NEW)
  bool isLoadingCategories = true;
  bool isLoadingSubCategories = false;
  bool isLoadingUnits = false;
  bool isLoadingMaterialId = false;

  // State flags for saving
  bool _isSaving = false; // in-progress saving
  bool _isSaved = false; // saved successfully to disable Save button

  // UPDATE TAB STATE
  List<Map<String, dynamic>> materials = [];
  bool isLoadingMaterials = false;
  DocumentReference? selectedMaterialRef;
  String? selectedMaterialId;
  String? selectedMaterialUnit;
  String? selectedMaterialPrice;
  bool isEditingPrice = false;
  final updateMaterialIdController = TextEditingController();
  final updateMaterialUnitController = TextEditingController();
  final updateMaterialPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCategories();
    _fetchNextMaterialId();
    _fetchMaterials();
  }

  @override
  void dispose() {
    materialIdController.dispose();
    materialNameController.dispose();
    unitPriceController.dispose();
    descriptionController.dispose();
    updateMaterialIdController.dispose();
    updateMaterialUnitController.dispose();
    updateMaterialPriceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- NEW TAB LOGIC ---

  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('materialCategories')
        .get();
    categories = snapshot.docs
        .map(
          (doc) => {'ref': doc.reference, 'name': doc['matCategory'] as String},
        )
        .toList();
    if (categories.isNotEmpty) {
      selectedCategoryRef = categories.first['ref'];
      selectedCategoryName = categories.first['name'];
      await _fetchSubCategories();
    }
    setState(() {
      isLoadingCategories = false;
    });
  }

  Future<void> _fetchSubCategories() async {
    if (selectedCategoryRef == null) {
      subCategories = [];
      selectedSubCategoryRef = null;
      selectedSubCategoryName = null;
      units = [];
      selectedUnitRef = null;
      selectedUnitName = null;
      _updateMaterialName();
      setState(() {});
      return;
    }
    setState(() {
      isLoadingSubCategories = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('materialSubCategories')
        .where('matCategory', isEqualTo: selectedCategoryRef)
        .get();
    subCategories = snapshot.docs
        .map(
          (doc) => {
            'ref': doc.reference,
            'name': doc['matSubCategory'] as String,
            'unitRef': doc['matUnit'] as DocumentReference,
          },
        )
        .toList();
    if (subCategories.isNotEmpty) {
      selectedSubCategoryRef = subCategories.first['ref'];
      selectedSubCategoryName = subCategories.first['name'];
      selectedUnitRef = subCategories.first['unitRef'];
      await _fetchUnitName();
    } else {
      selectedSubCategoryRef = null;
      selectedSubCategoryName = null;
      selectedUnitRef = null;
      selectedUnitName = null;
    }
    _updateMaterialName();
    setState(() {
      isLoadingSubCategories = false;
    });
  }

  Future<void> _fetchUnitName() async {
    if (selectedUnitRef == null) {
      selectedUnitName = null;
      setState(() {});
      return;
    }
    setState(() {
      isLoadingUnits = true;
    });
    final doc = await selectedUnitRef!.get();
    selectedUnitName = doc['matUnit'] as String;
    setState(() {
      isLoadingUnits = false;
    });
  }

  Future<void> _fetchNextMaterialId() async {
    setState(() {
      isLoadingMaterialId = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('materials')
        .orderBy('materialId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final String lastId = snapshot.docs.first['materialId'];
      final int lastNum = int.tryParse(lastId.replaceAll('MT', '')) ?? 0;
      final int nextNum = lastNum + 1;
      materialIdController.text = 'MT${nextNum.toString().padLeft(3, '0')}';
    } else {
      materialIdController.text = 'MT001';
    }
    setState(() {
      isLoadingMaterialId = false;
    });
  }

  void _onCategoryChanged(DocumentReference? ref, String? name) async {
    setState(() {
      selectedCategoryRef = ref;
      selectedCategoryName = name;
      selectedSubCategoryRef = null;
      selectedSubCategoryName = null;
      selectedUnitRef = null;
      selectedUnitName = null;
      subCategories = [];
      units = [];
    });
    await _fetchSubCategories();
    _updateMaterialName();
  }

  void _onSubCategoryChanged(
    DocumentReference? ref,
    String? name,
    DocumentReference? unitRef,
  ) async {
    setState(() {
      selectedSubCategoryRef = ref;
      selectedSubCategoryName = name;
      selectedUnitRef = unitRef;
      selectedUnitName = null;
    });
    await _fetchUnitName();
    _updateMaterialName();
  }

  void _updateMaterialName() {
    if ((selectedCategoryName ?? '').isNotEmpty &&
        (selectedSubCategoryName ?? '').isNotEmpty) {
      materialNameController.text =
          '${selectedCategoryName}_$selectedSubCategoryName';
    } else {
      materialNameController.text = '';
    }
    setState(() {});
  }

  void _resetForm() async {
    materialNameController.clear();
    unitPriceController.clear();
    descriptionController.clear();
    setState(() {
      _isSaved = false; // allow saving again after reset
    });
    await _fetchCategories();
    await _fetchNextMaterialId();
    setState(() {});
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate() &&
        selectedCategoryRef != null &&
        selectedSubCategoryRef != null &&
        selectedUnitRef != null &&
        !_isSaving &&
        !_isSaved) {
      setState(() {
        _isSaving = true;
      });

      final materialName = materialNameController.text.trim();
      final materialsRef = FirebaseFirestore.instance.collection('materials');

      // Check for duplicate material name
      final existing = await materialsRef
          .where('materialName', isEqualTo: materialName)
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Material name already exists."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('materials');
      String newMaterialId = materialIdController.text;

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final counterSnapshot = await transaction.get(counterRef);
          int lastNum = 0;
          if (counterSnapshot.exists) {
            lastNum = counterSnapshot.get('lastMaterialId') ?? 0;
          }
          int nextNum = lastNum + 1;

          if (newMaterialId != 'MT${nextNum.toString().padLeft(3, '0')}') {
            newMaterialId = 'MT${nextNum.toString().padLeft(3, '0')}';
          }

          final materialData = {
            'materialId': newMaterialId,
            'materialName': materialName,
            'materialCategory': selectedCategoryRef,
            'materialSubCategory': selectedSubCategoryRef,
            'materialUnit': selectedUnitRef,
            'materialPrice': unitPriceController.text,
            'description': descriptionController.text,
            'createdAt': FieldValue.serverTimestamp(),
          };

          transaction.set(materialsRef.doc(newMaterialId), materialData);
          transaction.set(counterRef, {'lastMaterialId': nextNum});
          materialIdController.text = newMaterialId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Material Saved Successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isSaved = true;
        });
        _resetForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save material: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // --- UPDATE TAB LOGIC ---

  Future<void> _fetchMaterials() async {
    setState(() {
      isLoadingMaterials = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('materials')
        .orderBy('materialId')
        .get();
    materials = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'ref': doc.reference,
        'materialId': doc.id,
        'materialName': data.containsKey('materialName')
            ? data['materialName'].toString()
            : '',
        'materialUnit': data.containsKey('materialUnit')
            ? data['materialUnit']
            : '',
        'materialPrice': data.containsKey('materialPrice')
            ? data['materialPrice']
            : '',
      };
    }).toList();

    print('Fetched materials:');
    for (var mat in materials) {
      print(
        'materialId: ${mat['materialId'] ?? ''}, materialName: ${mat['materialName'] ?? ''}',
      );
    }
    setState(() {
      isLoadingMaterials = false;
    });
  }

  void _onMaterialSelected(DocumentReference? ref) async {
    if (ref == null) return;
    final doc = await ref.get();
    selectedMaterialRef = ref;
    selectedMaterialId = doc['materialId'] as String?;
    var unitField = doc['materialUnit'];
    String unitName = '';
    if (unitField is DocumentReference) {
      unitName = await _getUnitName(unitField);
    } else if (unitField is String) {
      unitName = unitField;
    }
    selectedMaterialUnit = unitName;
    selectedMaterialPrice = doc['materialPrice']?.toString() ?? '';
    updateMaterialIdController.text = selectedMaterialId ?? '';
    updateMaterialUnitController.text = selectedMaterialUnit ?? '';
    updateMaterialPriceController.text = selectedMaterialPrice ?? '';
    isEditingPrice = false;
    setState(() {});
  }

  Future<String> _getUnitName(dynamic unitRef) async {
    if (unitRef == null) return '';
    if (unitRef is DocumentReference) {
      final doc = await unitRef.get();
      return doc['matUnit'] as String? ?? '';
    } else if (unitRef is String) {
      return unitRef;
    }
    return '';
  }

  void _resetUpdateForm() {
    selectedMaterialRef = null;
    selectedMaterialId = null;
    selectedMaterialUnit = null;
    selectedMaterialPrice = null;
    updateMaterialIdController.clear();
    updateMaterialUnitController.clear();
    updateMaterialPriceController.clear();
    isEditingPrice = false;
    setState(() {});
  }

  void _onEditPrice() {
    setState(() {
      isEditingPrice = true;
    });
  }

  void _onSaveUpdate() async {
    if (_updateFormKey.currentState!.validate() &&
        selectedMaterialRef != null) {
      final newPrice = updateMaterialPriceController.text;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Update'),
          content: const Text('Would you like to save your changes?'),
          actions: [
            ManagerTheme.buildDialogCancelButton(
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ManagerTheme.buildDialogButton(
              label: 'Confirm',
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icons.check,
            ),
          ],
        ),
      );
      if (confirm == true) {
        await selectedMaterialRef!.update({'materialPrice': newPrice});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Material Updated Successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchMaterials();
        _resetUpdateForm();
      }
    }
  }

  // --- UI ---

  Widget _buildHeader(BuildContext context) {
    return ManagerTheme.buildHeader(
      context,
      category: 'Material Management',
      title: 'Material Setup',
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
                  Tab(text: 'New Material'),
                  Tab(text: 'Update Material'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
          // --- NEW TAB ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Material Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ManagerTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          isLoadingMaterialId
                              ? const Center(child: CircularProgressIndicator())
                              : TextFormField(
                                  controller: materialIdController,
                                  readOnly: true,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'Material ID',
                                    prefixIcon: const Icon(
                                      Icons.confirmation_number_outlined,
                                      color: ManagerTheme.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: ManagerTheme.primaryColor,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                          const SizedBox(height: 16),
                          isLoadingCategories
                              ? const Center(child: CircularProgressIndicator())
                              : _buildCategoryDropdown(),
                          const SizedBox(height: 16),
                          isLoadingSubCategories
                              ? const Center(child: CircularProgressIndicator())
                              : _buildSubCategoryDropdown(),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: materialNameController,
                            readOnly: true,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Material Name',
                              prefixIcon: const Icon(
                                Icons.label_important_outline,
                                color: ManagerTheme.primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: ManagerTheme.primaryColor,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          isLoadingUnits
                              ? const Center(child: CircularProgressIndicator())
                              : _buildUnitDropdown(),
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            context,
                            controller: unitPriceController,
                            label: 'Unit Price',
                            icon: Icons.attach_money_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter unit price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Only numbers are allowed';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDescriptionField(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
          // --- UPDATE TAB ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _updateFormKey,
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Update Material',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ManagerTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          isLoadingMaterials
                              ? const Center(child: CircularProgressIndicator())
                              : Autocomplete<Map<String, dynamic>>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                        if (textEditingValue.text == '') {
                                          return const Iterable<
                                            Map<String, dynamic>
                                          >.empty();
                                        }
                                        return materials.where((mat) {
                                          final name =
                                              (mat['materialName'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                          return name.contains(
                                            textEditingValue.text.toLowerCase(),
                                          );
                                        });
                                      },
                                  displayStringForOption: (mat) =>
                                      mat['materialName'] ?? '',
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        if (selectedMaterialRef != null) {
                                          final selected = materials.firstWhere(
                                            (mat) =>
                                                mat['ref'] ==
                                                selectedMaterialRef,
                                            orElse: () => {'materialName': ''},
                                          );
                                          controller.text =
                                              selected['materialName'] ?? '';
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                            labelText: 'Material Eg:Cement',
                                            prefixIcon: const Icon(
                                              Icons.category_outlined,
                                              color: ManagerTheme.primaryColor,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: ManagerTheme.primaryColor,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                          ),
                                          validator: (value) {
                                            if ((value == null ||
                                                    value.isEmpty) &&
                                                selectedMaterialRef == null) {
                                              return 'Please select or enter a material';
                                            }
                                            return null;
                                          },
                                          onChanged: (value) {
                                            setState(() {
                                              selectedMaterialRef = null;
                                            });
                                          },
                                        );
                                      },
                                  onSelected: (mat) {
                                    _onMaterialSelected(
                                      mat['ref'] as DocumentReference,
                                    );
                                  },
                                ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: updateMaterialIdController,
                            readOnly: true,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Material ID',
                              prefixIcon: const Icon(
                                Icons.confirmation_number_outlined,
                                color: ManagerTheme.primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: ManagerTheme.primaryColor,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: updateMaterialUnitController,
                            readOnly: true,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              prefixIcon: const Icon(
                                Icons.category_outlined,
                                color: ManagerTheme.primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: ManagerTheme.primaryColor,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: updateMaterialPriceController,
                                  readOnly: !isEditingPrice,
                                  enabled: isEditingPrice,
                                  decoration: InputDecoration(
                                    labelText: 'Material Price',
                                    prefixIcon: const Icon(
                                      Icons.attach_money_outlined,
                                      color: ManagerTheme.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: ManagerTheme.primaryColor,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter unit price';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Only numbers are allowed';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isEditingPrice &&
                                  selectedMaterialRef != null)
                                ManagerTheme.buildDialogButton(
                                  label: 'Edit',
                                  icon: Icons.edit,
                                  onPressed: _onEditPrice,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ManagerTheme.buildCircularButton(
                  icon: Icons.save,
                  label: 'Save',
                  backgroundColor: ManagerTheme.primaryColor,
                  onPressed: (_isSaving || _isSaved) ? null : _saveForm,
                ),
                ManagerTheme.buildCircularButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  backgroundColor: Colors.orange,
                  onPressed: _resetUpdateForm,
                ),
                ManagerTheme.buildCircularButton(
                  icon: Icons.cancel,
                  label: 'Cancel',
                  backgroundColor: Colors.red,
                  onPressed: () => Navigator.pop(context),
                ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
),
);
  }

  Widget _buildCategoryDropdown() {
    return CustomDropdown<String>(
      value: selectedCategoryRef?.path,
      labelText: 'Material Category',
      prefixIcon: Icons.category_outlined,
      items: categories
          .map(
            (cat) => DropdownMenuItem<String>(
              value:
                  (cat['ref'] as DocumentReference).path,
              child: Text(cat['name'] as String),
            ),
          )
          .toList(),
      onChanged: (path) {
        if (path == null) return;
        final cat = categories.firstWhere(
          (c) => (c['ref'] as DocumentReference).path == path,
        );
        _onCategoryChanged(
          cat['ref'] as DocumentReference,
          cat['name'] as String,
        );
      },
    );
  }

  Widget _buildSubCategoryDropdown() {
    return CustomDropdown<String>(
      value: selectedSubCategoryRef?.path,
      labelText: 'Material Sub Category',
      prefixIcon: Icons.category_outlined,
      items: subCategories
          .map(
            (sub) => DropdownMenuItem<String>(
              value:
                  (sub['ref'] as DocumentReference).path,
              child: Text(sub['name'] as String),
            ),
          )
          .toList(),
      onChanged: (path) {
        if (path == null) return;
        final sub = subCategories.firstWhere(
          (s) => (s['ref'] as DocumentReference).path == path,
        );
        _onSubCategoryChanged(
          sub['ref'] as DocumentReference,
          sub['name'] as String,
          sub['unitRef'] as DocumentReference,
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return TextFormField(
      controller: TextEditingController(text: selectedUnitName ?? ''),
      decoration: InputDecoration(
        labelText: 'Unit',
        prefixIcon: const Icon(
          Icons.category_outlined,
          color: ManagerTheme.primaryColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ManagerTheme.primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        enabled: false,
      ),
      style: TextStyle(color: Colors.grey[700]),
    );
  }

  Widget _buildTextFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Text(
              '₹',
              style: TextStyle(fontSize: 20, color: ManagerTheme.primaryColor),
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ManagerTheme.primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildDescriptionField(BuildContext context) {
    return TextFormField(
      controller: descriptionController,
      decoration: InputDecoration(
        labelText: 'Description',
        prefixIcon: const Icon(
          Icons.description_outlined,
          color: ManagerTheme.primaryColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ManagerTheme.primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: 3,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ManagerTheme.buildCircularButton(
          icon: Icons.save,
          label: 'Save',
          backgroundColor: ManagerTheme.primaryColor,
          onPressed: _saveForm,
        ),
        ManagerTheme.buildCircularButton(
          icon: Icons.refresh,
          label: 'Reset',
          backgroundColor: Colors.orange,
          onPressed: _resetForm,
        ),
        ManagerTheme.buildCircularButton(
          icon: Icons.cancel,
          label: 'Cancel',
          backgroundColor: Colors.red,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

}
