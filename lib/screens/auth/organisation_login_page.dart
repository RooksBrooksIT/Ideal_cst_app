import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/auth/auth_layout.dart';
import 'package:ideal_cst/screens/onboarding/main_dashboard.dart';
import 'package:ideal_cst/screens/organization/Organization_Dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const primaryColor = Color(0xFF003768);
  static const primaryGradientStart = Color(0xFF003768);
  static const primaryGradientEnd = Color(0xFF005A9E);
}

class Organisation_LoginPage extends StatefulWidget {
  const Organisation_LoginPage({super.key});

  @override
  _Organisation_LoginPageState createState() => _Organisation_LoginPageState();
}

class _Organisation_LoginPageState extends State<Organisation_LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;
  late Animation<Color?> _gradientAnimation;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  late AnimationController _errorController;
  late Animation<Offset> _errorSlideAnimation;
  late Animation<double> _errorFadeAnimation;

  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successFadeAnimation;

  // SharedPreferences keys - ORGANIZATION specific
  static const String _isLoggedInKey = 'org_isLoggedIn';
  static const String _usernameKey = 'org_username';
  static const String _passwordKey = 'org_password';

  @override
  void initState() {
    super.initState();

    _checkLoginStatus();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuint),
    );

    _translateAnimation = Tween<double>(
      begin: 80,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _gradientAnimation = ColorTween(
      begin: AppColors.primaryColor,
      end: AppColors.primaryGradientEnd.withValues(alpha: 0.8),
    ).animate(_controller);

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _errorSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _errorController,
            curve: Curves.fastOutSlowIn,
          ),
        );

    _errorFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _errorController, curve: Curves.easeIn));

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _successScaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _successFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeInCirc),
    );
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn) {
      // Navigate automatically to main page without showing login
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, _, _) => const OrganizationDashboard(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      _controller.forward(); // start animations if not logged in
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _errorController.dispose();
    _successController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: AppColors.primaryColor,
      icon: Icons.business,
      onBack: () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const MainDashboard(),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        );
      },
      formContent: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _usernameController,
              label: 'Email / Username',
              hint: 'Enter your username',
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
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
                  color: AppColors.primaryColor,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 24),
            AuthButton(
              onPressed: _login,
              text: 'LOGIN',
              color: AppColors.primaryColor,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('organizationUser')
            .where('Username', isEqualTo: _usernameController.text.trim())
            .where('Password', isEqualTo: _passwordController.text.trim())
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_usernameKey, _usernameController.text.trim());
          await prefs.setString('persistent_role', 'Organization');

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (_, _, _) => const OrganizationDashboard(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
            ),
          );
        } else {
          _showErrorAnimation('Invalid username or password');
        }
      } catch (e) {
        _showErrorAnimation('Login failed. Please try again.');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorAnimation(String message) {
    _errorController.reset();
    _errorController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SlideTransition(
          position: _errorSlideAnimation,
          child: FadeTransition(
            opacity: _errorFadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF003768), // Primary blue start
                    Color(0xFF005A9E), // Accent lighter blue end
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessAnimation(String message) {
    _successController.reset();
    _successController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ScaleTransition(
          scale: _successScaleAnimation,
          child: FadeTransition(
            opacity: _successFadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[400],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final usernameController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryColor, Color(0xFF005A9E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white54),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    _showErrorAnimation(
                                      'Passwords do not match',
                                    );
                                    return;
                                  }

                                  setState(() => isUpdating = true);

                                  try {
                                    final querySnapshot =
                                        await FirebaseFirestore.instance
                                            .collection('organizationUser')
                                            .where(
                                              'Username',
                                              isEqualTo: usernameController.text
                                                  .trim(),
                                            )
                                            .get();

                                    if (querySnapshot.docs.isNotEmpty) {
                                      final docId = querySnapshot.docs.first.id;

                                      await FirebaseFirestore.instance
                                          .collection('organizationUser')
                                          .doc(docId)
                                          .update({
                                            'Password': newPasswordController
                                                .text
                                                .trim(),
                                          });

                                      Navigator.pop(context);
                                      _showSuccessAnimation(
                                        'Password updated successfully',
                                      );
                                    } else {
                                      _showErrorAnimation('Username not found');
                                    }
                                  } catch (e) {
                                    _showErrorAnimation(
                                      'Failed to update password. Please try again.',
                                    );
                                  } finally {
                                    setState(() => isUpdating = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  }
