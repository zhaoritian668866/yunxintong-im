const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../models/database');
const { generateToken, verifyToken, requireRole } = require('../middleware/auth');
const { Client } = require('ssh2');
const path = require('path');
const fs = require('fs');

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

// ==================== 公用接口：企业ID解析 ====================

router.post('/resolve', (req, res) => {
  try {
    const { enterprise_id } = req.body;
    if (!enterprise_id) return res.json({ code: 400, message: '请输入企业ID' });
    const eid = enterprise_id.trim().toUpperCase();
    const tenant = db.prepare('SELECT enterprise_id, name, api_url, ws_url, status, deploy_status FROM tenants WHERE enterprise_id = ?').get(eid);
    if (!tenant) return res.json({ code: 404, message: '企业ID不存在，请检查后重试' });
    if (tenant.status !== 'active') return res.json({ code: 403, message: '该企业已被停用' });
    if (tenant.deploy_status !== 'deployed' || !tenant.api_url) {
      return res.json({ code: 503, message: '该企业服务尚未部署完成，请稍后再试' });
    }
    res.json({ code: 200, data: { enterprise_id: tenant.enterprise_id, name: tenant.name, api_url: tenant.api_url, ws_url: tenant.ws_url || '' } });
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
    const eid = enterprise_id.trim().toUpperCase();
    const existing = db.prepare('SELECT id FROM tenants WHERE enterprise_id = ?').get(eid);
    if (existing) return res.json({ code: 409, message: '企业ID已存在' });
    const tenantId = uuidv4();
    db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, max_users) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(tenantId, eid, name, contact_person || '', contact_phone || '', contact_email || '', plan || 'basic', max_users || 100);
    res.json({ code: 200, message: '创建成功', data: { id: tenantId } });
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
    const { name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, api_port, admin_port } = req.body;
    if (!name || !ip_address) return res.json({ code: 400, message: '服务器名称和IP地址不能为空' });
    const serverId = uuidv4();
    db.prepare(`INSERT INTO servers (id, name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, api_port, admin_port, status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`)
      .run(serverId, name, ip_address, ssh_port || 22, ssh_user || 'root', ssh_password || '', ssh_key || '', cpu_cores || 0, memory_gb || 0, disk_gb || 0, api_port || 4001, admin_port || 4002, 'offline');
    res.json({ code: 200, message: '添加成功', data: { id: serverId } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

router.put('/servers/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, status, api_port, admin_port } = req.body;
    db.prepare(`UPDATE servers SET name=COALESCE(?,name), ip_address=COALESCE(?,ip_address), ssh_port=COALESCE(?,ssh_port), ssh_user=COALESCE(?,ssh_user), ssh_password=COALESCE(?,ssh_password), ssh_key=COALESCE(?,ssh_key), cpu_cores=COALESCE(?,cpu_cores), memory_gb=COALESCE(?,memory_gb), disk_gb=COALESCE(?,disk_gb), status=COALESCE(?,status), api_port=COALESCE(?,api_port), admin_port=COALESCE(?,admin_port), updated_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(name, ip_address, ssh_port, ssh_user, ssh_password, ssh_key, cpu_cores, memory_gb, disk_gb, status, api_port, admin_port, req.params.id);
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

// 测试SSH连接
router.post('/servers/:id/test', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const server = db.prepare('SELECT * FROM servers WHERE id = ?').get(req.params.id);
    if (!server) return res.json({ code: 404, message: '服务器不存在' });

    const conn = new Client();
    const connectConfig = {
      host: server.ip_address,
      port: server.ssh_port || 22,
      username: server.ssh_user || 'root',
      readyTimeout: 10000
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    conn.on('ready', () => {
      conn.exec('uname -a && free -h && df -h / | tail -1', (err, stream) => {
        if (err) { conn.end(); return res.json({ code: 500, message: 'SSH命令执行失败: ' + err.message }); }
        let output = '';
        stream.on('data', (data) => { output += data.toString(); });
        stream.on('close', () => {
          conn.end();
          db.prepare("UPDATE servers SET status='online', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);
          res.json({ code: 200, message: 'SSH连接成功', data: { output: output.trim() } });
        });
      });
    });

    conn.on('error', (err) => {
      db.prepare("UPDATE servers SET status='offline', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);
      res.json({ code: 502, message: 'SSH连接失败: ' + err.message });
    });

    conn.connect(connectConfig);
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// ==================== 一键部署（真实SSH） ====================

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

// 获取未部署的租户列表
router.get('/tenants/undeployed', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const tenants = db.prepare("SELECT id, enterprise_id, name FROM tenants WHERE deploy_status != 'deployed'").all();
    res.json({ code: 200, data: tenants });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取可用服务器列表（未分配租户的）
router.get('/servers/available', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const servers = db.prepare("SELECT id, name, ip_address, api_port FROM servers WHERE tenant_id IS NULL").all();
    res.json({ code: 200, data: servers });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 真实SSH部署
router.post('/deploy', verifyToken, requireRole('saas_admin'), async (req, res) => {
  const { tenant_id, server_id } = req.body;
  if (!tenant_id || !server_id) return res.json({ code: 400, message: '请选择租户和服务器' });

  const tenant = db.prepare('SELECT * FROM tenants WHERE id = ?').get(tenant_id);
  const server = db.prepare('SELECT * FROM servers WHERE id = ?').get(server_id);
  if (!tenant || !server) return res.json({ code: 404, message: '租户或服务器不存在' });

  const deployId = uuidv4();
  const apiPort = server.api_port || 4001;
  const logLines = [];

  function log(msg) {
    const line = `[${new Date().toISOString()}] ${msg}`;
    logLines.push(line);
    console.log(`[Deploy] ${msg}`);
  }

  // 创建部署记录
  db.prepare(`INSERT INTO deploy_logs (id, tenant_id, server_id, status, log, started_at) VALUES (?,?,?,?,?,CURRENT_TIMESTAMP)`)
    .run(deployId, tenant_id, server_id, 'deploying', '');

  log('========== 开始一键部署 ==========');
  log(`目标企业: ${tenant.name} (${tenant.enterprise_id})`);
  log(`目标服务器: ${server.name} (${server.ip_address}:${server.ssh_port})`);
  log(`API端口: ${apiPort}`);

  try {
    // 通过SSH连接并执行部署
    const result = await sshDeploy(server, tenant, apiPort, log);

    const apiUrl = `http://${server.ip_address}:${apiPort}/api`;
    const adminUrl = `http://${server.ip_address}:${apiPort}`;
    const wsUrl = `ws://${server.ip_address}:${apiPort}/ws`;

    log('');
    log('========== 部署完成 ==========');
    log(`企业API地址: ${apiUrl}`);
    log(`企业管理后台: ${adminUrl}`);
    log(`企业管理员账号: admin / 123456`);

    // 更新数据库
    db.prepare(`UPDATE deploy_logs SET status='success', log=?, finished_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(logLines.join('\n'), deployId);
    db.prepare('UPDATE tenants SET deploy_status=?, server_id=?, api_url=?, admin_url=?, ws_url=?, status=?, updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run('deployed', server_id, apiUrl, adminUrl, wsUrl, 'active', tenant_id);
    db.prepare("UPDATE servers SET status='online', tenant_id=?, updated_at=CURRENT_TIMESTAMP WHERE id=?")
      .run(tenant_id, server_id);

    res.json({ code: 200, message: '部署成功', data: { deploy_id: deployId, api_url: apiUrl, admin_url: adminUrl, ws_url: wsUrl, log: logLines } });
  } catch (err) {
    log(`❌ 部署失败: ${err.message}`);
    db.prepare(`UPDATE deploy_logs SET status='failed', log=?, finished_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(logLines.join('\n'), deployId);
    res.json({ code: 500, message: '部署失败: ' + err.message, data: { deploy_id: deployId, log: logLines } });
  }
});

// SSH部署核心逻辑
function sshDeploy(server, tenant, apiPort, log) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const connectConfig = {
      host: server.ip_address,
      port: server.ssh_port || 22,
      username: server.ssh_user || 'root',
      readyTimeout: 30000
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    conn.on('ready', () => {
      log('[1/6] ✓ SSH连接成功');

      const deployDir = `/opt/yunxintong/${tenant.enterprise_id}`;
      const deployPackageDir = path.join(__dirname, '..', 'deploy-package');

      // 读取deploy-package中所有文件
      const filesToUpload = getAllFiles(deployPackageDir, deployPackageDir);

      log('[2/6] 上传企业服务程序...');

      // 使用SFTP上传文件
      conn.sftp((err, sftp) => {
        if (err) { conn.end(); return reject(new Error('SFTP连接失败: ' + err.message)); }

        // 先创建目录结构，然后上传文件
        const mkdirAndUpload = async () => {
          try {
            // 创建基础目录
            await sshExec(conn, `mkdir -p ${deployDir}/data ${deployDir}/routes ${deployDir}/middleware ${deployDir}/models`);

            // 上传每个文件
            for (const file of filesToUpload) {
              if (file.relativePath.includes('node_modules/')) continue;
              const remotePath = `${deployDir}/${file.relativePath}`;
              const remoteDir = path.dirname(remotePath);
              await sshExec(conn, `mkdir -p ${remoteDir}`);
              await sftpUpload(sftp, file.localPath, remotePath);
              log(`  上传: ${file.relativePath}`);
            }
            log('[2/6] ✓ 文件上传完成');

            // 创建环境配置
            log('[3/6] 配置环境...');
            const envContent = `ENTERPRISE_ID=${tenant.enterprise_id}\nPORT=${apiPort}\nJWT_SECRET=yunxintong_${tenant.enterprise_id}_${Date.now()}\n`;
            await sshExec(conn, `echo '${envContent}' > ${deployDir}/.env`);
            log('[3/6] ✓ 环境配置完成');

            // 安装依赖
            log('[4/6] 安装Node.js依赖...');
            const installResult = await sshExec(conn, `cd ${deployDir} && npm install --production 2>&1 | tail -5`);
            log(`  ${installResult.trim()}`);
            log('[4/6] ✓ 依赖安装完成');

            // 使用pm2启动服务
            log('[5/6] 启动服务...');
            const pmName = `yxt-${tenant.enterprise_id}`;
            await sshExec(conn, `pm2 delete ${pmName} 2>/dev/null; cd ${deployDir} && PORT=${apiPort} ENTERPRISE_ID=${tenant.enterprise_id} pm2 start index.js --name ${pmName}`);
            await sshExec(conn, 'pm2 save 2>/dev/null');
            log('[5/6] ✓ 服务启动成功');

            // 验证服务
            log('[6/6] 验证服务...');
            // 等待2秒让服务启动
            await new Promise(r => setTimeout(r, 2000));
            const healthCheck = await sshExec(conn, `curl -s http://localhost:${apiPort}/api/health || echo "HEALTH_CHECK_FAILED"`);
            if (healthCheck.includes('HEALTH_CHECK_FAILED')) {
              log('[6/6] ⚠ 健康检查未通过，服务可能还在启动中');
            } else {
              log('[6/6] ✓ 服务健康检查通过');
            }

            conn.end();
            resolve();
          } catch (e) {
            conn.end();
            reject(e);
          }
        };

        mkdirAndUpload();
      });
    });

    conn.on('error', (err) => {
      log(`❌ SSH连接失败: ${err.message}`);
      reject(new Error('SSH连接失败: ' + err.message));
    });

    conn.connect(connectConfig);
  });
}

// 辅助函数：SSH执行命令
function sshExec(conn, command) {
  return new Promise((resolve, reject) => {
    conn.exec(command, (err, stream) => {
      if (err) return reject(err);
      let output = '';
      let errOutput = '';
      stream.on('data', (data) => { output += data.toString(); });
      stream.stderr.on('data', (data) => { errOutput += data.toString(); });
      stream.on('close', (code) => {
        if (code !== 0 && code !== null) {
          // 非零退出码不一定是错误（比如pm2 delete不存在的进程）
          resolve(output || errOutput);
        } else {
          resolve(output);
        }
      });
    });
  });
}

// 辅助函数：SFTP上传文件
function sftpUpload(sftp, localPath, remotePath) {
  return new Promise((resolve, reject) => {
    const readStream = fs.createReadStream(localPath);
    const writeStream = sftp.createWriteStream(remotePath);
    writeStream.on('close', () => resolve());
    writeStream.on('error', (err) => reject(new Error(`上传失败 ${remotePath}: ${err.message}`)));
    readStream.pipe(writeStream);
  });
}

// 辅助函数：递归获取目录下所有文件
function getAllFiles(dir, baseDir) {
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(baseDir, fullPath);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === 'data' || entry.name === '.git') continue;
      results.push(...getAllFiles(fullPath, baseDir));
    } else {
      results.push({ localPath: fullPath, relativePath });
    }
  }
  return results;
}

