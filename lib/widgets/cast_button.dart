/* Cast Button Widget

   An always-available Chromecast button for the home screen player.

   Unlike `GoogleCastMiniController` — which only becomes visible once
   a Cast session is already active — this button shows as soon as at
   least one Cast device has been discovered on the local network, so
   the user has a clear affordance to start casting.

   Behaviour:
   - Hidden entirely on web (Chromecast is mobile-only here).
   - Hidden when there are no discovered devices AND no active session.
     (Avoids showing a useless icon when the user's network has no
     Cast-enabled hardware.)
   - Icons.cast when disconnected, Icons.cast_connected when a session
     is active. Both are tappable.
   - Tap while disconnected → opens a bottom sheet listing the
     discovered devices; picking one starts the session. Connection is
     handled by the audio handler (which loads the radio stream onto
     the cast device automatically).
   - Tap while connected → opens the same sheet, showing the connected
     device, a volume slider, and a "Stop casten" action.

   Why an in-sheet volume slider?
   The phone's hardware volume buttons do not reliably control the
   Cast device's volume on Android, because the audio_service
   foreground notification holds a higher-priority claim on the
   media volume keys than the Cast SDK's media router. Rather than
   fight Android's media routing rules, we expose a slider here that
   talks directly to the Cast SDK via
   `GoogleCastSessionManager.instance.setDeviceVolume(...)`. This
   works the same on iOS and Android.

   Discovery is started/stopped by the parent app lifecycle (see
   `main.dart`); this widget only observes the streams.
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/session.dart';
import '../theme/app_theme.dart';

class CastButton extends StatelessWidget {
  /// Size of the cast icon.
  final double size;

  /// Colour of the cast icon.
  final Color color;

  const CastButton({
    super.key,
    this.size = 24,
    this.color = AppColors.textOnDark,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    return StreamBuilder<List<GoogleCastDevice>>(
      stream: GoogleCastDiscoveryManager.instance.devicesStream,
      builder: (context, devicesSnapshot) {
        final devices = devicesSnapshot.data ?? const <GoogleCastDevice>[];

        return StreamBuilder<GoogleCastSession?>(
          stream: GoogleCastSessionManager.instance.currentSessionStream,
          builder: (context, sessionSnapshot) {
            final isConnected =
                GoogleCastSessionManager.instance.connectionState ==
                GoogleCastConnectState.connected;

            // Nothing to do: no devices and no active session.
            if (devices.isEmpty && !isConnected) {
              return const SizedBox.shrink();
            }

            return IconButton(
              iconSize: size,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 22,
              tooltip: isConnected ? 'Cast-verbinding' : 'Cast naar apparaat',
              icon: Icon(
                isConnected ? Icons.cast_connected : Icons.cast,
                color: color,
                size: size,
              ),
              onPressed: () => _showDevicePicker(context, devices, isConnected),
            );
          },
        );
      },
    );
  }

  // ── Device picker ───────────────────────────────────────────────────────

  void _showDevicePicker(
    BuildContext context,
    List<GoogleCastDevice> devices,
    bool isConnected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      builder: (sheetCtx) {
        // Rebuild the sheet contents whenever the session changes so
        // the volume slider stays in sync with the device.
        return StreamBuilder<GoogleCastSession?>(
          stream: GoogleCastSessionManager.instance.currentSessionStream,
          initialData: GoogleCastSessionManager.instance.currentSession,
          builder: (ctx, sessionSnap) {
            final session = sessionSnap.data;
            final connectedNow =
                GoogleCastSessionManager.instance.connectionState ==
                GoogleCastConnectState.connected;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingXLarge,
                      ),
                      child: Text(
                        connectedNow ? 'Casten' : 'Cast naar apparaat',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMedium),

                    if (devices.isEmpty && !connectedNow)
                      const Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingXLarge),
                        child: Text(
                          'Geen Chromecast-apparaten gevonden.\n'
                          'Zorg dat je op hetzelfde wifi-netwerk zit.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...devices.map(
                        (device) => _buildDeviceTile(sheetCtx, device),
                      ),

                    if (connectedNow) ...[
                      const Divider(height: 24),
                      _VolumeSlider(session: session),
                      const Divider(height: 24),
                      ListTile(
                        leading: const Icon(
                          Icons.stop_circle_outlined,
                          color: AppColors.live,
                        ),
                        title: const Text(
                          'Stop casten',
                          style: TextStyle(color: AppColors.live),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          try {
                            await GoogleCastSessionManager.instance
                                .endSessionAndStopCasting();
                          } catch (e) {
                            debugPrint('[CastButton] End session failed: $e');
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceTile(BuildContext sheetCtx, GoogleCastDevice device) {
    final currentSession = GoogleCastSessionManager.instance.currentSession;
    final isCurrent =
        currentSession != null &&
        currentSession.device?.deviceID == device.deviceID;

    return ListTile(
      leading: Icon(
        isCurrent ? Icons.cast_connected : Icons.cast,
        color: isCurrent ? AppColors.primaryMid : AppColors.textBody,
      ),
      title: Text(
        device.friendlyName,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.textBody,
        ),
      ),
      subtitle: (device.modelName != null && device.modelName!.isNotEmpty)
          ? Text(
              device.modelName!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      onTap: isCurrent
          ? null
          : () async {
              Navigator.of(sheetCtx).pop();
              try {
                await GoogleCastSessionManager.instance.startSessionWithDevice(
                  device,
                );
                // The session listener in the audio handler picks this
                // up and loads the radio stream onto the device.
              } catch (e) {
                debugPrint('[CastButton] Start session failed: $e');
              }
            },
    );
  }
}

// ─── Volume slider ──────────────────────────────────────────────────────────
//
// A stateful slider that reflects (and writes) the connected Cast
// device's volume.
//
// We keep an internal `_localValue` so dragging feels responsive: the
// slider follows the user's finger immediately, and we send updates
// to the device. When the device confirms the new volume (via the
// session stream rebuilding the parent), the parent passes a new
// `session.currentDeviceVolume` in — we adopt that value only when the
// user is not actively dragging, otherwise we'd fight their gesture.

class _VolumeSlider extends StatefulWidget {
  final GoogleCastSession? session;

  const _VolumeSlider({required this.session});

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _localValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _localValue = _clampedSessionVolume(widget.session);
  }

  @override
  void didUpdateWidget(covariant _VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt new device volume only when the user isn't dragging.
    if (!_isDragging) {
      final fromDevice = _clampedSessionVolume(widget.session);
      if ((fromDevice - _localValue).abs() > 0.005) {
        _localValue = fromDevice;
      }
    }
  }

  double _clampedSessionVolume(GoogleCastSession? session) {
    final v = session?.currentDeviceVolume ?? 0.5;
    if (v.isNaN) return 0.5;
    return v.clamp(0.0, 1.0).toDouble();
  }

  void _send(double value) {
    try {
      GoogleCastSessionManager.instance.setDeviceVolume(value);
    } catch (e) {
      debugPrint('[CastButton] setDeviceVolume failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.volume_down,
            color: AppColors.textSecondary,
            size: 22,
          ),
          Expanded(
            child: Slider(
              value: _localValue,
              min: 0.0,
              max: 1.0,
              activeColor: AppColors.primaryMid,
              onChangeStart: (_) => _isDragging = true,
              onChanged: (v) {
                setState(() => _localValue = v);
                // Stream the value to the device while dragging so
                // the volume change feels live, not just on release.
                _send(v);
              },
              onChangeEnd: (v) {
                _isDragging = false;
                _send(v);
              },
            ),
          ),
          const Icon(
            Icons.volume_up,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }
}