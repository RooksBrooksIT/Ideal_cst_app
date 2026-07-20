import 'package:cloud_firestore/cloud_firestore.dart';

class SubContractor {
  final String? id;
  final String name;
  final String contractorId;
  final String category;
  final String mobileNumber;
  final String? address;
  final String salaryType;
  final double salaryRate;
  final double overtimeRate;
  final List<String> assignedSiteIds;
  final bool isActive;
  final DateTime joiningDate;
  final String? notes;
  final String? supervisorId;
  final String? supervisorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubContractor({
    this.id,
    required this.name,
    required this.contractorId,
    required this.category,
    required this.mobileNumber,
    this.address,
    required this.salaryType,
    required this.salaryRate,
    this.overtimeRate = 0.0,
    required this.assignedSiteIds,
    this.isActive = true,
    required this.joiningDate,
    this.notes,
    this.supervisorId,
    this.supervisorName,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contractorId': contractorId,
      'category': category,
      'mobileNumber': mobileNumber,
      'address': address,
      'salaryType': salaryType,
      'salaryRate': salaryRate,
      'overtimeRate': overtimeRate,
      'assignedSiteIds': assignedSiteIds,
      'isActive': isActive,
      'joiningDate': joiningDate.toIso8601String(),
      'notes': notes,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SubContractor.fromJson(String id, Map<String, dynamic> json) {
    return SubContractor(
      id: id,
      name: json['name'] ?? '',
      contractorId: json['contractorId'] ?? '',
      category: json['category'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      address: json['address'],
      salaryType: json['salaryType'] ?? 'Daily Wage',
      salaryRate: (json['salaryRate'] as num?)?.toDouble() ?? 0.0,
      overtimeRate: (json['overtimeRate'] as num?)?.toDouble() ?? 0.0,
      assignedSiteIds: List<String>.from(json['assignedSiteIds'] ?? []),
      isActive: json['isActive'] ?? true,
      joiningDate: json['joiningDate'] != null
          ? DateTime.parse(json['joiningDate'])
          : DateTime.now(),
      notes: json['notes'],
      supervisorId: json['supervisorId'],
      supervisorName: json['supervisorName'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}
