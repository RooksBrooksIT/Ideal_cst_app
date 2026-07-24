import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sub_contractor.dart';
import '../models/worker.dart';
import '../models/worker_attendance.dart';
import '../models/worker_transfer.dart';
import '../models/daily_labour_cost.dart';

class WorkforceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sub Contractor Operations
  Future<String> createSubContractor(SubContractor contractor) async {
    final docRef = _db.collection('sub_contractors').doc();
    await docRef.set(
      contractor.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateSubContractor(SubContractor contractor) async {
    await _db
        .collection('sub_contractors')
        .doc(contractor.id)
        .update(
          contractor.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
        );
  }

  Future<void> deleteSubContractor(String id) async {
    await _db.collection('sub_contractors').doc(id).delete();
  }

  Stream<List<SubContractor>> getSubContractorsBySupervisor(
    String supervisorId,
  ) {
    return _db
        .collection('sub_contractors')
        .where('supervisorId', isEqualTo: supervisorId)
        .snapshots()
        .map(
          (snapshot) => (snapshot.docs
              .map((doc) => SubContractor.fromJson(doc.id, doc.data()))
              .toList())
            ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase())),
        );
  }

  Future<List<SubContractor>> getSubContractors(String supervisorId) async {
    final snapshot = await _db
        .collection('sub_contractors')
        .where('supervisorId', isEqualTo: supervisorId)
        .get();
    return (snapshot.docs
        .map((doc) => SubContractor.fromJson(doc.id, doc.data()))
        .toList())
      ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
  }

  Future<String> generateSubContractorId() async {
    final snapshot = await _db
        .collection('sub_contractors')
        .orderBy('contractorId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return 'IC001';
    }
    final lastId = snapshot.docs.first['contractorId'] as String? ?? 'IC000';
    final number = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'IC${(number + 1).toString().padLeft(3, '0')}';
  }

  // Worker Operations
  Future<String> createWorker(Worker worker) async {
    final docRef = _db.collection('workers').doc();
    await docRef.set(
      worker.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateWorker(Worker worker) async {
    final workerData = worker.toJson()
      ..['updatedAt'] = DateTime.now().toIso8601String()
      // Remove the legacy field once a worker record is next updated.
      ..['salaryType'] = FieldValue.delete();
    await _db
        .collection('workers')
        .doc(worker.id)
        .update(workerData);
  }

  Future<void> softDeleteWorker(String id, String deletedBy) async {
    await _db.collection('workers').doc(id).update({
      'isDeleted': true,
      'deletedAt': DateTime.now().toIso8601String(),
      'deletedBy': deletedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteWorker(String id) async {
    await _db.collection('workers').doc(id).delete();
  }

  Stream<List<Worker>> getWorkersBySubContractor(String subContractorId) {
    return _db
        .collection('workers')
        .where('subContractorId', isEqualTo: subContractorId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => (snapshot.docs
              .map((doc) => Worker.fromJson(doc.id, doc.data()))
              .toList())
            ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase())),
        );
  }

  Future<List<Worker>> getWorkers(String subContractorId) async {
    final snapshot = await _db
        .collection('workers')
        .where('subContractorId', isEqualTo: subContractorId)
        .where('isDeleted', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => Worker.fromJson(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Worker>> getWorkersBySupervisor(String supervisorId) {
    return _db
        .collection('workers')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Worker.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> generateWorkerId() async {
    final snapshot = await _db
        .collection('workers')
        .orderBy('workerId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return 'W001';
    }
    final lastId = snapshot.docs.first['workerId'] as String? ?? 'W000';
    final number = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'W${(number + 1).toString().padLeft(3, '0')}';
  }

  // Worker Attendance Operations
  Future<String> createWorkerAttendance(WorkerAttendance attendance) async {
    final docRef = _db.collection('worker_attendance').doc();
    await docRef.set(
      attendance.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Future<void> updateWorkerAttendance(WorkerAttendance attendance) async {
    await _db
        .collection('worker_attendance')
        .doc(attendance.id)
        .update(
          attendance.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
        );
  }

  Future<void> deleteWorkerAttendance(String id) async {
    await _db.collection('worker_attendance').doc(id).delete();
  }

  Stream<List<WorkerAttendance>> getAttendanceByDateAndSite(
    DateTime date,
    String siteId,
  ) {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(const Duration(days: 1));
    return _db
        .collection('worker_attendance')
        .where('siteId', isEqualTo: siteId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThan: endDate.toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<WorkerAttendance>> getAttendanceByWorker(
    String workerId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _db
        .collection('worker_attendance')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerAttendance.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // Worker Transfer Operations
  Future<String> createWorkerTransfer(WorkerTransfer transfer) async {
    final docRef = _db.collection('worker_transfers').doc();
    await docRef.set(
      transfer.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Stream<List<WorkerTransfer>> getWorkerTransfersBySupervisor(
    String supervisorId,
  ) {
    return _db
        .collection('worker_transfers')
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerTransfer.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  // Daily Labour Cost Operations
  Future<String> createDailyLabourCost(DailyLabourCost cost) async {
    final docRef = _db.collection('daily_labour_cost').doc();
    await docRef.set(
      cost.toJson()
        ..['id'] = docRef.id
        ..['createdAt'] = DateTime.now().toIso8601String(),
    );
    return docRef.id;
  }

  Stream<List<DailyLabourCost>> getDailyLabourCostBySite(
    String siteId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _db
        .collection('daily_labour_cost')
        .where('siteId', isEqualTo: siteId)
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DailyLabourCost.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }
}
