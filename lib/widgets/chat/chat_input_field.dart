/* Chat Input Field Widget

   The text input and send button at the bottom of the chat screen.
   Shows a character countdown when within 30 characters of the limit.

   This is a pure presentation widget — it receives the max length
   and character count from its parent rather than reading ChatService.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final int charsLeft;
  final VoidCallback onSend;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.maxLength,
    required this.charsLeft,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical:   AppDimensions.paddingSmall,
      ),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.spaceMedium,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      decoration: AppDecorations.chatInputFull(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field + counter ──────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller:  controller,
                  style:       AppTextStyles.inputText,
                  maxLength:   maxLength,
                  buildCounter: (_, {required currentLength,
                      required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    hintText:  'Typ een bericht...',
                    hintStyle: AppTextStyles.inputHint,
                    border:    InputBorder.none,
                    isDense:   true,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
                if (charsLeft <= 30)
                  Text(
                    '$charsLeft',
                    style: TextStyle(
                      color: charsLeft <= 10
                          ? AppColors.charCounterWarn
                          : AppColors.loadingIndicator,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // ── Send button ───────────────────────────────────────────────────
          const SizedBox(width: AppDimensions.spaceSmall),
          GestureDetector(
            onTap: onSend,
            child: const Icon(
              Icons.send,
              color: AppColors.textOnDark,
              size:  AppDimensions.iconLarge,
            ),
          ),
        ],
      ),
    );
  }
}