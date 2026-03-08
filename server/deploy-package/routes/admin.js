const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken, requireRole } = require('../middleware/auth');

// ==================== 企业管理员认证 ====================
router.post('/login', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const admin = db.prepare('SELECT * FROM admins WHERE username = ?').get(username);
    if (!admin || !bcrypt.compareSync(password, admin.password)) return res.json({ code: 401, message: '用户名或密码错误' });
    if (!admin.status) return res.json({ code: 403, message: '账号已被禁用' });
    const token = generateToken({ id: admin.id, username: admin.username, role: 'enterprise_admin' });
    const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
    res.json({ code: 200, message: '登录成功', data: { token, admin: { id: admin.id, username: admin.username, nickname: admin.nickname, role: admin.role }, enterprise_name: settings ? settings.enterprise_name : '' } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 仪表盘 ====================
router.get('/dashboard', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const totalEmployees = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
    const onlineEmployees = db.prepare("SELECT COUNT(*) as count FROM users WHERE online_status='online'").get().count;
    const totalDepartments = db.prepare('SELECT COUNT(*) as count FROM departments').get().count;
    const totalGroups = db.prepare("SELECT COUNT(*) as count FROM conversations WHERE type='group'").get().count;
    const totalMessages = db.prepare('SELECT COUNT(*) as count FROM messages').get().count;
    const todayMessages = db.prepare("SELECT COUNT(*) as count FROM messages WHERE created_at >= date('now')").get().count;
    const departments = db.prepare(`
      SELECT d.id, d.name, COUNT(u.id) as employee_count,
        SUM(CASE WHEN u.online_status='online' THEN 1 ELSE 0 END) as online_count
      FROM departments d LEFT JOIN users u ON d.id=u.department_id GROUP BY d.id
    `).all();
    res.json({ code: 200, data: { stats: { totalEmployees, onlineEmployees, totalDepartments, totalGroups, totalMessages, todayMessages }, departments } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 员工管理 ====================
router.get('/employees', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 20, keyword, department_id, status } = req.query;
    let where = 'WHERE 1=1'; const params = [];
    if (keyword) { where += ' AND (u.nickname LIKE ? OR u.username LIKE ? OR u.phone LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
    if (department_id) { where += ' AND u.department_id=?'; params.push(department_id); }
    if (status) { where += ' AND u.status=?'; params.push(status); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM users u ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const employees = db.prepare(`SELECT u.id,u.username,u.nickname,u.avatar,u.phone,u.email,u.position,u.status,u.online_status,u.department_id,u.last_login_at,u.created_at, d.name as department_name FROM users u LEFT JOIN departments d ON u.department_id=d.id ${where} ORDER BY u.created_at DESC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: employees } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.post('/employees', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { username, password, nickname, phone, email, department_id, position } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const existing = db.prepare('SELECT id FROM users WHERE username=?').get(username);
    if (existing) return res.json({ code: 409, message: '用户名已存在' });
    const userId = uuidv4();
    db.prepare('INSERT INTO users (id,username,password,nickname,phone,email,department_id,position,status) VALUES (?,?,?,?,?,?,?,?,?)')
      .run(userId, username, bcrypt.hashSync(password, 10), nickname || username, phone || '', email || '', department_id || null, position || '', 'active');
    res.json({ code: 200, message: '添加成功', data: { id: userId } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/employees/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { nickname, phone, email, department_id, position, status } = req.body;
    db.prepare('UPDATE users SET nickname=COALESCE(?,nickname),phone=COALESCE(?,phone),email=COALESCE(?,email),department_id=COALESCE(?,department_id),position=COALESCE(?,position),status=COALESCE(?,status),updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run(nickname, phone, email, department_id, position, status, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 重置员工密码
router.put('/employees/:id/password', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { password } = req.body;
    if (!password || password.length < 6) return res.json({ code: 400, message: '密码不能少于6位' });
    db.prepare('UPDATE users SET password=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').run(bcrypt.hashSync(password, 10), req.params.id);
    res.json({ code: 200, message: '密码重置成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/employees/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM conversation_members WHERE user_id=?').run(req.params.id);
    db.prepare('DELETE FROM users WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 部门管理 ====================
router.get('/departments', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const depts = db.prepare('SELECT d.*, COUNT(u.id) as employee_count FROM departments d LEFT JOIN users u ON d.id=u.department_id GROUP BY d.id ORDER BY d.sort_order').all();
    res.json({ code: 200, data: depts });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.post('/departments', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, description, parent_id, sort_order } = req.body;
    if (!name) return res.json({ code: 400, message: '部门名称不能为空' });
    const id = uuidv4();
    db.prepare('INSERT INTO departments (id,name,description,parent_id,sort_order) VALUES (?,?,?,?,?)').run(id, name, description || '', parent_id || null, sort_order || 0);
    res.json({ code: 200, message: '创建成功', data: { id } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/departments/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, description, sort_order } = req.body;
    db.prepare('UPDATE departments SET name=COALESCE(?,name),description=COALESCE(?,description),sort_order=COALESCE(?,sort_order),updated_at=CURRENT_TIMESTAMP WHERE id=?').run(name, description, sort_order, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/departments/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('UPDATE users SET department_id=NULL WHERE department_id=?').run(req.params.id);
    db.prepare('DELETE FROM departments WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 企业设置 ====================
router.get('/settings', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const settings = db.prepare('SELECT * FROM settings LIMIT 1').get();
    res.json({ code: 200, data: settings });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/settings', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { require_approval, allow_group_creation, allow_file_sharing, message_recall_timeout, max_file_size, max_group_members, watermark_enabled, enterprise_name } = req.body;
    db.prepare(`UPDATE settings SET require_approval=COALESCE(?,require_approval), allow_group_creation=COALESCE(?,allow_group_creation), allow_file_sharing=COALESCE(?,allow_file_sharing), message_recall_timeout=COALESCE(?,message_recall_timeout), max_file_size=COALESCE(?,max_file_size), max_group_members=COALESCE(?,max_group_members), watermark_enabled=COALESCE(?,watermark_enabled), enterprise_name=COALESCE(?,enterprise_name), updated_at=CURRENT_TIMESTAMP`)
      .run(require_approval, allow_group_creation, allow_file_sharing, message_recall_timeout, max_file_size, max_group_members, watermark_enabled, enterprise_name);
    res.json({ code: 200, message: '设置已保存' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 聊天记录查看 ====================

// 获取所有会话列表
router.get('/chat-records/conversations', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { type, keyword, page = 1, pageSize = 20 } = req.query;
    let where = 'WHERE 1=1'; const params = [];
    if (type) { where += ' AND c.type=?'; params.push(type); }
    if (keyword) { where += ' AND (c.name LIKE ? OR EXISTS (SELECT 1 FROM conversation_members cm JOIN users u ON cm.user_id=u.id WHERE cm.conversation_id=c.id AND u.nickname LIKE ?))'; params.push(`%${keyword}%`, `%${keyword}%`); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM conversations c ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const convs = db.prepare(`
      SELECT c.*,
        (SELECT COUNT(*) FROM messages m WHERE m.conversation_id=c.id) as message_count,
        (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id=c.id) as member_count,
        (SELECT m.content FROM messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
        (SELECT m.created_at FROM messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at
      FROM conversations c ${where} ORDER BY last_message_at DESC NULLS LAST LIMIT ? OFFSET ?
    `).all(...params, Number(pageSize), offset);
    const result = convs.map(c => {
      c.members = db.prepare('SELECT u.id,u.nickname,u.avatar,u.username FROM conversation_members cm JOIN users u ON cm.user_id=u.id WHERE cm.conversation_id=?').all(c.id);
      return c;
    });
    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: result } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 获取指定会话的聊天记录
router.get('/chat-records/messages/:conversationId', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 50, keyword, sender_id, start_date, end_date } = req.query;
    const conv = db.prepare('SELECT * FROM conversations WHERE id=?').get(req.params.conversationId);
    if (!conv) return res.json({ code: 404, message: '会话不存在' });
    let where = 'WHERE m.conversation_id=?'; const params = [req.params.conversationId];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }
    if (sender_id) { where += ' AND m.sender_id=?'; params.push(sender_id); }
    if (start_date) { where += ' AND m.created_at>=?'; params.push(start_date); }
    if (end_date) { where += ' AND m.created_at<=?'; params.push(end_date); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const msgs = db.prepare(`SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar FROM messages m LEFT JOIN users u ON m.sender_id=u.id ${where} ORDER BY m.created_at ASC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { conversation: conv, total, page: Number(page), pageSize: Number(pageSize), list: msgs } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 全局搜索聊天记录
router.get('/chat-records/search', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { keyword, sender_id, start_date, end_date, page = 1, pageSize = 50 } = req.query;
    if (!keyword && !sender_id) return res.json({ code: 400, message: '请输入搜索关键词或选择发送者' });
    let where = 'WHERE 1=1'; const params = [];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }
    if (sender_id) { where += ' AND m.sender_id=?'; params.push(sender_id); }
    if (start_date) { where += ' AND m.created_at>=?'; params.push(start_date); }
    if (end_date) { where += ' AND m.created_at<=?'; params.push(end_date); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const msgs = db.prepare(`SELECT m.*, u.nickname as sender_name, u.avatar as sender_avatar, c.type as conversation_type, c.name as conversation_name FROM messages m JOIN conversations c ON m.conversation_id=c.id LEFT JOIN users u ON m.sender_id=u.id ${where} ORDER BY m.created_at DESC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: msgs } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 查看指定用户的所有聊天记录
router.get('/chat-records/user/:userId', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 50, keyword } = req.query;
    const user = db.prepare('SELECT id,nickname,username FROM users WHERE id=?').get(req.params.userId);
    if (!user) return res.json({ code: 404, message: '用户不存在' });
    let where = 'WHERE m.sender_id=?'; const params = [req.params.userId];
    if (keyword) { where += ' AND m.content LIKE ?'; params.push(`%${keyword}%`); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM messages m ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const msgs = db.prepare(`SELECT m.*, c.type as conversation_type, c.name as conversation_name FROM messages m JOIN conversations c ON m.conversation_id=c.id ${where} ORDER BY m.created_at DESC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { user, total, page: Number(page), pageSize: Number(pageSize), list: msgs } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 群组管理 ====================

router.get('/groups', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { keyword, page = 1, pageSize = 50 } = req.query;
    let where = "WHERE c.type IN ('group','notice')"; const params = [];
    if (keyword) { where += ' AND c.name LIKE ?'; params.push(`%${keyword}%`); }
    const groups = db.prepare(`
      SELECT c.id, c.type, c.name, c.avatar, c.created_by, c.created_at,
        (SELECT COUNT(*) FROM conversation_members cm WHERE cm.conversation_id=c.id) as member_count,
        (SELECT COUNT(*) FROM messages m WHERE m.conversation_id=c.id AND m.created_at >= date('now')) as today_messages,
        (SELECT u.nickname FROM users u WHERE u.id=c.created_by) as owner_name,
        COALESCE((SELECT 'disbanded' FROM conversation_members cm2 WHERE cm2.conversation_id=c.id LIMIT 0), 'active') as status
      FROM conversations c ${where} ORDER BY c.created_at DESC
    `).all(...params);
    // 添加额外字段
    groups.forEach(g => {
      g.max_members = 500;
      g.description = '';
    });
    res.json({ code: 200, data: { list: groups } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.post('/groups', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, type, description, max_members } = req.body;
    if (!name) return res.json({ code: 400, message: '群组名称不能为空' });
    const groupId = uuidv4();
    db.prepare('INSERT INTO conversations (id, type, name, created_by) VALUES (?,?,?,?)')
      .run(groupId, type || 'group', name, req.user.id);
    res.json({ code: 200, message: '创建成功', data: { id: groupId } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/groups/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { name, description, max_members, status } = req.body;
    db.prepare('UPDATE conversations SET name=COALESCE(?,name), updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run(name, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/groups/:id', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM messages WHERE conversation_id=?').run(req.params.id);
    db.prepare('DELETE FROM conversation_members WHERE conversation_id=?').run(req.params.id);
    db.prepare('DELETE FROM conversations WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// 群成员管理
router.get('/groups/:id/members', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const members = db.prepare(`
      SELECT cm.id, cm.user_id, u.username, u.nickname, u.avatar,
        CASE WHEN c.created_by = cm.user_id THEN 'owner' ELSE 'member' END as role
      FROM conversation_members cm
      JOIN users u ON cm.user_id = u.id
      JOIN conversations c ON cm.conversation_id = c.id
      WHERE cm.conversation_id = ?
      ORDER BY role DESC, cm.joined_at
    `).all(req.params.id);
    res.json({ code: 200, data: members });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.post('/groups/:id/members', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    const { user_id } = req.body;
    // 支持用户名或ID
    let user = db.prepare('SELECT id FROM users WHERE id=?').get(user_id);
    if (!user) user = db.prepare('SELECT id FROM users WHERE username=?').get(user_id);
    if (!user) return res.json({ code: 404, message: '用户不存在' });
    const existing = db.prepare('SELECT id FROM conversation_members WHERE conversation_id=? AND user_id=?').get(req.params.id, user.id);
    if (existing) return res.json({ code: 409, message: '该用户已在群中' });
    db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
      .run(uuidv4(), req.params.id, user.id);
    res.json({ code: 200, message: '添加成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/groups/:id/members/:userId', verifyToken, requireRole('enterprise_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM conversation_members WHERE conversation_id=? AND user_id=?').run(req.params.id, req.params.userId);
    res.json({ code: 200, message: '移除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

module.exports = router;
