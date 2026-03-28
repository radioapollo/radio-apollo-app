/* Audio Service

   This service manages the radio stream playback.

   It handles:
   - starting the radio stream
   - pausing the audio
   - controlling the audio player
*/

import 'package:just_audio/just_audio.dart';

class AudioService {
  late AudioPlayer _player;
  bool _isPlaying = false;
  
  Stream<bool> get playStateStream => _player.playerStateStream.map((state) => state.playing);
  
  bool get isPlaying => _isPlaying;

  AudioService() {
    _player = AudioPlayer();
    _initAudio();
    
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
    });
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl("https://streams.ilovemusic.de/iloveradio1.mp3");
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void dispose() {
    _player.dispose();
  }
}