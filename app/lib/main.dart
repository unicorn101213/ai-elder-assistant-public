import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/chat_screen.dart';
import 'services/api_service.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 强制竖屏
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ElderAssistantApp());
}

class ElderAssistantApp extends StatelessWidget {
  const ElderAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<SessionService>(
          create: (ctx) => SessionService(ctx.read<ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'AI 어시스턴트',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
          // 全局大字体，适合老人
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 18),
            bodyMedium: TextStyle(fontSize: 16),
            titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
