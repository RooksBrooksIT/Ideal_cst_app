import re

with open('lib/screens/auth/supervisor_login_page.dart', 'r') as f:
    content = f.read()

# Add import
import_stmt = "import 'package:ideal_cst/screens/auth/auth_layout.dart';\n"
if "auth_layout.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + import_stmt)

# Replace build method
build_pattern = r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n'
replacement = """  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: AppColors.supervisorPrimaryColor,
      icon: Icons.supervisor_account,
      onBack: () => Navigator.pop(context),
      formContent: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _usernameController,
              label: 'UserName',
              hint: 'Enter your username',
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'UserName is required' : null,
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
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.supervisorPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
"""
content = re.sub(build_pattern, replacement, content, flags=re.DOTALL)

# Clean up unused animation variables to avoid warnings
content = re.sub(r'  late AnimationController _controller;\n', '', content)
content = re.sub(r'  late Animation<double> _opacityAnimation;\n', '', content)
content = re.sub(r'  late Animation<double> _translateAnimation;\n', '', content)

content = re.sub(r'    _controller = AnimationController\([\s\S]*?_controller\.forward\(\);\n', '', content)
content = re.sub(r'    _controller\.dispose\(\);\n', '', content)

with open('lib/screens/auth/supervisor_login_page.dart', 'w') as f:
    f.write(content)

