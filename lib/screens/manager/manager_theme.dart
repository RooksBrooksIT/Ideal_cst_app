import 'package:flutter/material.dart';

class ManagerTheme {
  // Colors
  static const Color scaffoldBackgroundColor = Color.fromARGB(255, 218, 238, 220);
  // Dark forest green – matches the sage-green scaffold background palette
  static const Color primaryColor = Color(0xFF166534);
  static const Color secondaryNavy = Color(0xFF14532D);
  static const Color titleTextColor = Color(0xFF1E1E2D);
  static const Color cardColor = Colors.white;
  // Circular action button color (logout button style) – dark green to match theme
  static const Color logoutButtonColor = Color(0xFF166534);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  // Standard Header Widget
  static Widget buildHeader(
    BuildContext context, {
    required String category,
    required String title,
    Widget? trailing,
    VoidCallback? onBackPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              if (Navigator.canPop(context) || onBackPressed != null) ...[
                GestureDetector(
                  onTap: onBackPressed ?? () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: titleTextColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: titleTextColor,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  // Standard Card Widget
  static Widget buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }

  // Standard Input Field Decoration
  static InputDecoration buildInputDecoration({
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
    String? hintText,
    Color? iconColor,
  }) {
    final iColor = iconColor ?? logoutButtonColor;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(color: iColor.withValues(alpha: 0.8), fontSize: 14),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: iColor, size: 22) : null,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: iColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: iColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: iColor, width: 2),
      ),
    );
  }

  // Primary Action Button
  static Widget buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    Color? color,
  }) {
    final btnColor = color ?? primaryColor;
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: btnColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
    );
  }

  // Secondary Button
  static Widget buildSecondaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? color,
  }) {
    final btnColor = color ?? Colors.orange;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: btnColor,
        side: BorderSide(color: btnColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: btnColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: btnColor,
            ),
          ),
        ],
      ),
    );
  }

  // TabBar Header Container
  static Widget buildTabBar({
    required TabController controller,
    required List<Tab> tabs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardShadow,
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: primaryColor,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        tabs: tabs,
      ),
    );
  }

  // Circular Icon Button – matches the Logout button style from config_account_dashboard
  static Widget buildCircularButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color backgroundColor = primaryColor,
    Color iconColor = Colors.white,
    Color? labelColor,
    double size = 55,
  }) {
    final lColor = labelColor ?? backgroundColor;
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: onPressed != null
                  ? backgroundColor
                  : backgroundColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: backgroundColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.42,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: onPressed != null ? lColor : lColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Confirm Button – replaces raw ElevatedButton inside AlertDialog actions
  static Widget buildDialogButton({
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    IconData? icon,
  }) {
    final color = backgroundColor ?? primaryColor;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Cancel Button
  static Widget buildDialogCancelButton({
    required VoidCallback? onPressed,
    String label = 'Cancel',
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[600],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
