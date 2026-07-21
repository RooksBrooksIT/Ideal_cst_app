
enum SalaryStatus { generated, approved, paid, cancelled }

class SalaryRecord {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerType;
  final String subContractorId;
  final String? subContractorName;
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final DateTime startDate;
  final DateTime endDate;
  final int attendanceDays;
  final double regularHours;
  final double overtimeHours;
  final double basicSalary;
  final double overtimeSalary;
  final double bonus;
  final double allowances;
  final double advances;
  final double deductions;
  final double penalties;
  final double netSalary;
  final SalaryStatus status;
  final String generatedBy;
  final String? approvedBy;
  final DateTime generatedDate;
  final DateTime? approvedDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SalaryRecord({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerType,
    required this.subContractorId,
    this.subContractorName,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.startDate,
    required this.endDate,
    required this.attendanceDays,
    required this.regularHours,
    required this.overtimeHours,
    required this.basicSalary,
    required this.overtimeSalary,
    this.bonus = 0.0,
    this.allowances = 0.0,
    this.advances = 0.0,
    this.deductions = 0.0,
    this.penalties = 0.0,
    required this.netSalary,
    this.status = SalaryStatus.generated,
    required this.generatedBy,
    this.approvedBy,
    required this.generatedDate,
    this.approvedDate,
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
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'attendanceDays': attendanceDays,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'basicSalary': basicSalary,
      'overtimeSalary': overtimeSalary,
      'bonus': bonus,
      'allowances': allowances,
      'advances': advances,
      'deductions': deductions,
      'penalties': penalties,
      'netSalary': netSalary,
      'status': status.name,
      'generatedBy': generatedBy,
      'approvedBy': approvedBy,
      'generatedDate': generatedDate.toIso8601String(),
      'approvedDate': approvedDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SalaryRecord.fromJson(String id, Map<String, dynamic> json) {
    return SalaryRecord(
      id: id,
      workerId: json['workerId'] ?? '',
      workerName: json['workerName'] ?? '',
      workerType: json['workerType'] ?? '',
      subContractorId: json['subContractorId'] ?? '',
      subContractorName: json['subContractorName'],
      siteId: json['siteId'] ?? '',
      siteName: json['siteName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
      attendanceDays: (json['attendanceDays'] as num?)?.toInt() ?? 0,
      regularHours: (json['regularHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
      overtimeSalary: (json['overtimeSalary'] as num?)?.toDouble() ?? 0.0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0.0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
      advances: (json['advances'] as num?)?.toDouble() ?? 0.0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0.0,
      penalties: (json['penalties'] as num?)?.toDouble() ?? 0.0,
      netSalary: (json['netSalary'] as num?)?.toDouble() ?? 0.0,
      status: SalaryStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'generated'),
        orElse: () => SalaryStatus.generated,
      ),
      generatedBy: json['generatedBy'] ?? '',
      approvedBy: json['approvedBy'],
      generatedDate: json['generatedDate'] != null
          ? DateTime.parse(json['generatedDate'])
          : DateTime.now(),
      approvedDate: json['approvedDate'] != null
          ? DateTime.parse(json['approvedDate'])
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
