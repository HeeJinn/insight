import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../widgets/apple_chrome.dart';

/// Themed replacement for raw [AlertDialog] usage, styled to match the rest
/// of the app's Apple-HIG chrome (elevated surface background, HIG
/// typography, [AppleTactileButton] actions) instead of stock Material.
class AppDialog {
  AppDialog._();

  /// Shows a confirmation dialog and resolves to `true` only if the user
  /// taps the confirm action. Use [isDestructive] for actions like deleting
  /// a record, which tints the confirm button red.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await show<bool>(
      context,
      title: title,
      content: message == null
          ? null
          : Text(message, style: AppleTypography.body.copyWith(color: context.appColors.secondaryText)),
      actions: (dialogContext) => [
        Expanded(
          child: AppleTactileButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primaryText,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppleTactileButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            isDestructive: isDestructive,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
    return result ?? false;
  }

  /// Shows a themed dialog with arbitrary [content] and [actions]. Returns
  /// whatever value the caller pops the dialog's route with.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? content,
    List<Widget> Function(BuildContext dialogContext)? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: dialogContext.appColors.elevatedSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppleTypography.title3.copyWith(color: dialogContext.appColors.primaryText),
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 10),
                    content,
                  ],
                  if (actions != null) ...[
                    const SizedBox(height: 20),
                    Row(children: actions(dialogContext)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
