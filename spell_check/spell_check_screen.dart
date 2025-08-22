import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repo/spell_check_repo.dart';
import '../../../repo/backend_repo.dart';
import '../../../repo/lcu_repo.dart';
import '../home/home_screen.dart'; // currentUserProfileProvider import
import 'record_button.dart';
import 'ws/ws_handler.dart';
import 'realtime_audio_stream.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

class SpellCheckScreen extends ConsumerStatefulWidget {
  const SpellCheckScreen({super.key});

  @override
  ConsumerState<SpellCheckScreen> createState() => _SpellCheckScreenState();
}

class _SpellCheckScreenState extends ConsumerState<SpellCheckScreen> {
  String resultText = "결과가 여기에 표시됩니다.";
  bool isListening = false;
  bool isRecording = false;
  WsHandler? _wsHandler;
  bool _wsConnected = false;
  StreamSubscription<String>? _wsSubscription;
  RealtimeAudioStream? _audioStream;
  List<String> _micList = [];
  String? _selectedMic;
  bool _micLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMicList();
  }

  Future<void> _loadMicList() async {
    setState(() { _micLoading = true; });
    final mics = await RealtimeAudioStream.getAvailableMicrophones();
    setState(() {
      _micList = mics;
      _selectedMic = mics.isNotEmpty ? mics.first : null;
      _micLoading = false;
    });
  }

  Future<void> _onRecordButtonPressed() async {
    setState(() {
      resultText = "🎙️ WebSocket 연결 중...";
    });
    
    if (_wsHandler == null) {
      _wsHandler = WsHandler();
    }
    
    // 콜백 등록
    _wsHandler!.onTextMessage = (msg) {
      setState(() {
        resultText = "서버 응답: $msg";
      });
    };

    if (!_wsConnected) {
      try {
        await _wsHandler!.connect();
        _wsConnected = true;
        setState(() {
          resultText = "✅ WebSocket 연결됨. 실시간 스트리밍 시작...";
        });
      } catch (e) {
        setState(() {
          resultText = "❌ WebSocket 연결 실패: $e";
        });
        return;
      }
    }

    // summonerId 전송 (init 타입 JSON)
    final currentUserProfile = ref.read(currentUserProfileProvider);
    final currentUserNameAsync = ref.watch(currentUserNameProvider);
    final currentUserName = currentUserNameAsync.value;
    final summonerId = currentUserProfile?.summonerId;
    
    if (summonerId != null) {
      final initPayload = {
        "type": "init",
        "summonerId": summonerId.toString(),
        "region": currentUserName?.region,
      };
      _wsHandler!.send(jsonEncode(initPayload));
      print("summonerId 전송됨: $initPayload");
    } else {
      print("summonerId 없음");
    }

    setState(() {
      resultText = "🟢 실시간 음성 스트리밍 시작...";
    });

    // 실시간 오디오 스트리밍 시작
    try {
      _audioStream = RealtimeAudioStream();
      await _audioStream!.startStreaming(
        wsHandler: _wsHandler!,
        micName: _selectedMic ?? '마이크(EarPods)',
      );
      setState(() {
        resultText = "🎤 실시간 음성 스트리밍 중... (파이썬 서버로 전송 중)";
      });
    } catch (e) {
      setState(() {
        resultText = "❌ 스트리밍 시작 실패: $e";
      });
    }
  }

  Future<void> _stopStreaming() async {
    await _audioStream?.stopStreaming();
    setState(() {
      resultText = "🛑 스트리밍 중지됨";
    });
  }

  @override
  void dispose() {
    _audioStream?.stopStreaming(); // Future지만, dispose에서는 await 불가
    _wsHandler?.disconnect();
    _wsConnected = false;
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _cleanUp() async {
    await _audioStream?.stopStreaming();
    await _wsHandler?.disconnect();
    _wsConnected = false;
    await _wsSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("스펠 체크")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (currentUserProfile != null) ...[
              Text(
                "현재 플레이어: ${currentUserProfile.summonerName}#${currentUserProfile.summonerTag}",
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
              SizedBox(height: 10),
            ] else ...[
              Text(
                "⚠️ 먼저 홈에서 플레이어를 검색해주세요",
                style: TextStyle(fontSize: 16, color: Colors.orange),
              ),
              SizedBox(height: 10),
            ],
            // 마이크 선택 UI
            if (_micLoading)
              CircularProgressIndicator()
            else if (_micList.isNotEmpty)
              DropdownButton<String>(
                value: _selectedMic,
                items: _micList.map((mic) => DropdownMenuItem(
                  value: mic,
                  child: Text(mic),
                )).toList(),
                onChanged: (val) {
                  setState(() { _selectedMic = val; });
                },
              )
            else
              Text('사용 가능한 마이크를 찾을 수 없습니다.'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RecordButton(
                  onPressed: currentUserProfile != null && (_audioStream?.isStreaming != true)
                      ? () => _onRecordButtonPressed() 
                      : () {},
                ),
                SizedBox(width: 20),
                if (_audioStream?.isStreaming == true)
                  ElevatedButton(
                    onPressed: () async {
                      await _stopStreaming();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("중지"),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                resultText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
