const express = require('express');
const router = express.Router();
const { db } = require('../models/database');

// 解析企业ID → 获取企业服务器地址
// 前端拿到api_url后，后续所有请求通过代理转发到企业真实服务器
router.post('/resolve', (req, res) => {
  try {
    const { enterprise_id } = req.body;
    if (!enterprise_id) return res.json({ code: 400, message: '请输入企业ID' });

    const eid = enterprise_id.trim().toUpperCase();
    const tenant = db.prepare(
      'SELECT enterprise_id, name, api_url, ws_url, status, deploy_status FROM tenants WHERE enterprise_id = ?'
    ).get(eid);

    if (!tenant) return res.json({ code: 404, message: '企业ID不存在，请检查后重试' });
    if (tenant.status !== 'active') return res.json({ code: 403, message: '该企业已被停用，请联系管理员' });
    if (tenant.deploy_status !== 'deployed' || !tenant.api_url) {
      return res.json({ code: 503, message: '该企业服务尚未部署完成，请稍后再试' });
    }

    res.json({
      code: 200,
      message: '验证成功',
      data: {
        enterprise_id: tenant.enterprise_id,
        name: tenant.name,
        api_url: tenant.api_url,
        ws_url: tenant.ws_url || ''
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

module.exports = router;
