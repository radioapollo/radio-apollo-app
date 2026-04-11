/* Audio Handler

   This service manages the live radio stream playback.

   It uses audio_service and just_audio to:
   - play and pause the radio stream
   - expose playback state to the UI
   - handle background audio on all platforms
   - poll the stream stats endpoint for current song metadata
   - update the media notification with song title, artist, program name,
     and artwork (program image or Radio Apollo logo)
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

  /// Copies the Flutter logo asset to a temp file so Android/iOS
  /// can access it as artwork for the media notification.
  Future<void> _initDefaultArt() async {
    try {
      final byteData = await rootBundle.load('assets/images/Logo/transparant.png');
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/radio_apollo_logo.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _defaultArtUri = file.uri;
      debugPrint('[AudioHandler] Default art URI: $_defaultArtUri');
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
        final songTitle =
            (jsonDecode(response.body)['songtitle'] ?? '').toString().trim();

        debugPrint('[AudioHandler] Fetched song: "$songTitle"');

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
    final parts = songTitle.split(' - ');
    final artist = parts.length > 1 ? parts[0].trim() : 'Radio Apollo';
    final title = parts.length > 1 ? parts[1].trim() : songTitle;

    final album = _currentProgram.isNotEmpty
        ? '$_currentProgram — Radio Apollo'
        : 'Radio Apollo';

    // Use program image if available, otherwise fall back to logo
    final artUri = _programArtUri ?? _defaultArtUri;

    debugPrint('[AudioHandler] Updating MediaItem: "$title" by "$artist" [$album]');

    mediaItem.add(MediaItem(
      id: AppConstants.streamUrl,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    ));
  }

  /// Called from the UI when the current program changes.
  /// [programName] is the display name, [imageUrl] is the optional
  /// Firestore image URL for the program.
  void setCurrentProgram(String programName, {String? imageUrl}) {
    _currentProgram = programName;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      _programArtUri = Uri.parse(imageUrl);
    } else {
      _programArtUri = null;
    }

    // Re-emit the media item with updated program info
    if (_lastSongTitle.isNotEmpty) {
      _updateMediaItem(_lastSongTitle);
    }
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    // Set media item BEFORE playing so notification has content immediately
    mediaItem.add(MediaItem(
      id: AppConstants.streamUrl,
      title: 'Radio Apollo',
      artist: 'Live',
      album: 'Radio Apollo',
      artUri: _programArtUri ?? _defaultArtUri,
    ));

    // Always reload for live stream to start from the current position
    await _player.setUrl(AppConstants.streamUrl);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      // Set media item before playing so notification shows immediately
      mediaItem.add(MediaItem(
        id: AppConstants.streamUrl,
        title: _lastSongTitle.isNotEmpty
            ? _lastSongTitle.split(' - ').length > 1
                ? _lastSongTitle.split(' - ')[1].trim()
                : _lastSongTitle
            : 'Radio Apollo',
        artist: _lastSongTitle.isNotEmpty && _lastSongTitle.contains(' - ')
            ? _lastSongTitle.split(' - ')[0].trim()
            : 'Live',
        album: _currentProgram.isNotEmpty
            ? '$_currentProgram — Radio Apollo'
            : 'Radio Apollo',
        artUri: _programArtUri ?? _defaultArtUri,
      ));

      // Always reload for live stream to start from the current position
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