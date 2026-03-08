#!/bin/bash
# ============================================================
# 云信通 - 企业IM服务一键部署脚本
# 此脚本由SaaS平台通过SSH在企业服务器上执行
# ============================================================

set -e

ENTERPRISE_ID="${1:-ENT_DEFAULT}"
API_PORT="${2:-4001}"
INSTALL_DIR="/opt/yunxintong/${ENTERPRISE_ID}"

echo "=========================================="
echo " 云信通企业IM服务 - 一键部署"
echo " 企业ID: ${ENTERPRISE_ID}"
echo " 安装目录: ${INSTALL_DIR}"
echo " API端口: ${API_PORT}"
echo "=========================================="

# 1. 系统环境检查与更新
echo ""
echo "[1/8] 更新系统环境..."
apt-get update -qq
apt-get install -y -qq curl wget git build-essential

# 2. 安装Node.js
echo ""
echo "[2/8] 安装Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
fi
echo "  Node.js版本: $(node -v)"
echo "  npm版本: $(npm -v)"

# 3. 安装PM2进程管理器
echo ""
echo "[3/8] 安装PM2进程管理器..."
npm install -g pm2 --silent

# 4. 创建安装目录并部署代码
echo ""
echo "[4/8] 部署企业后端代码..."
mkdir -p ${INSTALL_DIR}
# 实际场景中，这里会从SaaS服务器下载部署包
# scp -r deploy-package/* root@enterprise-server:${INSTALL_DIR}/
# 或者从私有仓库拉取
# git clone https://your-repo/yunxintong-enterprise.git ${INSTALL_DIR}
cp -r /tmp/yunxintong-deploy/* ${INSTALL_DIR}/

# 5. 安装依赖
echo ""
echo "[5/8] 安装Node.js依赖..."
cd ${INSTALL_DIR}
npm install --production --silent

# 6. 配置环境变量
echo ""
echo "[6/8] 配置环境变量..."
cat > ${INSTALL_DIR}/.env << EOF
PORT=${API_PORT}
ENTERPRISE_ID=${ENTERPRISE_ID}
NODE_ENV=production
JWT_SECRET=$(openssl rand -hex 32)
EOF

# 7. 配置Nginx反向代理
echo ""
echo "[7/8] 配置Nginx..."
if ! command -v nginx &> /dev/null; then
    apt-get install -y -qq nginx
fi

cat > /etc/nginx/sites-available/yunxintong-${ENTERPRISE_ID} << EOF
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }

    location /ws {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/yunxintong-${ENTERPRISE_ID} /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 8. 启动服务
echo ""
echo "[8/8] 启动企业IM服务..."
cd ${INSTALL_DIR}
pm2 delete yunxintong-${ENTERPRISE_ID} 2>/dev/null || true
PORT=${API_PORT} pm2 start index.js --name yunxintong-${ENTERPRISE_ID}
pm2 save
pm2 startup systemd -u root --hp /root 2>/dev/null || true

echo ""
echo "=========================================="
echo " ✅ 部署完成！"
echo " API地址: http://$(hostname -I | awk '{print $1}'):${API_PORT}/api"
echo " WebSocket: ws://$(hostname -I | awk '{print $1}'):${API_PORT}/ws"
echo " 企业管理后台: http://$(hostname -I | awk '{print $1}'):${API_PORT}/admin"
echo " 默认管理员: admin / admin123"
echo "=========================================="
