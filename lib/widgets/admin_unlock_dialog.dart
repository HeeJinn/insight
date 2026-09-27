import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_lock_provider.dart';
import '../ui/insight_ui.dart';

/// Asks for the admin PIN, or has the admin create one the first time.
/// Resolves to true once the admin area is unlocked.
Future<bool> showAdminUnlockDialog(BuildContext context) async {
  final unlocked = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AdminUnlockDialog(),
  );
  return unlocked ?? false;
}

class _AdminUnlockDialog extends ConsumerStatefulWidget {
  const _AdminUnlockDialog();

  @override
  ConsumerState<_AdminUnlockDialog> createState() => _AdminUnlockDialogState();
}

class _AdminUnlockDialogState extends ConsumerState<_AdminUnlockDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  String? _error;
  late final bool _creating = !ref.read(adminLockControllerProvider).hasPin;

  static const _minLength = 4;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lock = ref.read(adminLockControllerProvider);
    final pin = _pin.text.trim();

    if (_creating) {
      if (pin.length < _minLength) {
        setState(() => _error = 'Use at least $_minLength digits.');
        return;
      }
      if (pin != _confirm.text.trim()) {
        setState(() => _error = "The PINs don't match.");
        return;
      }
      await lock.setPin(pin);
      lock.unlock();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    if (lock.tryUnlock(pin)) {
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Incorrect PIN.';
        _pin.clear();
      });
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    FocusNode? focusNode,
    bool autofocus = false,
    TextInputAction action = TextInputAction.go,
    ValueChanged<String>? onSubmitted,
  }) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      placeholder: placeholder,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 8,
      textAlign: TextAlign.center,
      textInputAction: action,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: onSubmitted ?? (_) => _submit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final danger = InsightColors.danger.resolveFrom(context);
    return CupertinoAlertDialog(
      title: Text(_creating ? 'Create Admin PIN' : 'Admin Access'),
      content: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            _creating
                ? 'This PIN keeps the admin area closed while the kiosk is running.'
                : 'Enter the admin PIN to leave the kiosk.',
          ),
          const SizedBox(height: 12),
          _field(
            controller: _pin,
            placeholder: 'PIN',
            autofocus: true,
            action: _creating ? TextInputAction.next : TextInputAction.go,
            onSubmitted: _creating
                ? (_) => _confirmFocus.requestFocus()
                : (_) => _submit(),
          ),
          if (_creating) ...[
            const SizedBox(height: 8),
            _field(
              controller: _confirm,
              focusNode: _confirmFocus,
              placeholder: 'Confirm PIN',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  size: 14,
                  color: danger,
                ),
                const SizedBox(width: 4),
                Text(
                  _error!,
                  style: InsightText.footnote.copyWith(color: danger),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: Text(_creating ? 'Create' : 'Unlock'),
        ),
      ],
    );
  }
}
