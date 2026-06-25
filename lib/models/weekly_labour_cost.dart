
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyLabourCost {
  final String? id;
  final int weekNumber;
  final int year;
  final DateTime startDate;
  final DateTime endDate;
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

  WeeklyLabourCost({
    this.id,
    required this.weekNumber,
    required this.year,
    required this.startDate,
    required this.endDate,
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
      'weekNumber': weekNumber,
      'year': year,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
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

  factory WeeklyLabourCost.fromJson(String id, Map<String, dynamic> json) {
    return WeeklyLabourCost(
      id: id,
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
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

