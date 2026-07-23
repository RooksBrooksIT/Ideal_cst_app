import 'package:flutter/material.dart';
import 'package:ideal_cst/screens/manager/manager_theme.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Color mainColor;
  final bool isExpanded;
  final FormFieldValidator<T>? validator;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.mainColor = ManagerTheme.primaryColor,
    this.isExpanded = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: isExpanded,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        validator: validator,
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: mainColor,
            size: 20,
          ),
        ),
        style: TextStyle(
          color: mainColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          labelText: labelText,
          labelStyle: TextStyle(
            color: mainColor.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: mainColor, size: 22)
              : null,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: mainColor, width: 2),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
