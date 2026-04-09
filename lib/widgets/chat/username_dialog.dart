/* Username Dialog

   Shown the first time a user opens the chat screen.

   The user picks a display name (3–20 characters) which is then
   checked for uniqueness and saved via UserService.
*/

import 'package:flutter/material.dart';
import '../../services/chat/user_service.dart';
import '../../theme/app_theme.dart';

class UsernameDialog extends StatefulWidget {
  const UsernameDialog({super.key});

  /// Shows the dialog and returns the chosen name, or null if dismissed.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UsernameDialog(),
    );
  }

  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Kies een naam van minimaal 3 tekens.');
      return;
    }
    if (name.length > 20) {
      setState(() => _error = 'Maximaal 20 tekens toegestaan.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await UserService.instance.setUsername(name);
      if (mounted) Navigator.of(context).pop(name);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge)),
      title: const Text(
        'Kies een gebruikersnaam',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deze naam is zichtbaar voor andere chatters.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus:  true,
            maxLength:  20,
            enabled:    !_loading,
            decoration: InputDecoration(
              hintText:  'Jouw naam...',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: const BorderSide(
                    color: AppColors.primaryLight, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
            onChanged:   (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Opslaan',
                  style: TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}