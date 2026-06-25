
import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType {
  paidLeave,
  unpaidLeave,
  medicalLeave
}

class LeaveRecord {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerType;
  final String subContractorId;
  final String subContractorName;
  final String supervisorId;
  final String supervisorName;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String? reason;
  final String? documents;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaveRecord({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerType,
    required this.subContractorId,
    required this.subContractorName,
    required this.supervisorId,
    required this.supervisorName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.reason,
    this.documents,
    this.status = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'workerType': workerType,
      'subContractorId': subContractorId,
      'subContractorName': subContractorName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'leaveType': leaveType.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalDays': totalDays,
      'reason': reason,
      'documents': documents,
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory LeaveRecord.fromJson(String id, Map<String, dynamic> json) {
    return LeaveRecord(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      workerType: json['workerType'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      leaveType: LeaveType.values.firstWhere(
        (e) => e.name == json['leaveType'],
        orElse: () => LeaveType.unpaidLeave,
      ),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      reason: json['reason'],
      documents: json['documents'],
      status: json['status'] ?? 'pending',
      approvedBy: json['approvedBy'],
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

