/* Cast Button Widget

   An always-visible casting button for the home screen player.

   Tapping it opens a draggable bottom sheet listing discovered
   Chromecasts AND Sonos speakers together. Picking a Chromecast starts
   a Cast session; picking a Sonos speaker hands off to the audio
   handler, which loads the radio stream onto the speaker over its local
   UPnP API.

   The sheet spans the full width, sits flush to the bottom edges, and
   has a grab handle at the top so the user can drag it taller or
   shorter (DraggableScrollableSheet). Its content scrolls, which keeps
   long device lists usable.

   Behaviour:
   - Hidden entirely on web (casting is mobile-only here).
   - Otherwise always shown. If no devices are found, the sheet explains
     that rather than the button silently vanishing.
   - Icons.cast when disconnected, Icons.cast_connected when a Chromecast
     session or a Sonos speaker is active.
   - When connected, the sheet shows a volume slider and a stop action.

   Chromecast vs Sonos
   ───────────────────
   Chromecast has a full SDK (sessions, media status, volume) via
   flutter_chrome_cast. Sonos has none of that — it's driven directly
   through SonosService (SSDP discovery + SOAP control). The two paths
   are kept separate: the Chromecast code is unchanged, the Sonos code
   sits alongside it. If Sonos fails on a network, Chromecast is
   unaffected.

   Why an in-sheet volume slider?
   The phone's hardware volume buttons do not reliably control the Cast
   device's volume on Android, because the audio_service foreground
   notification holds a higher-priority claim on the media volume keys
   than the Cast SDK's media router. So we expose a slider that talks
   directly to the Cast SDK. The Sonos slider is analogous, talking to
   the speaker via SonosService.
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/session.dart';
import '../theme/app_theme.dart';
import '../models/sonos_device.dart';
import '../services/sonos_service.dart';
import 'service_provider.dart';

class CastButton extends StatelessWidget {
  final double size;

  final Color color;

  const CastButton({
    super.key,
    this.size = 24,
    this.color = AppColors.textOnDark,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    // Fire-and-forget: refresh Sonos discovery whenever the player
    // builds, so speakers show up alongside Chromecasts. Safe to call
    // repeatedly — overlapping sweeps are coalesced inside the service.
    SonosService.instance.discover();

    return StreamBuilder<List<GoogleCastDevice>>(
      stream: GoogleCastDiscoveryManager.instance.devicesStream,
      builder: (context, devicesSnapshot) {
        final devices = devicesSnapshot.data ?? const <GoogleCastDevice>[];

        return StreamBuilder<List<SonosDevice>>(
          stream: SonosService.instance.devicesStream,
          initialData: SonosService.instance.devices,
          builder: (context, sonosSnapshot) {
            final sonosDevices = sonosSnapshot.data ?? const <SonosDevice>[];

            return StreamBuilder<GoogleCastSession?>(
              stream: GoogleCastSessionManager.instance.currentSessionStream,
              builder: (context, sessionSnapshot) {
                final isConnected =
                    GoogleCastSessionManager.instance.connectionState ==
                    GoogleCastConnectState.connected;

                // Defensive: if the ServiceProvider can't be found from
                // here, treat Sonos as inactive rather than throwing and
                // blanking the button.
                bool sonosActive = false;
                try {
                  sonosActive = ServiceProvider.of(
                    context,
                  ).audioHandler.isSonos;
                } catch (_) {
                  sonosActive = false;
                }

                final showConnected = isConnected || sonosActive;

                // Always visible (except on web). Device presence only
                // affects the sheet contents, not the icon.
                return IconButton(
                  iconSize: size,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 22,
                  tooltip: showConnected
                      ? 'Cast-verbinding'
                      : 'Cast naar apparaat',
                  icon: Icon(
                    showConnected ? Icons.cast_connected : Icons.cast,
                    color: color,
                    size: size,
                  ),
                  onPressed: () => _showDevicePicker(
                    context,
                    devices,
                    sonosDevices,
                    isConnected,
                  ),
                );
              },
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
    List<SonosDevice> sonosDevices,
    bool isConnected,
  ) {
    // Capture the audio handler from a context under ServiceProvider.
    // Defensive: may be null if not found.
    dynamic audioHandler;
    try {
      audioHandler = ServiceProvider.of(context).audioHandler;
    } catch (_) {
      audioHandler = null;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // let the sheet grow beyond the default cap
      builder: (sheetCtx) {
        final scrollController = ScrollController();
        // The sheet has a fixed white background. AppColors text colors
        // are theme-aware (white in dark mode) and would be invisible here,
        // so the sheet uses explicit dark colors (black87/black54). The
        // light Theme wrapper keeps Material defaults (ListTile, Slider)
        // light-on-white too.
        return Theme(
          data: ThemeData.light(),
          child: FractionallySizedBox(
          heightFactor: 0.6, // fixed ~60% of screen height
          child: Builder(
            builder: (dragCtx) {
              return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusXLarge),
                ),
              ),
              child: StreamBuilder<GoogleCastSession?>(
                stream: GoogleCastSessionManager.instance.currentSessionStream,
                initialData: GoogleCastSessionManager.instance.currentSession,
                builder: (ctx, sessionSnap) {
                  final session = sessionSnap.data;
                  final connectedNow =
                      GoogleCastSessionManager.instance.connectionState ==
                      GoogleCastConnectState.connected;

                  final sonosActive = audioHandler?.isSonos == true;

                  return StreamBuilder<List<SonosDevice>>(
                    stream: SonosService.instance.devicesStream,
                    initialData: sonosDevices,
                    builder: (ctx2, sonosSnap) {
                      final liveSonos = sonosSnap.data ?? const <SonosDevice>[];

                      final nothingFound =
                          devices.isEmpty &&
                          liveSonos.isEmpty &&
                          !connectedNow &&
                          !sonosActive;

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.paddingLarge,
                        ),
                        children: [
                          // Grab handle
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceMedium),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.paddingXLarge,
                            ),
                            child: Text(
                              (connectedNow || sonosActive)
                                  ? 'Casten'
                                  : 'Cast naar apparaat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceMedium),

                          if (nothingFound)
                            Padding(
                              padding: EdgeInsets.all(
                                AppDimensions.paddingXLarge,
                              ),
                              child: Text(
                                'Geen apparaten gevonden.\n'
                                'Zorg dat je op hetzelfde wifi-netwerk zit.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else ...[
                            // Chromecast devices
                            ...devices.map(
                              (device) => _buildDeviceTile(sheetCtx, device),
                            ),
                            // Sonos speakers, in the same list
                            ...liveSonos.map(
                              (device) => _buildSonosTile(
                                sheetCtx,
                                context,
                                audioHandler,
                                device,
                              ),
                            ),
                          ],

                          // Chromecast connected controls
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
                                  debugPrint(
                                    '[CastButton] End session failed: $e',
                                  );
                                }
                              },
                            ),
                          ],

                          // Sonos connected controls
                          if (sonosActive &&
                              !connectedNow &&
                              audioHandler != null) ...[
                            const Divider(height: 24),
                            _SonosVolumeSlider(audioHandler: audioHandler),
                            const Divider(height: 24),
                            ListTile(
                              leading: const Icon(
                                Icons.stop_circle_outlined,
                                color: AppColors.live,
                              ),
                              title: const Text(
                                'Stop afspelen',
                                style: TextStyle(color: AppColors.live),
                              ),
                              onTap: () async {
                                Navigator.of(sheetCtx).pop();
                                try {
                                  await audioHandler.disconnectSonos();
                                } catch (e) {
                                  debugPrint(
                                    '[CastButton] Sonos disconnect failed: $e',
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
              );
            },
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
        color: isCurrent ? AppColors.primaryMid : Colors.black87,
      ),
      title: Text(
        device.friendlyName,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: (device.modelName != null && device.modelName!.isNotEmpty)
          ? Text(
              device.modelName!,
              style: TextStyle(color: Colors.black54, fontSize: 12),
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
              } catch (e) {
                debugPrint('[CastButton] Start session failed: $e');
              }
            },
    );
  }

  // ── Sonos tile ────────────────────────────────────────────────────────────

  Widget _buildSonosTile(
    BuildContext sheetCtx,
    BuildContext liveCtx,
    dynamic audioHandler,
    SonosDevice device,
  ) {
    final isCurrent =
        audioHandler?.isSonos == true &&
        audioHandler?.sonosDevice?.uuid == device.uuid;

    return ListTile(
      leading: Icon(
        Icons.speaker,
        color: isCurrent ? AppColors.primaryMid : Colors.black87,
      ),
      title: Text(
        device.roomName,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        'Sonos',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      onTap: (isCurrent || audioHandler == null)
          ? null
          : () async {
              Navigator.of(sheetCtx).pop();
              try {
                await audioHandler.connectSonos(device);
              } catch (e) {
                if (liveCtx.mounted) {
                  ScaffoldMessenger.of(
                    liveCtx,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
    );
  }
}

// ─── Volume slider (Chromecast) ─────────────────────────────────────────────

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
          Icon(Icons.volume_down, color: Colors.black54, size: 22),
          Expanded(
            child: Slider(
              value: _localValue,
              min: 0.0,
              max: 1.0,
              activeColor: AppColors.primaryMid,
              onChangeStart: (_) => _isDragging = true,
              onChanged: (v) {
                setState(() => _localValue = v);

                _send(v);
              },
              onChangeEnd: (v) {
                _isDragging = false;
                _send(v);
              },
            ),
          ),
          Icon(Icons.volume_up, color: Colors.black54, size: 22),
        ],
      ),
    );
  }
}

// ─── Volume slider (Sonos) ──────────────────────────────────────────────────
//
// Analogous to _VolumeSlider but talks to the speaker through the audio
// handler (which forwards to SonosService). Sonos volume is 0–100; the
// slider works in 0.0–1.0 and converts on send. The initial value is
// read once from the speaker; if that read fails we start at 50%.

class _SonosVolumeSlider extends StatefulWidget {
  final dynamic audioHandler;

  const _SonosVolumeSlider({required this.audioHandler});

  @override
  State<_SonosVolumeSlider> createState() => _SonosVolumeSliderState();
}

class _SonosVolumeSliderState extends State<_SonosVolumeSlider> {
  double _localValue = 0.5;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadInitialVolume();
  }

  Future<void> _loadInitialVolume() async {
    try {
      final device = widget.audioHandler.sonosDevice;
      if (device == null) return;
      final vol = await SonosService.instance.getVolume(device);
      if (vol != null && mounted && !_isDragging) {
        setState(() => _localValue = (vol / 100).clamp(0.0, 1.0));
      }
    } catch (_) {
      // Keep the 50% default.
    }
  }

  void _send(double value) {
    widget.audioHandler.setSonosVolume((value * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
      ),
      child: Row(
        children: [
          Icon(Icons.volume_down, color: Colors.black54, size: 22),
          Expanded(
            child: Slider(
              value: _localValue,
              min: 0.0,
              max: 1.0,
              activeColor: AppColors.primaryMid,
              onChangeStart: (_) => _isDragging = true,
              onChanged: (v) {
                setState(() => _localValue = v);
                _send(v);
              },
              onChangeEnd: (v) {
                _isDragging = false;
                _send(v);
              },
            ),
          ),
          Icon(Icons.volume_up, color: Colors.black54, size: 22),
        ],
      ),
    );
  }
}
