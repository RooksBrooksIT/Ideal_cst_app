import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/auth/auth_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/receptionist/receptionist_dashboard.dart';

class ReceptionistLoginPage extends StatefulWidget {
  const ReceptionistLoginPage({super.key});

  @override
  State<ReceptionistLoginPage> createState() => _ReceptionistLoginPageState();
}

class _ReceptionistLoginPageState extends State<ReceptionistLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  static const String _isLoggedInKey = 'receptionist_is_logged_in';
  static const String _usernameKey = 'receptionist_username';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReceptionistDashboard()),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();

        final querySnapshot = await FirebaseFirestore.instance
            .collection('receptionist_login')
            .where('Username', isEqualTo: username)
            .where('Password', isEqualTo: password)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docData = querySnapshot.docs.first.data();
          final role = docData['role'] ?? 'Receptionist';

          if (role != 'Receptionist') {
            _showErrorDialog('User account is not registered as a Receptionist.');
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_usernameKey, username);
          await prefs.setString('persistent_role', 'Receptionist');

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receptionist logged in successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ReceptionistDashboard(),
            ),
          );
        } else {
          _showErrorDialog('Invalid username or password');
        }
      } catch (e) {
        _showErrorDialog('An error occurred during login. Please try again.');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: const Color(0xFFD84315),
      icon: Icons.support_agent_rounded,
      onBack: () => Navigator.pop(context),
      formContent: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _usernameController,
              label: 'Email / Username',
              hint: 'Enter your username',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: !_showPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            AuthButton(
              onPressed: _login,
              text: 'LOGIN AS RECEPTIONIST',
              color: const Color(0xFFD84315),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
