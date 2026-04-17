/* Audio Handler

   This service manages the live radio stream playback.

   IMPORTANT — Live stream behaviour:
   For a live radio stream, the "pause" action does NOT preserve
   position because there is no position — the stream is live.
   If we use _player.pause(), the player keeps its internal buffer.
   When we resume, it replays that buffered audio, putting the user
   behind the live broadcast by however long they paused.

   Solution: call _player.stop() instead of _player.pause() so the
   buffer is discarded. Then play() reconnects to the stream at the
   current live position — exactly like reloading the website player.

   FIXES APPLIED:
   - HTML tags stripped from song title metadata
   - stop() used instead of pause() to keep playback in sync with live
     broadcast (Issue: stream goes back in time after pause)
   - Notification shows "LIVE uitzending" subtitle
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

      playbackState.add(PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
        },
        playing: playing,
        processingState: _mapState(state.processingState),
        updatePosition: Duration.zero,
      ));

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

  Future<void> _initDefaultArt() async {
    try {
      final byteData = await rootBundle.load('assets/images/Logo/transparant.png');
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
      case ProcessingState.idle:      return AudioProcessingState.idle;
      case ProcessingState.loading:   return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready:     return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
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
      final response = await http.get(Uri.parse(AppConstants.statsUrl));
      if (response.statusCode == 200) {
        final rawTitle =
            (jsonDecode(response.body)['songtitle'] ?? '').toString().trim();
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

  void _updateMediaItem(String songTitle) {
    final parts  = songTitle.split(' - ');
    final artist = parts.length > 1 ? parts[0].trim() : 'Radio Apollo';
    final title  = parts.length > 1 ? parts[1].trim() : songTitle;
    final album  = _currentProgram.isNotEmpty
        ? '$_currentProgram — Radio Apollo'
        : 'Radio Apollo';
    final artUri = _programArtUri ?? _defaultArtUri;

    mediaItem.add(MediaItem(
      id:     AppConstants.streamUrl,
      title:  title,
      artist: artist,
      album:  album,
      artUri: artUri,
    ));
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

  @override
  Future<void> play() async {
    mediaItem.add(MediaItem(
      id:     AppConstants.streamUrl,
      title:  _currentProgram.isNotEmpty ? _currentProgram : 'Radio Apollo',
      artist: 'LIVE uitzending',
      album:  'Radio Apollo',
      artUri: _programArtUri ?? _defaultArtUri,
    ));

    // Load the stream fresh so we start at the live position
    await _player.setUrl(AppConstants.streamUrl);
    await _player.play();
  }

  @override
  Future<void> pause() async {
    // FIX: Use stop() instead of pause() for live streams.
    // pause() keeps the buffer, which means resume would replay old
    // audio and fall behind the live broadcast. stop() discards the
    // buffer so the next play() reconnects at the current live position.
    await _player.stop();
  }

  Future<void> toggle() async {
    if (_player.playing) {
      // FIX: same reason — stop() so we don't fall behind when resuming
      await _player.stop();
    } else {
      mediaItem.add(MediaItem(
        id:     AppConstants.streamUrl,
        title:  _currentProgram.isNotEmpty ? _currentProgram : 'Radio Apollo',
        artist: 'LIVE uitzending',
        album:  'Radio Apollo',
        artUri: _programArtUri ?? _defaultArtUri,
      ));

      // Reload URL to reconnect at the current live position
      await _player.setUrl(AppConstants.streamUrl);
      await _player.play();
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    _stopMetadataPolling();
    await super.onTaskRemoved();
  }
}