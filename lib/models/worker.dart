import 'package:cloud_firestore/cloud_firestore.dart';

class Worker {
  final String? id;
  final String name;
  final String workerId;
  final String workerType;
  final String salaryType;
  final double basicSalary;
  final double overtimeRate;
  final double defaultHours;
  final String mobileNumber;
  final String? emergencyContact;
  final String? aadharNumber;
  final String? bankAccountDetails;
  final DateTime joiningDate;
  final bool isActive;
  final String? subContractorId;
  final String? subContractorName;
  final String? supervisorId;
  final String? supervisorName;
  final List<String> assignedSiteIds;
  final String? photoUrl;
  final List<String>? documentUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  Worker({
    this.id,
    required this.name,
    required this.workerId,
    required this.workerType,
    required this.salaryType,
    required this.basicSalary,
    required this.overtimeRate,
    this.defaultHours = 8.0,
    required this.mobileNumber,
    this.emergencyContact,
    this.aadharNumber,
    this.bankAccountDetails,
    required this.joiningDate,
    this.isActive = true,
    this.subContractorId,
    this.subContractorName,
    this.supervisorId,
    this.supervisorName,
    required this.assignedSiteIds,
    this.photoUrl,
    this.documentUrls,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'workerId': workerId,
      'workerType': workerType,
      'salaryType': salaryType,
      'basicSalary': basicSalary,
      'overtimeRate': overtimeRate,
      'defaultHours': defaultHours,
      'mobileNumber': mobileNumber,
      'emergencyContact': emergencyContact,
      'aadharNumber': aadharNumber,
      'bankAccountDetails': bankAccountDetails,
      'joiningDate': joiningDate.toIso8601String(),
      'isActive': isActive,
      'subContractorId': subContractorId,
      'subContractorName': subContractorName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'assignedSiteIds': assignedSiteIds,
      'photoUrl': photoUrl,
      'documentUrls': documentUrls,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  factory Worker.fromJson(String id, Map<String, dynamic> json) {
    return Worker(
      id: id,
      name: json['name'] ?? '',
      workerId: json['workerId'] ?? '',
      workerType: json['workerType'] ?? '',
      salaryType: json['salaryType'] ?? 'Daily Wage',
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
      overtimeRate: (json['overtimeRate'] as num?)?.toDouble() ?? 0.0,
      defaultHours: (json['defaultHours'] as num?)?.toDouble() ?? 8.0,
      mobileNumber: json['mobileNumber'] ?? '',
      emergencyContact: json['emergencyContact'],
      aadharNumber: json['aadharNumber'],
      bankAccountDetails: json['bankAccountDetails'],
      joiningDate: json['joiningDate'] != null
          ? DateTime.parse(json['joiningDate'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
      subContractorId: json['subContractorId'],
      subContractorName: json['subContractorName'],
      supervisorId: json['supervisorId'],
      supervisorName: json['supervisorName'],
      assignedSiteIds: List<String>.from(json['assignedSiteIds'] ?? []),
      photoUrl: json['photoUrl'],
      documentUrls: json['documentUrls'] != null
          ? List<String>.from(json['documentUrls'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'])
          : null,
      deletedBy: json['deletedBy'],
    );
  }
}
