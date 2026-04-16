# AI Elder Assistant - 韩语 AI 助手

一款专为老年人设计的韩语语音 AI 助手 App，支持语音输入、图片识别、智能搜索等功能。

## 功能特性

- 🎤 **语音输入** - 长按说话，自动识别韩语（支持中文/韩语混合）
- 📷 **图片识别** - 拍照识物，识别药品说明书、路牌等，支持上下文追问
- 🔍 **智能搜索** - Qwen 原生联网搜索，模型自主判断是否需要搜索（无需手动开关）
- 💬 **多轮对话** - 记住最近 20 条上下文，连续对话
- 📅 **历史记录** - 侧边栏查看/切换历史对话，自动以首条消息命名
- 🔒 **设备隔离** - 每部手机独立的对话记录，互不可见

## 技术架构

```
┌─────────────────┐     HTTP       ┌─────────────────┐
│  Android App   │ ←────────────→ │  Ubuntu Server  │
│   Flutter/Dart │    19000 端口    │   FastAPI       │
└─────────────────┘                └────────┬────────┘
                                            │
                                    ┌───────┼───────┐
                                    ▼       ▼       ▼
                               DashScope  Qwen    SQLite
                               (AI 模型) (原生搜索)  (存储)
```

## 后端部署

### 服务器要求
- Ubuntu 22.04+
- Python 3.10+
- 公网 IP（部署时替换为实际 IP）
- Nginx 反向代理

### 安装步骤

```bash
# 1. 克隆代码
git clone https://github.com/unicorn101213/ai-elder-assistant-public.git
cd ai-elder-assistant/backend

# 2. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 3. 安装依赖
pip install -r requirements.txt

# 4. 配置环境变量
cp .env.example .env
# 编辑 .env 填入 API Key 和服务器 IP

# 5. 设置 systemd 服务（开机自启）
sudo cp deploy/ai-assistant.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ai-assistant
sudo systemctl start ai-assistant

# 6. 配置 Nginx
sudo cp deploy/nginx.conf /etc/nginx/sites-available/ai-assistant
sudo ln -s /etc/nginx/sites-available/ai-assistant /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 常用运维命令

```bash
# 查看状态
systemctl status ai-assistant

# 重启服务
systemctl restart ai-assistant

# 查看日志
journalctl -u ai-assistant -n 50 --no-pager

# 实时日志
journalctl -u ai-assistant -f
```

## 配置说明

### 1. 修改 AI 模型

编辑 `backend/config.py`：

```python
chat_model: str = "qwen3.5-flash"  # 对话模型
```

可用模型：
- `qwen3.5-flash` - 速度快，适合日常对话
- `qwen3.5-plus` - 更聪明，稍慢
- `qwen-max` - 最强，最慢

### 2. 修改系统提示词

编辑 `backend/services/qwen_service.py`，找到 `SYSTEM_PROMPT`。

### 3. API Key 配置

编辑 `backend/.env`（此文件不提交到 Git）：

```bash
# 阿里百炼 DashScope
DASHSCOPE_API_KEY=sk-xxxxxxxxxxxxx
DASHSCOPE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1

# 服务配置
HOST=0.0.0.0
PORT=8000
PUBLIC_BASE_URL=http://你的服务器IP:19000
```

## 前端构建

```bash
cd app

# 安装依赖
flutter pub get

# 构建 Release APK
flutter build apk --release

# APK 输出位置
ls build/app/outputs/flutter-apk/app-release.apk
```

## 安装到手机

### USB 安装（开发测试）
```bash
adb install -r app-release.apk
```

### 其他安装方式
通过微信/QQ/蓝牙等方式发送 APK 文件给用户

## 智能搜索

使用 Qwen 原生 `enable_search` 能力，模型自主判断是否需要联网搜索：
- 说"你好" → 不搜索，直接回复
- 说"北京天气" → 自动联网搜索后回复
- 支持中文、韩语、混合语言的语义理解

## 常见问题

### Q: 语音识别不准怎么办？
A: 确保说话清晰，环境安静。支持中文/韩语混合，但纯韩语效果更好。

### Q: 历史对话在哪里查看？
A: 点击左上角 ≡ 菜单按钮，打开侧边栏查看历史对话。

### Q: 图片识别后能继续追问吗？
A: 可以。发送图片后直接用文字追问，模型能理解上下文。

### Q: 不同手机的对话会互相看到吗？
A: 不会。每部手机有独立的设备 ID，对话记录互相隔离。

## 项目结构

```
ai-elder-assistant/
├── backend/                    # Python FastAPI 后端
│   ├── main.py                # 入口
│   ├── config.py              # 配置
│   ├── services/              # 业务逻辑
│   │   ├── qwen_service.py    # DashScope AI 服务（对话+搜索+识图+STT）
│   │   ├── search_service.py  # Tavily 搜索（备用）
│   │   └── memory_service.py  # SQLite 会话管理（设备隔离）
│   ├── routers/               # API 路由
│   │   ├── chat.py            # 对话
│   │   ├── voice.py           # 语音
│   │   ├── vision.py          # 识图
│   │   └── sessions.py        # 会话管理
│   └── static/                # 静态资源
│       └── .gitkeep
├── app/                        # Flutter 前端
│   └── lib/
│       ├── main.dart
│       ├── screens/
│       │   └── chat_screen.dart
│       ├── widgets/
│       │   ├── chat_bubble.dart
│       │   └── voice_hold_button.dart
│       └── services/
│           ├── api_service.dart
│           ├── session_service.dart
│           └── tts_service.dart
├── deploy/                     # 部署配置
│   ├── ai-assistant.service   # systemd 服务（开机自启）
│   └── nginx.conf             # Nginx 配置
└── README.md                   # 本文档
```

## 许可证

本项目仅供学习使用。

## 更新日志

### v1.1.0 (2026-04-16)
- ✅ 智能搜索升级为 Qwen 原生 enable_search（替代关键词匹配+Tavily）
- ✅ 图片识别支持上下文追问
- ✅ 上下文优化为最近 20 条消息
- ✅ 设备隔离（每部手机独立对话记录）
- ✅ 会话自动命名（首条消息作为标题）
- ✅ 移除 TTS 朗读功能（简化界面）
- ✅ 移除强制搜索开关（模型自主判断）

### v1.0.0 (2026-04-15)
- ✅ 语音输入（Paraformer-v2 异步识别）
- ✅ 图片识别（qwen3.5-flash 多模态）
- ✅ 智能搜索（关键词判断+Tavily）
- ✅ 历史对话（SQLite 存储）
- ✅ 日期分隔（오늘/어제/月日）
