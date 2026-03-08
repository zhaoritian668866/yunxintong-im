const express = require('express');
const router = express.Router();
const { db } = require('../models/database');

// 公用前端：验证企业ID并返回企业API地址
// 前端拿到api_url后，后续所有请求直接发到企业服务器
router.post('/resolve', (req, res) => {
  try {
    const { enterprise_id } = req.body;
    if (!enterprise_id) return res.json({ code: 400, message: '请输入企业ID' });

    const tenant = db.prepare(
      'SELECT enterprise_id, name, api_url, ws_url, status, deploy_status FROM tenants WHERE enterprise_id = ?'
    ).get(enterprise_id);

    if (!tenant) return res.json({ code: 404, message: '企业ID不存在，请联系管理员获取' });
    if (tenant.status !== 'active') return res.json({ code: 403, message: '该企业已被停用，请联系管理员' });
    if (tenant.deploy_status !== 'deployed' || !tenant.api_url) {
      return res.json({ code: 503, message: '该企业服务尚未部署完成，请联系管理员' });
    }

    res.json({
      code: 200,
      message: '验证成功',
      data: {
        enterprise_id: tenant.enterprise_id,
        name: tenant.name,
        api_url: tenant.api_url,
        ws_url: tenant.ws_url
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误: ' + err.message });
  }
});

module.exports = router;
