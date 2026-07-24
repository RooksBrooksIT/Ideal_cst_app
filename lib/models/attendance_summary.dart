
class AttendanceSummary {
  final String? id;
  final String workerId;
  final String workerName;
  final String subContractorId;
  final String subContractorName;
  final String supervisorId;
  final String supervisorName;
  final DateTime date;
  final double totalHoursWorked;
  final double totalRegularHours;
  final double totalOvertimeHours;
  final double totalOvertimeAmount;
  final int totalSitesWorked;
  final Map<String, dynamic> siteBreakdown;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceSummary({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.subContractorId,
    required this.subContractorName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    required this.totalHoursWorked,
    required this.totalRegularHours,
    required this.totalOvertimeHours,
    required this.totalOvertimeAmount,
    required this.totalSitesWorked,
    required this.siteBreakdown,
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
      'date': date.toIso8601String(),
      'totalHoursWorked': totalHoursWorked,
      'totalRegularHours': totalRegularHours,
      'totalOvertimeHours': totalOvertimeHours,
      'totalOvertimeAmount': totalOvertimeAmount,
      'totalSitesWorked': totalSitesWorked,
      'siteBreakdown': siteBreakdown,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AttendanceSummary.fromJson(String id, Map<String, dynamic> json) {
    return AttendanceSummary(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      totalHoursWorked: (json['totalHoursWorked'] as num?)?.toDouble() ?? 0.0,
      totalRegularHours: (json['totalRegularHours'] as num?)?.toDouble() ?? 0.0,
      totalOvertimeHours:
          (json['totalOvertimeHours'] as num?)?.toDouble() ?? 0.0,
      totalOvertimeAmount:
          (json['totalOvertimeAmount'] as num?)?.toDouble() ?? 0.0,
      totalSitesWorked: (json['totalSitesWorked'] as num?)?.toInt() ?? 0,
      siteBreakdown: json['siteBreakdown'] as Map<String, dynamic>? ?? {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}
