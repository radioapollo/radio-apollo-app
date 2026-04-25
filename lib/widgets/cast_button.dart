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
     discovered devices; picking one starts the session. Connection
     triggers `CastService.castRadioStream()` through the existing
     session listener in `ApolloNav`, so the stream begins playing on
     the cast device automatically.
   - Tap while connected → opens the same sheet, showing the connected
     device with a "Stop casten" action.

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
                    isConnected ? 'Casten' : 'Cast naar apparaat',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMedium),

                if (devices.isEmpty && !isConnected)
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

                if (isConnected) ...[
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
                // The session listener in ApolloNav picks this up and
                // loads the radio stream onto the device.
              } catch (e) {
                debugPrint('[CastButton] Start session failed: $e');
              }
            },
    );
  }
}
