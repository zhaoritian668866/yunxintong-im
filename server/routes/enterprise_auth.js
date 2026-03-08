const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken } = require('../middleware/auth');

// ==================== 用户注册 ====================

router.post('/register', (req, res) => {
  try {
    const { username, password, nickname, phone } = req.body;
    if (!username || !password) {
      return res.json({ code: 400, message: '用户名和密码不能为空' });
    }

    // 默认注册到ENT001（演示环境）
    const tenant = db.prepare("SELECT id FROM tenants WHERE enterprise_id = 'ENT001'").get();
    if (!tenant) return res.json({ code: 500, message: '企业不存在' });

    // 检查用户名是否已存在
    const existing = db.prepare('SELECT id FROM users WHERE username = ? AND tenant_id = ?').get(username, tenant.id);
    if (existing) return res.json({ code: 409, message: '用户名已存在' });

    const hashedPwd = bcrypt.hashSync(password, 10);
    const userId = uuidv4();
    db.prepare(`INSERT INTO users (id, tenant_id, username, password, nickname, phone, status, online_status)
      VALUES (?, ?, ?, ?, ?, ?, 'active', 'offline')`)
      .run(userId, tenant.id, username, hashedPwd, nickname || username, phone || '');

    const token = generateToken({ id: userId, tenant_id: tenant.id, username, role: 'user' });

    res.json({
      code: 200, message: '注册成功',
      data: {
        token,
        user: { id: userId, username, nickname: nickname || username }
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 用户登录 ====================

router.post('/login', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.json({ code: 400, message: '用户名和密码不能为空' });
    }

    // 查找用户（在所有企业中查找，或指定企业）
    const tenant = db.prepare("SELECT id FROM tenants WHERE enterprise_id = 'ENT001'").get();
    if (!tenant) return res.json({ code: 500, message: '企业不存在' });

    const user = db.prepare('SELECT * FROM users WHERE username = ? AND tenant_id = ?').get(username, tenant.id);
    if (!user) return res.json({ code: 401, message: '用户名或密码错误' });
    if (!bcrypt.compareSync(password, user.password)) {
      return res.json({ code: 401, message: '用户名或密码错误' });
    }
    if (user.status !== 'active') return res.json({ code: 403, message: '账号已被禁用' });

    // 更新在线状态
    db.prepare("UPDATE users SET online_status = 'online', last_login_at = ? WHERE id = ?")
      .run(new Date().toISOString(), user.id);

    const token = generateToken({ id: user.id, tenant_id: tenant.id, username: user.username, role: 'user' });

    res.json({
      code: 200, message: '登录成功',
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          nickname: user.nickname,
          avatar: user.avatar,
          phone: user.phone,
          email: user.email,
          position: user.position,
          department_id: user.department_id
        }
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 获取用户资料 ====================

router.get('/profile', verifyToken, (req, res) => {
  try {
    const user = db.prepare(`
      SELECT u.id, u.username, u.nickname, u.avatar, u.phone, u.email, u.position, u.online_status, u.department_id, d.name as department_name
      FROM users u LEFT JOIN departments d ON u.department_id = d.id
      WHERE u.id = ?
    `).get(req.user.id);
    if (!user) return res.json({ code: 404, message: '用户不存在' });
    res.json({ code: 200, data: user });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 更新用户资料 ====================

router.put('/profile', verifyToken, (req, res) => {
  try {
    const { nickname, avatar, phone, email, position } = req.body;
    db.prepare(`UPDATE users SET
      nickname = COALESCE(?, nickname),
      avatar = COALESCE(?, avatar),
      phone = COALESCE(?, phone),
      email = COALESCE(?, email),
      position = COALESCE(?, position)
      WHERE id = ?`)
      .run(nickname, avatar, phone, email, position, req.user.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

module.exports = router;