// ==================== 订单管理 ====================

router.get('/orders', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { page = 1, pageSize = 20, status, keyword } = req.query;
    let where = 'WHERE 1=1'; const params = [];
    if (status) { where += ' AND status=?'; params.push(status); }
    if (keyword) { where += ' AND (order_no LIKE ? OR enterprise_name LIKE ? OR enterprise_id LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
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
    db.prepare('INSERT INTO orders (id, order_no, enterprise_id, enterprise_name, plan, period, amount, status, remark) VALUES (?,?,?,?,?,?,?,?,?)')
      .run(orderId, orderNo, enterprise_id, tenant ? tenant.name : enterprise_id, plan || 'basic', period || 'monthly', amount || 0, 'pending', remark || '');
    res.json({ code: 200, message: '订单创建成功', data: { id: orderId, order_no: orderNo } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/orders/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { status, remark } = req.body;
    const updates = [];
    const params = [];
    if (status) { updates.push('status=?'); params.push(status); }
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
    const settings = db.prepare('SELECT * FROM saas_settings LIMIT 1').get();
    const admins = db.prepare('SELECT id, username, nickname, role, status, created_at FROM saas_admins ORDER BY created_at').all();
    res.json({ code: 200, data: { ...settings, admins } });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误: ' + err.message }); }
});

router.put('/settings', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { platform_name, support_email, support_phone, default_max_users, default_max_groups, default_max_file_size } = req.body;
    db.prepare(`UPDATE saas_settings SET platform_name=COALESCE(?,platform_name), support_email=COALESCE(?,support_email), support_phone=COALESCE(?,support_phone), default_max_users=COALESCE(?,default_max_users), default_max_groups=COALESCE(?,default_max_groups), default_max_file_size=COALESCE(?,default_max_file_size), updated_at=CURRENT_TIMESTAMP`)
      .run(platform_name, support_email, support_phone, default_max_users, default_max_groups, default_max_file_size);
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
