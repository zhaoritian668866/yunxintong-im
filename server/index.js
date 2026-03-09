const express = require('express');
const cors = require('cors');
const path = require('path');
const { initDatabase } = require('./models/database');

initDatabase();

const corsOptions = {
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

// ==================== 公用前端应用 ====================
const USER_WEB_DIR = path.join(__dirname, 'build/web_user');
const PORT_USER = process.env.PORT_USER || 8088;
const userApp = express();
userApp.use(cors(corsOptions));

userApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[User] ${req.method} ${req.path}`);
  next();
});

// 代理路由必须在express.json()之前注册，避免文件上传的原始请求体被解析消耗
userApp.use('/api/proxy', require('./routes/proxy')());

// 其他API路由需要JSON解析
userApp.use(express.json());
userApp.use(express.urlencoded({ extended: true }));

// 企业ID解析（查询数据库中租户的api_url）
userApp.use('/api/saas', require('./routes/auth'));
userApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'OK', timestamp: new Date().toISOString() });
});

// 静态文件
userApp.use(express.static(USER_WEB_DIR));
userApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(USER_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// ==================== SaaS管理后台应用 ====================
const SAAS_WEB_DIR = path.join(__dirname, 'build/web_saas');
const PORT_SAAS = process.env.PORT_SAAS || 8081;
const saasApp = express();
saasApp.use(cors(corsOptions));
saasApp.use(express.json());
saasApp.use(express.urlencoded({ extended: true }));

saasApp.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[SaaS] ${req.method} ${req.path}`);
  next();
});

saasApp.use('/api/saas', require('./routes/saas'));
saasApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'OK', timestamp: new Date().toISOString() });
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
  console.log(`🌐 公用前端已启动: http://0.0.0.0:${PORT_USER}`);
});

saasApp.listen(PORT_SAAS, '0.0.0.0', () => {
  console.log(`📊 SaaS管理后台已启动: http://0.0.0.0:${PORT_SAAS}`);
});

console.log('==========================================');
console.log('  云信通IM SaaS平台');
console.log(`  公用前端: http://0.0.0.0:${PORT_USER}`);
console.log(`  SaaS后台: http://0.0.0.0:${PORT_SAAS}`);
console.log('  默认管理员: superadmin / 123456');
console.log('==========================================');
