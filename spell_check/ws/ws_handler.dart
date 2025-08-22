import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../tts_audio_player.dart';

class WsHandler {
  WebSocket? _socket;
  final String url;
  Timer? _pingTimer;
  int _bytesSent = 0;
  int _messagesSent = 0;
  void Function(String)? onTextMessage;

  final TtsAudioPlayer _ttsPlayer = TtsAudioPlayer();
  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();
  late final StreamSubscription<Uint8List> _audioStreamSubscription;
 
  // WsHandler({this.url = 'ws://localhost:8888'}) {
  WsHandler({this.url = 'wss://lolpago.com:443/stt'}) { 
    // 오디오 응답 재생용 consumer 쓰레드 초기화
    _audioStreamSubscription = _audioStreamController.stream.listen((data) async {
      print("🎵 TTS 재생 시작 (${data.length} bytes)");
      try {
        await _ttsPlayer.playFromBytes(data);
        print("✅ TTS 재생 완료");
      } catch (e) {
        print("❌ TTS 재생 실패 : $e");
      }
    });
  }

  Future<void> connect() async {
    try {
      _socket = await WebSocket.connect(url);
      print('✅ WebSocket 연결 성공: $url');

      // 30초마다 ping 송신신
      _pingTimer = Timer.periodic(Duration(seconds: 30), (_) {
        if (_socket != null && _socket!.readyState == WebSocket.open) {
          _socket!.add("ping");
        }
      });

      _socket!.listen(
        (data) {
          if (data is List<int>) {
            final bytes = Uint8List.fromList(data);
            print("📥 mp3 바이너리 수신 (${bytes.length} bytes)");
            _audioStreamController.add(bytes); // 큐에 추가
          } else {
            print("📥 문자열 수신: $data");
            onTextMessage?.call(data.toString());
          }
        },
        onDone: () {
          print("🔌 WebSocket 연결 종료됨");
        },
        onError: (e) {
          print("❌ WebSocket 오류 발생: $e");
        },
      );
    } catch (e) {
      print('❌ WebSocket 연결 실패: $e');
      rethrow;
    }
  }

  void send(String message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(message);
      _messagesSent++;
      print('✅ 텍스트 메시지 전송: $message (총 $_messagesSent개)');
    } else {
      print('❌ WebSocket이 연결되어 있지 않습니다.');
    }
  }

  void sendBytes(List<int> bytes) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(bytes);
      _bytesSent += bytes.length;
      if (_bytesSent % 10000 == 0) {
        print('📡 바이너리 전송: ${bytes.length} bytes (총 ${_bytesSent ~/ 1024}KB)');
      }
    } else {
      print('❌ WebSocket이 연결되어 있지 않습니다.');
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    await _socket?.close();
    await _audioStreamSubscription.cancel();
    await _audioStreamController.close();
    _socket = null;
    print('🔌 WebSocket 연결 종료 (총 전송 데이터: ${_bytesSent ~/ 1024}KB, $_messagesSent개 메시지)');
  }

  bool get isConnected => _socket?.readyState == WebSocket.open;
}
