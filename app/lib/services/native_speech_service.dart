import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Android 原生语音识别封装（SpeechRecognizer API）
/// 直接利用系统 Google 语音引擎做韩语识别，响应极快，不需要后端 STT
class NativeSpeechService {
  static const _channel = MethodChannel('com.elder_assistant/speech');

  bool _isListening = false;
  String _currentText = '';

  // 回调
  Function(String text)? onPartialResult;
  Function(String text)? onFinalResult;
  Function(String error)? onError;
  Function()? onReady;
  Function()? onEnd;

  bool get isListening => _isListening;
  String get currentText => _currentText;

  Future<bool> start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    try {
      await _channel.invokeMethod('startListening');
      _isListening = true;
      _currentText = '';

      _channel.setMethodCallHandler(_handleMethod);
      onReady?.call();
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancelListening');
    } catch (_) {}
    _isListening = false;
    _currentText = '';
  }

  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onReady':
        _isListening = true;
        onReady?.call();
        break;
      case 'onBegin':
        // 开始说话
        break;
      case 'onPartialResult':
        final text = call.arguments as String?;
        if (text != null) {
          _currentText = text;
          onPartialResult?.call(text);
        }
        break;
      case 'onResult':
        final text = call.arguments as String?;
        if (text != null) {
          _currentText = text;
          _isListening = false;
          onFinalResult?.call(text);
        }
        break;
      case 'onEnd':
        _isListening = false;
        onEnd?.call();
        break;
      case 'onError':
        _isListening = false;
        final error = call.arguments as String? ?? 'unknown';
        // 输出详细错误到控制台
        print('[NativeSpeech] onError: $error');
        onError?.call(error);
        break;
    }
  }

  void dispose() {
    cancel();
    _channel.setMethodCallHandler(null);
  }
}
