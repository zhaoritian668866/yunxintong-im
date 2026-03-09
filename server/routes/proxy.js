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

module.exports = function(rawBodyEnabled) {
  // 通用代理转发（支持所有Content-Type，包括multipart/form-data文件上传）
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
        // 去掉 api_url 末尾的 /api，直接访问根路径
        const baseUrl = targetUrl.replace(/\/api\/?$/, '');
        targetUrl = `${baseUrl}/${subPath}`;
      } else {
        targetUrl = `${targetUrl}/${subPath}`;
      }
      if (queryString) targetUrl += '?' + queryString;

      const contentType = req.headers['content-type'] || '';
      const isFileUpload = contentType.includes('multipart/form-data');

      console.log(`[Proxy] ${req.method} ${enterprise_id}/${subPath} => ${targetUrl}${isFileUpload ? ' [FILE UPLOAD]' : ''}`);

      const parsedUrl = new URL(targetUrl);
      const isHttps = parsedUrl.protocol === 'https:';
      const httpModule = isHttps ? https : http;

      // 构建请求头
      const headers = {};
      // 转发关键头部
      if (req.headers['content-type']) headers['content-type'] = req.headers['content-type'];
      if (req.headers['authorization']) headers['authorization'] = req.headers['authorization'];
      if (req.headers['accept']) headers['accept'] = req.headers['accept'];
      headers['host'] = parsedUrl.host;

      // 对于非文件上传的JSON请求，需要序列化body
      let bodyData = null;
      if (!isFileUpload && req.body && Object.keys(req.body).length > 0) {
        bodyData = JSON.stringify(req.body);
        headers['content-type'] = 'application/json';
        headers['content-length'] = Buffer.byteLength(bodyData).toString();
      } else if (isFileUpload && req.headers['content-length']) {
        headers['content-length'] = req.headers['content-length'];
      }

      const options = {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (isHttps ? 443 : 80),
        path: parsedUrl.pathname + (parsedUrl.search || ''),
        method: req.method,
        headers: headers,
        timeout: 120000, // 文件上传需要更长超时
        rejectUnauthorized: false
      };

      const proxyReq = httpModule.request(options, (proxyRes) => {
        // 转发响应头
        const responseHeaders = {};
        if (proxyRes.headers['content-type']) responseHeaders['content-type'] = proxyRes.headers['content-type'];
        if (proxyRes.headers['content-disposition']) responseHeaders['content-disposition'] = proxyRes.headers['content-disposition'];

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

      if (isFileUpload) {
        // 文件上传：使用原始请求体流式转发
        if (req.rawBody) {
          // 如果有rawBody缓冲区，直接写入
          proxyReq.write(req.rawBody);
          proxyReq.end();
        } else {
          // 流式管道转发
          req.pipe(proxyReq);
        }
      } else if (bodyData) {
        proxyReq.write(bodyData);
        proxyReq.end();
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
