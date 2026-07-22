import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/supervisor/site_selection_screen.dart';
import 'package:ideal_cst/screens/supervisor/workers_management.dart';
import 'package:ideal_cst/screens/supervisor/site_progress_screen.dart';
import 'package:ideal_cst/screens/supervisor/material_request_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SupervisorDashboard extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String? username;

  const SupervisorDashboard({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    this.username,
  });

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final Color primaryColor = const Color(0xFF4527A0);
  List<DocumentSnapshot> assignedSites = [];
  List<DocumentSnapshot> assignedContractors = [];
  String? coordinatorName;
  DateTime? coordinatorDate;
  bool isLoading = true;
  Map<String, dynamic> todayStats = {
    'totalWorkers': 0,
    'present': 0,
    'halfDay': 0,
    'earlyOut': 0,
    'overtime': 0,
    'materialRequests': 0,
  };

  late PageController _pageController;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000, viewportFraction: 0.85);
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
    loadData();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await fetchAssignedSites();
    await fetchAssignedContractors();
    await fetchTodayStats();
    await fetchCoordinatorName();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchCoordinatorName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('supervisor')
          .doc(widget.supervisorId)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          coordinatorName = doc.data()!['CoordinatorName'] as String?;
          final dateVal = doc.data()!['CoordinatorDate'];
          if (dateVal != null) {
            if (dateVal is Timestamp) {
              coordinatorDate = dateVal.toDate();
            } else if (dateVal is String) {
              coordinatorDate = DateTime.tryParse(dateVal);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching coordinator name: $e');
    }
  }

  Future<void> fetchAssignedContractors() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('contractors')
          .where('supervisorName', isEqualTo: widget.supervisorName)
          .get();

      // If no results by name, try by supervisor ID
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('contractors')
            .where('supervisorId', isEqualTo: widget.supervisorId)
            .get();
      }

      setState(() {
        assignedContractors = querySnapshot.docs;
      });
    } catch (e) {
      debugPrint('Error fetching assigned contractors: $e');
    }
  }

  Future<void> fetchAssignedSites() async {
    try {
      // First try to find by supervisor name, then by supervisor ID
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();

      // If no results by name, try by Supervisor ID
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .where('Supervisor ID', isEqualTo: widget.supervisorId)
            .get();
      }

      setState(() {
        assignedSites = querySnapshot.docs;
      });
    } catch (e) {
      debugPrint('Error fetching assigned sites: $e');
    }
  }

  Future<void> fetchTodayStats() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      int totalWorkers = 0;
      int present = 0;
      int halfDay = 0;
      int earlyOut = 0;
      int overtime = 0;
      int materialRequests = 0;

      // Fetch material requests
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('material_requests')
          .where('supervisorId', isEqualTo: widget.supervisorId)
          .where('status', isEqualTo: 'Pending')
          .get();
      materialRequests = requestsSnapshot.docs.length;

      // Fetch attendance for today across all assigned sites
      for (final site in assignedSites) {
        final siteId = site.id;
        final docId = '${siteId}_$today';
        
        // Try daily_labour_entries first
        var workersSnapshot = await FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc(docId)
            .collection('workers')
            .get();
            
        // Fallback to attendance collection for older entries
        if (workersSnapshot.docs.isEmpty) {
          workersSnapshot = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(docId)
              .collection('workers')
              .get();
        }

        totalWorkers += workersSnapshot.docs.length;

        for (final workerDoc in workersSnapshot.docs) {
          final workerData = workerDoc.data();
          final type = workerData['attendanceType'];
          
          if (type == 'Full Day' || type == 'Night Shift') {
            present++;
          } else if (type == 'Half Day') {
            halfDay++;
            present++;
          } else if (type == 'Early Out') {
            earlyOut++;
            present++;
          } else if (type == 'Overtime') {
            overtime++;
            present++;
          }

          // Check for overtime hours
          final otHoursRaw = workerData['otHours'];
          double otHours = 0.0;
          if (otHoursRaw is num) {
            otHours = otHoursRaw.toDouble();
          } else if (otHoursRaw is String) {
            otHours = double.tryParse(otHoursRaw.split(' ').first) ?? 0.0;
          }
          if (otHours > 0 && type != 'Overtime') {
            overtime++;
          }
        }
      }

      setState(() {
        todayStats = {
          'totalWorkers': totalWorkers,
          'present': present,
          'halfDay': halfDay,
          'earlyOut': earlyOut,
          'overtime': overtime,
          'materialRequests': materialRequests,
        };
      });
    } catch (e) {
      debugPrint('Error fetching today stats: $e');
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4527A0).withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (route) => false,
              );
            },
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAssignCoordinatorDialog(BuildContext context) {
    String? selectedSite;
    final TextEditingController coordinatorController =
        TextEditingController();
    DateTime? selectedDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Project Coordinator'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (assignedSites.isEmpty)
                    const Text('No sites assigned.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedSite,
                      decoration: const InputDecoration(
                        labelText: 'Select Site',
                        border: OutlineInputBorder(),
                      ),
                      items: assignedSites.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final siteName =
                            data['site'] ?? data['siteId'] ?? doc.id;
                        return DropdownMenuItem<String>(
                          value: siteName.toString(),
                          child: Text(siteName.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedSite = val;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: coordinatorController,
                    decoration: const InputDecoration(
                      labelText: 'Coordinator Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'Select Date'
                              : 'Date: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_today, color: primaryColor),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving || assignedSites.isEmpty
                      ? null
                      : () async {
                          if (selectedSite == null ||
                              coordinatorController.text.trim().isEmpty ||
                              selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill all fields and select a date.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            isSaving = true;
                          });
                          try {
                            await FirebaseFirestore.instance
                                .collection('Site_Co-ordinator')
                                .add({
                                  'siteName': selectedSite,
                                  'supervisorName': widget.supervisorName,
                                  'coordinatorName': coordinatorController.text
                                      .trim(),
                                  'coordinatorDate': Timestamp.fromDate(
                                    selectedDate!,
                                  ),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                            // Also update the supervisor document so it reflects on the dashboard
                            await FirebaseFirestore.instance
                                .collection('supervisor')
                                .doc(widget.supervisorId)
                                .update({
                                  'CoordinatorName': coordinatorController.text
                                      .trim(),
                                  'CoordinatorDate': Timestamp.fromDate(
                                    selectedDate!,
                                  ),
                                });

                            fetchCoordinatorName();
                            
                            if (!context.mounted) return;

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Coordinator assigned successfully!',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                            setState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showLogoutDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 213, 207, 232), // Light primary color background
        body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: loadData,
                  color: primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildStatsCarousel(),
                      const SizedBox(height: 32),
                      _buildQuickActionsHeader(),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        title: 'Workers Management',
                        subtitle: 'Manage workers & attendance',
                        icon: Icons.manage_accounts,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkersManagementScreen(
                                supervisorId: widget.supervisorId,
                                supervisorName: widget.supervisorName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionCard(
                        title: 'Select Site',
                        subtitle: '${assignedSites.length} Sites Assigned',
                        icon: Icons.location_on,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SiteSelectionScreen(
                                supervisorId: widget.supervisorId,
                                supervisorName: widget.supervisorName,
                                assignedSites: assignedSites,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionCard(
                        title: 'Site Progress',
                        subtitle: 'Update site progress',
                        icon: Icons.bar_chart,
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SiteProgressScreen(
                                supervisorId: widget.supervisorId,
                                supervisorName: widget.supervisorName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionCard(
                        title: 'Material Request',
                        subtitle: 'Request materials',
                        icon: Icons.shopping_cart,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MaterialRequestForm(
                                supervisorId: widget.supervisorId,
                                supervisorName: widget.supervisorName,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  widget.supervisorName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => _showLogoutDialog(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4527A0).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 26),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStatsCarousel() {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Total Workers',
        'value': todayStats['totalWorkers'].toString(),
        'icon': Icons.people_alt,
        'color': const Color(0xFF7E57C2), // Purple
        'trend': '+12%',
        'isPositive': true,
      },
      {
        'title': 'Present Today',
        'value': todayStats['present'].toString(),
        'icon': Icons.verified,
        'color': const Color(0xFF26A69A), // Teal
        'trend': '+5%',
        'isPositive': true,
      },
      {
        'title': 'Overtime',
        'value': todayStats['overtime'].toString(),
        'icon': Icons.more_time,
        'color': const Color(0xFFEF5350), // Red
        'trend': '+8%',
        'isPositive': true,
      },
      {
        'title': 'Material Reqs',
        'value': todayStats['materialRequests'].toString(),
        'icon': Icons.inventory_2,
        'color': const Color(0xFF8D6E63), // Brown
        'trend': '0%',
        'isPositive': true,
      },
    ];

    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          final item = items[index % items.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildModernStatCard(
              item['title'],
              item['value'],
              item['icon'],
              item['color'],
              item['trend'],
              isPositive: item['isPositive'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend, {
    bool isPositive = true,
  }) {
    return AnimatedGradientCard(
      baseColor: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildQuickActionsHeader() {
    return const Text(
      'Quick Actions',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E1E2D),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_vert, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class AnimatedGradientCard extends StatefulWidget {
  final Widget child;
  final Color baseColor;

  const AnimatedGradientCard({
    Key? key,
    required this.child,
    required this.baseColor,
  }) : super(key: key);

  @override
  _AnimatedGradientCardState createState() => _AnimatedGradientCardState();
}

class _AnimatedGradientCardState extends State<AnimatedGradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                widget.baseColor,
                widget.baseColor.withValues(alpha: 0.6),
                widget.baseColor,
              ],
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.baseColor.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
