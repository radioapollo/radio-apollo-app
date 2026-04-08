/* Admin Login Dialog

   Shown when the admin long-presses the logo.

   Sends the password to AuthService for verification.
   Shows a snackbar on failure, closes the dialog on success.
*/

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    try {
      await widget.authService.login(_controller.text);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ongeldig wachtwoord')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin Login'),
      content: TextField(
        controller:  _controller,
        obscureText: true,
        autofocus:   true,
        decoration:  const InputDecoration(hintText: 'Wachtwoord'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Login'),
        ),
      ],
    );
  }
}