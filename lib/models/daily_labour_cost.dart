
class DailyLabourCost {
  final String? id;
  final DateTime date;
  final String siteId;
  final String siteName;
  final String supervisorId;
  final String supervisorName;
  final int totalWorkers;
  final double totalRegularCost;
  final double totalOvertimeCost;
  final double totalCost;
  final Map<String, dynamic>? workerBreakdown;
  final DateTime? createdAt;

  DailyLabourCost({
    this.id,
    required this.date,
    required this.siteId,
    required this.siteName,
    required this.supervisorId,
    required this.supervisorName,
    required this.totalWorkers,
    required this.totalRegularCost,
    required this.totalOvertimeCost,
    required this.totalCost,
    this.workerBreakdown,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'siteId': siteId,
      'siteName': siteName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'totalWorkers': totalWorkers,
      'totalRegularCost': totalRegularCost,
      'totalOvertimeCost': totalOvertimeCost,
      'totalCost': totalCost,
      'workerBreakdown': workerBreakdown,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory DailyLabourCost.fromJson(String id, Map<String, dynamic> json) {
    return DailyLabourCost(
      id: id,
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      siteId: json['siteId'] ?? '',
      siteName: json['siteName'] ?? '',
      supervisorId: json['supervisorId'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      totalWorkers: json['totalWorkers'] as int? ?? 0,
      totalRegularCost: (json['totalRegularCost'] as num?)?.toDouble() ?? 0.0,
      totalOvertimeCost: (json['totalOvertimeCost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      workerBreakdown: json['workerBreakdown'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}
