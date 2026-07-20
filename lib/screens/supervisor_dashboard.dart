import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/site_selection_screen.dart';
import 'package:ideal_cst/screens/supervisor_login_page.dart';
import 'package:ideal_cst/screens/workers_config_page.dart';
import 'package:ideal_cst/screens/contractor_page.dart';
import 'package:ideal_cst/screens/contractor_dashboard.dart';
import 'package:ideal_cst/screens/sub_contractor_management_screen.dart';
import 'package:ideal_cst/screens/daily_attendance_screen.dart';
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
  _SupervisorDashboardState createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final Color primaryColor = const Color(0xFF0b3470);
  List<DocumentSnapshot> assignedSites = [];
  List<DocumentSnapshot> assignedContractors = [];
  bool isLoading = true;
  Map<String, dynamic> todayStats = {
    'totalWorkers': 0,
    'present': 0,
    'halfDay': 0,
    'earlyOut': 0,
    'overtime': 0,
    'materialRequests': 0,
  };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await fetchAssignedSites();
    await fetchAssignedContractors();
    await fetchTodayStats();
    setState(() {
      isLoading = false;
    });
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
        final attendanceDocId = '${siteId}_$today';
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceDocId)
            .get();

        if (attendanceDoc.exists) {
          final data = attendanceDoc.data()!;
          totalWorkers += (data['totalWorkers'] as num?)?.toInt() ?? 0;

          // Fetch workers subcollection
          final workersSnapshot = await attendanceDoc.reference
              .collection('workers')
              .get();
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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor.withOpacity(0.85),
                primaryColor.withOpacity(0.55),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                "Supervisor Dashboard",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              backgroundColor: primaryColor,
              centerTitle: true,
              elevation: 6,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: "Logout",
                  onPressed: () => _showLogoutDialog(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
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
                                  backgroundColor: primaryColor,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.supervisorName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF222222),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Assigned Sites: ${assignedSites.length}',
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

                        // Today's Stats Section
                        const Text(
                          "Today's Overview",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Stats Grid
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
                              'Half Day',
                              todayStats['halfDay'].toString(),
                              Icons.access_time_filled,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'Early Out',
                              todayStats['earlyOut'].toString(),
                              Icons.logout,
                              Colors.purple,
                            ),
                            _buildStatCard(
                              'Overtime',
                              todayStats['overtime'].toString(),
                              Icons.timer,
                              Colors.red,
                            ),
                            _buildStatCard(
                              'Pending Requests',
                              todayStats['materialRequests'].toString(),
                              Icons.inventory,
                              Colors.teal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Select Site Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
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
                            icon: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Select Site',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Salary Management Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Convert DocumentSnapshot list to Map list
                              final sitesList = assignedSites.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return {'id': doc.id, ...data};
                              }).toList();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DailyAttendanceScreen(
                                    supervisorId: widget.supervisorId,
                                    supervisorName: widget.supervisorName,
                                    sites: sitesList,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.attach_money,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Salary Management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sub Contractor Config Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SubContractorManagementScreen(
                                        supervisorId: widget.supervisorId,
                                        supervisorName: widget.supervisorName,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.engineering,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Sub Contractor Management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Assigned Contractors Section
                        const Text(
                          "Assigned Sub-Contractors",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (assignedContractors.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No sub-contractors assigned yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          ...assignedContractors.map((contractor) {
                            final data =
                                contractor.data() as Map<String, dynamic>;
                            final contractorId =
                                data['contractorId'] as String? ?? '';
                            final contractorName =
                                data['contractorName'] as String? ?? 'Unknown';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ContractorDashboard(
                                        contractorId: contractorId,
                                        contractorName: contractorName,
                                      ),
                                    ),
                                  );
                                },
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.engineering,
                                    color: primaryColor,
                                  ),
                                ),
                                title: Text(
                                  contractorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['contractorField'] ?? ''),
                                    Text('Contact: ${data['contactNo'] ?? ''}'),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: primaryColor,
                                ),
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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
