const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { verifyToken } = require('../middleware/auth');
const { uploadDir } = require('../models/database');

// 配置multer存储
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    let subDir = 'files';
    const mime = file.mimetype || '';
    if (mime.startsWith('image/')) subDir = 'images';
    else if (mime.startsWith('video/')) subDir = 'videos';
    else if (mime.startsWith('audio/') || file.originalname.match(/\.(wav|mp3|m4a|ogg|webm|aac)$/i)) subDir = 'voices';
    const dir = path.join(uploadDir, subDir);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.bin';
    cb(null, `${uuidv4()}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 500 * 1024 * 1024 }, // 500MB
  fileFilter: (req, file, cb) => {
    // 允许图片、视频、音频、常见文件
    const allowedMimes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp', 'image/svg+xml',
      'video/mp4', 'video/quicktime', 'video/webm', 'video/x-msvideo', 'video/x-matroska',
      'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/webm', 'audio/aac', 'audio/mp4', 'audio/x-m4a',
      'application/pdf', 'application/msword', 'application/zip',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain', 'application/octet-stream'
    ];
    if (allowedMimes.includes(file.mimetype) || file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/') || file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(null, true); // 允许所有类型，由前端控制
    }
  }
});

// 单文件上传
router.post('/single', verifyToken, upload.single('file'), (req, res) => {
  try {
    if (!req.file) return res.json({ code: 400, message: '没有上传文件' });
    const file = req.file;
    const relativePath = path.relative(path.join(__dirname, '..'), file.path).replace(/\\/g, '/');
    const fileUrl = `/uploads/${relativePath.replace('uploads/', '')}`;
    res.json({
      code: 200,
      message: '上传成功',
      data: {
        url: fileUrl,
        file_url: fileUrl,
        filename: file.originalname,
        size: file.size,
        mimetype: file.mimetype,
      }
    });
  } catch (err) { res.status(500).json({ code: 500, message: '上传失败: ' + err.message }); }
});

// 多文件上传（最多9张图片）
router.post('/images', verifyToken, upload.array('images', 9), (req, res) => {
  try {
    if (!req.files || req.files.length === 0) return res.json({ code: 400, message: '没有上传图片' });
    const results = req.files.map(file => {
      const relativePath = path.relative(path.join(__dirname, '..'), file.path).replace(/\\/g, '/');
      const fileUrl = `/uploads/${relativePath.replace('uploads/', '')}`;
      return {
        url: fileUrl,
        file_url: fileUrl,
        filename: file.originalname,
        size: file.size,
        mimetype: file.mimetype,
      };
    });
    res.json({ code: 200, message: '上传成功', data: results });
  } catch (err) { res.status(500).json({ code: 500, message: '上传失败: ' + err.message }); }
});

// 语音上传
router.post('/voice', verifyToken, upload.single('file'), (req, res) => {
  try {
    if (!req.file) return res.json({ code: 400, message: '没有上传语音文件' });
    const file = req.file;
    const relativePath = path.relative(path.join(__dirname, '..'), file.path).replace(/\\/g, '/');
    const fileUrl = `/uploads/${relativePath.replace('uploads/', '')}`;
    res.json({
      code: 200,
      message: '上传成功',
      data: {
        url: fileUrl,
        file_url: fileUrl,
        filename: file.originalname,
        size: file.size,
        duration: parseInt(req.body.duration) || 0,
        mimetype: file.mimetype,
      }
    });
  } catch (err) { res.status(500).json({ code: 500, message: '上传失败: ' + err.message }); }
});

module.exports = router;
