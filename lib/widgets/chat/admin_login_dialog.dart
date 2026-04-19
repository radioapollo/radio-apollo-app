/* Admin Login Dialog

   Shown when the admin long-presses the logo on the chat screen.

   It handles:
   - accepting a password
   - calling AuthService.login() and showing a loading state
   - surfacing server errors inline inside the dialog
   - disabling all actions while a request is in flight so the user
     cannot spam the login button or cancel an in-flight request
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
      builder: (_) =>
          AdminLoginDialog(authService: authService, onSuccess: onSuccess),
    );
  }

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
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
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.login(_controller.text);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
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
      title: const Text('Admin Login'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'Wachtwoord',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login'),
        ),
      ],
    );
  }
}
