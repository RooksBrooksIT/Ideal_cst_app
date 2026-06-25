import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerTransfer {
  final String? id;
  final String workerId;
  final String workerName;
  final String fromSiteId;
  final String fromSiteName;
  final String? fromSubContractorId;
  final String? fromSubContractorName;
  final String toSiteId;
  final String toSiteName;
  final String? toSubContractorId;
  final String? toSubContractorName;
  final DateTime transferDate;
  final String reason;
  final String approvedBy;
  final String supervisorId;
  final String supervisorName;
  final DateTime? createdAt;

  WorkerTransfer({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.fromSiteId,
    required this.fromSiteName,
    this.fromSubContractorId,
    this.fromSubContractorName,
    required this.toSiteId,
    required this.toSiteName,
    this.toSubContractorId,
    this.toSubContractorName,
    required this.transferDate,
    required this.reason,
    required this.approvedBy,
    required this.supervisorId,
    required this.supervisorName,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'fromSiteId': fromSiteId,
      'fromSiteName': fromSiteName,
      'fromSubContractorId': fromSubContractorId,
      'fromSubContractorName': fromSubContractorName,
      'toSiteId': toSiteId,
      'toSiteName': toSiteName,
      'toSubContractorId': toSubContractorId,
      'toSubContractorName': toSubContractorName,
      'transferDate': transferDate.toIso8601String(),
      'reason': reason,
      'approvedBy': approvedBy,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory WorkerTransfer.fromJson(String id, Map<String, dynamic> json) {
    return WorkerTransfer(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      fromSiteId: json['fromSiteId'] ?? '',
      fromSiteName: json['fromSiteName'] ?? '',
      fromSubContractorId: json['fromSubContractorId'],
      fromSubContractorName: json['fromSubContractorName'],
      toSiteId: json['toSiteId'] ?? '',
      toSiteName: json['toSiteName'] ?? '',
      toSubContractorId: json['toSubContractorId'],
      toSubContractorName: json['toSubContractorName'],
      transferDate: json['transferDate'] != null
          ? DateTime.parse(json['transferDate'])
          : DateTime.now(),
      reason: json['reason'] ?? '',
      approvedBy: json['approvedBy'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}
