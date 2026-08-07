import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ReceptionistSupervisorConfig extends StatefulWidget {
  const ReceptionistSupervisorConfig({super.key});

  @override
  State<ReceptionistSupervisorConfig> createState() => _ReceptionistSupervisorConfigState();
}

class _ReceptionistSupervisorConfigState extends State<ReceptionistSupervisorConfig> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDesignation;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  List<String> _designationList = [];
  bool _isLoadingDesignations = true;
  bool _isPasswordVisible = false;
  int _selectedTab = 0; // 0: Create, 1: Info
  bool _isSubmitting = false;

  static const Color primaryColor = Color(0xFFD84315);
  static const Color backgroundColor = Color(0xFFFFF3E0);

  @override
  void initState() {
    super.initState();
    _fetchDesignations();
  }

  Future<void> _fetchDesignations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supervisorDesignation')
          .get();
      final designations = snapshot.docs
          .map((doc) => doc['Designation'] as String)
          .toList();
      setState(() {
        _designationList = designations;
        _isLoadingDesignations = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDesignations = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load designations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('supervisor')
          .where('UserName', isEqualTo: username.trim())
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isContactNoUnique(String contactNo) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('supervisor')
          .where('ContactNo', isEqualTo: contactNo.trim())
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final username = _userNameController.text.trim();
      final contactNo = _contactNoController.text.trim();

      bool isUsernameUnique = await _isUsernameUnique(username);
      if (!mounted) return;
      if (!isUsernameUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Username "$username" is already taken. Please choose a different one.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      bool isContactNoUnique = await _isContactNoUnique(contactNo);
      if (!mounted) return;
      if (!isContactNoUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contact number "$contactNo" is already registered. Please use a different one.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      await _createSupervisorAccount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking uniqueness: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _editSupervisorPassword(
    String documentId,
    String supervisorName,
    String currentPassword,
  ) async {
    TextEditingController newPasswordController = TextEditingController(
      text: currentPassword,
    );
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Password',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editing password for "$supervisorName"',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(newPasswordController.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((newPassword) async {
      if (newPassword != null && newPassword.isNotEmpty) {
        try {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Updating password...'),
                ],
              ),
              backgroundColor: Colors.blue,
            ),
          );

          await FirebaseFirestore.instance
              .collection('supervisor')
              .doc(documentId)
              .update({'Password': newPassword});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Password updated successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            setState(() {});
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Failed to update password: $e'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _deleteSupervisor(String documentId, String supervisorName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete supervisor "$supervisorName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('supervisor').doc(documentId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supervisor "$supervisorName" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete supervisor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createSupervisorAccount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supervisor')
          .get();
      int maxNumber = 0;
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final match = RegExp(r'SP(\d+)_').firstMatch(id);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxNumber) {
            maxNumber = num;
          }
        }
      }
      final nextNumber = maxNumber + 1;
      final supervisorNumber = nextNumber.toString().padLeft(3, '0');
      final username = _userNameController.text.trim();
      final supervisorId = 'SP${supervisorNumber}_$username';
      final documentId = supervisorId;

      final supervisorData = {
        'SupervisorId': supervisorId,
        'FullName': _fullNameController.text.trim(),
        'UserName': username,
        'Password': _passwordController.text.trim(),
        'Designation': _selectedDesignation,
        'ContactNo': _contactNoController.text.trim(),
        'Email': _emailController.text.trim(),
        'Photo': 'Photo URL or Placeholder',
        'CreatedAt': FieldValue.serverTimestamp(),
        'CreatedBy': 'Receptionist',
      };

      await FirebaseFirestore.instance
          .collection('supervisor')
          .doc(documentId)
          .set(supervisorData);

      _showSuccessDialog();
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to create supervisor account: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: 100,
                  height: 100,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your supervisor details have been saved successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _userNameController.clear();
    _passwordController.clear();
    _contactNoController.clear();
    _emailController.clear();
    setState(() {
      _selectedDesignation = null;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
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
            child: const Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor Management',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Supervisor Configuration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 8),

            // Top Two Navigation Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedTab = 0;
                            });
                          },
                          child: Text(
                            'Create Supervisor',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 0 ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedTab = 1;
                            });
                          },
                          child: Text(
                            'Supervisors Info',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 1 ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Tab Content
            Expanded(
              child: _selectedTab == 0 ? _buildCreateForm() : _buildInfoTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFormHeader(),
            const SizedBox(height: 24),
            _buildTextField('Full Name', _fullNameController, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField('User Name', _userNameController, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField(
              'Password',
              _passwordController,
              isRequired: true,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildDesignationDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'Contact No',
              _contactNoController,
              keyboardType: TextInputType.phone,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Email',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _buildPhotoUpload(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_add_alt_1, size: 40, color: primaryColor),
          const SizedBox(height: 8),
          const Text(
            'Create Supervisor Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Please fill in all required fields (*)',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.white,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
          ),
          obscureText: isPassword ? !_isPasswordVisible : false,
          keyboardType: keyboardType,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            if (label == 'Contact No' && value != null && value.isNotEmpty) {
              if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                return 'Please enter a valid contact number';
              }
            }
            if (label == 'Email' && value != null && value.isNotEmpty) {
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email address';
              }
            }
            return null;
          },
          cursorColor: primaryColor,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDesignationDropdown() {
    if (_isLoadingDesignations) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Designation *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading designations...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Designation *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        CustomDropdown<String>(
          value: _selectedDesignation,
          hintText: 'Select Designation',
          prefixIcon: Icons.work,
          items: _designationList
              .map(
                (desig) => DropdownMenuItem(
                  value: desig,
                  child: Text(desig),
                ),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedDesignation = val;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a designation';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor Photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 36, color: primaryColor.withValues(alpha: 0.6)),
                const SizedBox(height: 8),
                Text(
                  'Upload Supervisor Photo',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '(Optional)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _validateAndSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _resetForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: primaryColor, width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 20, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  'Reset',
                  style: TextStyle(fontSize: 16, color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTable() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Supervisors Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('supervisor').snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      '$count supervisors',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('supervisor').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading supervisors...',
                        style: TextStyle(fontSize: 15, color: primaryColor),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load supervisors: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null || data.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 60, color: primaryColor.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No Supervisors Found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final supervisors = data.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                physics: const BouncingScrollPhysics(),
                itemCount: supervisors.length,
                itemBuilder: (context, index) {
                  final doc = supervisors[index];
                  final itemData = doc.data() as Map<String, dynamic>;
                  final photoUrl = (itemData['Photo'] ?? '').toString();
                  final supervisorName = (itemData['FullName'] ?? '').toString();
                  final supervisorId = (itemData['SupervisorId'] ?? '').toString();
                  final password = (itemData['Password'] ?? '').toString();
                  final designation = (itemData['Designation'] ?? '').toString();
                  final contactNo = (itemData['ContactNo'] ?? '').toString();
                  final email = (itemData['Email'] ?? '').toString();

                  return SupervisorCard(
                    docId: doc.id,
                    supervisorId: supervisorId,
                    fullName: supervisorName,
                    password: password,
                    designation: designation,
                    photoUrl: photoUrl,
                    contactNo: contactNo,
                    email: email,
                    primaryColor: primaryColor,
                    onEditPassword: (docId, name, pass) => _editSupervisorPassword(docId, name, pass),
                    onDelete: (docId, name) => _deleteSupervisor(docId, name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class SupervisorCard extends StatefulWidget {
  final String docId;
  final String supervisorId;
  final String fullName;
  final String password;
  final String designation;
  final String photoUrl;
  final String contactNo;
  final String email;
  final Color primaryColor;
  final Function(String docId, String name, String password) onEditPassword;
  final Function(String docId, String name) onDelete;

  const SupervisorCard({
    super.key,
    required this.docId,
    required this.supervisorId,
    required this.fullName,
    required this.password,
    required this.designation,
    required this.photoUrl,
    required this.contactNo,
    required this.email,
    required this.primaryColor,
    required this.onEditPassword,
    required this.onDelete,
  });

  @override
  State<SupervisorCard> createState() => _SupervisorCardState();
}

class _SupervisorCardState extends State<SupervisorCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.15)),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: widget.primaryColor.withValues(alpha: 0.12),
                child: Icon(Icons.person, color: widget.primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    if (widget.designation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.designation,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE9E7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFAB91)),
                ),
                child: Text(
                  widget.supervisorId,
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (widget.contactNo.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: widget.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  "Contact: ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E2D)),
                ),
                Text(
                  widget.contactNo,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: widget.primaryColor),
              const SizedBox(width: 8),
              const Text(
                "Password: ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E2D)),
              ),
              Text(
                _showPassword ? widget.password : '••••••••',
                style: TextStyle(
                  fontFamily: _showPassword ? null : 'monospace',
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onEditPassword(widget.docId, widget.fullName, widget.password),
                icon: Icon(Icons.edit_outlined, size: 16, color: widget.primaryColor),
                label: Text(
                  'Edit Password',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.primaryColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => widget.onDelete(widget.docId, widget.fullName),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
