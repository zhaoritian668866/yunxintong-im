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

  // 租户表 - enterprise_id 到 api_url 的映射
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
      memory_gb INTEGER DEFAULT 0,
      disk_gb INTEGER DEFAULT 0,
      cpu_usage REAL DEFAULT 0,
      memory_usage REAL DEFAULT 0,
      disk_usage REAL DEFAULT 0,
      status TEXT DEFAULT 'offline',
      tenant_id TEXT,
      api_port INTEGER DEFAULT 4001,
      admin_port INTEGER DEFAULT 4002,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 部署日志表
  db.exec(`
    CREATE TABLE IF NOT EXISTS deploy_logs (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      server_id TEXT NOT NULL,
      status TEXT DEFAULT 'pending',
      log TEXT DEFAULT '',
      started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      finished_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 订单表
  db.exec(`
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      order_no TEXT UNIQUE NOT NULL,
      enterprise_id TEXT NOT NULL,
      enterprise_name TEXT DEFAULT '',
      plan TEXT DEFAULT 'basic',
      period TEXT DEFAULT 'monthly',
      amount INTEGER DEFAULT 0,
      status TEXT DEFAULT 'pending',
      remark TEXT DEFAULT '',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // SaaS系统设置表
  db.exec(`
    CREATE TABLE IF NOT EXISTS saas_settings (
      id TEXT PRIMARY KEY,
      platform_name TEXT DEFAULT '云信通IM平台',
      platform_logo TEXT DEFAULT '',
      support_email TEXT DEFAULT '',
      support_phone TEXT DEFAULT '',
      default_max_users INTEGER DEFAULT 100,
      default_max_groups INTEGER DEFAULT 50,
      default_max_file_size INTEGER DEFAULT 50,
      deploy_script_path TEXT DEFAULT '',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  seedDefaultData();
}

function seedDefaultData() {
  // 只在数据库为空时初始化
  const adminExists = db.prepare('SELECT id FROM saas_admins WHERE username = ?').get('superadmin');
  if (adminExists) return;

  const hashedPwd = bcrypt.hashSync('123456', 10);

  // 创建默认SaaS超级管理员
  db.prepare(`INSERT INTO saas_admins (id, username, password, nickname, role) VALUES (?, ?, ?, ?, ?)`)
    .run(uuidv4(), 'superadmin', hashedPwd, '超级管理员', 'super_admin');

  // 创建默认系统设置
  db.prepare(`INSERT INTO saas_settings (id, platform_name) VALUES (?, ?)`)
    .run(uuidv4(), '云信通IM平台');

  console.log('✅ SaaS数据库初始化完成');
  console.log('   默认管理员: superadmin / 123456');
}

module.exports = { db, initDatabase };
