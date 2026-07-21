import re
import os

# 1. Refactor organisation_login_page.dart
org_path = 'lib/screens/auth/organisation_login_page.dart'
with open(org_path, 'r') as f:
    org_code = f.read()

# Add import
org_code = org_code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ideal_cst/screens/auth/auth_layout.dart';")

new_build_org = """
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: AppColors.primaryColor,
      icon: Icons.domain,
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
"""

# Replace from build to the end of _buildLoginCard
org_code = re.sub(
    r'@override\s*Widget build\(BuildContext context\).*?(?=void _login\(\) async)',
    new_build_org.strip() + "\n\n  ",
    org_code,
    flags=re.DOTALL
)

# Remove _buildScaffold and _buildLoginCard completely
org_code = re.sub(r'Widget _buildScaffold\(BuildContext context\)\s*{.*?}\s*?(?=Future<void> _login)', '', org_code, flags=re.DOTALL)
org_code = re.sub(r'Widget _buildLoginCard\(\)\s*{.*?}\s*?}\s*$', '}\n', org_code, flags=re.DOTALL)

with open(org_path, 'w') as f:
    f.write(org_code)

# 2. Refactor config_login_page.dart
cfg_path = 'lib/screens/auth/config_login_page.dart'
with open(cfg_path, 'r') as f:
    cfg_code = f.read()

cfg_code = cfg_code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ideal_cst/screens/auth/auth_layout.dart';")

new_build_cfg = """
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: const Color(0xFF00695C), // Manager Color (Dark Teal)
      icon: Icons.settings,
      onBack: () => Navigator.pop(context),
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
                  color: const Color(0xFF00695C),
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF00695C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AuthButton(
              onPressed: _login,
              text: 'LOGIN',
              color: const Color(0xFF00695C),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
"""

cfg_code = re.sub(
    r'@override\s*Widget build\(BuildContext context\).*?(?=void _showForgotPasswordDialog\(\))',
    new_build_cfg.strip() + "\n\n  ",
    cfg_code,
    flags=re.DOTALL
)

with open(cfg_path, 'w') as f:
    f.write(cfg_code)

print("Done python script")
