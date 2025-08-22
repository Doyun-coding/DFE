# Spell Check Module

리그 오브 레전드 게임 중 실시간 음성 인식을 통한 스펠 체크 기능을 제공하는 Flutter 모듈입니다.

## 📋 개요

이 모듈은 사용자의 마이크 입력을 실시간으로 캡처하여 WebSocket을 통해 서버로 전송하고, 서버로부터 받은 음성 인식 결과와 TTS 응답을 처리합니다.

## 🏗️ 아키텍처

```
spell_check/
├── spell_check_screen.dart      # 메인 UI 화면
├── realtime_audio_stream.dart   # 실시간 오디오 스트리밍 처리
├── ws/
│   └── ws_handler.dart         # WebSocket 통신 관리
├── tts_audio_player.dart       # TTS 오디오 재생
├── record_button.dart          # 녹음 버튼 위젯
└── wav_volume_util.dart        # 오디오 볼륨 유틸리티
```

## 🔧 주요 컴포넌트

### 1. SpellCheckScreen
- **역할**: 메인 UI 화면 및 전체 기능 조율
- **주요 기능**:
  - 사용자 프로필 확인 (summonerId, region)
  - 마이크 목록 로드 및 선택
  - WebSocket 연결 관리
  - 실시간 스트리밍 시작/중지
  - 서버 응답 표시

### 2. WsHandler
- **역할**: WebSocket 통신 관리
- **주요 기능**:
  - WebSocket 연결/해제
  - 실시간 오디오 데이터 전송
  - 서버 응답 수신 (텍스트 + MP3)
  - TTS 오디오 재생
  - 30초마다 ping 전송으로 연결 유지

### 3. RealtimeAudioStream
- **역할**: 실시간 오디오 캡처 및 스트리밍
- **주요 기능**:
  - FFmpeg를 사용한 마이크 캡처
  - PCM 16bit, 16kHz, 모노로 인코딩
  - 실시간으로 WebSocket으로 데이터 전송
  - 연결 상태 모니터링

### 4. TtsAudioPlayer
- **역할**: 서버로부터 받은 TTS 오디오 재생
- **주요 기능**:
  - 바이트 배열로부터 직접 오디오 재생
  - audioplayers 패키지 사용

## 🌐 WebSocket 프로토콜

### 연결 정보
- **URL**: `wss://lolpago.com:443/stt`
- **프로토콜**: WSS (Secure WebSocket)

### 메시지 형식

#### 클라이언트 → 서버
1. **초기화 메시지** (JSON)
```json
{
  "type": "init",
  "summonerId": "123456789",
  "region": "KR"
}
```

2. **오디오 데이터** (바이너리)
- PCM 16bit, 16kHz, 모노
- WAV 형식으로 인코딩

3. **Ping 메시지**
- 30초마다 자동 전송
- 연결 유지를 위한 heartbeat

#### 서버 → 클라이언트
1. **텍스트 응답** (문자열)
- 음성 인식 결과
- 스펠 체크 결과

2. **TTS 오디오** (바이너리)
- MP3 형식
- 실시간 재생

## 🎤 오디오 설정

### 입력 설정
- **코덱**: PCM 16bit Little Endian
- **샘플레이트**: 16kHz
- **채널**: 모노 (1채널)
- **형식**: WAV

### FFmpeg 명령어
```bash
ffmpeg -y -f dshow -i audio="마이크(EarPods)" -acodec pcm_s16le -ar 16000 -ac 1 -f wav pipe:1
```

## 📱 사용법

1. **사전 준비**
   - 홈 화면에서 플레이어 검색 완료
   - 마이크 권한 허용
   - FFmpeg 설치 (Windows)

2. **실행 순서**
   ```
   1. 마이크 선택 (드롭다운)
   2. 녹음 버튼 클릭
   3. WebSocket 연결 확인
   4. 실시간 스트리밍 시작
   5. 음성 입력
   6. 서버 응답 수신 및 TTS 재생
   ```

## 🔒 보안 및 권한

### 필요한 권한
- **마이크 접근 권한**
- **네트워크 접근 권한**
- **오디오 재생 권한**

### 데이터 전송
- **암호화**: WSS (TLS/SSL)
- **인증**: summonerId 기반 사용자 식별
- **지역**: region 정보 포함

## 🛠️ 의존성

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  audioplayers: ^5.2.1
```

## 🐛 문제 해결

### 일반적인 문제들

1. **FFmpeg 파일을 찾을 수 없음**
   - Windows 실행 파일에 FFmpeg 포함 확인
   - 경로: `build/windows/x64/runner/ffmpeg.exe`

2. **WebSocket 연결 실패**
   - 네트워크 연결 확인
   - 서버 상태 확인
   - 방화벽 설정 확인

3. **마이크 인식 안됨**
   - 마이크 권한 확인
   - 시스템 마이크 설정 확인
   - 다른 마이크 선택 시도

4. **TTS 재생 안됨**
   - 오디오 출력 장치 확인
   - 볼륨 설정 확인
   - audioplayers 패키지 버전 확인

## 📊 성능 최적화

- **버퍼링**: 실시간 스트리밍으로 지연 최소화
- **메모리 관리**: 스트림 컨트롤러 적절한 해제
- **연결 관리**: 자동 ping으로 연결 유지
- **에러 처리**: 연결 끊김 시 자동 재연결 시도

## 🔄 업데이트 이력

- **v1.0**: 기본 실시간 음성 인식 기능
- **v1.1**: TTS 응답 재생 기능 추가
- **v1.2**: WebSocket 연결 안정성 개선
- **v1.3**: 마이크 선택 기능 추가
