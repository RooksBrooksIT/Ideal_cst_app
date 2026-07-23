
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyLabourCost {
  final String? id;
  final int month;
  final int year;
  final String? siteId;
  final String? siteName;
  final String? supervisorId;
  final String? supervisorName;
  final String? subContractorId;
  final String? subContractorName;
  final int totalWorkers;
  final double totalRegularCost;
  final double totalOvertimeCost;
  final double totalCost;
  final DateTime? createdAt;

  MonthlyLabourCost({
    this.id,
    required this.month,
    required this.year,
    this.siteId,
    this.siteName,
    this.supervisorId,
    this.supervisorName,
    this.subContractorId,
    this.subContractorName,
    required this.totalWorkers,
    required this.totalRegularCost,
    required this.totalOvertimeCost,
    required this.totalCost,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'year': year,
      'siteId': siteId,
      'siteName': siteName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'subContractorId': subContractorId,
      'subContractorName': subContractorName,
      'totalWorkers': totalWorkers,
      'totalRegularCost': totalRegularCost,
      'totalOvertimeCost': totalOvertimeCost,
      'totalCost': totalCost,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory MonthlyLabourCost.fromJson(String id, Map<String, dynamic> json) {
    return MonthlyLabourCost(
      id: id,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      siteId: json['siteId'],
      siteName: json['siteName'],
      supervisorId: json['supervisorId'],
      supervisorName: json['supervisorName'],
      subContractorId: json['subContractorId'],
      subContractorName: json['subContractorName'],
      totalWorkers: (json['totalWorkers'] as num?)?.toInt() ?? 0,
      totalRegularCost: (json['totalRegularCost'] as num?)?.toDouble() ?? 0.0,
      totalOvertimeCost: (json['totalOvertimeCost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}

