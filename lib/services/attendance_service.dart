import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worker_attendance.dart';
import '../models/attendance_summary.dart';
import '../models/overtime_record.dart';
import '../models/leave_record.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Worker Attendance CRUD
  Future<String> createWorkerAttendance(WorkerAttendance attendance) async {
    final docRef = await _firestore.collection('worker_attendance').add({
      ...attendance.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateWorkerAttendance(WorkerAttendance attendance) async {
    if (attendance.id == null) return;
    await _firestore.collection('worker_attendance').doc(attendance.id).update({
      ...attendance.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<WorkerAttendance>> getWorkerAttendanceByDate(
    String supervisorId,
    DateTime date,
  ) async {
    final querySnapshot = await _firestore
        .collection('worker_attendance')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('date', isEqualTo: date.toIso8601String())
        .get();
    return querySnapshot.docs
        .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<List<WorkerAttendance>> getWorkerAttendanceByWorker(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final querySnapshot = await _firestore
        .collection('worker_attendance')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('date')
        .get();
    return querySnapshot.docs
        .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
        .toList();
  }

  // Attendance Summary CRUD
  Future<String> createAttendanceSummary(AttendanceSummary summary) async {
    final docRef = await _firestore.collection('attendance_summary').add({
      ...summary.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateAttendanceSummary(AttendanceSummary summary) async {
    if (summary.id == null) return;
    await _firestore.collection('attendance_summary').doc(summary.id).update({
      ...summary.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AttendanceSummary?> getAttendanceSummaryForWorker(
    String workerId,
    DateTime date,
  ) async {
    final querySnapshot = await _firestore
        .collection('attendance_summary')
        .where('workerId', isEqualTo: workerId)
        .where('date', isEqualTo: date.toIso8601String())
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return null;
    return AttendanceSummary.fromJson(
      querySnapshot.docs.first.id,
      querySnapshot.docs.first.data(),
    );
  }

  // Overtime Record CRUD
  Future<String> createOvertimeRecord(OvertimeRecord record) async {
    final docRef = await _firestore.collection('overtime_records').add({
      ...record.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<List<OvertimeRecord>> getOvertimeRecordsByWorker(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final querySnapshot = await _firestore
        .collection('overtime_records')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('date')
        .get();
    return querySnapshot.docs
        .map((doc) => OvertimeRecord.fromJson(doc.id, doc.data()))
        .toList();
  }

  // Leave Record CRUD
  Future<String> createLeaveRecord(LeaveRecord record) async {
    final docRef = await _firestore.collection('leave_records').add({
      ...record.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateLeaveRecord(LeaveRecord record) async {
    if (record.id == null) return;
    await _firestore.collection('leave_records').doc(record.id).update({
      ...record.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<LeaveRecord>> getLeaveRecordsByWorker(String workerId) async {
    final querySnapshot = await _firestore
        .collection('leave_records')
        .where('workerId', isEqualTo: workerId)
        .orderBy('startDate')
        .get();
    return querySnapshot.docs
        .map((doc) => LeaveRecord.fromJson(doc.id, doc.data()))
        .toList();
  }

  // Helper: Calculate total daily hours for a worker
  Future<void> calculateAndSaveDailySummary(
    String workerId,
    DateTime date,
  ) async {
    final attendanceRecords = await _firestore
        .collection('worker_attendance')
        .where('workerId', isEqualTo: workerId)
        .where('date', isEqualTo: date.toIso8601String())
        .get();

    if (attendanceRecords.docs.isEmpty) return;

    double totalHours = 0.0;
    double totalOvertimeAmount = 0.0;
    final siteBreakdown = <String, dynamic>{};

    for (final doc in attendanceRecords.docs) {
      final attendance = WorkerAttendance.fromJson(doc.id, doc.data());
      totalHours += attendance.hoursWorked;
      totalOvertimeAmount += attendance.overtimeAmount;

      siteBreakdown[attendance.siteId] = {
        'siteName': attendance.siteName,
        'hoursWorked': attendance.hoursWorked,
        'regularHours': attendance.regularHours,
        'overtimeHours': attendance.overtimeHours,
      };
    }

    // Recalculate final regular and overtime based on total hours
    final finalRegular = WorkerAttendance.calculateRegularHours(totalHours);
    final finalOvertime = WorkerAttendance.calculateOvertimeHours(totalHours);

    final existingSummary = await getAttendanceSummaryForWorker(workerId, date);

    // Get worker details from first attendance
    final firstAttendance = WorkerAttendance.fromJson(
      attendanceRecords.docs.first.id,
      attendanceRecords.docs.first.data(),
    );

    final summary = AttendanceSummary(
      id: existingSummary?.id,
      workerId: workerId,
      workerName: firstAttendance.workerName,
      subContractorId: firstAttendance.subContractorId,
      subContractorName: firstAttendance.subContractorName,
      supervisorId: firstAttendance.supervisorId,
      supervisorName: firstAttendance.supervisorName,
      date: date,
      totalHoursWorked: totalHours,
      totalRegularHours: finalRegular,
      totalOvertimeHours: finalOvertime,
      totalOvertimeAmount: totalOvertimeAmount,
      totalSitesWorked: attendanceRecords.docs.length,
      siteBreakdown: siteBreakdown,
    );

    if (existingSummary == null) {
      await createAttendanceSummary(summary);
    } else {
      await updateAttendanceSummary(summary);
    }
  }
}
