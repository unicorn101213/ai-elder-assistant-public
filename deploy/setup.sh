#!/bin/bash
# Ubuntu 服务器一键部署脚本
# 运行方式: bash deploy/setup.sh

set -e

APP_DIR="/opt/ai-elder-assistant"
BACKEND_DIR="$APP_DIR/backend"

echo "=== 1. 创建项目目录 ==="
mkdir -p "$BACKEND_DIR"

echo "=== 2. 复制后端代码 ==="
cp -r backend/* "$BACKEND_DIR/"

echo "=== 3. 创建 Python 虚拟环境 ==="
python3 -m venv "$APP_DIR/venv"

echo "=== 4. 安装依赖 ==="
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$BACKEND_DIR/requirements.txt"

echo "=== 5. 检查 .env 文件 ==="
if [ ! -f "$BACKEND_DIR/.env" ]; then
    cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
    echo ""
    echo "⚠️  请编辑 $BACKEND_DIR/.env 填写 API Key："
    echo "   nano $BACKEND_DIR/.env"
    echo ""
fi

echo "=== 6. 安装 systemd 服务 ==="
cp deploy/ai-assistant.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable ai-assistant
systemctl restart ai-assistant

echo "=== 7. 配置 Nginx ==="
cp nginx/ai-assistant.conf /etc/nginx/sites-available/ai-assistant
ln -sf /etc/nginx/sites-available/ai-assistant /etc/nginx/sites-enabled/ai-assistant
nginx -t && systemctl reload nginx

echo ""
echo "✅ 部署完成！"
echo "   后端状态: systemctl status ai-assistant"
echo "   查看日志: journalctl -u ai-assistant -f"
echo "   健康检查: curl http://localhost:8000/health"
