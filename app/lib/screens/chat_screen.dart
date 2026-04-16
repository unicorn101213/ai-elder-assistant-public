import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/session_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_hold_button.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _voiceMode = true; // 默认语音模式

  final _drawerKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    FocusScope.of(context).unfocus();

    final session = context.read<SessionService>();
    await session.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    final session = context.read<SessionService>();
    await session.sendImage(File(file.path));
    _scrollToBottom();
  }

  void _showImageSourceSheet() {
    // 如果抽屉是打开的，先关闭
    if (_drawerKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 32, color: Color(0xFF2196F3)),
                title: const Text('카메라로 촬영', style: TextStyle(fontSize: 20)),
                subtitle: const Text('직접 사진 찍기', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library, size: 32, color: Color(0xFF2196F3)),
                title: const Text('갤러리에서 선택', style: TextStyle(fontSize: 20)),
                subtitle: const Text('저장된 사진 선택', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerKey,
      drawer: _buildSessionDrawer(),
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSessionDrawer() {
    return SafeArea(
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.82,
        child: Column(
          children: [
            // Drawer header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
              decoration: const BoxDecoration(color: Color(0xFF1976D2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.chat_bubble_outline, size: 36, color: Colors.white),
                  SizedBox(height: 10),
                  Text('대화 기록', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('이전 대화를 계속하세요', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            // New session button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await context.read<SessionService>().newSession();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text('새 대화', style: TextStyle(fontSize: 17)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Session list
            Expanded(
              child: Consumer<SessionService>(
                builder: (context, session, _) {
                  final sessions = session.sessionList;
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Text('대화 기록이 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = sessions[i];
                      final isActive = s.id == session.sessionId;
                      final date = _formatDate(s.updatedAt);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? const Color(0xFF1976D2) : Colors.grey.shade200,
                          child: Icon(
                            Icons.chat,
                            size: 20,
                            color: isActive ? Colors.white : Colors.grey,
                          ),
                        ),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(date, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('대화 삭제', style: TextStyle(fontSize: 18)),
                                content: const Text('이 대화를 삭제하시겠습니까?', style: TextStyle(fontSize: 16)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소', style: TextStyle(fontSize: 16)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      session.deleteSession(s.id);
                                    },
                                    child: const Text('삭제', style: TextStyle(fontSize: 16, color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        onTap: () async {
                          await session.switchSession(s.id);
                          if (mounted) Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  /// 消息日期标签（微信风格）
  String _dateLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(time.year, time.month, time.day);
    final diff = today.difference(msgDate).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (time.year != now.year) {
      return '${time.year}년 ${time.month}월 ${time.day}일';
    }
    return '${time.month}월 ${time.day}일';
  }

  /// 消息时间（小时:分钟）
  String _timeLabel(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 어시스턴트', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('항상 곁에 있습니다', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
      backgroundColor: const Color(0xFF1976D2),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu, size: 28),
        tooltip: '대화 기록',
        onPressed: () {
          _drawerKey.currentState?.openDrawer();
          context.read<SessionService>().refreshSessions();
        },
      ),
      actions: const [],
    );
  }

  Widget _buildMessageList() {
    return Consumer<SessionService>(
      builder: (context, session, _) {
        final messages = session.messages;
        final isStreaming = session.isLoading && session.streamingText.isNotEmpty;
        final isThinking = session.isLoading && session.streamingText.isEmpty;

        _scrollToBottom();

        if (messages.isEmpty && !session.isLoading) {
          return _buildWelcomeView();
        }

        // 构建带日期分隔的扁平列表
        final items = <Widget>[];
        String? lastDate;
        for (final msg in messages) {
          final msgDate = _dateLabel(msg.time);
          if (msgDate != lastDate) {
            items.add(_buildDateSeparator(msgDate));
            lastDate = msgDate;
          }
          items.add(_buildMessageBubble(msg, session));
        }

        if (isStreaming) {
          items.add(ChatBubble(
            role: 'assistant',
            content: session.streamingText,
            isStreaming: true,
          ));
        }
        if (isThinking) {
          items.add(Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFFFE0B2),
                  child: Icon(Icons.smart_toy_outlined, size: 20, color: Color(0xFFE65100)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('생각 중...', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ));
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          children: items,
        );
      },
    );
  }

  Widget _buildMessageBubble(Message msg, SessionService session) {
    return ChatBubble(
      role: msg.role,
      content: msg.content,
      type: msg.type,
      imagePath: msg.imagePath,
      timeLabel: _timeLabel(msg.time),
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 60, color: Color(0xFF1976D2)),
            ),
            const SizedBox(height: 24),
            const Text('안녕하세요!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              '무엇이든 물어보세요.\n말씀하시거나 입력하시면 도와드릴게요.',
              style: TextStyle(fontSize: 18, color: Colors.grey, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...[
              '오늘 날씨가 어때요?',
              '이 약 어떻게 먹어야 해요?',
              '가까운 병원이 어디에 있어요?',
            ].map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () {
                  _textController.text = q;
                  _sendText();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(q, style: const TextStyle(fontSize: 16)),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, size: 30, color: Color(0xFF1976D2)),
              onPressed: _showImageSourceSheet,
              tooltip: '사진',
            ),

            IconButton(
              icon: Icon(
                _voiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none_outlined,
                size: 30,
                color: const Color(0xFF1976D2),
              ),
              tooltip: _voiceMode ? '키보드' : '음성',
              onPressed: () => setState(() => _voiceMode = !_voiceMode),
            ),

            Expanded(
              child: _voiceMode
                  ? VoiceHoldButton(
                      onResult: (text) {
                        _textController.text = text;
                        _sendText();
                      },
                    )
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(fontSize: 18),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: '질문을 입력하세요...',
                          hintStyle: const TextStyle(fontSize: 17, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
            ),

            const SizedBox(width: 4),

            if (!_voiceMode)
              Consumer<SessionService>(
                builder: (_, session, __) => IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    size: 30,
                    color: session.isLoading ? Colors.grey : const Color(0xFF1976D2),
                  ),
                  onPressed: session.isLoading ? null : _sendText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
