const express = require('express');
const cors = require('cors');
const { initDatabase } = require('./models/database');

initDatabase();

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  console.log(`[SaaS] ${req.method} ${req.path}`);
  next();
});

// 公用接口：企业ID解析（前端输入企业ID后调用，获取企业API地址）
app.use('/api/auth', require('./routes/auth'));

// SaaS管理后台接口
app.use('/api/saas', require('./routes/saas'));

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({ code: 200, message: 'SaaS Platform OK', timestamp: new Date().toISOString() });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 云信通 SaaS 平台已启动`);
  console.log(`📡 SaaS API: http://0.0.0.0:${PORT}/api`);
  console.log(`\n📋 SaaS管理员: admin / admin123`);
  console.log(`📋 企业ID解析: POST /api/auth/resolve { enterprise_id: "ENT001" }`);
});
