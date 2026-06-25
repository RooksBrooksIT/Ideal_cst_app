
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/worker_attendance.dart';
import '../models/attendance_summary.dart';
import '../models/worker.dart';
import '../services/attendance_service.dart';

class WorkerAttendanceHistoryScreen extends StatefulWidget {
  final Worker worker;

  const WorkerAttendanceHistoryScreen({
    super.key,
    required this.worker,
  });

  @override
  State<WorkerAttendanceHistoryScreen> createState() =>
      _WorkerAttendanceHistoryScreenState();
}

class _WorkerAttendanceHistoryScreenState
    extends State<WorkerAttendanceHistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  List<WorkerAttendance> _attendanceRecords = [];
  List<AttendanceSummary> _summaryRecords = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    _loadAttendance();
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final records = await _attendanceService.getWorkerAttendanceByWorker(
        widget.worker.workerId,
        _startDate!,
        _endDate!,
      );
      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.worker.name} - Attendance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _attendanceRecords.isEmpty
                    ? const Center(child: Text('No attendance records found'))
                    : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('From'),
                    subtitle: Text(
                      _startDate != null
                          ? DateFormat('dd MMM yyyy').format(_startDate!)
                          : 'Select date',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('To'),
                    subtitle: Text(
                      _endDate != null
                          ? DateFormat('dd MMM yyyy').format(_endDate!)
                          : 'Select date',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadAttendance,
              icon: const Icon(Icons.refresh),
              label: const Text('Load Attendance'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    // Group by date
    final grouped = <DateTime, List<WorkerAttendance>>{};
    for (final record in _attendanceRecords) {
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

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final records = grouped[date]!;
        return _buildDateSection(date, records);
      },
    );
  }

  Widget _buildDateSection(DateTime date, List<WorkerAttendance> records) {
    // Calculate totals for the day
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 4),
                    Text('${totalHours.toStringAsFixed(1)}h'),
                    const SizedBox(width: 12),
                    if (totalOvertime > 0) ...[
                      const Icon(Icons.timelapse, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '+${totalOvertime.toStringAsFixed(1)}h OT',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...records.map((record) => _buildAttendanceCard(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(WorkerAttendance record) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(record.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getStatusColor(record.status),
                ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (record.workType.isNotEmpty)
                    Text(
                      record.workType,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            if (record.hoursWorked > 0)
              Text(
                '${record.hoursWorked.toStringAsFixed(1)}h',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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

