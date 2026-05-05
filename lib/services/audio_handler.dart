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
   - keeping an in-memory history of recently played songs (capped at 20)
     exposed as a stream for UI widgets to subscribe to

   Song-vs-filler classification
   ─────────────────────────────
   The stats endpoint's `songtitle` field doesn't distinguish between
   actual songs ("Coldplay - Yellow") and stream filler — show names,
   station IDs, presenter intros, commercials, etc. The broadcasting
   software just pushes whatever string the studio configured.

   We classify each metadata read as either a real song or filler. Real
   songs go onto the recently played list and are shown as "Artist —
   Title" in the player card / lock screen. Filler is suppressed: the
   recent list is not touched, and the player card / lock screen show
   the generic "Luister live" placeholder. See [_isRealSong].

   Filler is detected via four signals:
   - missing or empty " - " separator
   - the string overlapping the current program name
   - matching a small static blocklist of known station strings
   - the artist (left half) matching a known sponsor name —
     populated dynamically via [updateSponsorNames] from main.dart's
     subscription to InfoService's sponsors stream
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
import '../models/recent_song.dart';
import 'cast_service.dart';

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  Timer? _metadataTimer;
  String _currentProgram = '';
  String _lastSongTitle = '';
  Uri? _defaultArtUri;
  Uri? _programArtUri;

  // ── Recently played history ───────────────────────────────────────────────

  static const int _maxRecentSongs = 20;
  final List<RecentSong> _recentSongs = [];
  final StreamController<List<RecentSong>> _recentSongsController =
      StreamController<List<RecentSong>>.broadcast();

  /// Latest snapshot of recently played songs, newest first.
  List<RecentSong> get recentSongs => List.unmodifiable(_recentSongs);

  /// Broadcast stream of the recently played list.
  Stream<List<RecentSong>> get recentSongsStream =>
      _recentSongsController.stream;

  // ── Filler blocklist ──────────────────────────────────────────────────────

  static const List<String> _fillerKeywords = [
    'radio apollo',
    'live uitzending',
    'live stream',
    'unknown',
    'no metadata',
    '<unknown>',
  ];

  // Lowercased sponsor names. Populated by [updateSponsorNames] from
  // main.dart, which subscribes to InfoService.sponsorsStream. A song
  // whose artist (left of the dash) matches a sponsor name is treated
  // as a commercial and filtered out.
  List<String> _sponsorNames = const [];

  /// Replaces the current sponsor blocklist. Names are stored lowercased
  /// for case-insensitive comparison. Pass an empty list to clear it.
  void updateSponsorNames(List<String> names) {
    _sponsorNames = names
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  // ── Cast state ────────────────────────────────────────────────────────────

  StreamSubscription<GoogleCastSession?>? _castSessionSub;
  StreamSubscription<GoggleCastMediaStatus?>? _castMediaStatusSub;
  bool _isCasting = false;

  bool get isCasting => _isCasting;

  RadioAudioHandler() {
    _initDefaultArt();

    _player.playerStateStream.listen((state) {
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

    _castMediaStatusSub = GoogleCastRemoteMediaClient.instance.mediaStatusStream
        .listen((status) {
          if (!_isCasting) return;
          _publishCastPlaybackState(status);
        });
  }

  Future<void> _enterCastMode() async {
    _isCasting = true;

    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioHandler] Local stop on cast start failed: $e');
    }

    _startMetadataPolling();

    try {
      await CastService.instance.castRadioStream(
        programTitle: _currentProgram.isNotEmpty ? _currentProgram : null,
        imageUrl: _programArtUri?.toString(),
      );
    } catch (e) {
      debugPrint('[AudioHandler] castRadioStream failed: $e');
    }

    _publishCastPlaybackState(null, optimisticPlaying: true);
  }

  Future<void> _exitCastMode() async {
    _isCasting = false;

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

  // ── Song / filler classification ──────────────────────────────────────────
  //
  // Returns true if [raw] looks like an actual song ("Artist - Title").
  // Filters out:
  //   - Anything without a " - " separator
  //   - Empty halves (e.g. " - Title" or "Artist - ")
  //   - Strings overlapping the current program name on either side
  //   - Strings matching a small static known-filler blocklist
  //   - Strings whose left half (the "artist") matches a known sponsor
  //     name — this catches commercials like "Garage Janssens - Sale"

  bool _isRealSong(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    for (final keyword in _fillerKeywords) {
      if (lower.contains(keyword)) return false;
    }

    final dashIndex = trimmed.indexOf(' - ');
    if (dashIndex <= 0) return false;

    final left = trimmed.substring(0, dashIndex).trim();
    final right = trimmed.substring(dashIndex + 3).trim();
    if (left.isEmpty || right.isEmpty) return false;

    final leftLower = left.toLowerCase();
    final rightLower = right.toLowerCase();

    if (_currentProgram.isNotEmpty) {
      final programLower = _currentProgram.toLowerCase();

      if (programLower.contains(leftLower) ||
          leftLower.contains(programLower) ||
          programLower.contains(rightLower) ||
          rightLower.contains(programLower)) {
        return false;
      }
    }

    // Sponsor blocklist — match the artist position only. A sponsor
    // name appearing on the *right* side (in a song title) is fine and
    // shouldn't filter the song out. Use both equality and substring
    // checks so "Tony's Muziekhuis Aktie" still matches "Tony's
    // Muziekhuis", and vice versa.
    for (final sponsor in _sponsorNames) {
      if (leftLower == sponsor ||
          leftLower.contains(sponsor) ||
          sponsor.contains(leftLower)) {
        return false;
      }
    }

    return true;
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

          if (_isRealSong(songTitle)) {
            _updateMediaItem(songTitle);
            _pushRecentSong(songTitle);
          } else {
            _updateMediaItemAsLive();
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioHandler] Stats fetch error: $e');
    }
  }

  // ── Recently played helpers ───────────────────────────────────────────────

  void _pushRecentSong(String rawTitle) {
    final song = RecentSong.parse(rawTitle);

    if (_recentSongs.isNotEmpty &&
        _recentSongs.first.display == song.display) {
      return;
    }

    _recentSongs.insert(0, song);
    if (_recentSongs.length > _maxRecentSongs) {
      _recentSongs.removeLast();
    }

    _recentSongsController.add(List.unmodifiable(_recentSongs));
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

  /// Pushes a "live placeholder" MediaItem when the stream metadata is
  /// filler rather than a real song.
  void _updateMediaItemAsLive() {
    final album = _currentProgram.isNotEmpty
        ? '$_currentProgram — Radio Apollo'
        : 'Radio Apollo';
    final artUri = _programArtUri ?? _defaultArtUri;

    mediaItem.add(
      MediaItem(
        id: AppConstants.streamUrl,
        title: '',
        artist: '',
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
      if (_isRealSong(_lastSongTitle)) {
        _updateMediaItem(_lastSongTitle);
      } else {
        _updateMediaItemAsLive();
      }
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
    await _recentSongsController.close();
    await super.onTaskRemoved();
  }
}