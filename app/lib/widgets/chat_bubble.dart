import 'dart:io';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String role;
  final String content;
  final String type;
  final String? imagePath;
  final bool isStreaming;
  final VoidCallback? onSpeak;
  final String? timeLabel;

  const ChatBubble({
    super.key,
    required this.role,
    required this.content,
    this.type = 'text',
    this.imagePath,
    this.isStreaming = false,
    this.onSpeak,
    this.timeLabel,
  });

  bool get isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (type == 'image' && imagePath != null)
                  _buildImageBubble(context)
                else
                  _buildTextBubble(),
                if (timeLabel != null && !isStreaming)
                  Padding(
                    padding: EdgeInsets.only(top: 2, left: isUser ? 0 : 0, right: isUser ? 0 : 0),
                    child: Text(
                      timeLabel!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildTextBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF1976D2) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 18,
                color: isUser ? Colors.white : Colors.black87,
                height: 1.55,
              ),
            ),
          ),
          if (isStreaming)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isUser ? Colors.white70 : Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    final file = File(imagePath!);
    return GestureDetector(
      onTap: () => _showFullImage(context, file),
      child: Hero(
        tag: imagePath!,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 260),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, File file) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: imagePath!,
                  child: InteractiveViewer(
                    child: Image.file(file),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: isUser ? Colors.blue.shade100 : Colors.white,
      child: isUser
          ? Icon(Icons.person, size: 20, color: Colors.blue.shade700)
          : ClipOval(
              child: Image.asset(
                'assets/images/robot_avatar.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}
