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
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// 日志
app.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[${ENTERPRISE_ID}] ${req.method} ${req.path}`);
  next();
});

// API路由
app.use('/api/auth', require('./routes/auth'));
app.use('/api/im', require('./routes/im'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/upload', require('./routes/upload'));

// 功能开关查询API（用户端，不需要管理员权限，只需登录）
const { verifyToken } = require('./middleware/auth');
app.get('/api/features', verifyToken, (req, res) => {
  try {
    const settings = db.prepare('SELECT * FROM settings LIMIT 1').get();
    if (!settings) return res.json({ code: 200, data: {} });
    // 只返回功能开关相关字段
    const features = {
      // 聊天功能
      enable_voice_message: settings.enable_voice_message ?? 1,
      enable_image_send: settings.enable_image_send ?? 1,
      enable_video_send: settings.enable_video_send ?? 1,
      enable_emoji: settings.enable_emoji ?? 1,
      enable_voice_call: settings.enable_voice_call ?? 1,
      enable_video_call: settings.enable_video_call ?? 1,
      enable_read_receipt: settings.enable_read_receipt ?? 1,
      enable_msg_recall: settings.enable_msg_recall ?? 1,
      enable_file_send: settings.enable_file_send ?? 1,
      // 工作台功能
      enable_workbench: settings.enable_workbench ?? 1,
      enable_schedule: settings.enable_schedule ?? 1,
      enable_task: settings.enable_task ?? 1,
      enable_cloud_drive: settings.enable_cloud_drive ?? 1,
      enable_approval: settings.enable_approval ?? 1,
      enable_attendance: settings.enable_attendance ?? 1,
      enable_meeting_room: settings.enable_meeting_room ?? 1,
      enable_announcement: settings.enable_announcement ?? 1,
      enable_voting: settings.enable_voting ?? 1,
      enable_expense: settings.enable_expense ?? 1,
      enable_calendar: settings.enable_calendar ?? 1,
      enable_report: settings.enable_report ?? 1,
      enable_analytics: settings.enable_analytics ?? 1,
      // 其他设置
      max_file_size: settings.max_file_size ?? 50,
      allow_file_sharing: settings.allow_file_sharing ?? 1,
      allow_group_creation: settings.allow_group_creation ?? 1,
    };
    res.json({ code: 200, data: features });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

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

// 上传文件静态服务
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 企业管理后台静态文件（如果存在）
const ADMIN_WEB_DIR = path.join(__dirname, 'public');
app.use(express.static(ADMIN_WEB_DIR));
app.use((req, res, next) => {
  if (!req.path.startsWith('/api') && !req.path.startsWith('/uploads') && req.method === 'GET') {
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
const onlineUsers = new Map(); // userId -> ws

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

      // ==================== WebRTC 信令 ====================
      // 发起通话
      if (msg.type === 'call_offer' && userId) {
        const target = onlineUsers.get(msg.target_user_id);
        if (target && target.readyState === 1) {
          target.send(JSON.stringify({
            type: 'call_offer',
            from_user_id: userId,
            call_type: msg.call_type, // 'voice' or 'video'
            sdp: msg.sdp,
            conversation_id: msg.conversation_id,
          }));
        } else {
          ws.send(JSON.stringify({ type: 'call_error', message: '对方不在线' }));
        }
      }

      // 接听通话
      if (msg.type === 'call_answer' && userId) {
        const target = onlineUsers.get(msg.target_user_id);
        if (target && target.readyState === 1) {
          target.send(JSON.stringify({
            type: 'call_answer',
            from_user_id: userId,
            sdp: msg.sdp,
          }));
        }
      }

      // ICE候选
      if (msg.type === 'ice_candidate' && userId) {
        const target = onlineUsers.get(msg.target_user_id);
        if (target && target.readyState === 1) {
          target.send(JSON.stringify({
            type: 'ice_candidate',
            from_user_id: userId,
            candidate: msg.candidate,
          }));
        }
      }

      // 挂断通话
      if (msg.type === 'call_hangup' && userId) {
        const target = onlineUsers.get(msg.target_user_id);
        if (target && target.readyState === 1) {
          target.send(JSON.stringify({
            type: 'call_hangup',
            from_user_id: userId,
            reason: msg.reason || 'hangup',
          }));
        }
      }

      // 拒绝通话
      if (msg.type === 'call_reject' && userId) {
        const target = onlineUsers.get(msg.target_user_id);
        if (target && target.readyState === 1) {
          target.send(JSON.stringify({
            type: 'call_reject',
            from_user_id: userId,
            reason: msg.reason || 'rejected',
          }));
        }
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

// 广播功能开关变更给所有在线用户
function broadcastSettingsChanged() {
  try {
    const settings = db.prepare('SELECT * FROM settings LIMIT 1').get();
    if (!settings) return;
    const features = {
      enable_voice_message: settings.enable_voice_message ?? 1,
      enable_image_send: settings.enable_image_send ?? 1,
      enable_video_send: settings.enable_video_send ?? 1,
      enable_emoji: settings.enable_emoji ?? 1,
      enable_voice_call: settings.enable_voice_call ?? 1,
      enable_video_call: settings.enable_video_call ?? 1,
      enable_read_receipt: settings.enable_read_receipt ?? 1,
      enable_msg_recall: settings.enable_msg_recall ?? 1,
      enable_file_send: settings.enable_file_send ?? 1,
      enable_workbench: settings.enable_workbench ?? 1,
      enable_schedule: settings.enable_schedule ?? 1,
      enable_task: settings.enable_task ?? 1,
      enable_cloud_drive: settings.enable_cloud_drive ?? 1,
      enable_approval: settings.enable_approval ?? 1,
      enable_attendance: settings.enable_attendance ?? 1,
      enable_meeting_room: settings.enable_meeting_room ?? 1,
      enable_announcement: settings.enable_announcement ?? 1,
      enable_voting: settings.enable_voting ?? 1,
      enable_expense: settings.enable_expense ?? 1,
      enable_calendar: settings.enable_calendar ?? 1,
      enable_report: settings.enable_report ?? 1,
      enable_analytics: settings.enable_analytics ?? 1,
      max_file_size: settings.max_file_size ?? 50,
      allow_file_sharing: settings.allow_file_sharing ?? 1,
      allow_group_creation: settings.allow_group_creation ?? 1,
    };
    const payload = JSON.stringify({ type: 'settings_changed', data: features });
    console.log(`[WS] Broadcasting settings_changed to ${onlineUsers.size} users`);
    onlineUsers.forEach((ws, uid) => {
      if (ws.readyState === 1) {
        ws.send(payload);
      }
    });
  } catch (e) {
    console.error('[WS] broadcastSettingsChanged error:', e.message);
  }
}

// 通过全局变量导出广播函数供admin路由使用
global.broadcastSettingsChanged = broadcastSettingsChanged;

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
