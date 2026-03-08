const express = require('express');
const router = express.Router();
const http = require('http');
const https = require('https');
const { URL } = require('url');
const { db } = require('../models/database');

// 代理转发：/api/proxy/:enterprise_id/任意路径
// 使用req.originalUrl手动解析路径，避免Express v5 splat参数的逗号问题
router.use('/', (req, res) => {
  try {
    // 从URL中提取enterprise_id和子路径
    // req.originalUrl格式: /api/proxy/ENT001/auth/login?xxx
    // req.baseUrl: /api/proxy
    // req.url: /ENT001/auth/login?xxx
    const urlPath = req.url.split('?')[0]; // /ENT001/auth/login
    const parts = urlPath.split('/').filter(Boolean); // ['ENT001', 'auth', 'login']
    
    if (parts.length < 2) {
      return res.json({ code: 400, message: '无效的代理路径' });
    }

    const enterprise_id = parts[0];
    const subPath = parts.slice(1).join('/'); // auth/login

    // 查找企业的真实API地址
    const tenant = db.prepare(
      'SELECT api_url, status, deploy_status FROM tenants WHERE enterprise_id = ?'
    ).get(enterprise_id);

    if (!tenant) return res.json({ code: 404, message: '企业不存在' });
    if (tenant.status !== 'active') return res.json({ code: 403, message: '企业已停用' });
    if (!tenant.api_url) return res.json({ code: 503, message: '企业服务未部署' });

    // 构建目标URL
    let targetUrl = tenant.api_url;
    if (targetUrl.endsWith('/')) targetUrl = targetUrl.slice(0, -1);
    targetUrl = `${targetUrl}/${subPath}`;

    // 附加query参数
    const queryString = req.url.split('?')[1];
    if (queryString) targetUrl += '?' + queryString;

    console.log(`[Proxy] ${req.method} ${enterprise_id}/${subPath} => ${targetUrl}`);

    // 转发请求
    const parsedUrl = new URL(targetUrl);
    const isHttps = parsedUrl.protocol === 'https:';
    const httpModule = isHttps ? https : http;

    const headers = { ...req.headers };
    delete headers['host'];
    delete headers['origin'];
    delete headers['referer'];
    delete headers['connection'];
    headers['host'] = parsedUrl.host;

    const bodyStr = req.body && Object.keys(req.body).length > 0 ? JSON.stringify(req.body) : null;
    if (bodyStr) {
      headers['content-length'] = Buffer.byteLength(bodyStr).toString();
      headers['content-type'] = 'application/json';
    }

    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (isHttps ? 443 : 80),
      path: parsedUrl.pathname + (parsedUrl.search || ''),
      method: req.method,
      headers: headers,
      timeout: 30000,
      rejectUnauthorized: false
    };

    const proxyReq = httpModule.request(options, (proxyRes) => {
      let data = '';
      proxyRes.on('data', chunk => data += chunk);
      proxyRes.on('end', () => {
        try {
          const json = JSON.parse(data);
          res.status(proxyRes.statusCode || 200).json(json);
        } catch (e) {
          res.status(proxyRes.statusCode || 200).send(data);
        }
      });
    });

    proxyReq.on('error', (err) => {
      console.error(`[Proxy Error] ${err.message}`);
      res.json({ code: 502, message: '企业服务器连接失败: ' + err.message });
    });

    proxyReq.on('timeout', () => {
      proxyReq.destroy();
      res.json({ code: 504, message: '企业服务器响应超时' });
    });

    if (bodyStr) proxyReq.write(bodyStr);
    proxyReq.end();

  } catch (err) {
    console.error(`[Proxy Error] ${err.message}`);
    res.json({ code: 500, message: '代理服务错误: ' + err.message });
  }
});

module.exports = router;
