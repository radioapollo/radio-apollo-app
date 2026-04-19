/* Audio Handler

   Manages the live radio stream playback and the system media notification.

   Notes on live-stream behaviour:
   Pausing a live stream would keep the player's buffer, which makes the
   user fall behind the live broadcast when they resume. This handler uses
   stop() in place of pause() and reloads the URL on resume so playback
   always jumps back to the current live position.

   It handles:
   - stream playback with just_audio
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
import '../constants/constants.dart';

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  Timer? _metadataTimer;
  String _currentProgram = '';
  String _lastSongTitle = '';
  Uri? _defaultArtUri;
  Uri? _programArtUri;

  RadioAudioHandler() {
    _initDefaultArt();

    _player.playerStateStream.listen((state) {
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

    await _player.setUrl(AppConstants.streamUrl);
    await _player.play();
  }

  @override
  Future<void> play() => _startPlayback();

  @override
  Future<void> pause() async {
    await _player.stop();
  }

  Future<void> toggle() async {
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
    await super.onTaskRemoved();
  }
}
