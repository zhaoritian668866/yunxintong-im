const express = require('express');
const cors = require('cors');
const path = require('path');
const { initDatabase } = require('./models/database');

initDatabase();

const app = express();
app.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) console.log(`[SaaS] ${req.method} ${req.path}`);
  next();
});

// API路由
app.use('/api/auth', require('./routes/auth'));
app.use('/api/saas', require('./routes/saas'));
app.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'SaaS Platform OK', timestamp: new Date().toISOString() });
});

// 托管公用前端静态文件（端口8088）
const USER_WEB_DIR = path.join(__dirname, '../build/web_user');
const SAAS_WEB_DIR = path.join(__dirname, '../build/web_saas');

// 主应用（公用前端 + SaaS API）端口8088
const PORT_USER = process.env.PORT_USER || 8088;
const userApp = express();
userApp.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
userApp.use(express.json());
userApp.use(express.urlencoded({ extended: true }));
userApp.use('/api/auth', require('./routes/auth'));
userApp.use('/api/saas', require('./routes/saas'));
userApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'SaaS Platform OK', timestamp: new Date().toISOString() });
});
userApp.use(express.static(USER_WEB_DIR));
userApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(USER_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

// SaaS后台应用 端口8081
const PORT_SAAS = process.env.PORT_SAAS || 8081;
const saasApp = express();
saasApp.use(cors({ origin: '*', methods: ['GET','POST','PUT','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'] }));
saasApp.use(express.json());
saasApp.use(express.urlencoded({ extended: true }));
saasApp.use('/api/auth', require('./routes/auth'));
saasApp.use('/api/saas', require('./routes/saas'));
saasApp.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'SaaS Platform OK', timestamp: new Date().toISOString() });
});
saasApp.use(express.static(SAAS_WEB_DIR));
saasApp.use((req, res, next) => {
  if (!req.path.startsWith('/api') && req.method === 'GET') {
    res.sendFile(path.join(SAAS_WEB_DIR, 'index.html'));
  } else {
    next();
  }
});

userApp.listen(PORT_USER, '0.0.0.0', () => {
  console.log(`\n🌐 公用前端已启动: http://0.0.0.0:${PORT_USER}`);
});

saasApp.listen(PORT_SAAS, '0.0.0.0', () => {
  console.log(`🔧 SaaS管理后台已启动: http://0.0.0.0:${PORT_SAAS}`);
});

console.log(`\n📋 SaaS管理员: admin / admin123`);
console.log(`📋 企业ID: ENT001`);
