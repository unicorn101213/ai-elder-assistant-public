import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'tts_service.dart';

class Message {
  final String role; // 'user' | 'assistant'
  final String content;
  final String type; // 'text' | 'image' | 'voice'
  final String? imagePath; // 本地图片路径（用于图片消息展示）
  final DateTime time;

  Message({
    required this.role,
    required this.content,
    this.type = 'text',
    this.imagePath,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'type': type,
    'time': time.toIso8601String(),
  };
}

/// 会话列表项（从服务器获取）
class SessionItem {
  final String id;
  final String title;
  final String createdAt;
  final String updatedAt;

  SessionItem({required this.id, required this.title, required this.createdAt, required this.updatedAt});

  factory SessionItem.fromJson(Map<String, dynamic> json) {
    return SessionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

class SessionService extends ChangeNotifier {
  final ApiService _api;
  late final TtsService _tts;

  String? _sessionId;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String _streamingText = '';
  bool _autoSpeak = true;
  List<SessionItem> _sessionList = [];

  SessionService(this._api) {
    _tts = TtsService(_api);
    _init();
  }

  String? get sessionId => _sessionId;
  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get streamingText => _streamingText;
  bool get autoSpeak => _autoSpeak;
  List<SessionItem> get sessionList => List.unmodifiable(_sessionList);

  void toggleAutoSpeak() {
    _autoSpeak = !_autoSpeak;
    notifyListeners();
  }

  Future<void> speakMessage(String text) => _tts.speak(text);
  Future<void> stopSpeaking() => _tts.stop();

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('current_session_id');

    // 先加载本设备的历史列表
    await refreshSessions();

    // 检查上次的 session 是否属于本设备
    if (_sessionId != null) {
      final belongsToDevice = _sessionList.any((s) => s.id == _sessionId);
      if (belongsToDevice) {
        await _loadSessionMessages(_sessionId!);
      } else {
        _sessionId = null;
      }
    }

    if (_sessionId == null) {
      if (_sessionList.isNotEmpty) {
        await _loadSessionMessages(_sessionList.first.id);
      } else {
        await _createNewSession();
      }
    }
  }

  Future<void> refreshSessions() async {
    try {
      final list = await _api.listSessions();
      _sessionList = list.map((e) => SessionItem.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {
      _sessionList = [];
    }
  }

  /// 加载指定 session 的历史消息
  Future<void> _loadSessionMessages(String id) async {
    try {
      final data = await _api.getSession(id);
      final rawMessages = data['messages'] as List<dynamic>;
      _messages.clear();
      for (final m in rawMessages) {
        final map = m as Map<String, dynamic>;
        DateTime time;
        try {
          time = DateTime.parse(map['created_at'] as String);
        } catch (_) {
          time = DateTime.now();
        }
        _messages.add(Message(
          role: map['role'] as String,
          content: map['content'] as String,
          type: map.getOrDefault('message_type', 'text') as String,
          time: time,
        ));
      }
      _sessionId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session_id', _sessionId!);
      notifyListeners();
    } catch (_) {
      // 加载失败不影响
    }
  }

  /// 切换到已有 session
  Future<void> switchSession(String id) async {
    await _tts.stop();
    _streamingText = '';
    await _loadSessionMessages(id);
    await refreshSessions();
  }

  Future<void> _createNewSession() async {
    await _tts.stop();
    _sessionId = await _api.createSession();
    _messages.clear();
    _streamingText = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_session_id', _sessionId!);
    notifyListeners();
  }

  Future<void> newSession() => _createNewSession();

  Future<void> deleteSession(String id) async {
    await _api.deleteSession(id);
    await refreshSessions();

    // 如果删除的是当前 session，切到最近一个
    if (id == _sessionId) {
      if (_sessionList.isNotEmpty) {
        await switchSession(_sessionList.first.id);
      } else {
        await _createNewSession();
      }
    }
  }

  Future<void> sendMessage(String text, {bool useSearch = false}) async {
    if (_sessionId == null || text.trim().isEmpty) return;

    _messages.add(Message(role: 'user', content: text));
    _isLoading = true;
    _streamingText = '';
    notifyListeners();

    try {
      final buffer = StringBuffer();
      await for (final chunk in _api.chatStream(_sessionId!, text, useSearch: useSearch)) {
        buffer.write(chunk);
        _streamingText = buffer.toString();
        notifyListeners();
      }
      final reply = buffer.toString();
      _messages.add(Message(role: 'assistant', content: reply));
      _streamingText = '';

      // 自动朗读
      if (_autoSpeak && reply.isNotEmpty) {
        _tts.speak(reply);
      }
    } finally {
      _isLoading = false;
      // 刷新 session 列表（更新顺序）
      await refreshSessions();
      notifyListeners();
    }
  }

  Future<void> sendImage(dynamic imageFile, {String question = ''}) async {
    if (_sessionId == null) return;

    final localPath = (imageFile is String) ? imageFile : (imageFile?.path as String?);
    _messages.add(Message(
      role: 'user',
      content: question.isNotEmpty ? question : '이미지',
      type: 'image',
      imagePath: localPath,
    ));
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.analyzeImage(_sessionId!, imageFile, question: question);
      _messages.add(Message(role: 'assistant', content: result));

      if (_autoSpeak && result.isNotEmpty) {
        _tts.speak(result);
      }
    } finally {
      _isLoading = false;
      await refreshSessions();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }
}

extension MapGetOrDefault<K, V> on Map<K, V> {
  V getOrDefault(K key, V defaultValue) {
    return containsKey(key) ? this[key] as V : defaultValue;
  }
}
