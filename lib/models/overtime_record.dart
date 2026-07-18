
import 'package:cloud_firestore/cloud_firestore.dart';

class OvertimeRecord {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerType;
  final String subContractorId;
  final String subContractorName;
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final DateTime date;
  final double overtimeHours;
  final double overtimeRate;
  final double overtimeAmount;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OvertimeRecord({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerType,
    required this.subContractorId,
    required this.subContractorName,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    required this.overtimeHours,
    required this.overtimeRate,
    required this.overtimeAmount,
    this.reason,
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
      'siteId': siteId,
      'siteName': siteName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'date': date.toIso8601String(),
      'overtimeHours': overtimeHours,
      'overtimeRate': overtimeRate,
      'overtimeAmount': overtimeAmount,
      'reason': reason,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory OvertimeRecord.fromJson(String id, Map<String, dynamic> json) {
    return OvertimeRecord(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      workerType: json['workerType'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'] ?? '',
      siteId: json['siteId'] ?? '',
      siteName: json['siteName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      overtimeRate: (json['overtimeRate'] as num?)?.toDouble() ?? 0.0,
      overtimeAmount: (json['overtimeAmount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

