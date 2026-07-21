import re

sup_path = 'lib/screens/auth/supervisor_login_page.dart'
with open(sup_path, 'r') as f:
    sup_code = f.read()

# Add import
sup_code = sup_code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:ideal_cst/screens/auth/auth_layout.dart';")

new_build_sup = """
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      themeColor: const Color(0xFF4527A0), // Supervisor Color (Deep Purple)
      icon: Icons.supervisor_account,
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
                  (value == null || value.isEmpty) ? 'Required' : null,
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
                  color: const Color(0xFF4527A0),
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                title: const Text(
                  'Are you a Contractor?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                value: _isContractor,
                activeColor: const Color(0xFF4527A0),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contractor Name',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _supervisorNames
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ),
                        )
                        .toList(),
                    value: _selectedSupervisorName,
                    onChanged: (val) => setState(
                      () => _selectedSupervisorName = val,
                    ),
                    validator: (val) {
                      if (_isContractor && (val == null || val.isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF4527A0),
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
              color: const Color(0xFF4527A0),
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
"""

sup_code = re.sub(
    r'@override\s*Widget build\(BuildContext context\).*?(?=void _showForgotPasswordDialog\(\))',
    new_build_sup.strip() + "\n\n  ",
    sup_code,
    flags=re.DOTALL
)

with open(sup_path, 'w') as f:
    f.write(sup_code)

print("Done supervisor refactor")
