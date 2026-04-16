import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 语音识别 — Paraformer 异步 STT（录音→上传→识别→返回）
/// UI 状态: 空闲 → 录音中 → 识别中 → 完成
class VoiceSpeechService {
  static const _sttUrl = 'http://你的服务器IP:19000/voice/stt';

  final AudioRecorder _recorder = AudioRecorder();

  // 回调
  Function(String text)? onFinalResult;
  Function(String error)? onError;
  Function()? onRecording;
  Function()? onProcessing;

  bool _isRecording = false;
  bool _isProcessing = false;

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError?.call('permission_denied');
      return;
    }

    final dir = await Directory.systemTemp.createTemp('voice_');
    final path = '${dir.path}/recording.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _isRecording = true;
    onRecording?.call();
  }

  Future<void> stopAndRecognize() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    _isRecording = false;
    _isProcessing = true;
    onProcessing?.call();

    if (path == null) {
      _isProcessing = false;
      return;
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_sttUrl));
      request.files.add(await http.MultipartFile.fromPath('audio', path));
      request.fields['format'] = 'm4a';

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('STT 超时');
        },
      );
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        onError?.call('stt_failed: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final text = (data['text'] as String? ?? '').trim();
      _isProcessing = false;

      if (text.isEmpty) {
        onError?.call('no_speech_detected');
      } else {
        onFinalResult?.call(text);
      }
    } catch (e) {
      _isProcessing = false;
      onError?.call('error: $e');
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  void dispose() {
    try {
      _recorder.stop();
    } catch (_) {}
  }
}
