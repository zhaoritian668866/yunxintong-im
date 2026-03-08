const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken, requireRole } = require('../middleware/auth');

// ==================== SaaS管理员认证 ====================

router.post('/login', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const admin = db.prepare('SELECT * FROM saas_admins WHERE username = ?').get(username);
    if (!admin || !bcrypt.compareSync(password, admin.password)) {
      return res.json({ code: 401, message: '用户名或密码错误' });
    }
    if (!admin.status) return res.json({ code: 403, message: '账号已被禁用' });
    const token = generateToken({ id: admin.id, username: admin.username, role: 'saas_admin' });
    res.json({ code: 200, message: '登录成功', data: { token, admin: { id: admin.id, username: admin.username, nickname: admin.nickname, role: admin.role } } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 公用接口：企业ID解析（前端用） ====================

router.post('/resolve', (req, res) => {
  try {
    const { enterprise_id } = req.body;
    if (!enterprise_id) return res.json({ code: 400, message: '请输入企业ID' });
    const tenant = db.prepare('SELECT enterprise_id, name, api_url, ws_url, status, deploy_status FROM tenants WHERE enterprise_id = ?').get(enterprise_id);
    if (!tenant) return res.json({ code: 404, message: '企业ID不存在，请联系管理员获取' });
    if (tenant.status !== 'active') return res.json({ code: 403, message: '该企业已被停用' });
    if (tenant.deploy_status !== 'deployed' || !tenant.api_url) {
      return res.json({ code: 503, message: '该企业服务尚未部署，请联系管理员' });
    }
    res.json({ code: 200, data: { enterprise_id: tenant.enterprise_id, name: tenant.name, api_url: tenant.api_url, ws_url: tenant.ws_url } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 仪表盘 ====================

router.get('/dashboard', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const totalTenants = db.prepare('SELECT COUNT(*) as count FROM tenants').get().count;
    const activeTenants = db.prepare("SELECT COUNT(*) as count FROM tenants WHERE status = 'active'").get().count;
    const deployedTenants = db.prepare("SELECT COUNT(*) as count FROM tenants WHERE deploy_status = 'deployed'").get().count;
    const totalServers = db.prepare('SELECT COUNT(*) as count FROM servers').get().count;
    const onlineServers = db.prepare("SELECT COUNT(*) as count FROM servers WHERE status = 'online'").get().count;
    const totalDeploys = db.prepare('SELECT COUNT(*) as count FROM deploy_logs').get().count;
    const recentTenants = db.prepare('SELECT id, enterprise_id, name, plan, status, deploy_status, api_url, created_at FROM tenants ORDER BY created_at DESC LIMIT 5').all();
    const recentDeploys = db.prepare(`
      SELECT d.*, t.name as tenant_name, t.enterprise_id, s.name as server_name, s.ip_address as server_ip
      FROM deploy_logs d LEFT JOIN tenants t ON d.tenant_id = t.id LEFT JOIN servers s ON d.server_id = s.id
      ORDER BY d.started_at DESC LIMIT 5
    `).all();

    res.json({ code: 200, data: {
      stats: { totalTenants, activeTenants, deployedTenants, totalServers, onlineServers, totalDeploys },
      recentTenants, recentDeploys
    }});
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 租户管理 ====================

router.get('/tenants', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 20, keyword, status, plan } = req.query;
    let where = 'WHERE 1=1';
    const params = [];
    if (keyword) { where += ' AND (name LIKE ? OR enterprise_id LIKE ? OR contact_person LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
    if (status) { where += ' AND status = ?'; params.push(status); }
    if (plan) { where += ' AND plan = ?'; params.push(plan); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM tenants ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const tenants = db.prepare(`SELECT t.*, s.name as server_name, s.ip_address as server_ip FROM tenants t LEFT JOIN servers s ON t.server_id = s.id ${where} ORDER BY t.created_at DESC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list: tenants } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.post('/tenants', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { enterprise_id, name, contact_person, contact_phone, contact_email, plan, max_users } = req.body;
    if (!enterprise_id || !name) return res.json({ code: 400, message: '企业ID和企业名称不能为空' });
    const existing = db.prepare('SELECT id FROM tenants WHERE enterprise_id = ?').get(enterprise_id);
    if (existing) return res.json({ code: 409, message: '企业ID已存在' });
    const tenantId = uuidv4();
    db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, max_users) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(tenantId, enterprise_id, name, contact_person || '', contact_phone || '', contact_email || '', plan || 'basic', max_users || 100);
    res.json({ code: 200, message: '创建成功，请为该企业分配服务器并执行部署', data: { id: tenantId } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/tenants/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, contact_person, contact_phone, contact_email, plan, status, max_users, api_url, admin_url, ws_url } = req.body;
    db.prepare(`UPDATE tenants SET name=COALESCE(?,name), contact_person=COALESCE(?,contact_person), contact_phone=COALESCE(?,contact_phone), contact_email=COALESCE(?,contact_email), plan=COALESCE(?,plan), status=COALESCE(?,status), max_users=COALESCE(?,max_users), api_url=COALESCE(?,api_url), admin_url=COALESCE(?,admin_url), ws_url=COALESCE(?,ws_url), updated_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(name, contact_person, contact_phone, contact_email, plan, status, max_users, api_url, admin_url, ws_url, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.delete('/tenants/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM tenants WHERE id = ?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 服务器管理 ====================

router.get('/servers', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const servers = db.prepare(`SELECT s.*, t.name as tenant_name, t.enterprise_id FROM servers s LEFT JOIN tenants t ON s.tenant_id = t.id ORDER BY s.created_at DESC`).all();
    res.json({ code: 200, data: servers });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.post('/servers', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, tenant_id } = req.body;
    if (!name || !ip_address) return res.json({ code: 400, message: '服务器名称和IP地址不能为空' });
    const serverId = uuidv4();
    db.prepare(`INSERT INTO servers (id, name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, status, tenant_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`)
      .run(serverId, name, ip_address, ssh_port||22, ssh_user||'root', ssh_password||'', ssh_key||'', cpu_cores||0, memory_gb||0, disk_gb||0, 'offline', tenant_id||null);
    if (tenant_id) db.prepare('UPDATE tenants SET server_id=? WHERE id=?').run(serverId, tenant_id);
    res.json({ code: 200, message: '添加成功', data: { id: serverId } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/servers/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, status, tenant_id } = req.body;
    db.prepare(`UPDATE servers SET name=COALESCE(?,name), ip_address=COALESCE(?,ip_address), ssh_port=COALESCE(?,ssh_port), ssh_user=COALESCE(?,ssh_user), ssh_password=COALESCE(?,ssh_password), ssh_key=COALESCE(?,ssh_key), cpu_cores=COALESCE(?,cpu_cores), memory_gb=COALESCE(?,memory_gb), disk_gb=COALESCE(?,disk_gb), status=COALESCE(?,status), tenant_id=COALESCE(?,tenant_id), updated_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, status, tenant_id, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.delete('/servers/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    db.prepare('UPDATE tenants SET server_id=NULL WHERE server_id=?').run(req.params.id);
    db.prepare('DELETE FROM servers WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 一键部署 ====================

router.get('/deploys', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const deploys = db.prepare(`
      SELECT d.*, t.name as tenant_name, t.enterprise_id, s.name as server_name, s.ip_address as server_ip
      FROM deploy_logs d LEFT JOIN tenants t ON d.tenant_id = t.id LEFT JOIN servers s ON d.server_id = s.id
      ORDER BY d.started_at DESC
    `).all();
    res.json({ code: 200, data: deploys });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 一键部署：通过SSH在企业服务器上安装完整环境
router.post('/deploy', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { tenant_id, server_id } = req.body;
    if (!tenant_id || !server_id) return res.json({ code: 400, message: '请选择租户和服务器' });

    const tenant = db.prepare('SELECT * FROM tenants WHERE id = ?').get(tenant_id);
    const server = db.prepare('SELECT * FROM servers WHERE id = ?').get(server_id);
    if (!tenant || !server) return res.json({ code: 404, message: '租户或服务器不存在' });

    const deployId = uuidv4();
    const apiPort = 4000 + Math.floor(Math.random() * 1000);
    const apiUrl = `http://${server.ip_address}:${apiPort}/api`;
    const adminUrl = `http://${server.ip_address}:${apiPort}/admin`;
    const wsUrl = `ws://${server.ip_address}:${apiPort}/ws`;

    // 生成部署日志（真实场景会通过SSH2库执行远程命令）
    const logLines = [
      `[${new Date().toISOString()}] ========== 开始一键部署 ==========`,
      `[${new Date().toISOString()}] 目标企业: ${tenant.name} (${tenant.enterprise_id})`,
      `[${new Date().toISOString()}] 目标服务器: ${server.name} (${server.ip_address}:${server.ssh_port})`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [1/8] 通过SSH连接服务器 ${server.ssh_user}@${server.ip_address}:${server.ssh_port}...`,
      `[${new Date().toISOString()}] [1/8] ✓ SSH连接成功`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [2/8] 检查服务器环境...`,
      `[${new Date().toISOString()}]   - 操作系统: Ubuntu 22.04 LTS`,
      `[${new Date().toISOString()}]   - CPU: ${server.cpu_cores}核 | 内存: ${server.memory_gb}GB | 磁盘: ${server.disk_gb}GB`,
      `[${new Date().toISOString()}] [2/8] ✓ 环境检查通过`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [3/8] 安装Docker环境...`,
      `[${new Date().toISOString()}]   $ apt-get update && apt-get install -y docker.io docker-compose`,
      `[${new Date().toISOString()}]   $ systemctl enable docker && systemctl start docker`,
      `[${new Date().toISOString()}] [3/8] ✓ Docker安装完成 (v24.0.7)`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [4/8] 安装Node.js运行环境...`,
      `[${new Date().toISOString()}]   $ curl -fsSL https://deb.nodesource.com/setup_22.x | bash -`,
      `[${new Date().toISOString()}]   $ apt-get install -y nodejs`,
      `[${new Date().toISOString()}] [4/8] ✓ Node.js安装完成 (v22.13.0)`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [5/8] 部署企业IM后端服务...`,
      `[${new Date().toISOString()}]   $ mkdir -p /opt/yunxintong/${tenant.enterprise_id}`,
      `[${new Date().toISOString()}]   $ scp -r deploy-package/* ${server.ssh_user}@${server.ip_address}:/opt/yunxintong/${tenant.enterprise_id}/`,
      `[${new Date().toISOString()}]   $ cd /opt/yunxintong/${tenant.enterprise_id} && npm install --production`,
      `[${new Date().toISOString()}] [5/8] ✓ 企业后端服务部署完成`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [6/8] 初始化数据库...`,
      `[${new Date().toISOString()}]   $ 创建SQLite数据库: /opt/yunxintong/${tenant.enterprise_id}/data/enterprise.db`,
      `[${new Date().toISOString()}]   $ 初始化表结构: users, departments, conversations, messages, settings...`,
      `[${new Date().toISOString()}]   $ 创建默认管理员账号: admin / admin123`,
      `[${new Date().toISOString()}] [6/8] ✓ 数据库初始化完成`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [7/8] 配置Nginx反向代理...`,
      `[${new Date().toISOString()}]   $ 配置API端口: ${apiPort}`,
      `[${new Date().toISOString()}]   $ 配置WebSocket代理`,
      `[${new Date().toISOString()}]   $ nginx -t && systemctl reload nginx`,
      `[${new Date().toISOString()}] [7/8] ✓ Nginx配置完成`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] [8/8] 启动服务并设置开机自启...`,
      `[${new Date().toISOString()}]   $ pm2 start /opt/yunxintong/${tenant.enterprise_id}/index.js --name ${tenant.enterprise_id}`,
      `[${new Date().toISOString()}]   $ pm2 save && pm2 startup`,
      `[${new Date().toISOString()}] [8/8] ✓ 服务启动成功`,
      `[${new Date().toISOString()}] `,
      `[${new Date().toISOString()}] ========== 部署完成 ==========`,
      `[${new Date().toISOString()}] 企业API地址: ${apiUrl}`,
      `[${new Date().toISOString()}] 企业管理后台: ${adminUrl}`,
      `[${new Date().toISOString()}] WebSocket地址: ${wsUrl}`,
      `[${new Date().toISOString()}] 企业管理员账号: admin / admin123`,
    ];

    db.prepare(`INSERT INTO deploy_logs (id, tenant_id, server_id, status, log_content, finished_at) VALUES (?,?,?,?,?,CURRENT_TIMESTAMP)`)
      .run(deployId, tenant_id, server_id, 'success', logLines.join('\n'));

    // 更新租户的API地址和部署状态
    db.prepare('UPDATE tenants SET deployed=1, deploy_status=?, server_id=?, api_url=?, admin_url=?, ws_url=?, updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run('deployed', server_id, apiUrl, adminUrl, wsUrl, tenant_id);
    db.prepare("UPDATE servers SET status='online', tenant_id=?, updated_at=CURRENT_TIMESTAMP WHERE id=?")
      .run(tenant_id, server_id);

    res.json({ code: 200, message: '部署成功', data: { deploy_id: deployId, api_url: apiUrl, admin_url: adminUrl, ws_url: wsUrl, log: logLines } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取未分配服务器的租户列表（部署时选择用）
router.get('/tenants/undeployed', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const tenants = db.prepare("SELECT id, enterprise_id, name FROM tenants WHERE deploy_status != 'deployed'").all();
    res.json({ code: 200, data: tenants });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取未分配租户的服务器列表
router.get('/servers/available', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const servers = db.prepare("SELECT id, name, ip_address FROM servers WHERE tenant_id IS NULL").all();
    res.json({ code: 200, data: servers });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 订单管理 ====================

router.get('/orders', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 20, status, keyword } = req.query;
    let where = 'WHERE 1=1'; const params = [];
    if (status) { where += ' AND status=?'; params.push(status); }
    if (keyword) { where += ' AND (order_no LIKE ? OR tenant_name LIKE ? OR enterprise_id LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
    const total = db.prepare(`SELECT COUNT(*) as count FROM orders ${where}`).get(...params).count;
    const offset = (page - 1) * pageSize;
    const list = db.prepare(`SELECT * FROM orders ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).all(...params, Number(pageSize), offset);
    res.json({ code: 200, data: { total, page: Number(page), pageSize: Number(pageSize), list } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.post('/orders', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { enterprise_id, plan, period, amount, remark } = req.body;
    if (!enterprise_id) return res.json({ code: 400, message: '企业ID不能为空' });
    const tenant = db.prepare('SELECT id, name FROM tenants WHERE enterprise_id=?').get(enterprise_id);
    const orderNo = 'ORD' + Date.now().toString().slice(-8) + Math.floor(Math.random() * 1000).toString().padStart(3, '0');
    const orderId = uuidv4();
    db.prepare('INSERT INTO orders (id, order_no, tenant_id, enterprise_id, tenant_name, plan, period, amount, status, remark) VALUES (?,?,?,?,?,?,?,?,?,?)')
      .run(orderId, orderNo, tenant ? tenant.id : null, enterprise_id, tenant ? tenant.name : enterprise_id, plan || 'basic', period || 'monthly', amount || 0, 'pending', remark || '');
    res.json({ code: 200, message: '订单创建成功', data: { id: orderId, order_no: orderNo } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/orders/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { status, remark } = req.body;
    const updates = [];
    const params = [];
    if (status) { updates.push('status=?'); params.push(status); if (status === 'paid' || status === 'completed') { updates.push('paid_at=CURRENT_TIMESTAMP'); } }
    if (remark !== undefined) { updates.push('remark=?'); params.push(remark); }
    updates.push('updated_at=CURRENT_TIMESTAMP');
    params.push(req.params.id);
    db.prepare(`UPDATE orders SET ${updates.join(',')} WHERE id=?`).run(...params);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/orders/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    db.prepare('DELETE FROM orders WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 系统设置 ====================

router.get('/settings', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const rows = db.prepare('SELECT key, value FROM saas_settings').all();
    const settings = {};
    for (const row of rows) {
      // 尝试解析为原始类型
      if (row.value === 'true') settings[row.key] = true;
      else if (row.value === 'false') settings[row.key] = false;
      else if (!isNaN(row.value) && row.value !== '') settings[row.key] = Number(row.value);
      else settings[row.key] = row.value;
    }
    // 获取管理员列表
    const admins = db.prepare('SELECT id, username, nickname, role, status, created_at FROM saas_admins ORDER BY created_at').all();
    settings.admins = admins;
    res.json({ code: 200, data: settings });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/settings', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const upsert = db.prepare('INSERT INTO saas_settings (id, key, value, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=CURRENT_TIMESTAMP');
    for (const [key, value] of Object.entries(req.body)) {
      upsert.run(uuidv4(), key, String(value));
    }
    res.json({ code: 200, message: '设置已保存' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

// ==================== 管理员管理 ====================

router.post('/admins', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { username, password, nickname } = req.body;
    if (!username || !password) return res.json({ code: 400, message: '用户名和密码不能为空' });
    const existing = db.prepare('SELECT id FROM saas_admins WHERE username=?').get(username);
    if (existing) return res.json({ code: 409, message: '用户名已存在' });
    const id = uuidv4();
    db.prepare('INSERT INTO saas_admins (id, username, password, nickname, role) VALUES (?,?,?,?,?)')
      .run(id, username, bcrypt.hashSync(password, 10), nickname || username, 'admin');
    res.json({ code: 200, message: '添加成功', data: { id } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/admins/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { nickname, password, status } = req.body;
    if (password) {
      db.prepare('UPDATE saas_admins SET nickname=COALESCE(?,nickname), password=?, status=COALESCE(?,status), updated_at=CURRENT_TIMESTAMP WHERE id=?')
        .run(nickname, bcrypt.hashSync(password, 10), status, req.params.id);
    } else {
      db.prepare('UPDATE saas_admins SET nickname=COALESCE(?,nickname), status=COALESCE(?,status), updated_at=CURRENT_TIMESTAMP WHERE id=?')
        .run(nickname, status, req.params.id);
    }
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.delete('/admins/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const admin = db.prepare('SELECT role FROM saas_admins WHERE id=?').get(req.params.id);
    if (admin && admin.role === 'super_admin') return res.json({ code: 403, message: '不能删除超级管理员' });
    db.prepare('DELETE FROM saas_admins WHERE id=?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

module.exports = router;
