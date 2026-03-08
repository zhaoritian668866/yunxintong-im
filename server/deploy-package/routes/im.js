const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { verifyToken } = require('../middleware/auth');

// 会话列表
router.get('/conversations', verifyToken, (req, res) => {
  try {
    const userId = req.user.id;
    const conversations = db.prepare(`
      SELECT c.*, cm.is_pinned, cm.is_muted, cm.unread_count,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
        (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at,
        (SELECT m.type FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_type,
        (SELECT m.sender_id FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_sender_id,
        (SELECT COUNT(*) FROM conversation_members cm2 WHERE cm2.conversation_id = c.id) as member_count
      FROM conversations c
      JOIN conversation_members cm ON c.id = cm.conversation_id AND cm.user_id = ?
      ORDER BY cm.is_pinned DESC, last_message_at DESC NULLS LAST
    `).all(userId);

    const result = conversations.map(conv => {
      if (conv.type === 'private') {
        const other = db.prepare(`
          SELECT u.id, u.nickname, u.avatar, u.online_status
          FROM conversation_members cm JOIN users u ON cm.user_id = u.id
          WHERE cm.conversation_id = ? AND cm.user_id != ?
        `).get(conv.id, userId);
        if (other) { conv.name = other.nickname; conv.avatar = other.avatar; conv.peer_id = other.id; conv.peer_online = other.online_status; }
      }
      if (conv.last_sender_id) {
        const sender = db.prepare('SELECT nickname FROM users WHERE id = ?').get(conv.last_sender_id);
        conv.last_sender_name = sender ? sender.nickname : '';
      }
      return conv;
    });
    res.json({ code: 200, data: result });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 消息列表
router.get('/messages/:conversationId', verifyToken, (req, res) => {
  try {
    const { page = 1, pageSize = 30 } = req.query;
    const total = db.prepare('SELECT COUNT(*) as count FROM messages WHERE conversation_id=?').get(req.params.conversationId).count;
    const messages = db.prepare(`
      SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar
      FROM messages m LEFT JOIN users u ON m.sender_id = u.id
      WHERE m.conversation_id = ? ORDER BY m.created_at DESC LIMIT ? OFFSET ?
    `).all(req.params.conversationId, Number(pageSize), (Number(page) - 1) * Number(pageSize));
    db.prepare('UPDATE conversation_members SET unread_count=0, last_read_at=CURRENT_TIMESTAMP WHERE conversation_id=? AND user_id=?').run(req.params.conversationId, req.user.id);
    res.json({ code: 200, data: { total, list: messages.reverse() } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 发送消息
router.post('/messages', verifyToken, (req, res) => {
  try {
    const { conversation_id, type, content, file_url, file_name, reply_to } = req.body;
    if (!conversation_id || !content) return res.json({ code: 400, message: '会话ID和消息内容不能为空' });
    const member = db.prepare('SELECT id FROM conversation_members WHERE conversation_id=? AND user_id=?').get(conversation_id, req.user.id);
    if (!member) return res.json({ code: 403, message: '您不是该会话的成员' });
    const msgId = uuidv4();
    db.prepare('INSERT INTO messages (id,conversation_id,sender_id,type,content,file_url,file_name,reply_to) VALUES (?,?,?,?,?,?,?,?)')
      .run(msgId, conversation_id, req.user.id, type || 'text', content, file_url || null, file_name || null, reply_to || null);
    db.prepare('UPDATE conversation_members SET unread_count=unread_count+1 WHERE conversation_id=? AND user_id!=?').run(conversation_id, req.user.id);
    db.prepare('UPDATE conversations SET updated_at=CURRENT_TIMESTAMP WHERE id=?').run(conversation_id);
    const msg = db.prepare('SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar FROM messages m LEFT JOIN users u ON m.sender_id=u.id WHERE m.id=?').get(msgId);
    res.json({ code: 200, message: '发送成功', data: msg });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 撤回消息
router.put('/messages/:id/recall', verifyToken, (req, res) => {
  try {
    const msg = db.prepare('SELECT * FROM messages WHERE id=? AND sender_id=?').get(req.params.id, req.user.id);
    if (!msg) return res.json({ code: 404, message: '消息不存在或无权撤回' });
    const settings = db.prepare('SELECT message_recall_timeout FROM settings LIMIT 1').get();
    const timeout = (settings ? settings.message_recall_timeout : 120) * 1000;
    if (Date.now() - new Date(msg.created_at).getTime() > timeout) return res.json({ code: 403, message: '已超过撤回时限' });
    db.prepare("UPDATE messages SET is_recalled=1, content='此消息已被撤回' WHERE id=?").run(req.params.id);
    res.json({ code: 200, message: '撤回成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 通讯录
router.get('/contacts', verifyToken, (req, res) => {
  try {
    const users = db.prepare(`
      SELECT u.id,u.username,u.nickname,u.avatar,u.phone,u.email,u.position,u.online_status,u.department_id,d.name as department_name
      FROM users u LEFT JOIN departments d ON u.department_id=d.id
      WHERE u.status='active' AND u.id!=? ORDER BY u.nickname
    `).all(req.user.id);
    const departments = db.prepare('SELECT * FROM departments ORDER BY sort_order').all();
    const groups = db.prepare(`
      SELECT c.*, (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id=c.id) as member_count
      FROM conversations c JOIN conversation_members cm ON c.id=cm.conversation_id AND cm.user_id=?
      WHERE c.type='group'
    `).all(req.user.id);
    res.json({ code: 200, data: { contacts: users, departments, groups } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 创建会话
router.post('/conversations', verifyToken, (req, res) => {
  try {
    const { type, name, member_ids } = req.body;
    if (type === 'private') {
      if (!member_ids || member_ids.length !== 1) return res.json({ code: 400, message: '私聊需要指定一个对方用户' });
      const existing = db.prepare(`
        SELECT c.id FROM conversations c WHERE c.type='private'
        AND EXISTS (SELECT 1 FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.user_id=?)
        AND EXISTS (SELECT 1 FROM conversation_members cm WHERE cm.conversation_id=c.id AND cm.user_id=?)
      `).get(req.user.id, member_ids[0]);
      if (existing) return res.json({ code: 200, message: '会话已存在', data: { id: existing.id, is_existing: true } });
    }
    if (type === 'group' && !name) return res.json({ code: 400, message: '群聊名称不能为空' });
    const convId = uuidv4();
    db.prepare('INSERT INTO conversations (id,type,name,created_by) VALUES (?,?,?,?)').run(convId, type || 'private', name || '', req.user.id);
    db.prepare('INSERT INTO conversation_members (id,conversation_id,user_id) VALUES (?,?,?)').run(uuidv4(), convId, req.user.id);
    if (member_ids && member_ids.length > 0) {
      const ins = db.prepare('INSERT INTO conversation_members (id,conversation_id,user_id) VALUES (?,?,?)');
      for (const mid of member_ids) ins.run(uuidv4(), convId, mid);
    }
    res.json({ code: 200, message: '创建成功', data: { id: convId } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 置顶/取消置顶
router.put('/conversations/:id/pin', verifyToken, (req, res) => {
  try {
    const { is_pinned } = req.body;
    if (is_pinned) { const c = db.prepare('SELECT COUNT(*) as count FROM conversation_members WHERE user_id=? AND is_pinned=1').get(req.user.id).count; if (c >= 10) return res.json({ code: 403, message: '最多置顶10个会话' }); }
    db.prepare('UPDATE conversation_members SET is_pinned=? WHERE conversation_id=? AND user_id=?').run(is_pinned ? 1 : 0, req.params.id, req.user.id);
    res.json({ code: 200, message: is_pinned ? '已置顶' : '已取消置顶' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 免打扰
router.put('/conversations/:id/mute', verifyToken, (req, res) => {
  try {
    const { is_muted } = req.body;
    db.prepare('UPDATE conversation_members SET is_muted=? WHERE conversation_id=? AND user_id=?').run(is_muted ? 1 : 0, req.params.id, req.user.id);
    res.json({ code: 200, message: is_muted ? '已开启免打扰' : '已关闭免打扰' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

module.exports = router;
