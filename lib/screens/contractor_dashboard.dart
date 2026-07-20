import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contractor_login_page.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const primaryColor = Color(0xFF003768);
  static const accentColor = Color(0xFFDDEBF6);
}

class ContractorDashboard extends StatefulWidget {
  final String contractorId;
  final String contractorName;

  const ContractorDashboard({
    super.key,
    required this.contractorId,
    required this.contractorName,
  });

  @override
  State<ContractorDashboard> createState() => _ContractorDashboardState();
}

class _ContractorDashboardState extends State<ContractorDashboard> {
  List<DocumentSnapshot> workers = [];
  bool isLoading = true;
  Map<String, dynamic> todayStats = {
    'totalWorkers': 0,
    'present': 0,
    'absent': 0,
  };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await fetchWorkers();
    await fetchTodayStats();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchWorkers() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('workersConfig')
          .where('contractorId', isEqualTo: widget.contractorId)
          .orderBy('workerId')
          .get();

      setState(() {
        workers = querySnapshot.docs;
      });
    } catch (e) {
      debugPrint('Error fetching workers: $e');
    }
  }

  Future<void> fetchTodayStats() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      int totalWorkers = workers.length;
      int present = 0;
      int absent = 0;

      // Fetch attendance for today
      for (final worker in workers) {
        // For now, we'll just count total workers
        // You can expand this to check attendance records
      }

      setState(() {
        todayStats = {
          'totalWorkers': totalWorkers,
          'present': present,
          'absent': absent,
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
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showLogoutDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.accentColor,
        appBar: AppBar(
          title: const Text('Sub-Contractor Dashboard'),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.primaryColor,
                              child: const Icon(
                                Icons.engineering,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.contractorName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${widget.contractorId}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Today's Stats
                    const Text(
                      "Today's Overview",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                      children: [
                        _buildStatCard(
                          'Total Workers',
                          todayStats['totalWorkers'].toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Present',
                          todayStats['present'].toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Absent',
                          todayStats['absent'].toString(),
                          Icons.cancel,
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Workers List
                    const Text(
                      "Your Workers",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (workers.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'No workers assigned yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...workers.map((worker) {
                        final data = worker.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primaryColor,
                              ),
                            ),
                            title: Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['designation'] ?? ''),
                                Text('Mobile: ${data['phoneNumber'] ?? ''}'),
                                Text('ID: ${data['workerId'] ?? ''}'),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              flex: 2,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              flex: 2,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
