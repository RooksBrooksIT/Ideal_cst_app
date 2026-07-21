

enum AdvanceType {
  advance,
  loan,
}

enum AdvanceStatus {
  pending,
  approved,
  repaid,
}

class WorkerAdvance {
  final String? id;
  final String workerId;
  final String workerName;
  final String subContractorId;
  final String subContractorName;
  final String supervisorId;
  final String supervisorName;
  final AdvanceType type;
  final double amount;
  final String description;
  final DateTime date;
  final AdvanceStatus status;
  final String? approvedBy;
  final DateTime? approvedDate;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerAdvance({
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
    this.status = AdvanceStatus.pending,
    this.approvedBy,
    this.approvedDate,
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
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedDate': approvedDate?.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WorkerAdvance.fromJson(String id, Map<String, dynamic> json) {
    return WorkerAdvance(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      type: AdvanceType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'advance'),
        orElse: () => AdvanceType.advance,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      status: AdvanceStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => AdvanceStatus.pending,
      ),
      approvedBy: json['approvedBy'],
      approvedDate: json['approvedDate'] != null
          ? DateTime.parse(json['approvedDate'])
          : null,
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

