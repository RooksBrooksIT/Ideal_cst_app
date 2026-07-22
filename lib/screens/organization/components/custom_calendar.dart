import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomCalendar extends StatelessWidget {
  final DateTime? selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  final Color mainColor;
  final String labelText;
  final String? availableRangeText;

  CustomCalendar({
    super.key,
    required this.selectedDate,
    DateTime? firstDate,
    DateTime? lastDate,
    required this.onDateSelected,
    this.mainColor = const Color(0xFF003768),
    String labelText = 'Select Date',
    String? hintText,
    this.availableRangeText,
  })  : firstDate = firstDate ?? DateTime(2000),
        lastDate = lastDate ?? DateTime(2050),
        labelText = hintText ?? labelText;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initial = (selectedDate != null &&
            !selectedDate!.isBefore(firstDate) &&
            !selectedDate!.isAfter(lastDate))
        ? selectedDate!
        : firstDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: mainColor,
            colorScheme: ColorScheme.light(
              primary: mainColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E1E2D),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: mainColor,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText.isNotEmpty) ...[
          Text(
            labelText,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E2D),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('EEE, MMM dd, yyyy').format(selectedDate!)
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 15,
                    color: mainColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: mainColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: mainColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (availableRangeText != null && availableRangeText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            availableRangeText!,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ],
    );
  }
}
