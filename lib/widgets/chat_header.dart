/* Chat Header Widget

   Displays the logo at the top of the chat screen.
   Long-pressing the logo opens the admin login (unless already admin).
*/

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';
import 'admin_login_dialog.dart';

class ChatHeader extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onAdminLogin;

  const ChatHeader({
    super.key,
    required this.authService,
    required this.onAdminLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: authService.isAdmin
              ? null
              : () => AdminLoginDialog.show(
                    context,
                    authService: authService,
                    onSuccess: onAdminLogin,
                  ),
          child: Image.asset(
            AppAssets.logo,
            height: AppDimensions.logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}