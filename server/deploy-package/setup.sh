#!/bin/bash
# 云信通企业IM服务 - 自动安装部署脚本
# 用法: ENTERPRISE_ID=xxx PORT=4001 bash setup.sh

set -e

ENTERPRISE_ID=${ENTERPRISE_ID:-"UNKNOWN"}
PORT=${PORT:-4001}
INSTALL_DIR=${INSTALL_DIR:-"/opt/yunxintong/${ENTERPRISE_ID}"}
SERVICE_NAME="yunxintong-${ENTERPRISE_ID}"

echo "=========================================="
echo "  云信通企业IM服务 - 自动部署"
echo "  企业ID: ${ENTERPRISE_ID}"
echo "  端口: ${PORT}"
echo "  安装目录: ${INSTALL_DIR}"
echo "=========================================="

# 检查Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js 未安装，正在安装..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "✅ Node.js 版本: $(node -v)"

# 创建安装目录
sudo mkdir -p ${INSTALL_DIR}
sudo cp -r . ${INSTALL_DIR}/
sudo chown -R $(whoami):$(whoami) ${INSTALL_DIR}

# 安装依赖
cd ${INSTALL_DIR}
npm install --production

# 创建数据目录
mkdir -p ${INSTALL_DIR}/data
mkdir -p ${INSTALL_DIR}/public

# 创建环境变量文件
cat > ${INSTALL_DIR}/.env << EOF
ENTERPRISE_ID=${ENTERPRISE_ID}
PORT=${PORT}
JWT_SECRET=yunxintong_${ENTERPRISE_ID}_$(openssl rand -hex 16)
NODE_ENV=production
EOF

# 创建systemd服务
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=云信通企业IM服务 - ${ENTERPRISE_ID}
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${INSTALL_DIR}/.env
ExecStart=$(which node) ${INSTALL_DIR}/index.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

# 等待启动
sleep 3

# 检查状态
if sudo systemctl is-active --quiet ${SERVICE_NAME}; then
  echo ""
  echo "=========================================="
  echo "  ✅ 部署成功！"
  echo "  服务名: ${SERVICE_NAME}"
  echo "  API地址: http://0.0.0.0:${PORT}/api"
  echo "  WebSocket: ws://0.0.0.0:${PORT}/ws"
  echo "  管理后台: http://0.0.0.0:${PORT}"
  echo "  默认管理员: admin / 123456"
  echo "=========================================="
else
  echo "❌ 服务启动失败，查看日志: sudo journalctl -u ${SERVICE_NAME} -n 50"
  exit 1
fi
