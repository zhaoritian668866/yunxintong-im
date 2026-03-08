const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const { initDatabase } = require('./models/database');
const { db } = require('./models/database');
const { JWT_SECRET } = require('./middleware/auth');

// 从环境变量读取配置
const PORT = process.env.PORT || 4001;
const ENTERPRISE_ID = process.env.ENTERPRISE_ID || 'UNKNOWN';

initDatabase();

// ==================== 企业服务（API + 管理后台 + WebSocket） ====================
const app = express();
const server = http.createServer(app);

app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], allowedHeaders: ['Content-Type', 'Authorization'] }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 日志
app.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[${ENTERPRISE_ID}] ${req.method} ${req.path}`);
  next();
});

// API路由
app.use('/api/auth', require('./routes/auth'));
app.use('/api/im', require('./routes/im'));
app.use('/api/admin', require('./routes/admin'));

// 健康检查
app.get('/api/health', (req, res) => {
  const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
  res.json({
    code: 200,
    message: 'OK',
    enterprise_id: ENTERPRISE_ID,
    enterprise_name: settings ? settings.enterprise_name : '',
    timestamp: new Date().toISOString()
  });
});

// 企业管理后台静态文件（如果存在）
const ADMIN_WEB_DIR = path.join(__dirname, 'public');
app.use(express.static(ADMIN_WEB_DIR));
app.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    const indexPath = path.join(ADMIN_WEB_DIR, 'index.html');
    const fs = require('fs');
    if (fs.existsSync(indexPath)) {
      res.sendFile(indexPath);
    } else {
      res.json({ code: 200, message: `企业 ${ENTERPRISE_ID} 服务运行中`, api: '/api/health' });
    }
  } else {
    next();
  }
});

// ==================== WebSocket ====================
const wss = new WebSocketServer({ server, path: '/ws' });
const onlineUsers = new Map();

wss.on('connection', (ws) => {
  let userId = null;

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);

      // 认证
      if (msg.type === 'auth') {
        try {
          const decoded = jwt.verify(msg.token, JWT_SECRET);
          userId = decoded.id;
          onlineUsers.set(userId, ws);
          db.prepare("UPDATE users SET online_status='online' WHERE id=?").run(userId);
          ws.send(JSON.stringify({ type: 'auth_success', user_id: userId }));
          // 广播在线状态变更
          broadcastOnlineStatus(userId, 'online');
        } catch (e) {
          ws.send(JSON.stringify({ type: 'auth_error', message: '认证失败' }));
        }
        return;
      }

      // 新消息推送
      if (msg.type === 'message' && userId) {
        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id=?').all(msg.conversation_id);
        const payload = JSON.stringify({ type: 'new_message', data: msg.data });
        members.forEach(m => {
          if (m.user_id !== userId) {
            const target = onlineUsers.get(m.user_id);
            if (target && target.readyState === 1) target.send(payload);
          }
        });
      }

      // 正在输入
      if (msg.type === 'typing' && userId) {
        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id=?').all(msg.conversation_id);
        const payload = JSON.stringify({ type: 'typing', conversation_id: msg.conversation_id, user_id: userId });
        members.forEach(m => {
          if (m.user_id !== userId) {
            const target = onlineUsers.get(m.user_id);
            if (target && target.readyState === 1) target.send(payload);
          }
        });
      }
    } catch (e) {
      console.error('[WS] Error:', e.message);
    }
  });

  ws.on('close', () => {
    if (userId) {
      onlineUsers.delete(userId);
      db.prepare("UPDATE users SET online_status='offline' WHERE id=?").run(userId);
      broadcastOnlineStatus(userId, 'offline');
    }
  });
});

// 广播在线状态变更给所有在线用户
function broadcastOnlineStatus(userId, status) {
  const payload = JSON.stringify({ type: 'online_status', user_id: userId, status });
  onlineUsers.forEach((ws, uid) => {
    if (uid !== userId && ws.readyState === 1) {
      ws.send(payload);
    }
  });
}

// ==================== 启动服务 ====================
server.listen(PORT, '0.0.0.0', () => {
  console.log('==========================================');
  console.log(`  企业IM服务 [${ENTERPRISE_ID}]`);
  console.log(`  API: http://0.0.0.0:${PORT}/api`);
  console.log(`  WebSocket: ws://0.0.0.0:${PORT}/ws`);
  console.log(`  管理后台: http://0.0.0.0:${PORT}`);
  console.log('  默认管理员: admin / 123456');
  console.log('==========================================');
});
