
import 'package:cloud_firestore/cloud_firestore.dart';

enum DeductionType {
  penalty,
  other,
}

class WorkerDeduction {
  final String? id;
  final String workerId;
  final String workerName;
  final String subContractorId;
  final String subContractorName;
  final String supervisorId;
  final String supervisorName;
  final DeductionType type;
  final double amount;
  final String description;
  final DateTime date;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerDeduction({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.subContractorId,
    required this.subContractorName,
    required this.supervisorId,
    required this.supervisorName,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'workerId': workerId,
      'workerName': workerName,
      'subContractorId': subContractorId,
      'subContractorName': subContractorName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'type': type.name,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WorkerDeduction.fromJson(String id, Map<String, dynamic> json) {
    return WorkerDeduction(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      type: DeductionType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'penalty'),
        orElse: () => DeductionType.penalty,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

