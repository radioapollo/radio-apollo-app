/* Audio Handler

   This service manages the live radio stream playback.

   It uses audio_service and just_audio to:
   - play and pause the radio stream
   - expose playback state to the UI
   - handle background audio on all platforms
*/

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/constants.dart';

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  RadioAudioHandler() {
    _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: _mapState(state.processingState),
      ));
    });

    if (!kIsWeb && Platform.isIOS) {
      _player.setAutomaticallyWaitsToMinimizeStalling(false);
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

  @override
  Future<void> play() async {
    if (_player.audioSource == null) {
      await _player.setUrl(AppConstants.streamUrl);
    }
    mediaItem.add(const MediaItem(
      id: AppConstants.streamUrl,
      title: 'Radio Apollo',
      artist: 'Live',
    ));
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle ||
          _player.processingState == ProcessingState.completed) {
        await _player.setUrl(AppConstants.streamUrl);
      }
      await _player.play();
    }
  }
}