import 'package:flutter/material.dart';

enum AlertType { error, success, info }

class AlertMessage extends StatelessWidget {
  final String message;
  final AlertType type;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const AlertMessage({
    super.key,
    required this.message,
    this.type = AlertType.error,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color retryButtonColor;

    switch (type) {
      case AlertType.error:
        backgroundColor = colorScheme.errorContainer;
        borderColor = colorScheme.error;
        textColor = colorScheme.onErrorContainer;
        retryButtonColor = colorScheme.error.withValues(alpha: 0.2);
        break;
      case AlertType.success:
        backgroundColor = Colors.green.shade100;
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade700;
        retryButtonColor = Colors.green.shade200;
        break;
      case AlertType.info:
        backgroundColor = Colors.blue.shade100;
        borderColor = Colors.blue.shade400;
        textColor = Colors.blue.shade700;
        retryButtonColor = Colors.blue.shade200;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 2),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 30.0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 15.0,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null || onDismiss != null) ...[
            const SizedBox(width: 16.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      backgroundColor: retryButtonColor,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onDismiss != null) ...[
                  if (onRetry != null) const SizedBox(width: 8.0),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    color: textColor,
                    iconSize: 20.0,
                    constraints: const BoxConstraints(
                      minWidth: 32.0,
                      minHeight: 32.0,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
