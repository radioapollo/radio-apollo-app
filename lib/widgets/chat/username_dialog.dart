/* Username Dialog

   Shown when the user opens the chat screen without a username, OR
   when an existing user hasn't yet accepted the current EULA version.

   The user picks a display name (3–20 characters), explicitly accepts
   the gebruiksvoorwaarden via a required checkbox, and the name is
   then checked for uniqueness and saved via UserService.

   The dialog IS dismissible — users can tap "Later" to skip and
   choose later via the "Kies een naam" button in the title bar.

   EULA acceptance
   ───────────────
   Apple Guideline 1.2 requires explicit user acceptance of an EULA
   prohibiting objectionable content before they can post UGC. The
   "Opslaan" button stays disabled until the box is ticked.

   Existing users
   ──────────────
   If the user already has a username, the field is pre-filled with
   it. The acceptance checkbox starts unticked unless they've already
   accepted the current version, in which case the dialog is
   essentially a no-op confirmation step.
*/

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import '../../services/chat/eula_service.dart';
import '../../services/chat/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/url_launcher_utils.dart';

class UsernameDialog extends StatefulWidget {
  const UsernameDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const UsernameDialog(),
    );
  }

  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _loading = false;
  late bool _termsAccepted;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: UserService.instance.username ?? '',
    );
    _termsAccepted = EulaService.instance.hasAccepted;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    if (!_termsAccepted) {
      setState(() => _error =
          'Je moet de gebruiksvoorwaarden accepteren om te kunnen chatten.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await EulaService.instance.accept();

      if (name != UserService.instance.username) {
        await UserService.instance.setUsername(name);
      }
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

  @override
  Widget build(BuildContext context) {
    final hasExistingUsername = UserService.instance.hasUsername;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
      ),
      title: Text(
        hasExistingUsername
            ? 'Bevestig je gebruikersnaam'
            : 'Kies een gebruikersnaam',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasExistingUsername
                ? 'Accepteer onze gebruiksvoorwaarden om te kunnen blijven chatten.'
                : 'Deze naam is zichtbaar voor andere chatters.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: !hasExistingUsername,
            maxLength: 20,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'Jouw naam...',
              errorText: _error,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                borderSide: const BorderSide(
                  color: AppColors.primaryLight,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),

          // ── EULA checkbox ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _termsAccepted,
                onChanged: _loading
                    ? null
                    : (v) => setState(() {
                          _termsAccepted = v ?? false;
                          if (_error != null) _error = null;
                        }),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      children: [
                        const TextSpan(text: 'Ik ga akkoord met de '),
                        TextSpan(
                          text: 'gebruiksvoorwaarden',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => UrlLauncherUtils.openUrl(
                                  AppConstants.termsOfUseUrl,
                                ),
                        ),
                        const TextSpan(
                          text:
                              ' en begrijp dat ongepaste of beledigende '
                              'berichten verwijderd worden.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text(
            'Later',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Opslaan',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
