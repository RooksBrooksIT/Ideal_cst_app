import 'dart:async';
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
  final Color receptionistColor = const Color(0xFFD84315);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  String _searchText = '';

  String _selectedRole = 'Admin'; // 'Admin' or 'Receptionist'
  String _selectedFilterRole = 'All'; // 'All', 'Admin', 'Receptionist'

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getUsersStream() {
    late StreamController<List<Map<String, dynamic>>> controller;
    List<Map<String, dynamic>> adminDocs = [];
    List<Map<String, dynamic>> receptionistDocs = [];
    StreamSubscription? adminSub;
    StreamSubscription? receptionistSub;

    void emitCombined() {
      final combined = [...adminDocs, ...receptionistDocs];
      combined.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      if (!controller.isClosed) {
        controller.add(combined);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        adminSub = FirebaseFirestore.instance
            .collection('admin_login')
            .snapshots()
            .listen((snap) {
          adminDocs = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['role'] = data['role'] ?? 'Admin';
            return data;
          }).toList();
          emitCombined();
        });

        receptionistSub = FirebaseFirestore.instance
            .collection('receptionist_login')
            .snapshots()
            .listen((snap) {
          receptionistDocs = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['role'] = data['role'] ?? 'Receptionist';
            return data;
          }).toList();
          emitCombined();
        });
      },
      onCancel: () {
        adminSub?.cancel();
        receptionistSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final role = _selectedRole;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check username uniqueness in both collections
      final adminQuery = await FirebaseFirestore.instance
          .collection('admin_login')
          .where('Username', isEqualTo: username)
          .get();

      final receptionistQuery = await FirebaseFirestore.instance
          .collection('receptionist_login')
          .where('Username', isEqualTo: username)
          .get();

      if (adminQuery.docs.isNotEmpty || receptionistQuery.docs.isNotEmpty) {
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

      final collectionName = role == 'Receptionist' ? 'receptionist_login' : 'admin_login';

      await FirebaseFirestore.instance.collection(collectionName).add({
        'FullName': fullName,
        'Username': username,
        'Password': password,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Organization Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$role user created successfully!'),
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
            content: Text('Failed to create $role user: $e'),
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
        Expanded(
          child: Row(
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage Users & Accounts',
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
          ),
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
                              child: _buildCreateUserCard(),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 6,
                            child: _buildExistingUsersCard(),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCreateUserCard(),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 600,
                            child: _buildExistingUsersCard(),
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

  Widget _buildCreateUserCard() {
    final activeThemeColor = _selectedRole == 'Receptionist' ? receptionistColor : mainColor;

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
                Icon(
                  _selectedRole == 'Receptionist' ? Icons.support_agent_rounded : Icons.person_add_alt_1,
                  color: activeThemeColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Create $_selectedRole User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: activeThemeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Role Selection Toggle
            const Text(
              'Select User Role *',
              style: TextStyle(
                color: Color(0xFF1E1E2D),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = 'Admin'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'Admin' ? mainColor : const Color.fromARGB(255, 245, 247, 250),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'Admin' ? mainColor : mainColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                            color: _selectedRole == 'Admin' ? Colors.white : mainColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Admin',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _selectedRole == 'Admin' ? Colors.white : mainColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = 'Receptionist'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'Receptionist' ? receptionistColor : const Color.fromARGB(255, 245, 247, 250),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'Receptionist' ? receptionistColor : mainColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            size: 18,
                            color: _selectedRole == 'Receptionist' ? Colors.white : receptionistColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Receptionist',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _selectedRole == 'Receptionist' ? Colors.white : receptionistColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Full Name Field
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                labelStyle: TextStyle(color: activeThemeColor, fontWeight: FontWeight.w500),
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.badge_outlined, color: activeThemeColor),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 247, 250),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor, width: 1.5),
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
                labelStyle: TextStyle(color: activeThemeColor, fontWeight: FontWeight.w500),
                hintText: 'Enter username',
                prefixIcon: Icon(Icons.person_outline, color: activeThemeColor),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 247, 250),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor, width: 1.5),
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
                labelStyle: TextStyle(color: activeThemeColor, fontWeight: FontWeight.w500),
                hintText: 'Enter password',
                prefixIcon: Icon(Icons.lock_outline, color: activeThemeColor),
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
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: activeThemeColor, width: 1.5),
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

            // Create Button
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
                    : Text(
                        'CREATE ${_selectedRole.toUpperCase()} USER',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeThemeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _createUser,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingUsersCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_accounts, color: mainColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Existing Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Admin'),
                const SizedBox(width: 8),
                _buildFilterChip('Receptionist'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading users: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? [];
                var filteredUsers = users.where((user) {
                  final name = (user['FullName'] ?? '').toString().toLowerCase();
                  final uname = (user['Username'] ?? '').toString().toLowerCase();
                  final role = (user['role'] ?? 'Admin').toString();
                  final query = _searchText.toLowerCase();

                  final matchesQuery = name.contains(query) || uname.contains(query);
                  final matchesRole = _selectedFilterRole == 'All' || role == _selectedFilterRole;

                  return matchesQuery && matchesRole;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 56, color: mainColor.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No users found',
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
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final data = filteredUsers[index];
                    final fullName = data['FullName'] ?? 'N/A';
                    final username = data['Username'] ?? 'N/A';
                    final password = data['Password'] ?? '';
                    final role = data['role'] ?? 'Admin';
                    final timestamp = data['createdAt'] as Timestamp?;

                    String formattedDate = 'N/A';
                    if (timestamp != null) {
                      formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
                    }

                    return UserCard(
                      fullName: fullName,
                      username: username,
                      password: password,
                      role: role,
                      createdAt: formattedDate,
                      mainColor: mainColor,
                      receptionistColor: receptionistColor,
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilterRole == label;

    Color activeColor;
    if (label == 'Receptionist') {
      activeColor = receptionistColor;
    } else {
      activeColor = mainColor;
    }

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilterRole = label;
          });
        }
      },
      selectedColor: activeColor,
      backgroundColor: const Color.fromARGB(255, 245, 247, 250),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class UserCard extends StatefulWidget {
  final String fullName;
  final String username;
  final String password;
  final String role;
  final String createdAt;
  final Color mainColor;
  final Color receptionistColor;

  const UserCard({
    super.key,
    required this.fullName,
    required this.username,
    required this.password,
    required this.role,
    required this.createdAt,
    required this.mainColor,
    required this.receptionistColor,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final isReceptionist = widget.role == 'Receptionist';
    final roleColor = isReceptionist ? widget.receptionistColor : widget.mainColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roleColor.withValues(alpha: 0.15)),
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
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isReceptionist ? Icons.support_agent_rounded : Icons.admin_panel_settings,
                      color: roleColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReceptionist ? const Color(0xFFFBE9E7) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isReceptionist ? const Color(0xFFFFAB91) : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReceptionist ? Icons.badge : Icons.shield_outlined,
                      size: 12,
                      color: isReceptionist ? widget.receptionistColor : Colors.blue.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.role.toUpperCase(),
                      style: TextStyle(
                        color: isReceptionist ? widget.receptionistColor : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RowInfo(
            label: "Username",
            value: widget.username,
            icon: Icons.person_outline,
            mainColor: roleColor,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.lock_outline, color: roleColor, size: 18),
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
            mainColor: roleColor,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.green[700], size: 18),
              const SizedBox(width: 6),
              Text(
                "Active ${widget.role} Account",
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
