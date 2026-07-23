import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/auth/auth_layout.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/manager/contractor_entry_page.dart';
import 'package:ideal_cst/screens/supervisor/supervisor_dashboard.dart';

class AppColors {
  static const primaryColor = Color(0xFF003768);
  static const primaryGradientStart = Color(0xFF003768);
  static const primaryGradientEnd = Color(0xFF005A9E);

  static const supervisorPrimaryColor = Color(0xFF4527A0);
  static const supervisorGradientStart = Color(0xFF005A9E);
  static const supervisorGradientEnd = Color.fromARGB(255, 2, 138, 242);

  static const contractorGradientStart = Color(0xFF003768);
  static const contractorGradientEnd = Color(0xFF005A9E);
}

class Supervisor_LoginPage extends StatefulWidget {
  const Supervisor_LoginPage({super.key});

  @override
  _Supervisor_LoginPageState createState() => _Supervisor_LoginPageState();

  static Future<void> clearLoginData() async {}
}

class _Supervisor_LoginPageState extends State<Supervisor_LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  bool _isContractor = false;
  List<String> _supervisorNames = [];
  String? _selectedSupervisorName;

  // SharedPreferences keys - SUPERVISOR specific
  static const String _isLoggedInKey = 'sup_isLoggedIn';
  static const String _userTypeKey = 'sup_userType';
  static const String _usernameKey = 'sup_username';
  static const String _supervisorIdKey = 'sup_supervisorId';
  static const String _supervisorNameKey = 'sup_supervisorName';
  static const String _contractorNameKey = 'sup_contractorName';
  static const String _contractorFieldKey = 'sup_contractorField';
  static const String _isContractorKey = 'sup_isContractor';

  @override
  void initState() {
    super.initState();
    _fetchContractorNames();
    _checkLoginStatus();
  }

  // Check if user is already logged in
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final userType = prefs.getString(_userTypeKey) ?? 'supervisor';
        final username = prefs.getString(_usernameKey) ?? '';
        final supervisorId = prefs.getString(_supervisorIdKey) ?? '';
        final supervisorName = prefs.getString(_supervisorNameKey) ?? '';
        final isContractor = prefs.getBool(_isContractorKey) ?? false;

        if (isContractor) {
          final contractorName = prefs.getString(_contractorNameKey) ?? '';
          final contractorField = prefs.getString(_contractorFieldKey) ?? '';

          // Navigate to contractor page
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorEntryPage(
                  userName: username,
                  userDetails: {
                    'supervisorId': supervisorId,
                    'contractorName': contractorName,
                    'contractorField': contractorField,
                  },
                ),
              ),
            );
          }
        } else {
          // Navigate to supervisor dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorDashboard(
                  supervisorId: supervisorId,
                  supervisorName: supervisorName,
                  username: username,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }
  }

  // Save login data to SharedPreferences
  Future<void> _saveLoginData({
    required String username,
    required String supervisorId,
    required String supervisorName,
    required bool isContractor,
    String? contractorName,
    String? contractorField,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(
        _userTypeKey,
        isContractor ? 'contractor' : 'supervisor',
      );
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_supervisorIdKey, supervisorId);
      await prefs.setString(_supervisorNameKey, supervisorName);
      await prefs.setBool(_isContractorKey, isContractor);

      if (isContractor && contractorName != null) {
        await prefs.setString(_contractorNameKey, contractorName);
        await prefs.setString(_contractorFieldKey, contractorField ?? '');
        await prefs.setString('persistent_role', 'ContractorEntry');
      } else {
        await prefs.setString('persistent_role', 'Supervisor');
      }
    } catch (e) {
      debugPrint('Error saving login data: $e');
    }
  }

  // Clear login data (for logout)
  static Future<void> clearLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
      await prefs.remove(_userTypeKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_supervisorIdKey);
      await prefs.remove(_supervisorNameKey);
      await prefs.remove(_isContractorKey);
      await prefs.remove(_contractorNameKey);
      await prefs.remove(_contractorFieldKey);
    } catch (e) {
      debugPrint('Error clearing login data: $e');
    }
  }

  Future<void> _fetchContractorNames() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('contractors')
          .get();
      final names = querySnapshot.docs
          .map((doc) => doc.data()['contractorName'] as String?)
          .where((name) => name != null)
          .cast<String>()
          .toList();
      if (mounted) {
        setState(() {
          _supervisorNames = names;
        });
      }
    } catch (e) {
      print('Error fetching contractor names: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Login Failed'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _showSuccessDialog(String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Success'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _showForgotPasswordDialog() {
    final usernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: StatefulBuilder(
          builder: (context, setState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final verticalPadding = screenWidth < 400 ? 16.0 : 24.0;
            final horizontalPadding = screenWidth < 400 ? 16.0 : 24.0;

            return Container(
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding.toDouble(),
                horizontal: horizontalPadding.toDouble(),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.contractorGradientStart,
                    AppColors.contractorGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: verticalPadding.toDouble()),
                    TextField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: verticalPadding.toDouble()),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: verticalPadding.toDouble()),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.lock_reset,
                          color: Colors.white70,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: verticalPadding.toDouble()),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: const BorderSide(color: Colors.white54),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    if (newPasswordController.text !=
                                        confirmPasswordController.text) {
                                      _showErrorDialog(
                                        'Passwords do not match',
                                      );
                                      return;
                                    }
                                    setState(() => isUpdating = true);
                                    try {
                                      final querySnapshot =
                                          await FirebaseFirestore.instance
                                              .collection('supervisor')
                                              .where(
                                                'UserName',
                                                isEqualTo: usernameController
                                                    .text
                                                    .trim(),
                                              )
                                              .get();
                                      if (querySnapshot.docs.isNotEmpty) {
                                        final docId =
                                            querySnapshot.docs.first.id;
                                        await FirebaseFirestore.instance
                                            .collection('supervisor')
                                            .doc(docId)
                                            .update({
                                              'Password': newPasswordController
                                                  .text
                                                  .trim(),
                                            });
                                        Navigator.pop(context);
                                        _showSuccessDialog(
                                          'Password updated successfully',
                                        );
                                      } else {
                                        _showErrorDialog('Username not found');
                                      }
                                    } catch (e) {
                                      _showErrorDialog(
                                        'Failed to update password. Please try again.',
                                      );
                                    } finally {
                                      setState(() => isUpdating = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.contractorGradientEnd,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: isUpdating
                                ? const SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('supervisor')
            .where('UserName', isEqualTo: _usernameController.text.trim())
            .where('Password', isEqualTo: _passwordController.text.trim())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          final supervisorId = doc.id;
          final supervisorName =
              doc.data()['Name'] ?? _usernameController.text.trim();

          if (_isContractor && _selectedSupervisorName != null) {
            final contractorQuery = await FirebaseFirestore.instance
                .collection('contractors')
                .where('contractorName', isEqualTo: _selectedSupervisorName)
                .limit(1)
                .get();
            String? contractorField;
            if (contractorQuery.docs.isNotEmpty) {
              contractorField =
                  contractorQuery.docs.first.data()['contractorField']
                      as String?;
            }

            // Save login data
            await _saveLoginData(
              username: _usernameController.text.trim(),
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              isContractor: true,
              contractorName: _selectedSupervisorName!,
              contractorField: contractorField ?? '',
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorEntryPage(
                  userName: _usernameController.text.trim(),
                  userDetails: {
                    'supervisorId': supervisorId,
                    'contractorName': _selectedSupervisorName!,
                    'contractorField': contractorField ?? '',
                  },
                ),
              ),
            );
          } else {
            // Save login data
            await _saveLoginData(
              username: _usernameController.text.trim(),
              supervisorId: supervisorId,
              supervisorName: supervisorName,
              isContractor: false,
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorDashboard(
                  supervisorId: supervisorId,
                  supervisorName: supervisorName,
                  username: _usernameController.text.trim(),
                ),
              ),
            );
          }
        } else {
          _showErrorDialog('Invalid username or password');
        }
      } catch (e) {
        debugPrint('Login error: $e');
        _showErrorDialog('An error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: const Color(0xFF4527A0),
      icon: Icons.supervisor_account,
      onBack: () => Navigator.pop(context),
      formContent: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Enter your username',
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Username is required' : null,
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '********',
              obscureText: !_showPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.supervisorPrimaryColor,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Password is required' : null,
            ),

            const SizedBox(height: 16),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                title: const Text('Is Contractor'),
                value: _isContractor,
                activeColor: AppColors.supervisorPrimaryColor,
                onChanged: (val) {
                  setState(() {
                    _isContractor = val ?? false;
                    if (!_isContractor) {
                      _selectedSupervisorName = null;
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_isContractor) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Contractor Name',
                  prefixIcon: const Icon(
                    Icons.supervisor_account,
                    color: AppColors.supervisorPrimaryColor,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                items: _supervisorNames
                    .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                initialValue: _selectedSupervisorName,
                onChanged: (val) => setState(() => _selectedSupervisorName = val),
                validator: (val) {
                  if (_isContractor && (val == null || val.isEmpty)) {
                    return 'Please select a supervisor name';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            AuthButton(
              onPressed: _login,
              text: 'LOGIN',
              color: AppColors.supervisorPrimaryColor,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
