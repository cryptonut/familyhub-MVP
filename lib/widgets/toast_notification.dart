import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum ToastType {
  success,
  error,
  warning,
  info,
}

class ToastNotification {
  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;
    IconData defaultIcon;

    switch (type) {
      case ToastType.success:
        backgroundColor = Colors.green;
        textColor = Colors.white;
        defaultIcon = Icons.check_circle;
        break;
      case ToastType.error:
        backgroundColor = Colors.red;
        textColor = Colors.white;
        defaultIcon = Icons.error;
        break;
      case ToastType.warning:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        defaultIcon = Icons.warning;
        break;
      case ToastType.info:
        backgroundColor = Colors.blue;
        textColor = Colors.white;
        defaultIcon = Icons.info;
        break;
    }

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + AppTheme.spacingMD,
        left: AppTheme.spacingMD,
        right: AppTheme.spacingMD,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      icon ?? defaultIcon,
                      color: textColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  static void success(BuildContext context, String message, {VoidCallback? onTap}) {
    show(context, message: message, type: ToastType.success, onTap: onTap);
  }

  static void error(BuildContext context, String message, {VoidCallback? onTap}) {
    show(context, message: message, type: ToastType.error, onTap: onTap);
  }

  static void warning(BuildContext context, String message, {VoidCallback? onTap}) {
    show(context, message: message, type: ToastType.warning, onTap: onTap);
  }

  static void info(BuildContext context, String message, {VoidCallback? onTap}) {
    show(context, message: message, type: ToastType.info, onTap: onTap);
  }
}

