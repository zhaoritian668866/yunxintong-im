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

  // ==================== 企业IM相关表（演示环境共用同一数据库） ====================

  // 用户表
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      nickname TEXT DEFAULT '',
      avatar TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      email TEXT DEFAULT '',
      position TEXT DEFAULT '',
      department_id TEXT,
      status TEXT DEFAULT 'active',
      online_status TEXT DEFAULT 'offline',
      last_login_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 部门表
  db.exec(`
    CREATE TABLE IF NOT EXISTS departments (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      parent_id TEXT,
      sort_order INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 企业管理员表
  db.exec(`
    CREATE TABLE IF NOT EXISTS enterprise_admins (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      nickname TEXT DEFAULT '',
      role TEXT DEFAULT 'admin',
      status INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 企业设置表
  db.exec(`
    CREATE TABLE IF NOT EXISTS enterprise_settings (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL UNIQUE,
      require_approval INTEGER DEFAULT 0,
      allow_group_creation INTEGER DEFAULT 1,
      allow_file_sharing INTEGER DEFAULT 1,
      message_recall_timeout INTEGER DEFAULT 120,
      max_file_size INTEGER DEFAULT 50,
      max_group_members INTEGER DEFAULT 500,
      watermark_enabled INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 会话表
  db.exec(`
    CREATE TABLE IF NOT EXISTS conversations (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
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
      joined_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 消息表
  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      type TEXT DEFAULT 'text',
      content TEXT DEFAULT '',
      file_url TEXT DEFAULT '',
      file_name TEXT DEFAULT '',
      reply_to TEXT,
      is_recalled INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
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

  // ==================== 创建企业示例数据 ====================

  // 创建ENT001的企业管理员
  db.prepare('INSERT INTO enterprise_admins (id, tenant_id, username, password, nickname, role) VALUES (?,?,?,?,?,?)')
    .run(uuidv4(), tenant1Id, 'admin', hashedPwd, '企业管理员', 'admin');

  // 创建企业设置
  db.prepare('INSERT INTO enterprise_settings (id, tenant_id) VALUES (?,?)')
    .run(uuidv4(), tenant1Id);

  // 创建部门
  const dept1Id = uuidv4();
  const dept2Id = uuidv4();
  const dept3Id = uuidv4();
  db.prepare('INSERT INTO departments (id, tenant_id, name, sort_order) VALUES (?,?,?,?)')
    .run(dept1Id, tenant1Id, '技术部', 1);
  db.prepare('INSERT INTO departments (id, tenant_id, name, sort_order) VALUES (?,?,?,?)')
    .run(dept2Id, tenant1Id, '产品部', 2);
  db.prepare('INSERT INTO departments (id, tenant_id, name, sort_order) VALUES (?,?,?,?)')
    .run(dept3Id, tenant1Id, '市场部', 3);

  // 创建示例用户
  const userPwd = bcrypt.hashSync('123456', 10);
  const user1Id = uuidv4();
  const user2Id = uuidv4();
  const user3Id = uuidv4();
  const user4Id = uuidv4();
  const user5Id = uuidv4();

  const insertUser = db.prepare('INSERT INTO users (id, tenant_id, username, password, nickname, phone, email, position, department_id, status, online_status) VALUES (?,?,?,?,?,?,?,?,?,?,?)');
  insertUser.run(user1Id, tenant1Id, 'zhangsan', userPwd, '张三', '13800138001', 'zhangsan@yunxin.com', '前端开发工程师', dept1Id, 'active', 'online');
  insertUser.run(user2Id, tenant1Id, 'lisi', userPwd, '李四', '13800138002', 'lisi@yunxin.com', '后端开发工程师', dept1Id, 'active', 'online');
  insertUser.run(user3Id, tenant1Id, 'wangwu', userPwd, '王五', '13800138003', 'wangwu@yunxin.com', '产品经理', dept2Id, 'active', 'offline');
  insertUser.run(user4Id, tenant1Id, 'zhaoliu', userPwd, '赵六', '13800138004', 'zhaoliu@yunxin.com', '市场专员', dept3Id, 'active', 'offline');
  insertUser.run(user5Id, tenant1Id, 'sunqi', userPwd, '孙七', '13800138005', 'sunqi@yunxin.com', 'UI设计师', dept2Id, 'active', 'online');

  // 创建示例会话
  const conv1Id = uuidv4();
  const conv2Id = uuidv4();

  // 私聊会话：张三 <-> 李四
  db.prepare('INSERT INTO conversations (id, tenant_id, type, name, created_by) VALUES (?,?,?,?,?)')
    .run(conv1Id, tenant1Id, 'private', '', user1Id);
  db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
    .run(uuidv4(), conv1Id, user1Id);
  db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
    .run(uuidv4(), conv1Id, user2Id);

  // 群聊会话：技术部群
  db.prepare('INSERT INTO conversations (id, tenant_id, type, name, created_by) VALUES (?,?,?,?,?)')
    .run(conv2Id, tenant1Id, 'group', '技术部工作群', user1Id);
  db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
    .run(uuidv4(), conv2Id, user1Id);
  db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
    .run(uuidv4(), conv2Id, user2Id);
  db.prepare('INSERT INTO conversation_members (id, conversation_id, user_id) VALUES (?,?,?)')
    .run(uuidv4(), conv2Id, user5Id);

  // 创建示例消息
  const insertMsg = db.prepare('INSERT INTO messages (id, conversation_id, sender_id, type, content, created_at) VALUES (?,?,?,?,?,?)');
  insertMsg.run(uuidv4(), conv1Id, user1Id, 'text', '李四，今天的项目进度怎么样？', new Date(Date.now() - 3600000).toISOString());
  insertMsg.run(uuidv4(), conv1Id, user2Id, 'text', '已经完成了API接口开发，正在进行测试', new Date(Date.now() - 3000000).toISOString());
  insertMsg.run(uuidv4(), conv1Id, user1Id, 'text', '好的，辞苦了！', new Date(Date.now() - 2400000).toISOString());

  insertMsg.run(uuidv4(), conv2Id, user1Id, 'text', '大家注意，明天上午9点技术评审会议', new Date(Date.now() - 7200000).toISOString());
  insertMsg.run(uuidv4(), conv2Id, user2Id, 'text', '收到，我会准备好技术方案文档', new Date(Date.now() - 6000000).toISOString());
  insertMsg.run(uuidv4(), conv2Id, user5Id, 'text', 'UI设计稿也已经完成，稍后发到群里', new Date(Date.now() - 5400000).toISOString());

  console.log('✅ SaaS平台数据库初始化完成');
  console.log('✅ 示例用户: zhangsan/123456, lisi/123456, wangwu/123456, zhaoliu/123456, sunqi/123456');
}

module.exports = { db, initDatabase };
