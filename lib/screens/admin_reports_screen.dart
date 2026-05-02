/* Admin Reports Screen

   Shown only to logged-in admins. Lists all pending chat reports
   newest-first. For each one, the admin can:

   - delete the offending message
   - ban the reported user (and delete the message)
   - dismiss the report (no action needed)

   Resolved reports are stamped with the action and timestamp on the
   server; this screen filters them out automatically by listening
   only to status == 'pending'.
*/

import 'package:flutter/material.dart';
import '../models/report.dart';
import '../services/chat/admin_moderation_service.dart';
import '../theme/app_theme.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            image: AppDecorations.backgroundWatermark,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: StreamBuilder<List<Report>>(
                    stream: AdminModerationService.instance
                        .pendingReportsStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.loadingIndicator,
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Kon meldingen niet laden:\n${snap.error}',
                              style: const TextStyle(
                                color: AppColors.textBody,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final reports = snap.data ?? const <Report>[];
                      if (reports.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Geen openstaande meldingen.',
                              style: TextStyle(
                                color: AppColors.textBody,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.paddingLarge,
                          0,
                          AppDimensions.paddingLarge,
                          AppDimensions.paddingLarge,
                        ),
                        itemCount: reports.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppDimensions.spaceMedium),
                        itemBuilder: (context, i) =>
                            _ReportCard(report: reports[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingLarge,
        AppDimensions.paddingLarge,
        AppDimensions.paddingLarge,
        AppDimensions.paddingMedium,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textBody),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppDimensions.spaceMedium),
          const Text(
            'Meldingen',
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ReportCard
// ════════════════════════════════════════════════════════════════════════════

class _ReportCard extends StatefulWidget {
  final Report report;
  const _ReportCard({required this.report});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final time = r.timestamp != null ? _formatRelative(r.timestamp!) : '';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.navyDeep,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: reason + time
          Row(
            children: [
              Expanded(
                child: Text(
                  r.reason,
                  style: const TextStyle(
                    color: AppColors.live,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSmall),

          // Reported username + text
          if (r.reportedUsername != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Van: ${r.reportedUsername}',
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingSmall),
            decoration: BoxDecoration(
              color: AppColors.navyMedium,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: Text(
              r.reportedText.isEmpty ? '(leeg bericht)' : r.reportedText,
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSmall),

          // Reporter info
          if (r.reporterUsername != null)
            Text(
              'Gemeld door: ${r.reporterUsername}',
              style: const TextStyle(
                color: AppColors.textOnDarkMuted,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: AppDimensions.spaceMedium),

          // Action buttons
          if (_busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                  icon: Icons.delete_outline,
                  label: 'Verwijder bericht',
                  onTap: _deleteMessage,
                ),
                if (r.reportedUsername != null)
                  _actionButton(
                    icon: Icons.gavel_outlined,
                    label: 'Verban ${r.reportedUsername}',
                    onTap: _banUser,
                  ),
                _actionButton(
                  icon: Icons.check,
                  label: 'Negeer',
                  onTap: _dismiss,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16, color: AppColors.textOnDark),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textOnDark,
        ),
      ),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.steelMedium,
        foregroundColor: AppColors.textOnDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _deleteMessage() async {
    final r = widget.report;
    if (r.messageId == null) {
      _snack('Geen bericht-ID — kan niet verwijderen.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminModerationService.instance.deleteMessage(r.messageId!);
      await AdminModerationService.instance.updateReport(
        reportId: r.id,
        status: 'resolved',
        action: 'deleted',
      );
      _snack('Bericht verwijderd.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _banUser() async {
    final r = widget.report;
    if (r.reportedUsername == null) return;

    final reasonController = TextEditingController(text: r.reason);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${r.reportedUsername} verbannen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Deze gebruikersnaam kan nooit meer chatten en kan niet '
              'opnieuw geclaimd worden.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reden'),
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verbannen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AdminModerationService.instance.banUsername(
        r.reportedUsername!,
        reason: reasonController.text.trim(),
      );
      // Also delete the offending message if we have its ID.
      if (r.messageId != null) {
        try {
          await AdminModerationService.instance.deleteMessage(r.messageId!);
        } catch (_) {/* non-fatal */}
      }
      await AdminModerationService.instance.updateReport(
        reportId: r.id,
        status: 'resolved',
        action: 'banned',
      );
      _snack('${r.reportedUsername} is verbannen.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _busy = true);
    try {
      await AdminModerationService.instance.updateReport(
        reportId: widget.report.id,
        status: 'dismissed',
        action: 'no_action',
      );
      _snack('Melding genegeerd.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'nu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} u';
    return '${diff.inDays} d';
  }
}