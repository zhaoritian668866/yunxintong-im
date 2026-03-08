const Database = require('better-sqlite3');
const path = require('path');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');

const DB_PATH = path.join(__dirname, '..', 'data', 'enterprise.db');
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(DB_PATH);
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
      require_approval INTEGER DEFAULT 0,
      allow_group_creation INTEGER DEFAULT 1,
      allow_file_sharing INTEGER DEFAULT 1,
      message_recall_timeout INTEGER DEFAULT 120,
      max_file_size INTEGER DEFAULT 50,
      max_group_members INTEGER DEFAULT 500,
      watermark_enabled INTEGER DEFAULT 0,
      enterprise_name TEXT DEFAULT '',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  seedDefaultData();
}

function seedDefaultData() {
  const adminExists = db.prepare('SELECT id FROM admins WHERE username = ?').get('admin');
  if (adminExists) return;

  const hashedPwd = bcrypt.hashSync('admin123', 10);
  const userPwd = bcrypt.hashSync('123456', 10);

  // 创建默认管理员
  db.prepare('INSERT INTO admins (id, username, password, nickname, role) VALUES (?,?,?,?,?)')
    .run(uuidv4(), 'admin', hashedPwd, '企业管理员', 'admin');

  // 创建默认设置
  db.prepare('INSERT INTO settings (id, enterprise_name) VALUES (?,?)').run(uuidv4(), '默认企业');

  // 创建示例部门
  const dept1 = uuidv4(), dept2 = uuidv4(), dept3 = uuidv4();
  db.prepare('INSERT INTO departments (id, name, description, sort_order) VALUES (?,?,?,?)').run(dept1, '技术部', '负责产品研发与技术支持', 1);
  db.prepare('INSERT INTO departments (id, name, description, sort_order) VALUES (?,?,?,?)').run(dept2, '市场部', '负责市场推广与品牌运营', 2);
  db.prepare('INSERT INTO departments (id, name, description, sort_order) VALUES (?,?,?,?)').run(dept3, '人事部', '负责人力资源与行政管理', 3);

  // 创建示例用户
  const u1 = uuidv4(), u2 = uuidv4(), u3 = uuidv4(), u4 = uuidv4(), u5 = uuidv4();
  const ins = db.prepare('INSERT INTO users (id, username, password, nickname, phone, email, department_id, position, status, online_status) VALUES (?,?,?,?,?,?,?,?,?,?)');
  ins.run(u1, 'zhangwei', userPwd, '张伟', '13900001001', 'zhangwei@company.com', dept1, '高级工程师', 'active', 'online');
  ins.run(u2, 'liuna', userPwd, '刘娜', '13900001002', 'liuna@company.com', dept1, '前端工程师', 'active', 'online');
  ins.run(u3, 'wangfang', userPwd, '王芳', '13900001003', 'wangfang@company.com', dept2, '市场经理', 'active', 'offline');
  ins.run(u4, 'chenming', userPwd, '陈明', '13900001004', 'chenming@company.com', dept2, '运营专员', 'active', 'offline');
  ins.run(u5, 'zhaoli', userPwd, '赵丽', '13900001005', 'zhaoli@company.com', dept3, 'HR主管', 'active', 'online');

  // 创建示例会话和消息
  const c1 = uuidv4(), c2 = uuidv4(), c3 = uuidv4();
  db.prepare('INSERT INTO conversations (id, type, name, created_by) VALUES (?,?,?,?)').run(c1, 'private', '', u1);
  db.prepare('INSERT INTO conversations (id, type, name, created_by) VALUES (?,?,?,?)').run(c2, 'group', '技术部工作群', u1);
  db.prepare('INSERT INTO conversations (id, type, name, created_by) VALUES (?,?,?,?)').run(c3, 'group', '全员通知群', u1);

  const addMember = db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id, unread_count) VALUES (?,?,?,?)');
  addMember.run(uuidv4(), c1, u1, 0); addMember.run(uuidv4(), c1, u2, 2);
  addMember.run(uuidv4(), c2, u1, 0); addMember.run(uuidv4(), c2, u2, 3); addMember.run(uuidv4(), c2, u3, 1);
  addMember.run(uuidv4(), c3, u1, 0); addMember.run(uuidv4(), c3, u2, 0); addMember.run(uuidv4(), c3, u3, 0); addMember.run(uuidv4(), c3, u4, 0); addMember.run(uuidv4(), c3, u5, 0);

  const addMsg = db.prepare('INSERT INTO messages (id, conversation_id, sender_id, type, content, created_at) VALUES (?,?,?,?,?,?)');
  const now = new Date();
  addMsg.run(uuidv4(), c1, u1, 'text', '你好，新版本的接口文档写好了吗？', new Date(now - 3600000).toISOString());
  addMsg.run(uuidv4(), c1, u2, 'text', '正在写，预计今天下午完成', new Date(now - 3000000).toISOString());
  addMsg.run(uuidv4(), c1, u1, 'text', '好的，辛苦了', new Date(now - 2400000).toISOString());
  addMsg.run(uuidv4(), c2, u1, 'text', '大家注意，本周五进行代码评审', new Date(now - 7200000).toISOString());
  addMsg.run(uuidv4(), c2, u2, 'text', '收到，我会准备好的', new Date(now - 6000000).toISOString());
  addMsg.run(uuidv4(), c3, u1, 'text', '通知：下周一全员会议，请准时参加', new Date(now - 86400000).toISOString());

  console.log('✅ 企业数据库初始化完成，已创建默认数据');
}

module.exports = { db, initDatabase };
