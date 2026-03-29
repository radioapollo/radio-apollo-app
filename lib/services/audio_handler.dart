import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class RadioAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final String _streamUrl = "http://radioapollo.beheerstream.nl:8004/stream";

  RadioAudioHandler() {
    _player.playerStateStream.listen((state) {
      playbackState.add(
        playbackState.value.copyWith(
          playing: state.playing,
          processingState: _mapState(state.processingState),
        ),
      );
    });

    _player.setAutomaticallyWaitsToMinimizeStalling(false);
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

  @override
  Future<void> play() async {
    if (_player.audioSource == null) {
      await _player.setUrl(_streamUrl);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await pause(); // pause normally
    } else {
      await _player.stop(); // reset to live
      await _player.setUrl(_streamUrl);
      await _player.play();
    }
  }
}