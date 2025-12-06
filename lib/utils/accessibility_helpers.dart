import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility helper functions

/// Wrap widget with semantic label for screen readers
Widget withSemanticLabel(Widget child, String label, {String? hint}) {
  return Semantics(
    label: label,
    hint: hint,
    child: child,
  );
}

/// Ensure minimum touch target size (44x44pt iOS, 48x48dp Android)
Widget ensureMinimumTouchTarget(Widget child, {double minSize = 48.0}) {
  return SizedBox(
    width: minSize,
    height: minSize,
    child: Center(child: child),
  );
}

/// Create accessible button with proper labels
Widget accessibleButton({
  required String label,
  String? hint,
  required VoidCallback onPressed,
  required Widget child,
}) {
  return Semantics(
    label: label,
    hint: hint,
    button: true,
    child: InkWell(
      onTap: onPressed,
      child: child,
    ),
  );
}

/// Create accessible text field
Widget accessibleTextField({
  required String label,
  String? hint,
  required TextEditingController controller,
  required Widget child,
}) {
  return Semantics(
    label: label,
    hint: hint,
    textField: true,
    child: child,
  );
}

/// Check if system is using high contrast
bool isHighContrast(BuildContext context) {
  return MediaQuery.of(context).highContrast;
}

/// Get accessible text scale factor
double getTextScaleFactor(BuildContext context) {
  return MediaQuery.of(context).textScaleFactor;
}

/// Check if text scaling is large
bool isLargeText(BuildContext context) {
  return getTextScaleFactor(context) > 1.2;
}

