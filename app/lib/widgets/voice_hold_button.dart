import 'package:flutter/material.dart';
import '../services/voice_speech_service.dart';

/// 语音按钮 — Paraformer 异步 STT
/// 状态: 空闲(蓝色) → 录音中(红色) → 识别中(蓝色+加载)
class VoiceHoldButton extends StatefulWidget {
  final void Function(String text) onResult;

  const VoiceHoldButton({super.key, required this.onResult});

  @override
  State<VoiceHoldButton> createState() => _VoiceHoldButtonState();
}

class _VoiceHoldButtonState extends State<VoiceHoldButton> with SingleTickerProviderStateMixin {
  final _voiceSpeech = VoiceSpeechService();
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _cancelMode = false;
  double _dragY = 0;
  final _cancelThreshold = -50.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _voiceSpeech.onRecording = () {
      if (mounted) setState(() { _isRecording = true; _cancelMode = false; _dragY = 0; });
      _pulseController.repeat(reverse: true);
    };

    _voiceSpeech.onProcessing = () {
      if (mounted) setState(() { _isRecording = false; _isProcessing = true; });
      _pulseController.stop();
      _pulseController.reset();
    };

    _voiceSpeech.onFinalResult = (text) {
      if (mounted) setState(() { _isRecording = false; _isProcessing = false; _cancelMode = false; });
      widget.onResult(text);
    };

    _voiceSpeech.onError = (error) {
      if (mounted) setState(() { _isRecording = false; _isProcessing = false; _cancelMode = false; });
      _pulseController.stop();
      _pulseController.reset();
      if (error != 'no_speech_detected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식 오류: $error', style: const TextStyle(fontSize: 16))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성이 인식되지 않았습니다', style: TextStyle(fontSize: 16))),
        );
      }
    };
  }

  @override
  void dispose() {
    _voiceSpeech.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() {
    if (_isRecording || _isProcessing) return;
    setState(() { _cancelMode = false; _dragY = 0; });
    _voiceSpeech.startRecording();
  }

  void _stopRecording() {
    if (!_isRecording) return;
    if (_cancelMode) {
      _voiceSpeech.dispose();
      setState(() { _isRecording = false; _cancelMode = false; _dragY = 0; });
      _pulseController.stop();
      _pulseController.reset();
      return;
    }
    _voiceSpeech.stopAndRecognize();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;
    _dragY += details.delta.dy;
    final shouldCancel = _dragY < _cancelThreshold;
    if (shouldCancel != _cancelMode) {
      setState(() => _cancelMode = shouldCancel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onVerticalDragUpdate: _onVerticalDragUpdate,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          Color bgColor;
          String statusText;
          Widget? icon;

          if (_isProcessing) {
            bgColor = const Color(0xFF1976D2);
            statusText = '인식 중...';
            icon = const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            );
          } else if (_isRecording) {
            bgColor = _cancelMode ? Colors.grey.shade400 : Colors.red.shade500;
            statusText = _cancelMode ? '↑ 놓으면 취소' : '놓으면 전송 ↑ 위로 밀면 취소';
            icon = const Icon(Icons.mic, size: 22, color: Colors.white);
          } else {
            bgColor = const Color(0xFF1976D2);
            statusText = '음성으로 입력하기';
            icon = const Icon(Icons.mic_none_outlined, size: 22, color: Colors.white);
          }

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: bgColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon, const SizedBox(width: 8)],
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
