import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 后端 API 地址，生产环境替换为服务器地址
const String kBaseUrl = 'http://你的服务器IP:19000';

class ApiService {
  final String baseUrl;
  String? _deviceId;

  ApiService({this.baseUrl = kBaseUrl});

  /// 获取设备 ID（首次生成，之后复用）
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
          Object().hashCode.toRadixString(36);
      await prefs.setString('device_id', _deviceId!);
    }
    return _deviceId!;
  }

  // =====================
  // 会话管理
  // =====================

  Future<String> createSession() async {
    final deviceId = await getDeviceId();
    final resp = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId}),
    );
    _checkStatus(resp);
    return jsonDecode(resp.body)['session_id'] as String;
  }

  Future<List<dynamic>> listSessions() async {
    final deviceId = await getDeviceId();
    final resp = await http.get(Uri.parse('$baseUrl/sessions?device_id=$deviceId'));
    _checkStatus(resp);
    return jsonDecode(resp.body)['sessions'] as List;
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final resp = await http.get(Uri.parse('$baseUrl/sessions/$sessionId'));
    _checkStatus(resp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> deleteSession(String sessionId) async {
    final resp = await http.delete(Uri.parse('$baseUrl/sessions/$sessionId'));
    _checkStatus(resp);
  }

  // =====================
  // 对话
  // =====================

  /// 流式对话，返回文字流 Stream
  /// useSearch=true 时强制搜索，false 时由后端自动判断
  Stream<String> chatStream(String sessionId, String message, {bool useSearch = false}) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'session_id': sessionId, 'message': message, 'use_search': useSearch});

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode != 200) {
      throw Exception('Chat API error: ${streamedResponse.statusCode}');
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      yield chunk;
    }
  }

  // =====================
  // 语音
  // =====================

  Future<String> speechToText(File audioFile, String format) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/stt'));
    request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    request.fields['format'] = format;

    final response = await request.send();
    final body = await response.stream.bytesToString();
    _checkStatusCode(response.statusCode, body);

    return jsonDecode(body)['text'] as String;
  }

  Future<List<int>> textToSpeech(String text) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/tts'));
    request.fields['text'] = text;

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('TTS error: ${response.statusCode}');
    }
    return await response.stream.toBytes();
  }

  // =====================
  // 识图
  // =====================

  Future<String> analyzeImage(String sessionId, File imageFile, {String question = ''}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/vision'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    request.fields['session_id'] = sessionId;
    request.fields['question'] = question;

    final response = await request.send();
    final body = await response.stream.bytesToString();
    _checkStatusCode(response.statusCode, body);

    return jsonDecode(body)['result'] as String;
  }

  // =====================
  // 工具方法
  // =====================

  void _checkStatus(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw Exception('API error ${resp.statusCode}: ${resp.body}');
    }
  }

  void _checkStatusCode(int code, String body) {
    if (code >= 400) {
      throw Exception('API error $code: $body');
    }
  }
}
