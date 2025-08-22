import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class TtsAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playFromBytes(Uint8List bytes) async {
    try {
      await _player.play(BytesSource(bytes), volume: 1.0);
    } catch (e) {
      print('🎧 재생 실패: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
