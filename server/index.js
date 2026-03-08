const express = require('express');
const cors = require('cors');
const path = require('path');
const { initDatabase } = require('./models/database');

initDatabase();

const corsOptions = {
  origin: '*',
  methods: ['GET','POST','PUT','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization']
};

// ==================== 公用前端应用 端口8088 ====================
const USER_WEB_DIR = path.join(__dirname, '../build/web_user');
const PORT_USER = process.env.PORT_USER || 8088;
const userApp = express();
userApp.use(cors(corsOptions));
userApp.use(express.json());
userApp.use(express.urlencoded({ extended: true }));

// 日志
userApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[User:8088] ${req.method} ${req.path}`);
  next();
});

// SaaS平台API（企业ID解析等）
userApp.use('/api/auth', require('./routes/auth'));
userApp.use('/api/saas', require('./routes/saas'));
userApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'User Frontend OK', timestamp: new Date().toISOString() });
});

// 代理路由：前端通过 /api/proxy/ENT001/auth/login 访问企业服务器
userApp.use('/api/proxy', require('./routes/proxy'));

// 静态文件
userApp.use(express.static(USER_WEB_DIR));
userApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(USER_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// ==================== SaaS管理后台应用 端口8081 ====================
const SAAS_WEB_DIR = path.join(__dirname, '../build/web_saas');
const PORT_SAAS = process.env.PORT_SAAS || 8081;
const saasApp = express();
saasApp.use(cors(corsOptions));
saasApp.use(express.json());
saasApp.use(express.urlencoded({ extended: true }));

saasApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[SaaS:8081] ${req.method} ${req.path}`);
  next();
});

saasApp.use('/api/auth', require('./routes/auth'));
saasApp.use('/api/saas', require('./routes/saas'));
saasApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'SaaS Admin OK', timestamp: new Date().toISOString() });
});

saasApp.use(express.static(SAAS_WEB_DIR));
saasApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(SAAS_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// ==================== 启动服务 ====================
userApp.listen(PORT_USER, '0.0.0.0', () => {
  console.log(`\n🌐 公用前端已启动: http://0.0.0.0:${PORT_USER}`);
});

saasApp.listen(PORT_SAAS, '0.0.0.0', () => {
  console.log(`🔧 SaaS管理后台已启动: http://0.0.0.0:${PORT_SAAS}`);
});

console.log(`\n📋 SaaS管理员: admin / admin123`);
console.log(`📋 企业ID: ENT001`);
console.log(`📋 代理路径: /api/proxy/{enterprise_id}/{path}`);
