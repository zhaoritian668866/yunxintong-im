const Database = require('better-sqlite3');
const path = require('path');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');

const ENTERPRISE_ID = process.env.ENTERPRISE_ID || 'UNKNOWN';
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const dbPath = path.join(dataDir, 'enterprise.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function initDatabase() {
  // 企业管理员表
  db.exec(`
    CREATE TABLE IF NOT EXISTS admins (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      nickname TEXT DEFAULT '企业管理员',
      role TEXT DEFAULT 'admin',
      status INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 部门表
  db.exec(`
    CREATE TABLE IF NOT EXISTS departments (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT DEFAULT '',
      parent_id TEXT,
      sort_order INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 用户表
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      nickname TEXT DEFAULT '',
      avatar TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      email TEXT DEFAULT '',
      department_id TEXT,
      position TEXT DEFAULT '',
      status TEXT DEFAULT 'active',
      online_status TEXT DEFAULT 'offline',
      max_devices INTEGER DEFAULT 1,
      last_login_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (department_id) REFERENCES departments(id)
    )
  `);

  // 会话表
  db.exec(`
    CREATE TABLE IF NOT EXISTS conversations (
      id TEXT PRIMARY KEY,
      type TEXT DEFAULT 'private',
      name TEXT DEFAULT '',
      avatar TEXT DEFAULT '',
      created_by TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 会话成员表
  db.exec(`
    CREATE TABLE IF NOT EXISTS conversation_members (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      role TEXT DEFAULT 'member',
      is_pinned INTEGER DEFAULT 0,
      is_muted INTEGER DEFAULT 0,
      unread_count INTEGER DEFAULT 0,
      last_read_at DATETIME,
      joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (conversation_id) REFERENCES conversations(id),
      FOREIGN KEY (user_id) REFERENCES users(id),
      UNIQUE(conversation_id, user_id)
    )
  `);

  // 消息表
  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      type TEXT DEFAULT 'text',
      content TEXT NOT NULL,
      file_url TEXT,
      file_name TEXT,
      reply_to TEXT,
      is_recalled INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (conversation_id) REFERENCES conversations(id),
      FOREIGN KEY (sender_id) REFERENCES users(id)
    )
  `);

  // 企业设置表
  db.exec(`
    CREATE TABLE IF NOT EXISTS settings (
      id TEXT PRIMARY KEY,
      enterprise_name TEXT DEFAULT '',
      require_approval INTEGER DEFAULT 0,
      allow_group_creation INTEGER DEFAULT 1,
      allow_file_sharing INTEGER DEFAULT 1,
      message_recall_timeout INTEGER DEFAULT 120,
      max_file_size INTEGER DEFAULT 50,
      max_group_members INTEGER DEFAULT 500,
      max_users INTEGER DEFAULT 100,
      watermark_enabled INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 创建索引
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
    CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);
    CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_conv_members ON conversation_members(conversation_id, user_id);
  `);

  // 初始化默认数据（仅在空数据库时）
  seedDefaultData();
}

function seedDefaultData() {
  const adminExists = db.prepare('SELECT id FROM admins LIMIT 1').get();
  if (adminExists) return;

  // 默认管理员 admin / 123456
  const hashedPwd = bcrypt.hashSync('123456', 10);
  db.prepare('INSERT INTO admins (id, username, password, nickname, role) VALUES (?,?,?,?,?)')
    .run(uuidv4(), 'admin', hashedPwd, '企业管理员', 'admin');

  // 默认企业设置
  db.prepare('INSERT INTO settings (id, enterprise_name) VALUES (?,?)')
    .run(uuidv4(), ENTERPRISE_ID);

  // 默认部门
  db.prepare('INSERT INTO departments (id, name, description, sort_order) VALUES (?,?,?,?)')
    .run(uuidv4(), '默认部门', '默认部门', 1);

  console.log(`✅ 企业 [${ENTERPRISE_ID}] 数据库初始化完成`);
  console.log('   默认管理员: admin / 123456');
}

module.exports = { db, initDatabase };
