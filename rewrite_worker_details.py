import os

file_path = "lib/screens/supervisor/worker_details_screen.dart"

content = """import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/models/worker.dart';
import 'package:ideal_cst/models/worker_attendance.dart';
import 'package:ideal_cst/services/workforce_service.dart';
import 'package:ideal_cst/services/attendance_service.dart';
import 'worker_attendance_history_screen.dart';
import 'package:ideal_cst/models/worker_transfer.dart';

final WorkforceService _workforceService = WorkforceService();
final AttendanceService _attendanceService = AttendanceService();

const Color primaryColor = Color(0xFF4527A0);
const Color backgroundColor = Color.fromARGB(255, 213, 207, 232);

class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;
  final String supervisorId;
  final String supervisorName;

  const WorkerDetailsScreen({
    super.key,
    required this.worker,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _WorkerDetailsScreenState createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Worker Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'Salary'),
            Tab(text: 'Transfers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(worker: widget.worker),
          _AttendanceTab(
            worker: widget.worker,
            supervisorId: widget.supervisorId,
            supervisorName: widget.supervisorName,
          ),
          _SalaryTab(worker: widget.worker),
          _TransfersTab(worker: widget.worker),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _OverviewTab extends StatelessWidget {
  final Worker worker;

  const _OverviewTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: worker.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(worker.photoUrl!, width: 100, height: 100, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.person,
                            size: 50,
                            color: primaryColor,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    worker.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${worker.workerId}',
                      style: const TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Contact Information Card
          _buildInfoCard(
            title: 'Contact Details',
            icon: Icons.contact_phone,
            children: [
              _InfoRow(label: 'Mobile Number', value: worker.mobileNumber),
              _InfoRow(label: 'Emergency Contact', value: worker.emergencyContact ?? 'N/A'),
              _InfoRow(label: 'Aadhar Number', value: worker.aadharNumber ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          // Employment Information Card
          _buildInfoCard(
            title: 'Employment Information',
            icon: Icons.work,
            children: [
              _InfoRow(label: 'Category', value: worker.workerType),
              _InfoRow(label: 'Sub Contractor', value: worker.subContractorName ?? 'N/A'),
              _InfoRow(label: 'Labour Type', value: worker.labourType),
              _InfoRow(label: 'Joining Date', value: '${worker.joiningDate.day}/${worker.joiningDate.month}/${worker.joiningDate.year}'),
              _InfoRow(
                label: 'Status',
                value: worker.isActive ? 'Active' : 'Inactive',
                valueColor: worker.isActive ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Financial Details Card
          _buildInfoCard(
            title: 'Financial Details',
            icon: Icons.account_balance_wallet,
            children: [
              _InfoRow(label: 'Basic Salary', value: '₹${worker.basicSalary}'),
              _InfoRow(label: 'Overtime Rate', value: '₹${worker.overtimeRate}'),
            ],
          ),
          const SizedBox(height: 16),
          // Assigned Sites Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Assigned Sites',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: worker.assignedSiteIds.map((siteId) {
                      return Chip(
                        label: Text(siteId, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              style: TextStyle(
                color: valueColor ?? const Color(0xFF1E1E2D), 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  final Worker worker;
  final String supervisorId;
  final String supervisorName;

  const _AttendanceTab({
    required this.worker,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  List<WorkerAttendance> _recentAttendance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAttendance();
  }

  Future<void> _loadRecentAttendance() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    try {
      final records = await _attendanceService.getWorkerAttendanceByWorker(
        widget.worker.workerId,
        startDate,
        now,
      );
      if (mounted) {
        setState(() {
          _recentAttendance = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkerAttendanceHistoryScreen(worker: widget.worker),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: primaryColor),
                  SizedBox(width: 8),
                  Text('View Full Attendance History', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : _recentAttendance.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records this month',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _buildRecentAttendance(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendance() {
    final grouped = <DateTime, List<WorkerAttendance>>{};
    for (final record in _recentAttendance) {
      final date = DateTime(record.date.year, record.date.month, record.date.day);
      if (!grouped.containsKey(date)) grouped[date] = [];
      grouped[date]!.add(record);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final records = grouped[date]!;
        return _buildDateCard(date, records);
      },
    );
  }

  Widget _buildDateCard(DateTime date, List<WorkerAttendance> records) {
    double totalHours = 0.0;
    double totalOvertime = 0.0;
    for (final record in records) {
      totalHours += record.hoursWorked;
      totalOvertime += record.overtimeHours;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, dd MMM yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E2D)),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${totalHours.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (totalOvertime > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.timelapse, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '+${totalOvertime.toStringAsFixed(1)}h',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...records.map((record) => _buildAttendanceRow(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(WorkerAttendance record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(record.status).withValues(alpha: 0.5)),
              ),
              child: Text(
                _getStatusText(record.status),
                style: TextStyle(
                  color: _getStatusColor(record.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.siteName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                  ),
                  if (record.workType.isNotEmpty)
                    Text(
                      record.workType,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (record.hoursWorked > 0)
              Text(
                '${record.hoursWorked.toStringAsFixed(1)}h',
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present: return Colors.green;
      case AttendanceStatus.absent: return Colors.red;
      case AttendanceStatus.halfDay: return Colors.blue;
      case AttendanceStatus.paidLeave: return Colors.purple;
      case AttendanceStatus.unpaidLeave: return Colors.orange;
      case AttendanceStatus.holiday: return Colors.yellow.shade700;
      case AttendanceStatus.medicalLeave: return Colors.pink;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present: return 'Present';
      case AttendanceStatus.absent: return 'Absent';
      case AttendanceStatus.halfDay: return 'Half Day';
      case AttendanceStatus.paidLeave: return 'Paid Leave';
      case AttendanceStatus.unpaidLeave: return 'Unpaid Leave';
      case AttendanceStatus.holiday: return 'Holiday';
      case AttendanceStatus.medicalLeave: return 'Medical Leave';
    }
  }
}

class _SalaryTab extends StatelessWidget {
  final Worker worker;

  const _SalaryTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Salary history will be displayed here',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TransfersTab extends StatelessWidget {
  final Worker worker;

  const _TransfersTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<List<WorkerTransfer>>(
        stream: _workforceService.getWorkerTransfersBySupervisor(
          worker.supervisorId ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Error loading transfers: ${snapshot.error}',
              style: TextStyle(color: Colors.grey.shade600),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          final transfers = snapshot.data!
              .where((transfer) => transfer.workerId == worker.workerId)
              .toList();
          if (transfers.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final transfer = transfers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.swap_horiz, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Transfer Date: ${transfer.transferDate.day}/${transfer.transferDate.month}/${transfer.transferDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E2D)),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildTransferRow('From', '${transfer.fromSubContractorName ?? 'N/A'} (${transfer.fromSiteName})'),
                      const SizedBox(height: 8),
                      _buildTransferRow('To', '${transfer.toSubContractorName ?? 'N/A'} (${transfer.toSiteName})'),
                      const SizedBox(height: 8),
                      _buildTransferRow('Reason', transfer.reason),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          'No transfer history',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTransferRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D))),
        ),
      ],
    );
  }
}
"""

with open(file_path, "w") as f:
    f.write(content)
