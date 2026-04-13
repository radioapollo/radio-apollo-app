/* Username Prompt Widget

   A tappable bar shown in place of the chat input field when the
   user has not yet picked a username. Invites them to choose one
   so they can start chatting.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class UsernamePrompt extends StatelessWidget {
  final VoidCallback onTap;

  const UsernamePrompt({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical:   AppDimensions.paddingSmall + 4,
        ),
        margin: const EdgeInsets.fromLTRB(
          AppDimensions.paddingXLarge,
          AppDimensions.spaceMedium,
          AppDimensions.paddingXLarge,
          AppDimensions.paddingXLarge,
        ),
        decoration: AppDecorations.chatInputFull(),
        child: const Row(
          children: [
            Icon(Icons.person_add_alt_1,
                color: AppColors.textOnDarkMuted, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kies een naam om mee te chatten',
                style: TextStyle(
                    color: AppColors.textOnDarkMuted, fontSize: 14),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: AppColors.textOnDarkMuted, size: 14),
          ],
        ),
      ),
    );
  }
}