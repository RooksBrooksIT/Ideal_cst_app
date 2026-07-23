import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageAdminUsersScreen extends StatefulWidget {
  const ManageAdminUsersScreen({super.key});

  @override
  State<ManageAdminUsersScreen> createState() => _ManageAdminUsersScreenState();
}

class _ManageAdminUsersScreenState extends State<ManageAdminUsersScreen> {
  final Color mainColor = const Color(0xFF003768);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  String _searchText = '';

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('admin_login')
          .where('Username', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Username "$username" already exists! Please choose a unique username.'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('admin_login').add({
        'FullName': fullName,
        'Username': username,
        'Password': password,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Organization Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin user created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _fullNameController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _formKey.currentState?.reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create admin user: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
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
                child: Icon(Icons.arrow_back_ios_new, color: mainColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Configuration',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage Admin Users',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 207, 226, 243),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth >= 850;

                    if (isWideScreen) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              child: _buildCreateAdminCard(),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 6,
                            child: _buildExistingAdminsCard(),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCreateAdminCard(),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 600,
                            child: _buildExistingAdminsCard(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAdminCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.person_add_alt_1, color: mainColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Create Admin User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Full Name Field
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                labelStyle: TextStyle(color: mainColor, fontWeight: FontWeight.w500),
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.badge_outlined, color: mainColor),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 247, 250),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Username Field
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username *',
                labelStyle: TextStyle(color: mainColor, fontWeight: FontWeight.w500),
                hintText: 'Enter username',
                prefixIcon: Icon(Icons.person_outline, color: mainColor),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 247, 250),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password *',
                labelStyle: TextStyle(color: mainColor, fontWeight: FontWeight.w500),
                hintText: 'Enter password',
                prefixIcon: Icon(Icons.lock_outline, color: mainColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 247, 250),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: mainColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Create Admin Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.add_circle_outline, color: Colors.white),
                label: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'CREATE ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _createAdmin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingAdminsCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
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
              Icon(Icons.admin_panel_settings, color: mainColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'Existing Admin Users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Name or Username...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search, color: mainColor),
              filled: true,
              fillColor: const Color.fromARGB(255, 245, 247, 250),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: mainColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value.trim();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admin_login')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading admins: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                var filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['FullName'] ?? '').toString().toLowerCase();
                  final uname = (data['Username'] ?? '').toString().toLowerCase();
                  final query = _searchText.toLowerCase();
                  return name.contains(query) || uname.contains(query);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 56, color: mainColor.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No admin users found',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final fullName = data['FullName'] ?? 'N/A';
                    final username = data['Username'] ?? 'N/A';
                    final password = data['Password'] ?? '';
                    final timestamp = data['createdAt'] as Timestamp?;

                    String formattedDate = 'N/A';
                    if (timestamp != null) {
                      formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
                    }

                    return AdminUserCard(
                      fullName: fullName,
                      username: username,
                      password: password,
                      createdAt: formattedDate,
                      mainColor: mainColor,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserCard extends StatefulWidget {
  final String fullName;
  final String username;
  final String password;
  final String createdAt;
  final Color mainColor;

  const AdminUserCard({
    super.key,
    required this.fullName,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.mainColor,
  });

  @override
  State<AdminUserCard> createState() => _AdminUserCardState();
}

class _AdminUserCardState extends State<AdminUserCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.mainColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge, color: widget.mainColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.fullName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.mainColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '@${widget.username}',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RowInfo(
            label: "Username",
            value: widget.username,
            icon: Icons.person_outline,
            mainColor: widget.mainColor,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.lock_outline, color: widget.mainColor, size: 18),
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
              const SizedBox(width: 4),
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
          const SizedBox(height: 6),
          _RowInfo(
            label: "Created At",
            value: widget.createdAt,
            icon: Icons.access_time,
            mainColor: widget.mainColor,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.green[700], size: 18),
              const SizedBox(width: 6),
              Text(
                "Active Admin Account",
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color mainColor;

  const _RowInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: mainColor, size: 18),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E2D)),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
