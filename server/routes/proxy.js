const express = require('express');
const router = express.Router();
const http = require('http');
const https = require('https');
const { URL } = require('url');
const { db } = require('../models/database');

// 解析企业ID和子路径
function parseProxyPath(reqUrl) {
  const urlPath = reqUrl.split('?')[0];
  const parts = urlPath.split('/').filter(Boolean);
  if (parts.length < 2) return null;
  return {
    enterprise_id: parts[0],
    subPath: parts.slice(1).join('/'),
    queryString: reqUrl.split('?')[1] || ''
  };
}

// 查找企业API地址
function getTenantApiUrl(enterprise_id) {
  const tenant = db.prepare(
    'SELECT api_url, status, deploy_status FROM tenants WHERE enterprise_id = ?'
  ).get(enterprise_id);
  if (!tenant) return { error: { code: 404, message: '企业不存在' } };
  if (tenant.status !== 'active') return { error: { code: 403, message: '企业已停用' } };
  if (!tenant.api_url) return { error: { code: 503, message: '企业服务未部署' } };
  return { api_url: tenant.api_url };
}

module.exports = function() {
  // 通用代理转发（支持所有Content-Type，包括JSON和multipart/form-data文件上传）
  // 重要：此路由必须注册在express.json()之前，这样所有请求体都以原始流的方式转发
  router.use('/', (req, res) => {
    try {
      const parsed = parseProxyPath(req.url);
      if (!parsed) return res.json({ code: 400, message: '无效的代理路径' });

      const { enterprise_id, subPath, queryString } = parsed;
      const tenantResult = getTenantApiUrl(enterprise_id);
      if (tenantResult.error) return res.json(tenantResult.error);

      // 构建目标URL
      let targetUrl = tenantResult.api_url;
      if (targetUrl.endsWith('/')) targetUrl = targetUrl.slice(0, -1);
      
      // 对于 /uploads 路径，需要访问企业服务器的静态文件目录
      // api_url = http://ip:port/api，但 uploads 在 http://ip:port/uploads
      if (subPath.startsWith('uploads/') || subPath === 'uploads') {
        const baseUrl = targetUrl.replace(/\/api\/?$/, '');
        targetUrl = `${baseUrl}/${subPath}`;
      } else {
        targetUrl = `${targetUrl}/${subPath}`;
      }
      if (queryString) targetUrl += '?' + queryString;

      console.log(`[Proxy] ${req.method} ${enterprise_id}/${subPath} => ${targetUrl}`);

      const parsedUrl = new URL(targetUrl);
      const isHttps = parsedUrl.protocol === 'https:';
      const httpModule = isHttps ? https : http;

      // 构建请求头 - 直接转发原始请求头中的关键字段
      const headers = {};
      if (req.headers['content-type']) headers['content-type'] = req.headers['content-type'];
      if (req.headers['authorization']) headers['authorization'] = req.headers['authorization'];
      if (req.headers['accept']) headers['accept'] = req.headers['accept'];
      if (req.headers['content-length']) headers['content-length'] = req.headers['content-length'];
      headers['host'] = parsedUrl.host;

      const options = {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (isHttps ? 443 : 80),
        path: parsedUrl.pathname + (parsedUrl.search || ''),
        method: req.method,
        headers: headers,
        timeout: 120000,
        rejectUnauthorized: false
      };

      const proxyReq = httpModule.request(options, (proxyRes) => {
        // 转发响应头
        const responseHeaders = {};
        if (proxyRes.headers['content-type']) responseHeaders['content-type'] = proxyRes.headers['content-type'];
        if (proxyRes.headers['content-disposition']) responseHeaders['content-disposition'] = proxyRes.headers['content-disposition'];
        if (proxyRes.headers['content-length']) responseHeaders['content-length'] = proxyRes.headers['content-length'];

        res.writeHead(proxyRes.statusCode || 200, responseHeaders);
        // 流式转发响应体
        proxyRes.pipe(res);
      });

      proxyReq.on('error', (err) => {
        console.error(`[Proxy Error] ${err.message}`);
        if (!res.headersSent) {
          res.json({ code: 502, message: '企业服务器连接失败: ' + err.message });
        }
      });

      proxyReq.on('timeout', () => {
        proxyReq.destroy();
        if (!res.headersSent) {
          res.json({ code: 504, message: '企业服务器响应超时' });
        }
      });

      // 所有请求（包括JSON和文件上传）都使用流式转发
      // 因为此路由注册在express.json()之前，req的原始body流未被消耗
      if (req.method !== 'GET' && req.method !== 'HEAD') {
        req.pipe(proxyReq);
      } else {
        proxyReq.end();
      }

    } catch (err) {
      console.error(`[Proxy Error] ${err.message}`);
      if (!res.headersSent) {
        res.json({ code: 500, message: '代理服务错误: ' + err.message });
      }
    }
  });

  return router;
};
