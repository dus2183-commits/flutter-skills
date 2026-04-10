import 'package:flutter/material.dart';

enum AppButtonType { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.loading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    final child = loading
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
              Text(text),
            ],
          );

    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton(onPressed: disabled ? null : onPressed, child: child);
      case AppButtonType.secondary:
        return OutlinedButton(onPressed: disabled ? null : onPressed, child: child);
      case AppButtonType.text:
        return TextButton(onPressed: disabled ? null : onPressed, child: child);
    }
  }
}
