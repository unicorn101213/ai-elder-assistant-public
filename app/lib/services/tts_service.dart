import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

/// 语音合成服务：调用后端 TTS，自动播放韩语回复
class TtsService {
  final ApiService _api;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  TtsService(this._api);

  bool get isPlaying => _isPlaying;

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    // 如果正在播放，先停止
    await stop();

    try {
      _isPlaying = true;
      final audioBytes = await _api.textToSpeech(text);
      await _playBytes(audioBytes);
    } catch (e) {
      // TTS 失败不阻断正常流程
      _isPlaying = false;
    }
  }

  Future<void> _playBytes(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    // qwen-tts 返回 WAV 格式
    final file = File('${dir.path}/tts_response.wav');
    await file.writeAsBytes(bytes);

    await _player.play(DeviceFileSource(file.path));
    _player.onPlayerComplete.listen((_) => _isPlaying = false);
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  void dispose() {
    _player.dispose();
  }
}
