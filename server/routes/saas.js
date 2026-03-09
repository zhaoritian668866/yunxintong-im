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
    db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, max_users, status, deploy_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending')`)
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
    // 先解绑服务器
    const tenant = db.prepare('SELECT server_id FROM tenants WHERE id = ?').get(req.params.id);
    if (tenant && tenant.server_id) {
      db.prepare('UPDATE servers SET tenant_id=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?').run(tenant.server_id);
    }
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
      readyTimeout: 15000,
      keepaliveInterval: 5000
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    let responded = false;
    conn.on('ready', () => {
      conn.exec('uname -a && free -h && df -h / | tail -1', (err, stream) => {
        if (err) { conn.end(); if (!responded) { responded = true; return res.json({ code: 500, message: 'SSH命令执行失败: ' + err.message }); } return; }
        let output = '';
        stream.on('data', (data) => { output += data.toString(); });
        stream.on('close', () => {
          conn.end();
          db.prepare("UPDATE servers SET status='online', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);
          if (!responded) { responded = true; res.json({ code: 200, message: 'SSH连接成功', data: { output: output.trim() } }); }
        });
      });
    });

    conn.on('error', (err) => {
      db.prepare("UPDATE servers SET status='offline', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);
      if (!responded) { responded = true; res.json({ code: 502, message: 'SSH连接失败: ' + err.message }); }
    });

    // 超时保护
    setTimeout(() => {
      if (!responded) {
        responded = true;
        try { conn.end(); } catch(e) {}
        res.json({ code: 504, message: 'SSH连接超时，请检查服务器IP、端口和防火墙设置' });
      }
    }, 20000);

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

// 获取待部署的租户列表（包括pending和failed状态，以及需要重新部署的）
router.get('/tenants/undeployed', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const tenants = db.prepare("SELECT id, enterprise_id, name, plan, max_users, deploy_status FROM tenants WHERE deploy_status != 'deployed' OR deploy_status IS NULL").all();
    res.json({ code: 200, data: tenants });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取所有服务器列表（部署时选择用）
router.get('/servers/available', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const servers = db.prepare("SELECT id, name, ip_address, api_port, ssh_port, status, tenant_id FROM servers ORDER BY tenant_id IS NOT NULL, created_at DESC").all();
    // 标注每台服务器的分配状态
    const result = servers.map(s => {
      let assignedTenant = null;
      if (s.tenant_id) {
        const t = db.prepare('SELECT enterprise_id, name FROM tenants WHERE id = ?').get(s.tenant_id);
        if (t) assignedTenant = `${t.name} (${t.enterprise_id})`;
      }
      return {
        id: s.id,
        name: s.name,
        ip_address: s.ip_address,
        api_port: s.api_port || 4001,
        ssh_port: s.ssh_port || 22,
        status: s.status,
        assigned_tenant: assignedTenant,
        is_available: !s.tenant_id
      };
    });
    res.json({ code: 200, data: result });
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

  // 更新租户状态为部署中
  db.prepare("UPDATE tenants SET deploy_status='deploying', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(tenant_id);

  // 解析部署包版本
  let packageDirName = 'deploy-package'; // 默认标准版
  let packageName = '标准版';
  if (tenant.package_id) {
    const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(tenant.package_id);
    if (pkg) {
      packageDirName = pkg.dir_name;
      packageName = `${pkg.name} v${pkg.version}`;
    }
  } else {
    // 未绑定部署包，自动绑定默认标准版
    const defaultPkg = db.prepare('SELECT id FROM deploy_packages WHERE is_default = 1').get();
    if (defaultPkg) {
      db.prepare('UPDATE tenants SET package_id = ? WHERE id = ?').run(defaultPkg.id, tenant_id);
      tenant.package_id = defaultPkg.id;
    }
  }

  log('========== 开始一键部署 ==========');
  log(`目标企业: ${tenant.name} (${tenant.enterprise_id})`);
  log(`部署包: ${packageName}`);
  log(`目标服务器: ${server.name} (${server.ip_address}:${server.ssh_port || 22})`);
  log(`API端口: ${apiPort}`);

  try {
    // 通过SSH连接并执行部署
    await sshDeploy(server, tenant, apiPort, log, packageDirName);

    const apiUrl = `http://${server.ip_address}:${apiPort}/api`;
    const adminUrl = `http://${server.ip_address}:${apiPort}`;
    const wsUrl = `ws://${server.ip_address}:${apiPort}/ws`;

    log('');
    log('========== 部署完成 ==========');
    log(`企业API地址: ${apiUrl}`);
    log(`企业管理后台: ${adminUrl}`);
    log(`企业管理员账号: admin / 123456`);

    // 更新数据库 - 先解绑旧服务器的租户
    const oldServer = db.prepare('SELECT id FROM servers WHERE tenant_id = ?').get(tenant_id);
    if (oldServer && oldServer.id !== server_id) {
      db.prepare("UPDATE servers SET tenant_id=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?").run(oldServer.id);
    }

    db.prepare(`UPDATE deploy_logs SET status='success', log=?, finished_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(logLines.join('\n'), deployId);
    db.prepare('UPDATE tenants SET deploy_status=?, server_id=?, api_url=?, admin_url=?, ws_url=?, status=?, updated_at=CURRENT_TIMESTAMP WHERE id=?')
      .run('deployed', server_id, apiUrl, adminUrl, wsUrl, 'active', tenant_id);
    db.prepare("UPDATE servers SET status='online', tenant_id=?, updated_at=CURRENT_TIMESTAMP WHERE id=?")
      .run(tenant_id, server_id);

    res.json({ code: 200, message: '部署成功', data: { deploy_id: deployId, api_url: apiUrl, admin_url: adminUrl, ws_url: wsUrl, log: logLines } });
  } catch (err) {
    log(`部署失败: ${err.message}`);
    db.prepare(`UPDATE deploy_logs SET status='failed', log=?, finished_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(logLines.join('\n'), deployId);
    db.prepare("UPDATE tenants SET deploy_status='failed', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(tenant_id);
    res.json({ code: 500, message: '部署失败: ' + err.message, data: { deploy_id: deployId, log: logLines } });
  }
});

// SSH部署核心逻辑
function sshDeploy(server, tenant, apiPort, log, packageDirName) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const connectConfig = {
      host: server.ip_address,
      port: server.ssh_port || 22,
      username: server.ssh_user || 'root',
      readyTimeout: 30000,
      keepaliveInterval: 10000,
      keepaliveCountMax: 5
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    // 全局超时保护（10分钟，包含可能的Node.js/PM2安装时间）
    const deployTimeout = setTimeout(() => {
      try { conn.end(); } catch(e) {}
      reject(new Error('部署超时（10分钟），请检查网络连接'));
    }, 600000);

    conn.on('ready', () => {
      log('[1/8] SSH连接成功');

      const deployDir = `/opt/yunxintong/${tenant.enterprise_id}`;
      const deployPackageDir = path.join(__dirname, '..', packageDirName || 'deploy-package');

      // 读取deploy-package中所有文件
      const filesToUpload = getAllFiles(deployPackageDir, deployPackageDir);

      log('[2/8] 上传企业服务程序...');

      // 使用SFTP上传文件
      conn.sftp((err, sftp) => {
        if (err) { clearTimeout(deployTimeout); conn.end(); return reject(new Error('SFTP连接失败: ' + err.message)); }

        // 先创建目录结构，然后上传文件
        const mkdirAndUpload = async () => {
          try {
            // 创建基础目录
            await sshExec(conn, `mkdir -p ${deployDir}/data ${deployDir}/routes ${deployDir}/middleware ${deployDir}/models ${deployDir}/public`);

            // 上传每个文件
            let uploadCount = 0;
            for (const file of filesToUpload) {
              if (file.relativePath.includes('node_modules/')) continue;
              const remotePath = `${deployDir}/${file.relativePath}`;
              const remoteDir = path.dirname(remotePath);
              await sshExec(conn, `mkdir -p ${remoteDir}`);
              await sftpUpload(sftp, file.localPath, remotePath);
              uploadCount++;
              if (uploadCount % 10 === 0 || !file.relativePath.startsWith('public/canvaskit/')) {
                log(`  上传: ${file.relativePath}`);
              }
            }
            log(`[2/8] 文件上传完成 (共${uploadCount}个文件)`);

            // 创建环境配置
            log('[3/8] 配置环境...');
            const envContent = `ENTERPRISE_ID=${tenant.enterprise_id}\nPORT=${apiPort}\nJWT_SECRET=yunxintong_${tenant.enterprise_id}_${Date.now()}\n`;
            await sshExec(conn, `cat > ${deployDir}/.env << 'ENVEOF'\n${envContent}ENVEOF`);
            log('[3/8] 环境配置完成');

            // 检测并安装Node.js
            log('[4/8] 检测Node.js环境...');
            const nodeCheck = await sshExec(conn, 'node -v 2>/dev/null || echo "NODE_NOT_FOUND"');
            if (nodeCheck.includes('NODE_NOT_FOUND')) {
              log('[4/8] Node.js未安装，正在自动安装Node.js 22...');
              // 使用NodeSource安装Node.js 22
              const installNodeResult = await sshExec(conn, `
                export DEBIAN_FRONTEND=noninteractive && \
                apt-get update -qq && \
                apt-get install -y -qq curl ca-certificates gnupg 2>&1 | tail -2 && \
                mkdir -p /etc/apt/keyrings && \
                curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null && \
                echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
                apt-get update -qq && \
                apt-get install -y -qq nodejs 2>&1 | tail -3 && \
                echo "NODE_INSTALL_DONE"
              `);
              if (!installNodeResult.includes('NODE_INSTALL_DONE')) {
                log('  Node.js安装可能有问题，尝试备用方案...');
                await sshExec(conn, 'curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>&1 | tail -3 && apt-get install -y nodejs 2>&1 | tail -3');
              }
              const nodeVer = await sshExec(conn, 'node -v 2>/dev/null || echo "STILL_NOT_FOUND"');
              if (nodeVer.includes('STILL_NOT_FOUND')) {
                throw new Error('Node.js安装失败，请手动在目标服务器上安装Node.js 22');
              }
              log(`[4/8] Node.js安装成功: ${nodeVer.trim()}`);
            } else {
              log(`[4/8] Node.js已安装: ${nodeCheck.trim()}`);
            }

            // 检测并安装PM2
            log('[5/8] 检测PM2...');
            const pm2Check = await sshExec(conn, 'pm2 -v 2>/dev/null || echo "PM2_NOT_FOUND"');
            if (pm2Check.includes('PM2_NOT_FOUND')) {
              log('[5/8] PM2未安装，正在自动安装...');
              await sshExec(conn, 'npm install -g pm2 2>&1 | tail -3');
              const pm2Ver = await sshExec(conn, 'pm2 -v 2>/dev/null || echo "STILL_NOT_FOUND"');
              if (pm2Ver.includes('STILL_NOT_FOUND')) {
                throw new Error('PM2安装失败，请手动在目标服务器上执行: npm install -g pm2');
              }
              // 配置PM2开机自启
              await sshExec(conn, 'pm2 startup 2>/dev/null || true');
              log(`[5/8] PM2安装成功: ${pm2Ver.trim()}`);
            } else {
              log(`[5/8] PM2已安装: ${pm2Check.trim()}`);
            }

            // 安装npm依赖
            log('[6/8] 安装Node.js依赖...');
            const installResult = await sshExec(conn, `cd ${deployDir} && npm install --production 2>&1 | tail -5`);
            log(`  ${installResult.trim()}`);
            log('[6/8] 依赖安装完成');

            // 使用pm2启动服务
            log('[7/8] 启动服务...');
            const pmName = `yxt-${tenant.enterprise_id}`;
            await sshExec(conn, `pm2 delete ${pmName} 2>/dev/null; cd ${deployDir} && PORT=${apiPort} ENTERPRISE_ID=${tenant.enterprise_id} pm2 start index.js --name ${pmName}`);
            await sshExec(conn, 'pm2 save 2>/dev/null');
            log('[7/8] 服务启动成功');

            // 验证服务
            log('[8/8] 验证服务...');
            // 等待3秒让服务启动
            await new Promise(r => setTimeout(r, 3000));
            const healthCheck = await sshExec(conn, `curl -s --connect-timeout 5 http://localhost:${apiPort}/api/health || echo "HEALTH_CHECK_FAILED"`);
            if (healthCheck.includes('HEALTH_CHECK_FAILED')) {
              log('[8/8] 健康检查未通过，服务可能还在启动中');
            } else {
              log('[8/8] 服务健康检查通过');
            }

            clearTimeout(deployTimeout);
            conn.end();
            resolve();
          } catch (e) {
            clearTimeout(deployTimeout);
            conn.end();
            reject(e);
          }
        };

        mkdirAndUpload();
      });
    });

    conn.on('error', (err) => {
      clearTimeout(deployTimeout);
      log(`SSH连接失败: ${err.message}`);
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
    readStream.on('error', (err) => reject(new Error(`读取失败 ${localPath}: ${err.message}`)));
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

// ==================== 一键清除（SSH远程清除） ====================

router.post('/undeploy', verifyToken, requireRole('saas_admin'), async (req, res) => {
  const { tenant_id } = req.body;
  if (!tenant_id) return res.json({ code: 400, message: '请指定租户' });

  const tenant = db.prepare('SELECT * FROM tenants WHERE id = ?').get(tenant_id);
  if (!tenant) return res.json({ code: 404, message: '租户不存在' });
  if (tenant.deploy_status !== 'deployed') return res.json({ code: 400, message: '该租户尚未部署' });

  const server = tenant.server_id ? db.prepare('SELECT * FROM servers WHERE id = ?').get(tenant.server_id) : null;
  if (!server) return res.json({ code: 404, message: '未找到关联的服务器，将直接重置租户状态' });

  const logLines = [];
  function log(msg) {
    const line = `[${new Date().toISOString()}] ${msg}`;
    logLines.push(line);
    console.log(`[Undeploy] ${msg}`);
  }

  log('========== 开始一键清除 ==========');
  log(`目标企业: ${tenant.name} (${tenant.enterprise_id})`);
  log(`目标服务器: ${server.name} (${server.ip_address})`);

  try {
    await sshUndeploy(server, tenant, log);

    // 更新数据库：重置租户状态
    db.prepare("UPDATE tenants SET deploy_status='pending', server_id=NULL, api_url=NULL, admin_url=NULL, ws_url=NULL, status='pending', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(tenant_id);
    // 释放服务器
    db.prepare("UPDATE servers SET tenant_id=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);

    log('');
    log('========== 清除完成 ==========');
    log(`服务器 ${server.name} 已释放，可重新用于部署`);

    res.json({ code: 200, message: '清除成功', data: { log: logLines } });
  } catch (err) {
    log(`清除失败: ${err.message}`);
    // 即使SSH失败，也重置数据库状态让服务器可重新使用
    db.prepare("UPDATE tenants SET deploy_status='pending', server_id=NULL, api_url=NULL, admin_url=NULL, ws_url=NULL, status='pending', updated_at=CURRENT_TIMESTAMP WHERE id=?").run(tenant_id);
    db.prepare("UPDATE servers SET tenant_id=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?").run(server.id);
    res.json({ code: 200, message: '清除完成（远程清理可能部分失败，数据库已重置）', data: { log: logLines } });
  }
});

// SSH清除核心逻辑
function sshUndeploy(server, tenant, log) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const connectConfig = {
      host: server.ip_address,
      port: server.ssh_port || 22,
      username: server.ssh_user || 'root',
      readyTimeout: 15000,
      keepaliveInterval: 5000
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    const timeout = setTimeout(() => {
      try { conn.end(); } catch(e) {}
      reject(new Error('SSH连接超时'));
    }, 60000);

    conn.on('ready', async () => {
      try {
        const pmName = `yxt-${tenant.enterprise_id}`;
        const deployDir = `/opt/yunxintong/${tenant.enterprise_id}`;

        log('[1/3] SSH连接成功');

        // 停止PM2进程
        log('[2/3] 停止服务进程...');
        const stopResult = await sshExec(conn, `pm2 stop ${pmName} 2>/dev/null && pm2 delete ${pmName} 2>/dev/null && pm2 save 2>/dev/null; echo "done"`);
        log(`  PM2进程 ${pmName} 已停止并删除`);

        // 删除部署目录
        log('[3/3] 清除部署文件...');
        const rmResult = await sshExec(conn, `rm -rf ${deployDir} && echo "removed"`);
        if (rmResult.includes('removed')) {
          log(`  部署目录 ${deployDir} 已删除`);
        } else {
          log(`  部署目录清理结果: ${rmResult.trim()}`);
        }

        clearTimeout(timeout);
        conn.end();
        resolve();
      } catch (e) {
        clearTimeout(timeout);
        conn.end();
        reject(e);
      }
    });

    conn.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error('SSH连接失败: ' + err.message));
    });

    conn.connect(connectConfig);
  });
}

// ==================== 一键更新（SSH远程更新代码，保留数据） ====================

// 更新单个租户
router.post('/update-tenant', verifyToken, requireRole('saas_admin'), async (req, res) => {
  const { tenant_id } = req.body;
  if (!tenant_id) return res.json({ code: 400, message: '请指定租户' });

  const tenant = db.prepare('SELECT * FROM tenants WHERE id = ?').get(tenant_id);
  if (!tenant) return res.json({ code: 404, message: '租户不存在' });
  if (tenant.deploy_status !== 'deployed') return res.json({ code: 400, message: '该租户尚未部署，请先进行一键部署' });

  const server = tenant.server_id ? db.prepare('SELECT * FROM servers WHERE id = ?').get(tenant.server_id) : null;
  if (!server) return res.json({ code: 404, message: '未找到关联的服务器' });

  const logLines = [];
  function log(msg) {
    const line = `[${new Date().toISOString()}] ${msg}`;
    logLines.push(line);
    console.log(`[Update] ${msg}`);
  }

  // 解析部署包版本
  let packageDirName = 'deploy-package';
  let packageName = '标准版';
  if (tenant.package_id) {
    const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(tenant.package_id);
    if (pkg) {
      packageDirName = pkg.dir_name;
      packageName = `${pkg.name} v${pkg.version}`;
    }
  } else {
    const defaultPkg = db.prepare('SELECT id FROM deploy_packages WHERE is_default = 1').get();
    if (defaultPkg) {
      db.prepare('UPDATE tenants SET package_id = ? WHERE id = ?').run(defaultPkg.id, tenant.id);
    }
  }

  log('========== 开始一键更新 ==========');
  log(`目标企业: ${tenant.name} (${tenant.enterprise_id})`);
  log(`部署包: ${packageName}`);
  log(`目标服务器: ${server.name} (${server.ip_address})`);

  try {
    await sshUpdate(server, tenant, log, packageDirName);
    log('');
    log('========== 更新完成 ==========');
    log(`企业 ${tenant.name} (${tenant.enterprise_id}) 已更新到最新版本`);
    res.json({ code: 200, message: '更新成功', data: { log: logLines } });
  } catch (err) {
    log(`更新失败: ${err.message}`);
    res.json({ code: 500, message: '更新失败: ' + err.message, data: { log: logLines } });
  }
});

// 更新全部已部署的租户
router.post('/update-all', verifyToken, requireRole('saas_admin'), async (req, res) => {
  const tenants = db.prepare("SELECT t.*, s.name as server_name, s.ip_address, s.ssh_port, s.ssh_user, s.ssh_password, s.ssh_key FROM tenants t LEFT JOIN servers s ON t.server_id = s.id WHERE t.deploy_status = 'deployed' AND t.server_id IS NOT NULL").all();
  if (tenants.length === 0) return res.json({ code: 400, message: '没有已部署的租户' });

  const results = [];
  const allLogLines = [];

  function log(msg) {
    const line = `[${new Date().toISOString()}] ${msg}`;
    allLogLines.push(line);
    console.log(`[UpdateAll] ${msg}`);
  }

  log(`========== 开始批量更新 (共${tenants.length}个租户) ==========`);

  for (let i = 0; i < tenants.length; i++) {
    const tenant = tenants[i];
    const server = {
      ip_address: tenant.ip_address,
      ssh_port: tenant.ssh_port,
      ssh_user: tenant.ssh_user,
      ssh_password: tenant.ssh_password,
      ssh_key: tenant.ssh_key,
      name: tenant.server_name
    };

    log(``);
    // 解析每个租户的部署包版本
    let pkgDirName = 'deploy-package';
    let pkgName = '标准版';
    if (tenant.package_id) {
      const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(tenant.package_id);
      if (pkg) { pkgDirName = pkg.dir_name; pkgName = `${pkg.name} v${pkg.version}`; }
    }
    log(`--- [${i + 1}/${tenants.length}] ${tenant.name} (${tenant.enterprise_id}) @ ${server.ip_address} [部署包: ${pkgName}] ---`);

    try {
      await sshUpdate(server, tenant, log, pkgDirName);
      results.push({ enterprise_id: tenant.enterprise_id, name: tenant.name, status: 'success' });
      log(`[${i + 1}/${tenants.length}] ${tenant.name} 更新成功`);
    } catch (err) {
      results.push({ enterprise_id: tenant.enterprise_id, name: tenant.name, status: 'failed', error: err.message });
      log(`[${i + 1}/${tenants.length}] ${tenant.name} 更新失败: ${err.message}`);
    }
  }

  const successCount = results.filter(r => r.status === 'success').length;
  const failCount = results.filter(r => r.status === 'failed').length;
  log(``);
  log(`========== 批量更新完成 ==========`);
  log(`成功: ${successCount}, 失败: ${failCount}, 总计: ${tenants.length}`);

  res.json({ code: 200, message: `更新完成: 成功${successCount}个, 失败${failCount}个`, data: { results, log: allLogLines } });
});

// SSH更新核心逻辑（只更新代码，保留data/uploads/node_modules/.env）
function sshUpdate(server, tenant, log, packageDirName) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const connectConfig = {
      host: server.ip_address,
      port: server.ssh_port || 22,
      username: server.ssh_user || 'root',
      readyTimeout: 30000,
      keepaliveInterval: 10000,
      keepaliveCountMax: 5
    };
    if (server.ssh_key) {
      connectConfig.privateKey = server.ssh_key;
    } else if (server.ssh_password) {
      connectConfig.password = server.ssh_password;
    }

    const updateTimeout = setTimeout(() => {
      try { conn.end(); } catch(e) {}
      reject(new Error('更新超时（5分钟）'));
    }, 300000);

    conn.on('ready', () => {
      log('[1/5] SSH连接成功');

      const deployDir = `/opt/yunxintong/${tenant.enterprise_id}`;
      const deployPackageDir = path.join(__dirname, '..', packageDirName || 'deploy-package');

      // 读取deploy-package中所有文件（排除node_modules/data/.git）
      const filesToUpload = getAllFiles(deployPackageDir, deployPackageDir);

      conn.sftp((err, sftp) => {
        if (err) { clearTimeout(updateTimeout); conn.end(); return reject(new Error('SFTP连接失败: ' + err.message)); }

        const doUpdate = async () => {
          try {
            // 检查部署目录是否存在
            const checkDir = await sshExec(conn, `test -d ${deployDir} && echo "EXISTS" || echo "NOT_FOUND"`);
            if (checkDir.includes('NOT_FOUND')) {
              throw new Error(`部署目录 ${deployDir} 不存在，请先进行一键部署`);
            }

            // 停止PM2进程
            log('[2/5] 停止服务...');
            const pmName = `yxt-${tenant.enterprise_id}`;
            await sshExec(conn, `pm2 stop ${pmName} 2>/dev/null || true`);
            log(`  PM2进程 ${pmName} 已停止`);

            // 上传更新的文件（跳过node_modules、data、uploads、.env）
            log('[3/5] 上传更新文件...');
            let uploadCount = 0;
            let skipCount = 0;
            for (const file of filesToUpload) {
              // 跳过不需要更新的目录
              if (file.relativePath.includes('node_modules/')) { skipCount++; continue; }
              if (file.relativePath.startsWith('data/')) { skipCount++; continue; }
              if (file.relativePath.startsWith('uploads/')) { skipCount++; continue; }
              if (file.relativePath === '.env') { skipCount++; continue; }

              const remotePath = `${deployDir}/${file.relativePath}`;
              const remoteDir = path.dirname(remotePath);
              await sshExec(conn, `mkdir -p ${remoteDir}`);
              await sftpUpload(sftp, file.localPath, remotePath);
              uploadCount++;
              if (uploadCount % 10 === 0 || !file.relativePath.startsWith('public/canvaskit/')) {
                log(`  更新: ${file.relativePath}`);
              }
            }
            log(`[3/5] 文件更新完成 (更新${uploadCount}个, 跳过${skipCount}个)`);

            // 检查是否需要安装新依赖（对比package.json）
            log('[4/5] 检查并安装依赖...');
            const installResult = await sshExec(conn, `cd ${deployDir} && npm install --production 2>&1 | tail -3`);
            log(`  ${installResult.trim()}`);
            log('[4/5] 依赖检查完成');

            // 重启PM2进程
            log('[5/5] 重启服务...');
            await sshExec(conn, `cd ${deployDir} && pm2 restart ${pmName} 2>/dev/null || pm2 start index.js --name ${pmName}`);
            await sshExec(conn, 'pm2 save 2>/dev/null');

            // 等待3秒验证
            await new Promise(r => setTimeout(r, 3000));
            const apiPort = tenant.api_url ? new URL(tenant.api_url).port || 4001 : 4001;
            const healthCheck = await sshExec(conn, `curl -s --connect-timeout 5 http://localhost:${apiPort}/api/health || echo "HEALTH_CHECK_FAILED"`);
            if (healthCheck.includes('HEALTH_CHECK_FAILED')) {
              log('[5/5] 服务重启中，健康检查暂未通过');
            } else {
              log('[5/5] 服务重启成功，健康检查通过');
            }

            clearTimeout(updateTimeout);
            conn.end();
            resolve();
          } catch (e) {
            // 更新失败时尝试重启服务
            try {
              const pmName = `yxt-${tenant.enterprise_id}`;
              await sshExec(conn, `pm2 restart ${pmName} 2>/dev/null || true`);
              log('  已尝试重启服务');
            } catch(e2) {}
            clearTimeout(updateTimeout);
            conn.end();
            reject(e);
          }
        };

        doUpdate();
      });
    });

    conn.on('error', (err) => {
      clearTimeout(updateTimeout);
      reject(new Error('SSH连接失败: ' + err.message));
    });

    conn.connect(connectConfig);
  });
}

// ==================== 部署包版本管理 ====================

// 获取所有部署包版本
router.get('/packages', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const packages = db.prepare(`
      SELECT p.*, 
        (SELECT COUNT(*) FROM tenants WHERE package_id = p.id) as tenant_count
      FROM deploy_packages p 
      ORDER BY p.is_default DESC, p.created_at ASC
    `).all();
    // 检查每个部署包目录是否存在
    const result = packages.map(pkg => {
      const pkgDir = path.join(__dirname, '..', pkg.dir_name);
      return { ...pkg, dir_exists: fs.existsSync(pkgDir) };
    });
    res.json({ code: 200, data: result });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 获取单个部署包详情
router.get('/packages/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(req.params.id);
    if (!pkg) return res.json({ code: 404, message: '部署包不存在' });
    const pkgDir = path.join(__dirname, '..', pkg.dir_name);
    const dirExists = fs.existsSync(pkgDir);
    // 获取绑定的租户列表
    const tenants = db.prepare('SELECT id, enterprise_id, name, deploy_status FROM tenants WHERE package_id = ?').all(pkg.id);
    res.json({ code: 200, data: { ...pkg, dir_exists: dirExists, tenants } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 创建新的部署包版本（基于现有版本复制）
router.post('/packages', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, version, description, base_package_id } = req.body;
    if (!name) return res.json({ code: 400, message: '部署包名称不能为空' });

    // 生成唯一目录名
    const dirName = 'deploy-package-' + Date.now();
    const pkgId = uuidv4();
    const newPkgDir = path.join(__dirname, '..', dirName);

    // 如果指定了基础包，复制其代码
    if (base_package_id) {
      const basePkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(base_package_id);
      if (!basePkg) return res.json({ code: 404, message: '基础部署包不存在' });
      const baseDir = path.join(__dirname, '..', basePkg.dir_name);
      if (!fs.existsSync(baseDir)) return res.json({ code: 404, message: '基础部署包目录不存在' });
      // 复制目录（排除node_modules和data）
      copyDirSync(baseDir, newPkgDir, ['node_modules', 'data', '.git', 'uploads']);
    } else {
      // 创建空目录结构
      fs.mkdirSync(newPkgDir, { recursive: true });
      fs.mkdirSync(path.join(newPkgDir, 'routes'), { recursive: true });
      fs.mkdirSync(path.join(newPkgDir, 'models'), { recursive: true });
      fs.mkdirSync(path.join(newPkgDir, 'middleware'), { recursive: true });
      fs.mkdirSync(path.join(newPkgDir, 'public'), { recursive: true });
    }

    // 写入数据库
    db.prepare(`INSERT INTO deploy_packages (id, name, version, description, dir_name, is_default, base_package_id, status) VALUES (?,?,?,?,?,?,?,?)`)
      .run(pkgId, name, version || '1.0.0', description || '', dirName, 0, base_package_id || '', 'active');

    res.json({ code: 200, message: '部署包创建成功', data: { id: pkgId, dir_name: dirName } });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 更新部署包信息
router.put('/packages/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { name, version, description, status } = req.body;
    db.prepare(`UPDATE deploy_packages SET name=COALESCE(?,name), version=COALESCE(?,version), description=COALESCE(?,description), status=COALESCE(?,status), updated_at=CURRENT_TIMESTAMP WHERE id=?`)
      .run(name, version, description, status, req.params.id);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 删除部署包
router.delete('/packages/:id', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(req.params.id);
    if (!pkg) return res.json({ code: 404, message: '部署包不存在' });
    if (pkg.is_default) return res.json({ code: 403, message: '不能删除默认标准版部署包' });
    // 检查是否有租户在使用
    const tenantCount = db.prepare('SELECT COUNT(*) as count FROM tenants WHERE package_id = ?').get(req.params.id).count;
    if (tenantCount > 0) return res.json({ code: 400, message: `还有 ${tenantCount} 个租户在使用此部署包，请先切换其部署包版本` });
    // 删除目录
    const pkgDir = path.join(__dirname, '..', pkg.dir_name);
    if (fs.existsSync(pkgDir)) {
      fs.rmSync(pkgDir, { recursive: true, force: true });
    }
    db.prepare('DELETE FROM deploy_packages WHERE id = ?').run(req.params.id);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 绑定租户到指定部署包
router.post('/packages/bind', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const { tenant_id, package_id } = req.body;
    if (!tenant_id || !package_id) return res.json({ code: 400, message: '请指定租户和部署包' });
    const pkg = db.prepare('SELECT id, name FROM deploy_packages WHERE id = ?').get(package_id);
    if (!pkg) return res.json({ code: 404, message: '部署包不存在' });
    db.prepare('UPDATE tenants SET package_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(package_id, tenant_id);
    res.json({ code: 200, message: `已绑定到部署包: ${pkg.name}` });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

// 辅助函数：递归复制目录（排除指定目录）
function copyDirSync(src, dest, excludeDirs = []) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    if (excludeDirs.includes(entry.name)) continue;
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath, excludeDirs);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// 获取部署包目录的文件列表（用于前端展示）
router.get('/packages/:id/files', verifyToken, requireRole('saas_admin'), (req, res) => {
  try {
    const pkg = db.prepare('SELECT * FROM deploy_packages WHERE id = ?').get(req.params.id);
    if (!pkg) return res.json({ code: 404, message: '部署包不存在' });
    const pkgDir = path.join(__dirname, '..', pkg.dir_name);
    if (!fs.existsSync(pkgDir)) return res.json({ code: 404, message: '部署包目录不存在' });
    // 获取文件树（只展示前两层）
    const tree = getFileTree(pkgDir, 2);
    res.json({ code: 200, data: tree });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

function getFileTree(dir, maxDepth, currentDepth = 0) {
  if (currentDepth >= maxDepth) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const result = [];
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name === '.git') continue;
    const item = { name: entry.name, type: entry.isDirectory() ? 'dir' : 'file' };
    if (entry.isDirectory()) {
      item.children = getFileTree(path.join(dir, entry.name), maxDepth, currentDepth + 1);
    } else {
      const stat = fs.statSync(path.join(dir, entry.name));
      item.size = stat.size;
    }
    result.push(item);
  }
  return result.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'dir' ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
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
