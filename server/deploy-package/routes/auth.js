const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken } = require('../middleware/auth');

// 用户注册
router.post('/register', (req, res) => {
  try {
    const { username, password, nickname, phone } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
    if (existing) return res.json({ code: 409, message: '该用户名已被注册' });

    const settings = db.prepare('SELECT require_approval FROM settings LIMIT 1').get();
    const status = settings && settings.require_approval ? 'pending' : 'active';
    const userId = uuidv4();
    const hashedPwd = bcrypt.hashSync(password, 10);
    db.prepare('INSERT INTO users (id, username, password, nickname, phone, status) VALUES (?,?,?,?,?,?)')
      .run(userId, username, hashedPwd, nickname || username, phone || '', status);

    if (status === 'pending') return res.json({ code: 200, message: '注册成功，等待管理员审批', data: { status: 'pending' } });

    const token = generateToken({ id: userId, username, role: 'user' });
    res.json({ code: 200, message: '注册成功', data: { token, user: { id: userId, username, nickname: nickname || username, status } } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 用户登录
router.post('/login', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!user || !bcrypt.compareSync(password, user.password)) {
      return res.json({ code: 401, message: '用户名或密码错误' });
    }
    if (user.status === 'pending') return res.json({ code: 403, message: '账号正在审批中' });
    if (user.status !== 'active') return res.json({ code: 403, message: '账号已被禁用' });

    db.prepare("UPDATE users SET online_status='online', last_login_at=CURRENT_TIMESTAMP WHERE id=?").run(user.id);
    const token = generateToken({ id: user.id, username: user.username, role: 'user' });
    const settings = db.prepare('SELECT enterprise_name FROM settings LIMIT 1').get();
    res.json({ code: 200, message: '登录成功', data: {
      token,
      user: { id: user.id, username: user.username, nickname: user.nickname, avatar: user.avatar, phone: user.phone, email: user.email, position: user.position, department_id: user.department_id },
      enterprise_name: settings ? settings.enterprise_name : ''
    }});
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取/修改个人信息
router.get('/profile', verifyToken, (req, res) => {
  try {
    const user = db.prepare('SELECT u.*, d.name as department_name FROM users u LEFT JOIN departments d ON u.department_id=d.id WHERE u.id=?').get(req.user.id);
    if (!user) return res.json({ code: 404, message: '用户不存在' });
    delete user.password;
    res.json({ code: 200, data: user });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/profile', verifyToken, (req, res) => {
  try {
    const { nickname, avatar, phone, email } = req.body;
    db.prepare('UPDATE users SET nickname=COALESCE(?,nickname), avatar=COALESCE(?,avatar), phone=COALESCE(?,phone), email=COALESCE(?,email), updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run(nickname, avatar, phone, email, req.user.id);
    res.json({ code: 200, message: '修改成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 修改密码
router.put('/password', verifyToken, (req, res) => {
  try {
    const { old_password, new_password } = req.body;
    if (!old_password || !new_password) return res.json({ code: 400, message: '请输入当前密码和新密码' });
    if (new_password.length < 6) return res.json({ code: 400, message: '新密码长度不能少于6位' });
    const user = db.prepare('SELECT password FROM users WHERE id=?').get(req.user.id);
    if (!user || !bcrypt.compareSync(old_password, user.password)) {
      return res.json({ code: 401, message: '当前密码错误' });
    }
    const hashedPwd = bcrypt.hashSync(new_password, 10);
    db.prepare('UPDATE users SET password=?, updated_at=CURRENT_TIMESTAMP WHERE id=?').run(hashedPwd, req.user.id);
    res.json({ code: 200, message: '密码修改成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

module.exports = router;
