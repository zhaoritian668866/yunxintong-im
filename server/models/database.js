const Database = require('better-sqlite3');
const path = require('path');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');

const DB_PATH = path.join(__dirname, '..', 'data', 'saas_platform.db');
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function initDatabase() {
  // SaaS管理员表
  db.exec(`
    CREATE TABLE IF NOT EXISTS saas_admins (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      nickname TEXT DEFAULT 'SaaS管理员',
      role TEXT DEFAULT 'super_admin',
      status INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 租户表 - 核心是 enterprise_id 到 api_url 的映射
  db.exec(`
    CREATE TABLE IF NOT EXISTS tenants (
      id TEXT PRIMARY KEY,
      enterprise_id TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      contact_person TEXT DEFAULT '',
      contact_phone TEXT DEFAULT '',
      contact_email TEXT DEFAULT '',
      plan TEXT DEFAULT 'basic',
      status TEXT DEFAULT 'active',
      max_users INTEGER DEFAULT 100,
      api_url TEXT DEFAULT '',
      admin_url TEXT DEFAULT '',
      ws_url TEXT DEFAULT '',
      server_id TEXT,
      deploy_status TEXT DEFAULT 'pending',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      expires_at DATETIME
    )
  `);

  // 服务器表
  db.exec(`
    CREATE TABLE IF NOT EXISTS servers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ip_address TEXT NOT NULL,
      ssh_port INTEGER DEFAULT 22,
      ssh_user TEXT DEFAULT 'root',
      ssh_password TEXT DEFAULT '',
      ssh_key TEXT DEFAULT '',
      cpu_cores INTEGER DEFAULT 0,
      memory_gb REAL DEFAULT 0,
      disk_gb REAL DEFAULT 0,
      cpu_usage REAL DEFAULT 0,
      memory_usage REAL DEFAULT 0,
      disk_usage REAL DEFAULT 0,
      status TEXT DEFAULT 'offline',
      tenant_id TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 部署记录表
  db.exec(`
    CREATE TABLE IF NOT EXISTS deploy_logs (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      server_id TEXT NOT NULL,
      status TEXT DEFAULT 'pending',
      log_content TEXT DEFAULT '',
      started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      finished_at DATETIME
    )
  `);

  seedDefaultData();
}

function seedDefaultData() {
  const adminExists = db.prepare('SELECT id FROM saas_admins WHERE username = ?').get('admin');
  if (adminExists) return;

  const hashedPwd = bcrypt.hashSync('admin123', 10);

  // 创建SaaS超级管理员
  db.prepare(`INSERT INTO saas_admins (id, username, password, nickname, role) VALUES (?, ?, ?, ?, ?)`)
    .run(uuidv4(), 'admin', hashedPwd, '超级管理员', 'super_admin');

  // 创建示例租户（已部署状态，指向本机模拟企业服务）
  const tenant1Id = uuidv4();
  const tenant2Id = uuidv4();
  const server1Id = uuidv4();

  db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, status, max_users, api_url, admin_url, ws_url, server_id, deploy_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(tenant1Id, 'ENT001', '云信科技有限公司', '张三', '13800138001', 'zhangsan@yunxin.com', 'enterprise', 'active', 200,
      'https://4001-i2n18dh7l6sqyame3d6u0-92687a5f.sg1.manus.computer/api', 'https://4001-i2n18dh7l6sqyame3d6u0-92687a5f.sg1.manus.computer/admin', 'wss://4001-i2n18dh7l6sqyame3d6u0-92687a5f.sg1.manus.computer/ws', server1Id, 'deployed');

  db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, status, max_users, deploy_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(tenant2Id, 'ENT002', '星辰互联网科技', '李四', '13800138002', 'lisi@xingchen.com', 'basic', 'active', 100, 'pending');

  db.prepare(`INSERT INTO servers (id, name, ip_address, ssh_port, ssh_user, cpu_cores, memory_gb, disk_gb, cpu_usage, memory_usage, disk_usage, status, tenant_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(server1Id, 'ENT001-生产服务器', '192.168.1.100', 22, 'root', 8, 16, 200, 35.2, 62.1, 45.8, 'online', tenant1Id);

  console.log('✅ SaaS平台数据库初始化完成');
}

module.exports = { db, initDatabase };
