/* Chat Input Field Widget

   The text input and send button at the bottom of the chat screen.

   It shows:
   - an optional "replying to: Jan — hey everyone..." banner above the
     input when the parent has an active reply target, with an X to
     cancel
   - a character countdown when within 30 characters of the limit
   - a spinner on the send button while a message is in flight
   - a small "Xs" pill on the send button during the per-user cooldown
   - a brief "Nog Xs geduld..." hint inside the field if the user taps
     send while the cooldown is still active (Option B behaviour, only
     triggered by the tap — so it's proportional to user action)

   This is a pure presentation widget — all state is passed in via the
   constructor. The parent (ChatScreen) owns the reply state, timers,
   and the send logic.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
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

  /// Active reply target. When non-null, the banner is shown above the
  /// input field and the new message will be sent as a reply.
  final Message? replyingTo;

  /// Called when the user taps the X on the reply banner.
  final VoidCallback? onCancelReply;

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
    this.replyingTo,
    this.onCancelReply,
  });

  bool get _onCooldown => cooldownRemaining > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyingTo != null) _buildReplyBanner(replyingTo!),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
            vertical: AppDimensions.paddingSmall,
          ),
          margin: EdgeInsets.fromLTRB(
            AppDimensions.paddingXLarge,
            replyingTo != null
                ? AppDimensions.spaceXSmall
                : AppDimensions.spaceMedium,
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
          ),
          decoration: AppDecorations.chatInputFull(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                      enabled: true,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      decoration: InputDecoration(
                        hintText: replyingTo != null
                            ? 'Schrijf een antwoord...'
                            : 'Typ een bericht...',
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
              const SizedBox(width: AppDimensions.spaceSmall),
              _buildSendButton(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Reply banner ──────────────────────────────────────────────────────────

  Widget _buildReplyBanner(Message reply) {
    final preview = reply.text.length > 60
        ? '${reply.text.substring(0, 59)}…'
        : reply.text;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.spaceMedium,
        AppDimensions.paddingXLarge,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border(
          left: BorderSide(color: AppColors.primaryLight, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Antwoord aan ${reply.username ?? "iemand"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onCancelReply,
            tooltip: 'Annuleer antwoord',
          ),
        ],
      ),
    );
  }

  // ── Subline below the text field ──────────────────────────────────────────

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