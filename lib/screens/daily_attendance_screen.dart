import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/worker_attendance.dart';
import '../models/worker.dart';
import '../services/attendance_service.dart';
import '../services/workforce_service.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, dynamic>> sites;

  const DailyAttendanceScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.sites,
  });

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final WorkforceService _workforceService = WorkforceService();

  String? _selectedSite;
  DateTime _selectedDate = DateTime.now();
  List<Worker> _workers = [];
  Map<String, WorkerAttendance> _existingAttendance = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.sites.isNotEmpty) {
      _selectedSite = widget.sites.first['id'];
      _loadWorkers();
    }
  }

  Future<void> _loadWorkers() async {
    if (_selectedSite == null) return;

    setState(() => _isLoading = true);

    try {
      final subContractors = await _workforceService.getSubContractors(
        widget.supervisorId,
      );

      final allWorkers = <Worker>[];
      for (final sc in subContractors) {
        if (sc.id == null) continue;
        final workers = await _workforceService.getWorkers(sc.id!);
        for (final worker in workers) {
          if (worker.assignedSiteIds.contains(_selectedSite) &&
              worker.isActive) {
            allWorkers.add(worker);
          }
        }
      }

      // Load existing attendance
      final existing = await _attendanceService.getWorkerAttendanceByDate(
        widget.supervisorId,
        _selectedDate,
      );
      final existingMap = <String, WorkerAttendance>{};
      for (final att in existing) {
        if (att.siteId == _selectedSite) {
          existingMap[att.workerId] = att;
        }
      }

      setState(() {
        _workers = allWorkers;
        _existingAttendance = existingMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
  }

  final Color primaryColor = const Color(0xFF0b3470);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _workers.isEmpty
                ? const Center(child: Text('No workers found'))
                : _buildWorkersList(),
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
            // Site Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedSite,
              decoration: const InputDecoration(
                labelText: 'Select Site *',
                border: OutlineInputBorder(),
              ),
              items: widget.sites.map<DropdownMenuItem<String>>((site) {
                final siteName =
                    site['siteName'] ?? site['Site Name'] ?? site['id'];
                return DropdownMenuItem<String>(
                  value: site['id'],
                  child: Text(siteName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSite = value);
                _loadWorkers();
              },
            ),
            const SizedBox(height: 12),
            // Date Picker
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadWorkers();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _workers.length,
      itemBuilder: (context, index) {
        final worker = _workers[index];
        final existing = _existingAttendance[worker.workerId];
        return _buildWorkerCard(worker, existing);
      },
    );
  }

  Widget _buildWorkerCard(Worker worker, WorkerAttendance? existing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(worker.name[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${worker.workerType} • ${worker.workerId}'),
                    ],
                  ),
                ),
                if (existing != null)
                  Chip(
                    label: Text(
                      _getStatusText(existing.status),
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(existing.status),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openAttendanceForm(worker, existing),
                    icon: Icon(existing != null ? Icons.edit : Icons.add),
                    label: Text(
                      existing != null ? 'Edit Attendance' : 'Mark Attendance',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAttendanceForm(Worker worker, WorkerAttendance? existing) {
    showDialog(
      context: context,
      builder: (context) => AttendanceFormDialog(
        worker: worker,
        siteId: _selectedSite!,
        siteName:
            widget.sites.firstWhere(
              (s) => s['id'] == _selectedSite,
              orElse: () => {'siteName': 'Unknown'},
            )['siteName'] ??
            'Unknown',
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        date: _selectedDate,
        existingAttendance: existing,
        onSave: (attendance) async {
          if (existing == null) {
            await _attendanceService.createWorkerAttendance(attendance);
          } else {
            await _attendanceService.updateWorkerAttendance(attendance);
          }
          await _attendanceService.calculateAndSaveDailySummary(
            worker.workerId,
            _selectedDate,
          );
          if (mounted) {
            Navigator.pop(context);
            _loadWorkers();
          }
        },
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

class AttendanceFormDialog extends StatefulWidget {
  final Worker worker;
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final DateTime date;
  final WorkerAttendance? existingAttendance;
  final Function(WorkerAttendance) onSave;

  const AttendanceFormDialog({
    super.key,
    required this.worker,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    this.existingAttendance,
    required this.onSave,
  });

  @override
  State<AttendanceFormDialog> createState() => _AttendanceFormDialogState();
}

class _AttendanceFormDialogState extends State<AttendanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late AttendanceStatus _status;
  final _hoursWorkedController = TextEditingController();
  final _workTypeController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.existingAttendance?.status ?? AttendanceStatus.present;
    _hoursWorkedController.text =
        widget.existingAttendance?.hoursWorked.toString() ?? '8';
    _workTypeController.text = widget.existingAttendance?.workType ?? '';
    _remarksController.text = widget.existingAttendance?.remarks ?? '';
  }

  @override
  void dispose() {
    _hoursWorkedController.dispose();
    _workTypeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark Attendance'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Worker: ${widget.worker.name}'),
              const SizedBox(height: 16),
              // Status Dropdown
              DropdownButtonFormField<AttendanceStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                ),
                items: AttendanceStatus.values
                    .map<DropdownMenuItem<AttendanceStatus>>((status) {
                      return DropdownMenuItem<AttendanceStatus>(
                        value: status,
                        child: Text(_getStatusText(status)),
                      );
                    })
                    .toList(),
                onChanged: (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 12),
              // Hours Worked
              if (_status == AttendanceStatus.present ||
                  _status == AttendanceStatus.halfDay)
                TextFormField(
                  controller: _hoursWorkedController,
                  decoration: const InputDecoration(
                    labelText: 'Hours Worked *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hours';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              // Work Type
              if (_status == AttendanceStatus.present ||
                  _status == AttendanceStatus.halfDay)
                TextFormField(
                  controller: _workTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Work Type',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              // Remarks
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveAttendance, child: const Text('Save')),
      ],
    );
  }

  void _saveAttendance() {
    if (!_formKey.currentState!.validate()) return;

    final hoursWorked = double.tryParse(_hoursWorkedController.text) ?? 0.0;
    final regularHours = WorkerAttendance.calculateRegularHours(hoursWorked);
    final overtimeHours = WorkerAttendance.calculateOvertimeHours(hoursWorked);
    final overtimeAmount = WorkerAttendance.calculateOvertimeAmount(
      overtimeHours,
      widget.worker.basicSalary,
    );

    final attendance = WorkerAttendance(
      id: widget.existingAttendance?.id,
      workerId: widget.worker.workerId,
      workerName: widget.worker.name,
      workerType: widget.worker.workerType,
      subContractorId: widget.worker.subContractorId ?? '',
      subContractorName: widget.worker.subContractorName ?? '',
      siteId: widget.siteId,
      siteName: widget.siteName,
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
      date: widget.date,
      hoursWorked: hoursWorked,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      overtimeAmount: overtimeAmount,
      workType: _workTypeController.text,
      status: _status,
      remarks: _remarksController.text,
    );

    widget.onSave(attendance);
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
