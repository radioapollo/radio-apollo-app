/* Audio Handler

   Manages the live radio stream playback and the system media notification.

   Notes on live-stream behaviour:
   Pausing a live stream would keep the player's buffer, which makes the
   user fall behind the live broadcast when they resume. This handler uses
   stop() in place of pause() and reloads the URL on resume so playback
   always jumps back to the current live position.

   Cast awareness:
   When a Google Cast session is active, the local just_audio player must
   stay silent and all play / pause / stop commands are forwarded to the
   Cast device. The PlaybackState (which drives the system notification
   and the in-app play/pause icon) is then derived from the Cast device's
   media status stream rather than from the local player. This avoids:
   - Double audio (phone + speakers playing at the same time)
   - The "pause" button doing nothing on the Cast device
   - The notification flickering between the local audio_service one and
     the Cast SDK one

   It handles:
   - stream playback with just_audio (when not casting)
   - stream playback on Chromecast via flutter_chrome_cast (when casting)
   - publishing PlaybackState and MediaItem for audio_service
   - fetching the current song title every 10 seconds from the stats endpoint
   - stripping HTML entities from the song title metadata
   - showing a default logo as notification artwork when no program image is set
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../constants/constants.dart';
import 'cast_service.dart';

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  Timer? _metadataTimer;
  String _currentProgram = '';
  String _lastSongTitle = '';
  Uri? _defaultArtUri;
  Uri? _programArtUri;

  // ── Cast state ────────────────────────────────────────────────────────────
  //
  // Tracks whether a Cast session is currently active. When true, all
  // playback is delegated to the Cast device and the local player is
  // kept stopped.

  StreamSubscription<GoogleCastSession?>? _castSessionSub;
  StreamSubscription<GoggleCastMediaStatus?>? _castMediaStatusSub;
  bool _isCasting = false;

  /// Whether a Cast session is currently active (radio is on speakers,
  /// not on the phone).
  bool get isCasting => _isCasting;

  RadioAudioHandler() {
    _initDefaultArt();

    _player.playerStateStream.listen((state) {
      // While casting, the local player is intentionally idle; do not
      // let its state overwrite the PlaybackState that we derive from
      // the Cast device.
      if (_isCasting) return;

      final playing = state.playing;

      playbackState.add(
        PlaybackState(
          controls: [if (playing) MediaControl.pause else MediaControl.play],
          systemActions: const {MediaAction.play, MediaAction.pause},
          playing: playing,
          processingState: _mapState(state.processingState),
          updatePosition: Duration.zero,
        ),
      );

      if (playing) {
        _startMetadataPolling();
      } else {
        _stopMetadataPolling();
      }
    });

    if (!kIsWeb && Platform.isIOS) {
      _player.setAutomaticallyWaitsToMinimizeStalling(false);
    }

    if (!kIsWeb) {
      _initCastListeners();
    }
  }

  // ── Cast listeners ────────────────────────────────────────────────────────

  void _initCastListeners() {
    // Session changes → flip into / out of cast mode.
    _castSessionSub = GoogleCastSessionManager.instance.currentSessionStream
        .listen((session) async {
          final connected =
              session != null &&
              GoogleCastSessionManager.instance.connectionState ==
                  GoogleCastConnectState.connected;

          if (connected && !_isCasting) {
            await _enterCastMode();
          } else if (!connected && _isCasting) {
            await _exitCastMode();
          }
        });

    // Media status changes on the Cast device → mirror them into our
    // PlaybackState so the notification and the in-app icon are accurate.
    _castMediaStatusSub = GoogleCastRemoteMediaClient.instance.mediaStatusStream
        .listen((status) {
          if (!_isCasting) return;
          _publishCastPlaybackState(status);
        });
  }

  Future<void> _enterCastMode() async {
    _isCasting = true;

    // Silence the local player immediately to avoid double-audio.
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioHandler] Local stop on cast start failed: $e');
    }

    // Keep metadata polling running while casting so the song title in
    // the notification stays fresh.
    _startMetadataPolling();

    // Load the stream onto the Cast device. This handler now owns the
    // Cast session lifecycle entirely (ApolloNav no longer listens),
    // so this is the single place the stream gets loaded onto the
    // device when the session opens.
    try {
      await CastService.instance.castRadioStream(
        programTitle: _currentProgram.isNotEmpty ? _currentProgram : null,
        imageUrl: _programArtUri?.toString(),
      );
    } catch (e) {
      debugPrint('[AudioHandler] castRadioStream failed: $e');
    }

    // Optimistic playback state: we just told the Cast device to play.
    // The mediaStatusStream listener will refine this once the device
    // confirms.
    _publishCastPlaybackState(null, optimisticPlaying: true);
  }

  Future<void> _exitCastMode() async {
    _isCasting = false;

    // We do NOT auto-resume on the phone when casting ends. The user
    // explicitly stopped casting; resuming on the phone would be
    // surprising. Instead, publish a stopped state so the UI shows
    // a play button and the user can tap to resume locally.
    _stopMetadataPolling();

    playbackState.add(
      PlaybackState(
        controls: const [MediaControl.play],
        systemActions: const {MediaAction.play, MediaAction.pause},
        playing: false,
        processingState: AudioProcessingState.idle,
        updatePosition: Duration.zero,
      ),
    );
  }

  void _publishCastPlaybackState(
    GoggleCastMediaStatus? status, {
    bool? optimisticPlaying,
  }) {
    final state = status?.playerState;
    final castPlaying =
        optimisticPlaying ??
        (state == CastMediaPlayerState.playing ||
            state == CastMediaPlayerState.buffering);

    final processing = _mapCastState(state);

    playbackState.add(
      PlaybackState(
        controls: [if (castPlaying) MediaControl.pause else MediaControl.play],
        systemActions: const {MediaAction.play, MediaAction.pause},
        playing: castPlaying,
        processingState: processing,
        updatePosition: Duration.zero,
      ),
    );
  }

  // Conservative mapping that only relies on the player states we are
  // certain exist in flutter_chrome_cast (playing, paused, buffering,
  // idle, unknown). Anything else maps to `ready`, which is the safe
  // default for a live stream's notification.
  AudioProcessingState _mapCastState(CastMediaPlayerState? state) {
    if (state == CastMediaPlayerState.buffering) {
      return AudioProcessingState.buffering;
    }
    return AudioProcessingState.ready;
  }

  // ── Default artwork ───────────────────────────────────────────────────────

  Future<void> _initDefaultArt() async {
    try {
      final byteData = await rootBundle.load(
        'assets/images/Logo/transparant.png',
      );
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/radio_apollo_logo.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _defaultArtUri = file.uri;
    } catch (e) {
      debugPrint('[AudioHandler] Failed to init default art: $e');
    }
  }

  AudioProcessingState _mapState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ── HTML stripping ────────────────────────────────────────────────────────

  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  // ── Metadata polling ──────────────────────────────────────────────────────

  void _startMetadataPolling() {
    _metadataTimer?.cancel();
    _fetchAndUpdateMetadata();
    _metadataTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchAndUpdateMetadata(),
    );
  }

  void _stopMetadataPolling() {
    _metadataTimer?.cancel();
    _metadataTimer = null;
  }

  Future<void> _fetchAndUpdateMetadata() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.statsUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final rawTitle = (jsonDecode(response.body)['songtitle'] ?? '')
            .toString()
            .trim();
        final songTitle = _stripHtml(rawTitle);

        if (songTitle.isNotEmpty && songTitle != _lastSongTitle) {
          _lastSongTitle = songTitle;
          _updateMediaItem(songTitle);
        }
      }
    } catch (e) {
      debugPrint('[AudioHandler] Stats fetch error: $e');
    }
  }

  // ── Media item ────────────────────────────────────────────────────────────

  void _updateMediaItem(String songTitle) {
    final parts = songTitle.split(' - ');
    final artist = parts.length > 1 ? parts[0].trim() : 'Radio Apollo';
    final title = parts.length > 1 ? parts[1].trim() : songTitle;
    final album = _currentProgram.isNotEmpty
        ? '$_currentProgram — Radio Apollo'
        : 'Radio Apollo';
    final artUri = _programArtUri ?? _defaultArtUri;

    mediaItem.add(
      MediaItem(
        id: AppConstants.streamUrl,
        title: title,
        artist: artist,
        album: album,
        artUri: artUri,
      ),
    );
  }

  void setCurrentProgram(String programName, {String? imageUrl}) {
    _currentProgram = programName;
    _programArtUri = (imageUrl != null && imageUrl.isNotEmpty)
        ? Uri.parse(imageUrl)
        : null;
    if (_lastSongTitle.isNotEmpty) {
      _updateMediaItem(_lastSongTitle);
    }
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> _startPlayback() async {
    mediaItem.add(
      MediaItem(
        id: AppConstants.streamUrl,
        title: _currentProgram.isNotEmpty ? _currentProgram : 'Radio Apollo',
        artist: 'LIVE uitzending',
        album: 'Radio Apollo',
        artUri: _programArtUri ?? _defaultArtUri,
      ),
    );

    if (_isCasting) {
      // Tell the Cast device to (re)start. If no media is loaded yet
      // (e.g. session just started), load it; otherwise resume.
      try {
        final hasMedia =
            GoogleCastRemoteMediaClient.instance.mediaStatus != null;
        if (hasMedia) {
          await GoogleCastRemoteMediaClient.instance.play();
        } else {
          await CastService.instance.castRadioStream(
            programTitle: _currentProgram.isNotEmpty ? _currentProgram : null,
            imageUrl: _programArtUri?.toString(),
          );
        }
      } catch (e) {
        debugPrint('[AudioHandler] Cast play failed: $e');
      }
      _publishCastPlaybackState(null, optimisticPlaying: true);
      return;
    }

    await _player.setUrl(AppConstants.streamUrl);
    await _player.play();
  }

  @override
  Future<void> play() => _startPlayback();

  @override
  Future<void> pause() async {
    if (_isCasting) {
      try {
        // For a live stream, "pause" on the Cast device is more like
        // stop — but pause() is what the receiver responds to and what
        // keeps the session alive. Resume will reload via play().
        await GoogleCastRemoteMediaClient.instance.pause();
      } catch (e) {
        debugPrint('[AudioHandler] Cast pause failed: $e');
      }
      _publishCastPlaybackState(null, optimisticPlaying: false);
      return;
    }

    await _player.stop();
  }

  @override
  Future<void> stop() async {
    if (_isCasting) {
      try {
        await GoogleCastRemoteMediaClient.instance.stop();
      } catch (e) {
        debugPrint('[AudioHandler] Cast stop failed: $e');
      }
      _publishCastPlaybackState(null, optimisticPlaying: false);
      return;
    }

    await _player.stop();
    await super.stop();
  }

  Future<void> toggle() async {
    if (_isCasting) {
      final castPlaying =
          GoogleCastRemoteMediaClient.instance.mediaStatus?.playerState ==
          CastMediaPlayerState.playing;
      if (castPlaying) {
        await pause();
      } else {
        await play();
      }
      return;
    }

    if (_player.playing) {
      await _player.stop();
    } else {
      await _startPlayback();
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    _stopMetadataPolling();
    await _castSessionSub?.cancel();
    await _castMediaStatusSub?.cancel();
    await super.onTaskRemoved();
  }
}
