import 'dart:math';
import 'package:flutter/material.dart';

class CustomTableColumn<T> {
  final String header;
  final Widget Function(T item, int index) cellBuilder;
  final Alignment alignment;
  final double? width;
  final Widget Function()? totalCellBuilder;

  const CustomTableColumn({
    required this.header,
    required this.cellBuilder,
    this.alignment = Alignment.centerLeft,
    this.width,
    this.totalCellBuilder,
  });
}

class CustomTable<T> extends StatefulWidget {
  final List<T> data;
  final List<CustomTableColumn<T>> columns;
  final int defaultRowsPerPage;
  final List<int> availableRowsPerPage;
  final bool showPagination;
  final Color mainColor;
  final Color headerBgColor;
  final Color headerTextColor;
  final Widget? emptyWidget;
  final bool showTotalsRow;
  final EdgeInsetsGeometry padding;

  const CustomTable({
    super.key,
    required this.data,
    required this.columns,
    this.defaultRowsPerPage = 10,
    this.availableRowsPerPage = const [10, 25, 50, 100],
    this.showPagination = true,
    this.mainColor = const Color(0xFF003768),
    Color? headerBgColor,
    this.headerTextColor = Colors.white,
    this.emptyWidget,
    this.showTotalsRow = false,
    this.padding = EdgeInsets.zero,
  }) : headerBgColor = headerBgColor ?? mainColor;

  @override
  State<CustomTable<T>> createState() => _CustomTableState<T>();
}

class _CustomTableState<T> extends State<CustomTable<T>> {
  late int _rowsPerPage;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _rowsPerPage = widget.defaultRowsPerPage;
  }

  @override
  void didUpdateWidget(covariant CustomTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to page 0 if data length changed significantly
    final maxPage = _maxPage();
    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }
  }

  int _maxPage() {
    if (widget.data.isEmpty) return 0;
    return max(0, ((widget.data.length - 1) / _rowsPerPage).floor());
  }

  List<T> get _currentPageData {
    if (widget.data.isEmpty) return [];
    final start = _currentPage * _rowsPerPage;
    final end = min(start + _rowsPerPage, widget.data.length);
    if (start >= widget.data.length) return [];
    return widget.data.sublist(start, end);
  }

  void _goToPage(int page) {
    final maxP = _maxPage();
    final target = page.clamp(0, maxP);
    if (target != _currentPage) {
      setState(() {
        _currentPage = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.data.length;
    final pageData = widget.showPagination ? _currentPageData : widget.data;
    final startItem = totalItems == 0 ? 0 : (_currentPage * _rowsPerPage) + 1;
    final endItem = totalItems == 0 ? 0 : min((_currentPage + 1) * _rowsPerPage, totalItems);
    final maxP = _maxPage();

    return Padding(
      padding: widget.padding,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.mainColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: widget.mainColor.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table content area with horizontal scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 64,
                ),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(widget.headerBgColor),
                  columns: widget.columns.map((col) {
                    return DataColumn(
                      label: Container(
                        width: col.width,
                        alignment: col.alignment,
                        child: Text(
                          col.header,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.headerTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  rows: [
                    ...List.generate(pageData.length, (pageIdx) {
                      final globalIndex = (_currentPage * _rowsPerPage) + pageIdx;
                      final item = pageData[pageIdx];
                      return DataRow(
                        cells: widget.columns.map((col) {
                          return DataCell(
                            Container(
                              width: col.width,
                              alignment: col.alignment,
                              child: col.cellBuilder(item, globalIndex),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                    if (widget.showTotalsRow && widget.data.isNotEmpty)
                      DataRow(
                        color: WidgetStateProperty.all(
                          widget.mainColor.withValues(alpha: 0.08),
                        ),
                        cells: widget.columns.map((col) {
                          return DataCell(
                            Container(
                              width: col.width,
                              alignment: col.alignment,
                              child: col.totalCellBuilder != null
                                  ? col.totalCellBuilder!()
                                  : const Text('-'),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Empty state fallback
            if (widget.data.isEmpty)
              widget.emptyWidget ??
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No records found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

            // Bottom Pagination Controls Bar
            if (widget.showPagination && totalItems > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: widget.mainColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Entry summary text
                    Text(
                      'Showing $startItem to $endItem of $totalItems entries',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    // Controls (Rows per page + Page Nav)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rows per page dropdown
                          Text(
                            'Rows per page:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _rowsPerPage,
                                isDense: true,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.mainColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: widget.availableRowsPerPage.map((count) {
                                  return DropdownMenuItem<int>(
                                    value: count,
                                    child: Text('$count'),
                                  );
                                }).toList(),
                                onChanged: (newCount) {
                                  if (newCount != null && newCount != _rowsPerPage) {
                                    setState(() {
                                      _rowsPerPage = newCount;
                                      _currentPage = 0;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Navigation Buttons
                          _buildNavButton(
                            icon: Icons.first_page_rounded,
                            onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                            tooltip: 'First Page',
                          ),
                          _buildNavButton(
                            icon: Icons.chevron_left_rounded,
                            onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                            tooltip: 'Previous Page',
                          ),

                          // Page indicator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.mainColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_currentPage + 1} / ${maxP + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.mainColor,
                                ),
                              ),
                            ),
                          ),

                          _buildNavButton(
                            icon: Icons.chevron_right_rounded,
                            onPressed: _currentPage < maxP ? () => _goToPage(_currentPage + 1) : null,
                            tooltip: 'Next Page',
                          ),
                          _buildNavButton(
                            icon: Icons.last_page_rounded,
                            onPressed: _currentPage < maxP ? () => _goToPage(maxP) : null,
                            tooltip: 'Last Page',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? widget.mainColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
