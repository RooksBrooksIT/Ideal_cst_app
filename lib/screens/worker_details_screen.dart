import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/worker.dart';
import '../models/worker_attendance.dart';
import '../models/worker_transfer.dart';
import '../services/workforce_service.dart';
import '../services/attendance_service.dart';
import 'worker_attendance_history_screen.dart';

final WorkforceService _workforceService = WorkforceService();
final AttendanceService _attendanceService = AttendanceService();

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
  final Color primaryColor = const Color(0xFF0b3470);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Worker Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'Salary'),
            Tab(text: 'Transfers'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: 0.85),
              primaryColor.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: TabBarView(
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
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF0b3470).withValues(alpha: 0.1),
                  child: worker.photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.network(worker.photoUrl!),
                        )
                      : const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF0b3470),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                worker.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${worker.workerId}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _InfoRow(label: 'Category', value: worker.workerType),
              _InfoRow(
                label: 'Sub Contractor',
                value: worker.subContractorName ?? 'N/A',
              ),
              _InfoRow(label: 'Labour Type', value: worker.labourType),
              _InfoRow(label: 'Basic Salary', value: '₹${worker.basicSalary}'),
              _InfoRow(
                label: 'Overtime Rate',
                value: '₹${worker.overtimeRate}',
              ),
              _InfoRow(label: 'Mobile Number', value: worker.mobileNumber),
              _InfoRow(
                label: 'Emergency Contact',
                value: worker.emergencyContact ?? 'N/A',
              ),
              _InfoRow(
                label: 'Aadhar Number',
                value: worker.aadharNumber ?? 'N/A',
              ),
              _InfoRow(
                label: 'Joining Date',
                value:
                    '${worker.joiningDate.day}/${worker.joiningDate.month}/${worker.joiningDate.year}',
              ),
              _InfoRow(
                label: 'Status',
                value: worker.isActive ? 'Active' : 'Inactive',
                valueColor: worker.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Assigned Sites',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: worker.assignedSiteIds.map((siteId) {
                  return Chip(
                    label: Text(siteId),
                    backgroundColor: const Color(0xFF0b3470).withValues(alpha: 0.1),
                  );
                }).toList(),
              ),
            ],
          ),
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
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(value, style: TextStyle(color: valueColor)),
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
      setState(() {
        _recentAttendance = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkerAttendanceHistoryScreen(worker: widget.worker),
                ),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('View Full Attendance History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0b3470),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentAttendance.isEmpty
                ? const Center(
                    child: Text(
                      'No attendance records this month',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : _buildRecentAttendance(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendance() {
    // Group by date
    final grouped = <DateTime, List<WorkerAttendance>>{};
    for (final record in _recentAttendance) {
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 4),
                    Text('${totalHours.toStringAsFixed(1)}h'),
                    if (totalOvertime > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.timelapse,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${totalOvertime.toStringAsFixed(1)}h',
                        style: const TextStyle(color: Colors.orange),
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(record.status)),
              ),
              child: Text(
                _getStatusText(record.status),
                style: TextStyle(
                  color: _getStatusColor(record.status),
                  fontWeight: FontWeight.bold,
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (record.workType.isNotEmpty)
                    Text(
                      record.workType,
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (record.hoursWorked > 0)
              Text(
                '${record.hoursWorked.toStringAsFixed(1)}h',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.halfDay:
        return Colors.blue;
      case AttendanceStatus.paidLeave:
        return Colors.purple;
      case AttendanceStatus.unpaidLeave:
        return Colors.orange;
      case AttendanceStatus.holiday:
        return Colors.yellow;
      case AttendanceStatus.medicalLeave:
        return Colors.pink;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.paidLeave:
        return 'Paid Leave';
      case AttendanceStatus.unpaidLeave:
        return 'Unpaid Leave';
      case AttendanceStatus.holiday:
        return 'Holiday';
      case AttendanceStatus.medicalLeave:
        return 'Medical Leave';
    }
  }
}

class _SalaryTab extends StatelessWidget {
  final Worker worker;

  const _SalaryTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Salary history will be displayed here',
        style: TextStyle(color: Colors.white),
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
              style: const TextStyle(color: Colors.white),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text(
              'No transfer history',
              style: TextStyle(color: Colors.white),
            );
          }
          final transfers = snapshot.data!
              .where((transfer) => transfer.workerId == worker.workerId)
              .toList();
          if (transfers.isEmpty) {
            return const Text(
              'No transfer history',
              style: TextStyle(color: Colors.white),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final transfer = transfers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Date: ${transfer.transferDate.day}/${transfer.transferDate.month}/${transfer.transferDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From: ${transfer.fromSubContractorName ?? 'N/A'} (${transfer.fromSiteName})',
                      ),
                      Text(
                        'To: ${transfer.toSubContractorName ?? 'N/A'} (${transfer.toSiteName})',
                      ),
                      Text('Reason: ${transfer.reason}'),
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
}
