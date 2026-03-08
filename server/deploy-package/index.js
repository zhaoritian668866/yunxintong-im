const express = require('express');
const cors = require('cors');
const http = require('http');
const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const { initDatabase } = require('./models/database');
const { db } = require('./models/database');
const { JWT_SECRET } = require('./middleware/auth');

initDatabase();

const app = express();
const server = http.createServer(app);

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  console.log(`[Enterprise] ${req.method} ${req.path}`);
  next();
});

// 用户端API（公用前端直连此服务）
app.use('/api/auth', require('./routes/auth'));
app.use('/api/im', require('./routes/im'));

// 企业管理后台API
app.use('/api/admin', require('./routes/admin'));

// 健康检查
app.get('/api/health', (req, res) => {
  const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
  res.json({ code: 200, message: 'Enterprise Server OK', enterprise: settings ? settings.enterprise_name : '', timestamp: new Date().toISOString() });
});

// ==================== WebSocket ====================
const wss = new WebSocketServer({ server, path: '/ws' });
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

const PORT = process.env.PORT || 4001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🏢 企业IM服务已启动`);
  console.log(`📡 API: http://0.0.0.0:${PORT}/api`);
  console.log(`🔌 WebSocket: ws://0.0.0.0:${PORT}/ws`);
  console.log(`📋 企业管理员: admin / admin123`);
  console.log(`📋 测试用户: zhangwei / 123456, liuna / 123456`);
});
