import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert'; // 파일 상단에 추가
import 'ws/ws_handler.dart';

class RealtimeAudioStream {
  Process? _ffmpegProcess;
  WsHandler? _wsHandler;
  bool _isStreaming = false;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  bool _warnedNotConnected = false;

  /// 테스트용: ffmpeg 경로 확인
  static void testFfmpegPath() {
    print('🧪 FFmpeg 경로 테스트 시작');
    final path = _getFfmpegPath();
    print('🧪 테스트 결과: $path');
    
    final file = File(path);
    if (file.existsSync()) {
      print('✅ FFmpeg 파일 존재함');
    } else {
      print('❌ FFmpeg 파일 없음');
    }
  }

  /// 실시간 오디오 스트리밍 시작
  Future<void> startStreaming({
    required WsHandler wsHandler,
    String micName = '마이크(EarPods)',
    int sampleRate = 16000,
  }) async {
    _wsHandler = wsHandler;
    _isStreaming = true;
    _warnedNotConnected = false;

    print('🎤 실시간 오디오 스트리밍 시작...');
    
    try {
      final ffmpegPath = RealtimeAudioStream._getFfmpegPath();
      print('🔧 FFmpeg 경로: $ffmpegPath');
      
      // ffmpeg 파일 존재 여부 확인
      final ffmpegFile = File(ffmpegPath);
      if (ffmpegFile.existsSync()) {
        print('✅ FFmpeg 파일 존재 확인됨');
      } else {
        print('❌ FFmpeg 파일을 찾을 수 없음: $ffmpegPath');
        print('🔍 실행 파일 위치: ${Platform.resolvedExecutable}');
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final runnerDir = Directory(exeDir).parent.path;
        final archDir = Directory(runnerDir).parent.path;
        print('🔍 실행 파일 디렉토리: $exeDir');
        print('🔍 runner 디렉토리: $runnerDir');
        print('🔍 x64 디렉토리: $archDir');
      }
      
      // ffmpeg로 실시간 오디오 캡처 (raw PCM)
      _ffmpegProcess = await Process.start(
        ffmpegPath,
        [
          '-y',
          '-f', 'dshow',
          '-i', 'audio=$micName',
          '-acodec', 'pcm_s16le',
          '-ar', sampleRate.toString(),
          '-ac', '1',
          '-f', 'wav',
          'pipe:1', // stdout으로 출력
        ],
        runInShell: true,
      );

      // 실시간으로 오디오 데이터 읽기
      _stdoutSub = _ffmpegProcess!.stdout.listen((data) {
        if (!_isStreaming) return;
        if (_wsHandler != null && _wsHandler!.isConnected) {
          _wsHandler!.sendBytes(data);
          _warnedNotConnected = false;
          print('📡 오디오 데이터 전송: ${data.length} bytes');
        } else {
          if (!_warnedNotConnected) {
            print('❌ WebSocket이 연결되어 있지 않습니다. (오디오 데이터 전송 중단)');
            _warnedNotConnected = true;
          }
          // 연결이 끊겼으면 스트리밍도 중지
          stopStreaming();
        }
      });

      // 에러 처리
      _stderrSub = _ffmpegProcess!.stderr.transform(SystemEncoding().decoder).listen((error) {
        print('ffmpeg stderr: $error');
      });

      // 프로세스 종료 처리
      _ffmpegProcess!.exitCode.then((code) {
        print('ffmpeg 프로세스 종료: exit code $code');
      });

    } catch (e) {
      print('❌ 실시간 스트리밍 시작 실패: $e');
      _isStreaming = false;
      rethrow;
    }
  }

  /// 스트리밍 중지
  Future<void> stopStreaming() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    _warnedNotConnected = false;

    // 리스너 취소
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();

    if (_ffmpegProcess != null) {
      try {
        _ffmpegProcess!.kill(ProcessSignal.sigkill);
        await _ffmpegProcess!.exitCode;
      } catch (e) {
        print('ffmpeg 프로세스 종료 중 오류: $e');
      }
      _ffmpegProcess = null;
    }
    
    print('🛑 실시간 오디오 스트리밍 중지');
  }

  /// 스트리밍 상태 확인
  bool get isStreaming => _isStreaming;

  static String _getFfmpegPath() {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent; // .../Release
      final ffmpegPath = '${exeDir.path}/resources/ffmpeg.exe';
      return ffmpegPath;
    }
    return 'ffmpeg'; // macOS/Linux 기본
  }

  static Future<List<String>> getAvailableMicrophones() async {
    final ffmpegPath = RealtimeAudioStream._getFfmpegPath();
    final result = await Process.run(
      ffmpegPath,
      ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      runInShell: true,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final output = (result.stderr as String) + '\n' + (result.stdout as String);
    print('FFmpeg device list output:\n$output'); // 실제 출력 확인용
    final lines = output.split('\n');
    final micNames = <String>[];
    final regex = RegExp(r'"(.+)" \(audio\)');
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        micNames.add(match.group(1)!);
      }
    }
    return micNames;
  }
} 
