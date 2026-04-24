/* Chat Input Field Widget

   The text input and send button at the bottom of the chat screen.

   It shows:
   - a character countdown when within 30 characters of the limit
   - a spinner on the send button while a message is in flight
   - a small "Xs" pill on the send button during the per-user cooldown
   - a brief "Nog Xs geduld..." hint inside the field if the user taps
     send while the cooldown is still active (Option B behaviour, only
     triggered by the tap — so it's proportional to user action)

   This is a pure presentation widget — all state is passed in via the
   constructor. The parent (ChatScreen) owns the timers and the logic.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxLength;
  final int charsLeft;
  final VoidCallback onSend;
  final bool isSending;
  final int cooldownRemaining;
  final bool showCooldownHint;

  const ChatInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.maxLength,
    required this.charsLeft,
    required this.onSend,
    this.isSending = false,
    this.cooldownRemaining = 0,
    this.showCooldownHint = false,
  });

  bool get _onCooldown => cooldownRemaining > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
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
          // ── Text field + counter + (optional) cooldown hint ───────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTextStyles.inputText,
                  maxLength: maxLength,
                  enabled: true, // Always enabled - only send button is disabled
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  decoration: const InputDecoration(
                    hintText: 'Typ een bericht...',
                    hintStyle: AppTextStyles.inputHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
                _buildSubline(),
              ],
            ),
          ),

          // ── Send button ───────────────────────────────────────────────────
          const SizedBox(width: AppDimensions.spaceSmall),
          _buildSendButton(),
        ],
      ),
    );
  }

  // ── Subline below the text field ──────────────────────────────────────────
  //
  // Shows, in order of priority:
  //   1. the cooldown hint flash (if the user just tapped send while waiting)
  //   2. the character counter (if near the limit)
  //   3. nothing

  Widget _buildSubline() {
    if (showCooldownHint) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Nog ${cooldownRemaining}s geduld...',
          style: const TextStyle(
            color: AppColors.textOnDarkMuted,
            fontSize: 11,
          ),
        ),
      );
    }
    if (charsLeft <= 30) {
      return Text(
        '$charsLeft',
        style: TextStyle(
          color: charsLeft <= 10
              ? AppColors.charCounterWarn
              : AppColors.loadingIndicator,
          fontSize: 11,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Send button: icon, spinner, or cooldown pill ──────────────────────────

  Widget _buildSendButton() {
    if (isSending) {
      return const SizedBox(
        width: AppDimensions.iconLarge,
        height: AppDimensions.iconLarge,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textOnDark,
          ),
        ),
      );
    }

    if (_onCooldown) {
      // Tappable so the user's tap reaches _sendMessage, which will
      // flash the cooldown hint. The pill itself just shows the seconds.
      return GestureDetector(
        onTap: onSend,
        child: Container(
          height: AppDimensions.iconLarge,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Text(
            '${cooldownRemaining}s',
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onSend,
      child: const Icon(
        Icons.send,
        color: AppColors.textOnDark,
        size: AppDimensions.iconLarge,
      ),
    );
  }
}