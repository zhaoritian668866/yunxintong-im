const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const { initDatabase } = require('./models/database');
const { db } = require('./models/database');
const { JWT_SECRET } = require('./middleware/auth');

initDatabase();

// ==================== 企业API服务（用户端直连）端口4001 ====================
const apiApp = express();
const apiServer = http.createServer(apiApp);

apiApp.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
apiApp.use(express.json());
apiApp.use(express.urlencoded({ extended: true }));

apiApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[Enterprise] ${req.method} ${req.path}`);
  next();
});

apiApp.use('/api/auth', require('./routes/auth'));
apiApp.use('/api/im', require('./routes/im'));
apiApp.use('/api/admin', require('./routes/admin'));
apiApp.get('/api/health', (req, res) => {
  const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
  res.json({ code: 200, message: 'Enterprise Server OK', enterprise: settings ? settings.enterprise_name : '', timestamp: new Date().toISOString() });
});

// ==================== 企业管理后台Web应用 端口8082 ====================
const ADMIN_WEB_DIR = path.join(__dirname, '../../build/web_enterprise');
const adminApp = express();
const PORT_ADMIN = process.env.PORT_ADMIN || 8082;

adminApp.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
adminApp.use(express.json());
adminApp.use(express.urlencoded({ extended: true }));

// 企业管理后台也需要API（同域访问）
adminApp.use('/api/auth', require('./routes/auth'));
adminApp.use('/api/im', require('./routes/im'));
adminApp.use('/api/admin', require('./routes/admin'));
adminApp.get('/api/health', (req, res) => {
  const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
  res.json({ code: 200, message: 'Enterprise Server OK', enterprise: settings ? settings.enterprise_name : '', timestamp: new Date().toISOString() });
});
adminApp.use(express.static(ADMIN_WEB_DIR));
adminApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(ADMIN_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// ==================== WebSocket ====================
const wss = new WebSocketServer({ server: apiServer, path: '/ws' });
const onlineUsers = new Map();

wss.on('connection', (ws) => {
  let userId = null;

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      if (msg.type === 'auth') {
        try {
          const decoded = jwt.verify(msg.token, JWT_SECRET);
          userId = decoded.id;
          onlineUsers.set(userId, ws);
          db.prepare("UPDATE users SET online_status='online' WHERE id=?").run(userId);
          ws.send(JSON.stringify({ type: 'auth_success', user_id: userId }));
        } catch (e) { ws.send(JSON.stringify({ type: 'auth_error', message: '认证失败' })); }
        return;
      }
      if (msg.type === 'message' && userId) {
        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id=?').all(msg.conversation_id);
        const payload = JSON.stringify({ type: 'new_message', data: msg.data });
        members.forEach(m => { if (m.user_id !== userId) { const t = onlineUsers.get(m.user_id); if (t && t.readyState === 1) t.send(payload); } });
      }
      if (msg.type === 'typing' && userId) {
        const members = db.prepare('SELECT user_id FROM conversation_members WHERE conversation_id=?').all(msg.conversation_id);
        const payload = JSON.stringify({ type: 'typing', conversation_id: msg.conversation_id, user_id: userId });
        members.forEach(m => { if (m.user_id !== userId) { const t = onlineUsers.get(m.user_id); if (t && t.readyState === 1) t.send(payload); } });
      }
    } catch (e) { console.error('[WS] Error:', e.message); }
  });

  ws.on('close', () => {
    if (userId) { onlineUsers.delete(userId); db.prepare("UPDATE users SET online_status='offline' WHERE id=?").run(userId); }
  });
});

const PORT_API = process.env.PORT || 4001;
apiServer.listen(PORT_API, '0.0.0.0', () => {
  console.log(`\n🏢 企业API服务已启动: http://0.0.0.0:${PORT_API}`);
  console.log(`🔌 WebSocket: ws://0.0.0.0:${PORT_API}/ws`);
});

adminApp.listen(PORT_ADMIN, '0.0.0.0', () => {
  console.log(`📊 企业管理后台已启动: http://0.0.0.0:${PORT_ADMIN}`);
});

console.log(`\n📋 企业管理员: admin / admin123`);
console.log(`📋 测试用户: zhangwei / 123456, liuna / 123456`);
