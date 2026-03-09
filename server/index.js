const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { WebSocket, WebSocketServer } = require('ws');
const { URL } = require('url');
const { initDatabase, db } = require('./models/database');

initDatabase();

const corsOptions = {
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

// ==================== 公用前端应用 ====================
const USER_WEB_DIR = path.join(__dirname, 'build/web_user');
const PORT_USER = process.env.PORT_USER || 8088;
const userApp = express();
userApp.use(cors(corsOptions));

userApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[User] ${req.method} ${req.path}`);
  next();
});

// 代理路由必须在express.json()之前注册，避免文件上传的原始请求体被解析消耗
userApp.use('/api/proxy', require('./routes/proxy')());

// 其他API路由需要JSON解析
userApp.use(express.json());
userApp.use(express.urlencoded({ extended: true }));

// 企业ID解析（查询数据库中租户的api_url）
userApp.use('/api/saas', require('./routes/auth'));
userApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'OK', timestamp: new Date().toISOString() });
});

// 静态文件
userApp.use(express.static(USER_WEB_DIR));
userApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(USER_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// 创建HTTP服务器（用于支持WebSocket升级）
const userServer = http.createServer(userApp);

// ==================== WebSocket代理 ====================
// 将用户端的WebSocket连接代理到企业服务器
// 路径格式: /ws/{enterprise_id}?token=xxx
userServer.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;

  // 匹配 /ws/{enterprise_id} 路径
  const wsMatch = pathname.match(/^\/ws\/([^\/]+)$/);
  if (!wsMatch) {
    socket.destroy();
    return;
  }

  const enterpriseId = wsMatch[1];
  const token = url.searchParams.get('token') || '';

  console.log(`[WS Proxy] Upgrade request for enterprise: ${enterpriseId}`);

  // 查找企业服务器地址
  try {
    const tenant = db.prepare(
      'SELECT api_url, ws_url, status, deploy_status FROM tenants WHERE enterprise_id = ?'
    ).get(enterpriseId);

    if (!tenant || tenant.status !== 'active' || !tenant.api_url) {
      console.log(`[WS Proxy] Enterprise ${enterpriseId} not found or inactive`);
      socket.destroy();
      return;
    }

    // 推导WebSocket地址
    let wsUrl = tenant.ws_url;
    if (!wsUrl) {
      // 从api_url推导: http://ip:port/api -> ws://ip:port/ws
      const apiUrl = tenant.api_url;
      wsUrl = apiUrl.replace(/^https?:\/\//, 'ws://').replace(/\/api\/?$/, '/ws');
    }

    // 附加token参数
    const targetUrl = `${wsUrl}?token=${token}`;
    console.log(`[WS Proxy] Connecting to: ${wsUrl}`);

    // 创建到企业服务器的WebSocket连接
    const targetWs = new WebSocket(targetUrl);

    targetWs.on('open', () => {
      console.log(`[WS Proxy] Connected to enterprise ${enterpriseId}`);

      // 创建WebSocket服务器来处理客户端连接
      const wss = new WebSocketServer({ noServer: true });
      wss.handleUpgrade(req, socket, head, (clientWs) => {
        // 双向转发消息
        clientWs.on('message', (data) => {
          if (targetWs.readyState === WebSocket.OPEN) {
            targetWs.send(data);
          }
        });

        targetWs.on('message', (data) => {
          if (clientWs.readyState === WebSocket.OPEN) {
            clientWs.send(data);
          }
        });

        clientWs.on('close', () => {
          console.log(`[WS Proxy] Client disconnected from ${enterpriseId}`);
          targetWs.close();
        });

        targetWs.on('close', () => {
          console.log(`[WS Proxy] Target disconnected from ${enterpriseId}`);
          clientWs.close();
        });

        clientWs.on('error', (err) => {
          console.error(`[WS Proxy] Client error:`, err.message);
          targetWs.close();
        });

        targetWs.on('error', (err) => {
          console.error(`[WS Proxy] Target error:`, err.message);
          clientWs.close();
        });
      });
    });

    targetWs.on('error', (err) => {
      console.error(`[WS Proxy] Failed to connect to enterprise ${enterpriseId}:`, err.message);
      socket.destroy();
    });

  } catch (err) {
    console.error(`[WS Proxy] Error:`, err.message);
    socket.destroy();
  }
});

// ==================== SaaS管理后台应用 ====================
const SAAS_WEB_DIR = path.join(__dirname, 'build/web_saas');
const PORT_SAAS = process.env.PORT_SAAS || 8081;
const saasApp = express();
saasApp.use(cors(corsOptions));
saasApp.use(express.json());
saasApp.use(express.urlencoded({ extended: true }));

saasApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[SaaS] ${req.method} ${req.path}`);
  next();
});

saasApp.use('/api/saas', require('./routes/saas'));
saasApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'OK', timestamp: new Date().toISOString() });
});

saasApp.use(express.static(SAAS_WEB_DIR));
saasApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(SAAS_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// ==================== 启动服务 ====================
userServer.listen(PORT_USER, '0.0.0.0', () => {
  console.log(`🌐 公用前端已启动: http://0.0.0.0:${PORT_USER}`);
  console.log(`   WebSocket代理: ws://0.0.0.0:${PORT_USER}/ws/{enterprise_id}`);
});

saasApp.listen(PORT_SAAS, '0.0.0.0', () => {
  console.log(`📊 SaaS管理后台已启动: http://0.0.0.0:${PORT_SAAS}`);
});

console.log('==========================================');
console.log('  云信通IM SaaS平台');
console.log(`  公用前端: http://0.0.0.0:${PORT_USER}`);
console.log(`  SaaS后台: http://0.0.0.0:${PORT_SAAS}`);
console.log('  默认管理员: superadmin / 123456');
console.log('==========================================');
