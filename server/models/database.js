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

  // 订单表
  db.exec(`
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      order_no TEXT UNIQUE NOT NULL,
      tenant_id TEXT,
      enterprise_id TEXT NOT NULL,
      tenant_name TEXT DEFAULT '',
      plan TEXT DEFAULT 'basic',
      period TEXT DEFAULT 'monthly',
      amount REAL DEFAULT 0,
      status TEXT DEFAULT 'pending',
      remark TEXT DEFAULT '',
      paid_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // SaaS平台设置表
  db.exec(`
    CREATE TABLE IF NOT EXISTS saas_settings (
      id TEXT PRIMARY KEY,
      key TEXT UNIQUE NOT NULL,
      value TEXT DEFAULT '',
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
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
      'http://localhost:4001/api', 'http://localhost:4001/admin', 'ws://localhost:4001/ws', server1Id, 'deployed');

  db.prepare(`INSERT INTO tenants (id, enterprise_id, name, contact_person, contact_phone, contact_email, plan, status, max_users, deploy_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(tenant2Id, 'ENT002', '星辰互联网科技', '李四', '13800138002', 'lisi@xingchen.com', 'basic', 'active', 100, 'pending');

  db.prepare(`INSERT INTO servers (id, name, ip_address, ssh_port, ssh_user, cpu_cores, memory_gb, disk_gb, cpu_usage, memory_usage, disk_usage, status, tenant_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(server1Id, 'ENT001-生产服务器', '192.168.1.100', 22, 'root', 8, 16, 200, 35.2, 62.1, 45.8, 'online', tenant1Id);

  // 创建示例订单
  const genOrderNo = () => 'ORD' + Date.now().toString().slice(-8) + Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  db.prepare('INSERT INTO orders (id, order_no, enterprise_id, tenant_name, plan, period, amount, status, created_at) VALUES (?,?,?,?,?,?,?,?,?)')
    .run(uuidv4(), genOrderNo(), 'ENT001', '云信科技有限公司', 'enterprise', 'yearly', 9590, 'completed', new Date(Date.now() - 86400000 * 30).toISOString());
  db.prepare('INSERT INTO orders (id, order_no, enterprise_id, tenant_name, plan, period, amount, status, created_at) VALUES (?,?,?,?,?,?,?,?,?)')
    .run(uuidv4(), genOrderNo(), 'ENT002', '星辰互联网科技', 'basic', 'monthly', 299, 'pending', new Date(Date.now() - 86400000 * 2).toISOString());
  db.prepare('INSERT INTO orders (id, order_no, enterprise_id, tenant_name, plan, period, amount, status, created_at) VALUES (?,?,?,?,?,?,?,?,?)')
    .run(uuidv4(), genOrderNo(), 'ENT001', '云信科技有限公司', 'enterprise', 'monthly', 999, 'paid', new Date(Date.now() - 86400000 * 5).toISOString());

  // 创建默认设置
  const defaultSettings = {
    platform_name: '云信通',
    platform_desc: '多租户企业即时通讯平台',
    contact_email: 'admin@yunxintong.com',
    contact_phone: '400-888-9999',
    enable_registration: 'true',
    enable_email_verify: 'false',
    enable_two_factor: 'false',
    max_login_attempts: '5',
    session_timeout: '24',
    basic_price: '299',
    pro_price: '599',
    ent_price: '999',
    basic_max_users: '50',
    pro_max_users: '200',
    ent_max_users: '1000',
  };
  const insertSetting = db.prepare('INSERT OR IGNORE INTO saas_settings (id, key, value) VALUES (?,?,?)');
  for (const [k, v] of Object.entries(defaultSettings)) {
    insertSetting.run(uuidv4(), k, v);
  }

  console.log('✅ SaaS平台数据库初始化完成');
}

module.exports = { db, initDatabase };
