# AI Elder Assistant - 项目状态摘要

## 架构
```
[Android App - Flutter/Dart] ↔ [Ubuntu后端 - FastAPI] ↔ 阿里百炼 API
```

## 技术栈
- **移动端**: Flutter 3.24.5, Dart
- **后端**: Python FastAPI, 部署在 Ubuntu 22.04
- **对话AI**: DashScope qwen3.5-flash（流式输出）
- **视觉识图**: DashScope qwen3.5-flash（多模态）
- **智能搜索**: Qwen 原生 enable_search（模型自主判断是否联网）
- **语音识别STT**: DashScope Paraformer-v2 异步
- **对话记忆**: SQLite (elder_assistant.db)，按设备隔离
- **上下文**: 最近 20 条消息

## 需要修改的地方（部署时）

以下文件中的 `你的服务器IP` 需要替换为实际公网 IP：

| 文件 | 位置 | 说明 |
|------|------|------|
| `backend/config.py` | `public_base_url` | 后端服务地址 |
| `app/lib/services/api_service.dart` | `kBaseUrl` | App 连接后端的地址 |
| `app/lib/services/voice_speech_service.dart` | `_sttUrl` | 语音识别地址 |
| `backend/.env` | `PUBLIC_BASE_URL` | 环境变量 |

## 关键文件
| 文件 | 作用 |
|------|------|
| `backend/main.py` | FastAPI 入口 |
| `backend/services/qwen_service.py` | AI 服务（对话+搜索+识图+STT） |
| `backend/services/memory_service.py` | SQLite 会话管理（设备隔离） |
| `backend/routers/chat.py` | 对话路由 |
| `backend/routers/vision.py` | 识图路由 |
| `backend/routers/voice.py` | 语音路由 |
| `backend/routers/sessions.py` | 会话管理路由 |
| `backend/config.py` | 配置 |
| `app/lib/screens/chat_screen.dart` | 主对话界面 + 侧边栏 |
| `app/lib/widgets/chat_bubble.dart` | 消息气泡 |
| `app/lib/widgets/voice_hold_button.dart` | 长按语音按钮 |
| `app/lib/services/session_service.dart` | 会话管理 |
| `app/lib/services/api_service.dart` | HTTP API 客户端（含设备ID） |

## 后端配置 (.env)
```
DASHSCOPE_API_KEY=sk-xxxxxxxxxxxxx
DASHSCOPE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
PUBLIC_BASE_URL=http://你的服务器IP:19000
```

## 部署
- 后端: `/opt/ai-elder-assistant/` (systemd: ai-assistant，开机自启)
- 代理: Nginx 端口 19000 → localhost:8000
- 部署命令: `scp ... && systemctl restart ai-assistant`
- 前端构建: `flutter build apk --release`

## 当前状态 (v1.1.0)
- ✅ 文本对话（韩语，流式，Qwen原生搜索）
- ✅ 图片识别（支持上下文追问）
- ✅ 语音识别 STT（Paraformer-v2 异步）
- ✅ 语音输入 UI（长按说话，上滑取消）
- ✅ 历史对话侧边栏（自动以首条消息命名）
- ✅ 日期分隔（오늘/어제/月日/年）
- ✅ 设备隔离（每部手机独立对话记录）
- ❌ 已移除：TTS 自动朗读、强制搜索开关
