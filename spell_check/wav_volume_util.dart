import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class WavVolumeUtil {
  /// 16bit PCM WAV 파일의 RMS 볼륨을 0~1로 정규화하여 반환
  static Future<double> analyzeWavVolume(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length <= 44) return 0.0; // WAV 헤더는 44바이트
    final pcm = bytes.sublist(44);
    if (pcm.length % 2 != 0) return 0.0; // 16bit 샘플이 아니면 무시
    final samples = Int16List.view(pcm.buffer, pcm.offsetInBytes, pcm.lengthInBytes ~/ 2);
    if (samples.isEmpty) return 0.0;
    double sum = 0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    final rms = sqrt(sum / samples.length);
    final normalized = rms / 32768.0; // 16bit PCM 최대값
    print('🔊 실제 볼륨 분석: $normalized');
    return normalized;
  }
} 