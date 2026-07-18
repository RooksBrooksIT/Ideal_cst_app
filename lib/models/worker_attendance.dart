import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  present,
  absent,
  halfDay,
  paidLeave,
  unpaidLeave,
  holiday,
  medicalLeave
}

class WorkerAttendance {
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
  final double hoursWorked;
  final double regularHours;
  final double overtimeHours;
  final double overtimeAmount;
  final String workType;
  final AttendanceStatus status;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkerAttendance({
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
    required this.hoursWorked,
    required this.regularHours,
    required this.overtimeHours,
    required this.overtimeAmount,
    required this.workType,
    this.status = AttendanceStatus.present,
    this.remarks,
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
      'hoursWorked': hoursWorked,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'overtimeAmount': overtimeAmount,
      'workType': workType,
      'status': status.name,
      'remarks': remarks,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WorkerAttendance.fromJson(String id, Map<String, dynamic> json) {
    return WorkerAttendance(
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
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0.0,
      regularHours: (json['regularHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      overtimeAmount: (json['overtimeAmount'] as num?)?.toDouble() ?? 0.0,
      workType: json['workType'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AttendanceStatus.present,
      ),
      remarks: json['remarks'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  static double calculateRegularHours(double totalHours) {
    if (totalHours > 8) {
      return 8.0;
    }
    return totalHours;
  }

  static double calculateOvertimeHours(double totalHours) {
    if (totalHours > 8) {
      return totalHours - 8.0;
    }
    return 0.0;
  }

  static double calculateOvertimeAmount(
    double overtimeHours,
    double dailyRate,
  ) {
    double overtimeRate = dailyRate / 8.0;
    return overtimeHours * overtimeRate;
  }
}
