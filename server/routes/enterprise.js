const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken, requireRole } = require('../middleware/auth');

// ==================== 企业管理员认证 ====================

router.post('/login', (req, res) => {
  try {
    const { username, password, enterprise_id } = req.body;
    if (!username || !password || !enterprise_id) {
      return res.json({ code: 400, message: '用户名、密码和企业ID不能为空' });
    }
    const tenant = db.prepare('SELECT id, enterprise_id, name, status FROM tenants WHERE enterprise_id = ?').get(enterprise_id);
    if (!tenant) {
      return res.json({ code: 404, message: '企业ID不存在' });
    }
    if (tenant.status !== 'active') {
      return res.json({ code: 403, message: '该企业已被停用' });
    }
    const admin = db.prepare('SELECT * FROM enterprise_admins WHERE tenant_id = ? AND username = ?').get(tenant.id, username);
    if (!admin) {
      return res.json({ code: 401, message: '用户名或密码错误' });
    }
    if (!bcrypt.compareSync(password, admin.password)) {
      return res.json({ code: 401, message: '用户名或密码错误' });
    }
    if (!admin.status) {
      return res.json({ code: 403, message: '账号已被禁用' });
    }
    const token = generateToken({ id: admin.id, tenant_id: tenant.id, username: admin.username, role: 'enterprise_admin' });
    res.json({
      code: 200, message: '登录成功',
      data: {
        token,
        admin: { id: admin.id, username: admin.username, nickname: admin.nickname, role: admin.role },
        enterprise: { id: tenant.id, enterprise_id: tenant.enterprise_id, name: tenant.name }
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 仪表盘 ====================

router.get('/dashboard', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const totalEmployees = db.prepare('SELECT COUNT(*) as count FROM users WHERE tenant_id = ?').get(tid).count;
    const onlineEmployees = db.prepare("SELECT COUNT(*) as count FROM users WHERE tenant_id = ? AND online_status = 'online'").get(tid).count;
    const totalDepartments = db.prepare('SELECT COUNT(*) as count FROM departments WHERE tenant_id = ?').get(tid).count;
    const totalGroups = db.prepare("SELECT COUNT(*) as count FROM conversations WHERE tenant_id = ? AND type = 'group'").get(tid).count;
    const totalMessages = db.prepare('SELECT COUNT(*) as count FROM messages m JOIN conversations c ON m.conversation_id = c.id WHERE c.tenant_id = ?').get(tid).count;
    const todayMessages = db.prepare("SELECT COUNT(*) as count FROM messages m JOIN conversations c ON m.conversation_id = c.id WHERE c.tenant_id = ? AND m.created_at >= date('now')").get(tid).count;

    const departments = db.prepare(`
      SELECT d.id, d.name, COUNT(u.id) as employee_count,
        SUM(CASE WHEN u.online_status = 'online' THEN 1 ELSE 0 END) as online_count
      FROM departments d
      LEFT JOIN users u ON d.id = u.department_id AND u.tenant_id = d.tenant_id
      WHERE d.tenant_id = ?
      GROUP BY d.id
    `).all(tid);

    res.json({
      code: 200,
      data: {
        stats: { totalEmployees, onlineEmployees, totalDepartments, totalGroups, totalMessages, todayMessages },
        departments
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 员工管理 ====================

router.get('/employees', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { page = 1, pageSize = 20, keyword, department_id, status } = req.query;
    let where = 'WHERE u.tenant_id = ?';
    const params = [tid];
    if (keyword) { where += ' AND (u.nickname LIKE ? OR u.username LIKE ? OR u.phone LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
    if (department_id) { where += ' AND u.department_id = ?'; params.push(department_id); }
    if (status) { where += ' AND u.status = ?'; params.push(status); }

    const total = db.prepare(`SELECT COUNT(*) as count FROM users u ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const employees = db.prepare(`
      SELECT u.id, u.username, u.nickname, u.avatar, u.phone, u.email, u.position, u.status, u.online_status, u.department_id, u.last_login_at, u.created_at, d.name as department_name
      FROM users u LEFT JOIN departments d ON u.department_id = d.id
      ${where} ORDER BY u.created_at DESC LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);

    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: employees } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.post('/employees', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { username, password, nickname, phone, email, department_id, position } = req.body;
    if (!username || !password) {
      return res.json({ code: 400, message: '用户名和密码不能为空' });
    }
    const existing = db.prepare('SELECT id FROM users WHERE tenant_id = ? AND username = ?').get(tid, username);
    if (existing) return res.json({ code: 409, message: '用户名已存在' });

    const userId = uuidv4();
    const hashedPwd = bcrypt.hashSync(password, 10);
    db.prepare(`INSERT INTO users (id, tenant_id, username, password, nickname, phone, email, department_id, position, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(userId, tid, username, hashedPwd, nickname || username, phone || '', email || '', department_id || null, position || '', 'active');
    res.json({ code: 200, message: '添加成功', data: { id: userId } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/employees/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { nickname, phone, email, department_id, position, status } = req.body;
    db.prepare(`UPDATE users SET nickname = COALESCE(?, nickname), phone = COALESCE(?, phone), email = COALESCE(?, email), department_id = COALESCE(?, department_id), position = COALESCE(?, position), status = COALESCE(?, status), updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?`)
      .run(nickname, phone, email, department_id, position, status, req.params.id, req.user.tenant_id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.delete('/employees/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM users WHERE id = ? AND tenant_id = ?').run(req.params.id, req.user.tenant_id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 部门管理 ====================

router.get('/departments', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const departments = db.prepare(`
      SELECT d.*, COUNT(u.id) as employee_count
      FROM departments d LEFT JOIN users u ON d.id = u.department_id
      WHERE d.tenant_id = ? GROUP BY d.id ORDER BY d.sort_order
    `).all(req.user.tenant_id);
    res.json({ code: 200, data: departments });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.post('/departments', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, description, parent_id, sort_order } = req.body;
    if (!name) return res.json({ code: 400, message: '部门名称不能为空' });
    const deptId = uuidv4();
    db.prepare(`INSERT INTO departments (id, tenant_id, name, description, parent_id, sort_order) VALUES (?, ?, ?, ?, ?, ?)`)
      .run(deptId, req.user.tenant_id, name, description || '', parent_id || null, sort_order || 0);
    res.json({ code: 200, message: '创建成功', data: { id: deptId } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/departments/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, description, sort_order } = req.body;
    db.prepare(`UPDATE departments SET name = COALESCE(?, name), description = COALESCE(?, description), sort_order = COALESCE(?, sort_order), updated_at = CURRENT_TIMESTAMP WHERE id = ? AND tenant_id = ?`)
      .run(name, description, sort_order, req.params.id, req.user.tenant_id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.delete('/departments/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('UPDATE users SET department_id = NULL WHERE department_id = ? AND tenant_id = ?').run(req.params.id, req.user.tenant_id);
    db.prepare('DELETE FROM departments WHERE id = ? AND tenant_id = ?').run(req.params.id, req.user.tenant_id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 企业设置 ====================

router.get('/settings', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const settings = db.prepare('SELECT * FROM enterprise_settings WHERE tenant_id = ?').get(req.user.tenant_id);
    res.json({ code: 200, data: settings });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/settings', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { require_approval, allow_group_creation, allow_file_sharing, message_recall_timeout, max_file_size, max_group_members, watermark_enabled } = req.body;
    db.prepare(`UPDATE enterprise_settings SET
      require_approval = COALESCE(?, require_approval),
      allow_group_creation = COALESCE(?, allow_group_creation),
      allow_file_sharing = COALESCE(?, allow_file_sharing),
      message_recall_timeout = COALESCE(?, message_recall_timeout),
      max_file_size = COALESCE(?, max_file_size),
      max_group_members = COALESCE(?, max_group_members),
      watermark_enabled = COALESCE(?, watermark_enabled),
      updated_at = CURRENT_TIMESTAMP
      WHERE tenant_id = ?`)
      .run(require_approval, allow_group_creation, allow_file_sharing, message_recall_timeout, max_file_size, max_group_members, watermark_enabled, req.user.tenant_id);
    res.json({ code: 200, message: '设置已保存' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 聊天记录查看（企业管理员专属） ====================

// 获取所有会话列表
router.get('/chat-records/conversations', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { type, keyword, page = 1, pageSize = 20 } = req.query;
    let where = 'WHERE c.tenant_id = ?';
    const params = [tid];
    if (type) { where += ' AND c.type = ?'; params.push(type); }
    if (keyword) { where += ' AND (c.name LIKE ? OR EXISTS (SELECT 1 FROM conversation_members cm JOIN users u ON cm.user_id = u.id WHERE cm.conversation_id = c.id AND u.nickname LIKE ?))'; params.push(`%${keyword}%`, `%${keyword}%`); }

    const total = db.prepare(`SELECT COUNT(*) as count FROM conversations c ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const conversations = db.prepare(`
      SELECT c.*,
        (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id) as message_count,
        (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id = c.id) as member_count,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
        (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at
      FROM conversations c
      ${where} ORDER BY last_message_at DESC NULLS LAST LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);

    // 为每个会话获取成员名称
    const convWithMembers = conversations.map(conv => {
      const members = db.prepare(`
        SELECT u.id, u.nickname, u.avatar, u.username
        FROM conversation_members cm JOIN users u ON cm.user_id = u.id
        WHERE cm.conversation_id = ?
      `).all(conv.id);
      return { ...conv, members };
    });

    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: convWithMembers } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取指定会话的聊天记录
router.get('/chat-records/messages/:conversationId', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { page = 1, pageSize = 50, keyword, sender_id, start_date, end_date } = req.query;

    // 验证会话属于该企业
    const conv = db.prepare('SELECT * FROM conversations WHERE id = ? AND tenant_id = ?').get(req.params.conversationId, tid);
    if (!conv) return res.json({ code: 404, message: '会话不存在' });

    let where = 'WHERE m.conversation_id = ?';
    const params = [req.params.conversationId];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }
    if (sender_id) { where += ' AND m.sender_id = ?'; params.push(sender_id); }
    if (start_date) { where += ' AND m.created_at >= ?'; params.push(start_date); }
    if (end_date) { where += ' AND m.created_at <= ?'; params.push(end_date); }

    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const messages = db.prepare(`
      SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar, u.username as sender_username
      FROM messages m LEFT JOIN users u ON m.sender_id = u.id
      ${where} ORDER BY m.created_at ASC LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);

    res.json({
      code: 200,
      data: { conversation: conv, total, page: Number(page), pageSize: Number(pageSize), list: messages }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 搜索全企业聊天记录
router.get('/chat-records/search', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { keyword, sender_id, start_date, end_date, page = 1, pageSize = 50 } = req.query;
    if (!keyword && !sender_id) {
      return res.json({ code: 400, message: '请输入搜索关键词或选择发送者' });
    }

    let where = 'WHERE c.tenant_id = ?';
    const params = [tid];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }
    if (sender_id) { where += ' AND m.sender_id = ?'; params.push(sender_id); }
    if (start_date) { where += ' AND m.created_at >= ?'; params.push(start_date); }
    if (end_date) { where += ' AND m.created_at <= ?'; params.push(end_date); }

    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m JOIN conversations c ON m.conversation_id = c.id ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const messages = db.prepare(`
      SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar,
        c.type as conversation_type, c.name as conversation_name
      FROM messages m
      JOIN conversations c ON m.conversation_id = c.id
      LEFT JOIN users u ON m.sender_id = u.id
      ${where} ORDER BY m.created_at DESC LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);

    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: messages } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取指定用户的所有聊天记录
router.get('/chat-records/user/:userId', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const tid = req.user.tenant_id;
    const { page = 1, pageSize = 50, keyword } = req.query;

    // 验证用户属于该企业
    const user = db.prepare('SELECT id, nickname, username FROM users WHERE id = ? AND tenant_id = ?').get(req.params.userId, tid);
    if (!user) return res.json({ code: 404, message: '用户不存在' });

    let where = 'WHERE c.tenant_id = ? AND m.sender_id = ?';
    const params = [tid, req.params.userId];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }

    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m JOIN conversations c ON m.conversation_id = c.id ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const messages = db.prepare(`
      SELECT m.*, c.type as conversation_type, c.name as conversation_name
      FROM messages m
      JOIN conversations c ON m.conversation_id = c.id
      ${where} ORDER BY m.created_at DESC LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);

    res.json({ code: 200, data: { user, total, page: Number(page), pageSize: Number(pageSize), list: messages } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

module.exports = router;
