import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/organization/components/custom_table.dart';

export 'package:ideal_cst/screens/organization/components/custom_table.dart' show CustomTableColumn;

class ReceptionistCustomTable<T> extends StatelessWidget {
  final List<T> data;
  final List<CustomTableColumn<T>> columns;
  final int defaultRowsPerPage;
  final List<int> availableRowsPerPage;
  final bool showPagination;
  final Color mainColor;
  final Color? headerBgColor;
  final Color headerTextColor;
  final Widget? emptyWidget;
  final bool showTotalsRow;
  final EdgeInsetsGeometry padding;

  const ReceptionistCustomTable({
    super.key,
    required this.data,
    required this.columns,
    this.defaultRowsPerPage = 10,
    this.availableRowsPerPage = const [10, 25, 50, 100],
    this.showPagination = true,
    this.mainColor = const Color(0xFFD84315),
    this.headerBgColor,
    this.headerTextColor = Colors.white,
    this.emptyWidget,
    this.showTotalsRow = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTable<T>(
      data: data,
      columns: columns,
      defaultRowsPerPage: defaultRowsPerPage,
      availableRowsPerPage: availableRowsPerPage,
      showPagination: showPagination,
      mainColor: mainColor,
      headerBgColor: headerBgColor ?? mainColor,
      headerTextColor: headerTextColor,
      emptyWidget: emptyWidget,
      showTotalsRow: showTotalsRow,
      padding: padding,
    );
  }
}
