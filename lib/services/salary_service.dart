import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/salary_record.dart';
import '../models/worker_advance.dart';
import '../models/worker_deduction.dart';
import '../models/daily_labour_cost.dart';
import '../models/weekly_labour_cost.dart';
import '../models/monthly_labour_cost.dart';
import '../models/worker.dart';
import '../models/worker_attendance.dart';
import 'workforce_service.dart';

class SalaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Salary Record Operations
  Future<String> createSalaryRecord(SalaryRecord record) async {
    final docRef = _db.collection('salary_records').doc();
    await docRef.set(
      record.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateSalaryRecord(SalaryRecord record) async {
    if (record.id == null) return;
    await _db
        .collection('salary_records')
        .doc(record.id)
        .update(
          record.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
        );
  }

  Stream<List<SalaryRecord>> getSalaryRecordsBySupervisor(String supervisorId) {
    return _db
        .collection('salary_records')
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('generatedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryRecord.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<SalaryRecord>> getSalaryRecordsByWorker(String workerId) {
    return _db
        .collection('salary_records')
        .where('workerId', isEqualTo: workerId)
        .orderBy('generatedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryRecord.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // Worker Advance Operations
  Future<String> createWorkerAdvance(WorkerAdvance advance) async {
    final docRef = _db.collection('worker_advances').doc();
    await docRef.set(
      advance.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateWorkerAdvance(WorkerAdvance advance) async {
    if (advance.id == null) return;
    await _db
        .collection('worker_advances')
        .doc(advance.id)
        .update(
          advance.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
        );
  }

  Stream<List<WorkerAdvance>> getAdvancesByWorker(String workerId) {
    return _db
        .collection('worker_advances')
        .where('workerId', isEqualTo: workerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerAdvance.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<WorkerAdvance>> getAdvancesBySupervisor(String supervisorId) {
    return _db
        .collection('worker_advances')
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerAdvance.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // Worker Deduction Operations
  Future<String> createWorkerDeduction(WorkerDeduction deduction) async {
    final docRef = _db.collection('worker_deductions').doc();
    await docRef.set(
      deduction.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateWorkerDeduction(WorkerDeduction deduction) async {
    if (deduction.id == null) return;
    await _db
        .collection('worker_deductions')
        .doc(deduction.id)
        .update(
          deduction.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
        );
  }

  Stream<List<WorkerDeduction>> getDeductionsByWorker(String workerId) {
    return _db
        .collection('worker_deductions')
        .where('workerId', isEqualTo: workerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerDeduction.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<WorkerDeduction>> getDeductionsBySupervisor(String supervisorId) {
    return _db
        .collection('worker_deductions')
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerDeduction.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // Weekly Labour Cost Operations
  Future<String> createWeeklyLabourCost(WeeklyLabourCost cost) async {
    final docRef = _db.collection('weekly_labour_cost').doc();
    await docRef.set(
      cost.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  // Monthly Labour Cost Operations
  Future<String> createMonthlyLabourCost(MonthlyLabourCost cost) async {
    final docRef = _db.collection('monthly_labour_cost').doc();
    await docRef.set(
      cost.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  // Salary Calculation Engine
  Future<List<SalaryRecord>> generateSalaryForPeriod({
    required String supervisorId,
    required String supervisorName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Worker> workers,
  }) async {
    final salaryRecords = <SalaryRecord>[];

    for (final worker in workers) {
      // Get attendance for period
      final attendanceSnapshot = await _db
          .collection('worker_attendance')
          .where('workerId', isEqualTo: worker.workerId)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();

      final attendances = attendanceSnapshot.docs
          .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
          .toList();

      double totalRegularHours = 0;
      double totalOvertimeHours = 0;
      int attendanceDays = 0;
      double basicSalary = 0;
      double overtimeSalary = 0;

      // Calculate from attendance
      for (final att in attendances) {
        totalRegularHours += att.regularHours;
        totalOvertimeHours += att.overtimeHours;
        if (att.status == AttendanceStatus.present ||
            att.status == AttendanceStatus.halfDay) {
          attendanceDays++;
        }
      }

      // Calculate salary based on worker's labour type.
      if (worker.labourType == 'Daily Wage') {
        // Daily wage: use days worked * daily rate + overtime
        basicSalary = attendanceDays * worker.basicSalary;
        overtimeSalary = totalOvertimeHours * worker.overtimeRate;
      } else {
        // Monthly salary: prorate based on attendance
        // Simple implementation - can be enhanced
        basicSalary = worker.basicSalary;
        overtimeSalary = totalOvertimeHours * worker.overtimeRate;
      }

      // Get advances and deductions for period
      final advancesSnapshot = await _db
          .collection('worker_advances')
          .where('workerId', isEqualTo: worker.workerId)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();
      final totalAdvances = advancesSnapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
      );

      final deductionsSnapshot = await _db
          .collection('worker_deductions')
          .where('workerId', isEqualTo: worker.workerId)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();
      final totalDeductions = deductionsSnapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
      );

      final netSalary =
          basicSalary + overtimeSalary - totalAdvances - totalDeductions;

      final salaryRecord = SalaryRecord(
        workerId: worker.workerId,
        workerName: worker.name,
        workerType: worker.workerType,
        subContractorId: worker.subContractorId ?? '',
        subContractorName: worker.subContractorName,
        siteId: worker.assignedSiteIds.first,
        siteName: worker.assignedSiteIds.first,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        startDate: startDate,
        endDate: endDate,
        attendanceDays: attendanceDays,
        regularHours: totalRegularHours,
        overtimeHours: totalOvertimeHours,
        basicSalary: basicSalary,
        overtimeSalary: overtimeSalary,
        advances: totalAdvances,
        deductions: totalDeductions,
        netSalary: netSalary,
        generatedBy: supervisorId,
        generatedDate: DateTime.now(),
      );

      salaryRecords.add(salaryRecord);
    }

    // Save all salary records
    for (final record in salaryRecords) {
      await createSalaryRecord(record);
    }

    return salaryRecords;
  }

  // Labour Cost Calculation Engine
  Future<void> calculateDailyLabourCost(
    String siteId,
    String siteName,
    String supervisorId,
    String supervisorName,
    DateTime date,
  ) async {
    // Get all attendance for the site on the date
    final attendanceSnapshot = await _db
        .collection('worker_attendance')
        .where('siteId', isEqualTo: siteId)
        .where('date', isEqualTo: date.toIso8601String())
        .get();

    final attendances = attendanceSnapshot.docs
        .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
        .toList();

    double totalRegularCost = 0;
    double totalOvertimeCost = 0;
    final workerBreakdown = <String, dynamic>{};
    final workerIds = <String>{};

    for (final att in attendances) {
      workerIds.add(att.workerId);
      totalRegularCost += att.overtimeAmount; // Need to calculate properly
      totalOvertimeCost += att.overtimeAmount;

      workerBreakdown[att.workerId] = {
        'workerName': att.workerName,
        'regularHours': att.regularHours,
        'overtimeHours': att.overtimeHours,
        'regularCost': att.overtimeAmount, // Placeholder
        'overtimeCost': att.overtimeAmount,
      };
    }

    final dailyCost = DailyLabourCost(
      date: date,
      siteId: siteId,
      siteName: siteName,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      totalWorkers: workerIds.length,
      totalRegularCost: totalRegularCost,
      totalOvertimeCost: totalOvertimeCost,
      totalCost: totalRegularCost + totalOvertimeCost,
      workerBreakdown: workerBreakdown,
    );

    // Use WorkforceService to create daily labour cost
    final workforceService = WorkforceService();
    await workforceService.createDailyLabourCost(dailyCost);
  }
}
