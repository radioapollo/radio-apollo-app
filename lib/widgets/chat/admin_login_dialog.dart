/* Admin Login Dialog

   Shown when the admin long-presses the logo.

   FIXES APPLIED:
   - Login button disabled while a request is in-flight (Issue: App crash when spamming admin login)
   - Loading indicator shown instead of button text during request (Issue: Delayed error feedback)
   - Error shown inline in the dialog instead of closing first (Issue: Inconsistent snackbar usage)
*/

import 'package:flutter/material.dart';
import '../../services/chat/auth_service.dart';

class AdminLoginDialog extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onSuccess;

  const AdminLoginDialog({
    super.key,
    required this.authService,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthService authService,
    required VoidCallback onSuccess,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AdminLoginDialog(
        authService: authService,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false; // FIX: track loading state to disable the button

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // FIX: Prevent double-tap / spam by ignoring if already loading
    if (_loading) return;

    setState(() { _loading = true; _error = null; });

    try {
      await widget.authService.login(_controller.text);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        // FIX: Show error inline in the dialog instead of closing and using a snackbar.
        // This is consistent with how other dialogs handle errors in the app.
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
      title: const Text('Admin Login'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller:  _controller,
            obscureText: true,
            autofocus:   true,
            enabled:     !_loading, // FIX: disable input while loading
            decoration:  InputDecoration(
              hintText:  'Wachtwoord',
              // FIX: show error inline with enough space for the full message
              errorText:     _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          // FIX: disable cancel button while loading to prevent orphaned requests
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          // FIX: disable login button while loading — prevents spam/crash
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login'),
        ),
      ],
    );
  }
}