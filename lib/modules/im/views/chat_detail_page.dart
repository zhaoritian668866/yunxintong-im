import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import 'emoji_picker_widget.dart';
import 'image_preview_page.dart';
import 'call_page.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final String? conversationName;
  final String? conversationType;
  final String? targetUserId;
  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.title = '',
    this.conversationName,
    this.conversationType,
    this.targetUserId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String _currentUserId = '';
  Timer? _refreshTimer;

  // 功能开关
  Map<String, dynamic> _features = {};
  bool get _enableVoiceMessage => _features['enable_voice_message'] != false;
  bool get _enableImageSend => _features['enable_image_send'] != false;
  bool get _enableVideoSend => _features['enable_video_send'] != false;
  bool get _enableEmoji => _features['enable_emoji'] != false;
  bool get _enableVoiceCall => _features['enable_voice_call'] != false;
  bool get _enableVideoCall => _features['enable_video_call'] != false;
  bool get _enableFileSend => _features['enable_file_send'] != false;

  // 附件面板
  bool _showAttachPanel = false;
  bool _showEmojiPanel = false;

  // 已选图片（用于多图发送）
  List<PlatformFile> _selectedImages = [];

  String get _displayTitle => widget.title.isNotEmpty ? widget.title : (widget.conversationName ?? '');

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMessages();
    _loadFeatures();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.userProfile();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _currentUserId = res.data['id'] ?? ''; });
    }
  }

  Future<void> _loadFeatures() async {
    final res = await ApiService.getFeatures();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _features = Map<String, dynamic>.from(res.data); });
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; });
    final res = await ApiService.getMessages(widget.conversationId);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      final rawData = res.data;
      List list = [];
      if (rawData is Map) {
        list = rawData['list'] ?? rawData['messages'] ?? [];
      } else if (rawData is List) {
        list = rawData;
      }
      final oldLen = _messages.length;
      setState(() { _messages = list; _loading = false; });
      if (!silent || list.length > oldLen) _scrollToBottom();
    } else {
      setState(() { _loading = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // 发送纯文本消息
  Future<void> _sendTextMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;

    // 如果有选中的图片，发送图文混合消息
    if (_selectedImages.isNotEmpty) {
      await _sendMixedMessage(text);
      return;
    }

    setState(() { _sending = true; });
    _msgController.clear();
    final res = await ApiService.sendMessage(widget.conversationId, text);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() { _messages.add(res.data); _sending = false; });
      _scrollToBottom();
    } else {
      setState(() { _sending = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: ${res.message}'), behavior: SnackBarBehavior.floating));
    }
  }

  // 发送图文混合消息
  Future<void> _sendMixedMessage(String text) async {
    setState(() { _sending = true; });
    _msgController.clear();

    // 先上传所有图片
    final imageUrls = <String>[];
    for (final file in _selectedImages) {
      if (file.bytes != null) {
        final uploadRes = await ApiService.uploadFile(file.bytes!, file.name, type: 'images');
        if (uploadRes.isSuccess && uploadRes.data != null) {
          imageUrls.add(uploadRes.data['url'] ?? uploadRes.data['file_url'] ?? '');
        }
      }
    }

    if (imageUrls.isEmpty && text.isEmpty) {
      setState(() { _sending = false; _selectedImages = []; });
      return;
    }

    final res = await ApiService.sendMessage(
      widget.conversationId,
      text,
      type: imageUrls.isNotEmpty ? 'mixed' : 'text',
      images: imageUrls.isNotEmpty ? imageUrls : null,
    );

    if (!mounted) return;
    setState(() { _sending = false; _selectedImages = []; });
    if (res.isSuccess && res.data != null) {
      setState(() { _messages.add(res.data); });
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: ${res.message}'), behavior: SnackBarBehavior.floating));
    }
  }

  // 选择图片
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        // 最多9张
        final remaining = 9 - _selectedImages.length;
        _selectedImages.addAll(result.files.take(remaining));
        _showAttachPanel = false;
      });
    }
  }

  // 直接发送图片（不带文字）
  Future<void> _sendImages() async {
    if (_selectedImages.isEmpty) return;
    await _sendMixedMessage(_msgController.text.trim());
  }

  // 选择并发送视频
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() { _sending = true; _showAttachPanel = false; });
      final uploadRes = await ApiService.uploadFile(file.bytes!, file.name, type: 'videos');
      if (!mounted) return;
      if (uploadRes.isSuccess && uploadRes.data != null) {
        final fileUrl = uploadRes.data['url'] ?? uploadRes.data['file_url'] ?? '';
        final res = await ApiService.sendMessage(widget.conversationId, '[视频]', type: 'video', fileUrl: fileUrl, fileName: file.name);
        if (res.isSuccess && res.data != null) {
          setState(() { _messages.add(res.data); });
          _scrollToBottom();
        }
      }
      setState(() { _sending = false; });
    }
  }

  // 选择并发送文件
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() { _sending = true; _showAttachPanel = false; });
      final uploadRes = await ApiService.uploadFile(file.bytes!, file.name, type: 'files');
      if (!mounted) return;
      if (uploadRes.isSuccess && uploadRes.data != null) {
        final fileUrl = uploadRes.data['url'] ?? uploadRes.data['file_url'] ?? '';
        final res = await ApiService.sendMessage(widget.conversationId, '[文件] ${file.name}', type: 'file', fileUrl: fileUrl, fileName: file.name);
        if (res.isSuccess && res.data != null) {
          setState(() { _messages.add(res.data); });
          _scrollToBottom();
        }
      }
      setState(() { _sending = false; });
    }
  }

  // 插入Emoji
  void _insertEmoji(String emoji) {
    final text = _msgController.text;
    final selection = _msgController.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      emoji,
    );
    _msgController.text = newText;
    _msgController.selection = TextSelection.collapsed(
      offset: (selection.start >= 0 ? selection.start : text.length) + emoji.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(_displayTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          if (_enableVoiceCall)
            IconButton(icon: const Icon(Icons.call_outlined, size: 22), onPressed: () => _showCallDialog(false)),
          if (_enableVideoCall)
            IconButton(icon: const Icon(Icons.videocam_outlined, size: 22), onPressed: () => _showCallDialog(true)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() { _showAttachPanel = false; _showEmojiPanel = false; }),
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? Center(child: Text('暂无消息，发送第一条消息吧', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], index),
                  ),
          ),
        ),
        // 已选图片预览
        if (_selectedImages.isNotEmpty) _buildSelectedImagesBar(),
        // 输入栏
        _buildInputBar(),
        // Emoji面板
        if (_showEmojiPanel) EmojiPickerWidget(onEmojiSelected: _insertEmoji, onClose: () => setState(() => _showEmojiPanel = false)),
        // 附件面板
        if (_showAttachPanel) _buildAttachPanel(),
      ]),
    );
  }

  Widget _buildMessageBubble(dynamic msg, int index) {
    final isMe = msg['sender_id'] == _currentUserId;
    final content = msg['content'] ?? '';
    final senderName = msg['sender_name'] ?? '';
    final isRecalled = msg['is_recalled'] == 1;
    final msgType = msg['type'] ?? 'text';
    final time = msg['created_at'] ?? '';

    // 时间分隔
    bool showTime = false;
    String timeStr = '';
    try { final dt = DateTime.parse(time); timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; } catch (_) {}
    if (index == 0) {
      showTime = true;
    } else {
      try {
        final prev = DateTime.parse(_messages[index - 1]['created_at']);
        final curr = DateTime.parse(msg['created_at']);
        showTime = curr.difference(prev).inMinutes > 5;
      } catch (_) {}
    }

    if (isRecalled) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('${isMe ? "你" : senderName} 撤回了一条消息', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))));
    }

    return Column(children: [
      if (showTime) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
          child: Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.15), child: Text(senderName.isNotEmpty ? senderName[0] : '?', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
            ],
            Flexible(child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 2, left: 4), child: Text(senderName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                GestureDetector(
                  onLongPress: () => _showMessageMenu(msg, isMe),
                  child: _buildMessageContent(msg, msgType, content, isMe),
                ),
              ],
            )),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: const Text('我', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _buildMessageContent(dynamic msg, String msgType, String content, bool isMe) {
    final maxWidth = MediaQuery.of(context).size.width * 0.65;
    final bubbleColor = isMe ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    switch (msgType) {
      case 'image':
        final url = msg['file_url'] ?? '';
        return GestureDetector(
          onTap: () => _previewImage(url),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 200),
            decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
            child: ClipRRect(borderRadius: borderRadius, child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(
              width: 150, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey),
            ))),
          ),
        );

      case 'video':
        return Container(
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_circle_filled, color: textColor, size: 36),
            const SizedBox(width: 8),
            Text('[视频消息]', style: TextStyle(fontSize: 14, color: textColor)),
          ]),
        );

      case 'voice':
        final duration = msg['duration'] ?? 0;
        final width = 80.0 + (duration as num).toDouble() * 3;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 80),
          width: width.clamp(80, maxWidth),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic, color: textColor, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('${duration}″', style: TextStyle(fontSize: 14, color: textColor))),
          ]),
        );

      case 'file':
        return Container(
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file, color: textColor, size: 28),
            const SizedBox(width: 8),
            Flexible(child: Text(msg['file_name'] ?? '文件', style: TextStyle(fontSize: 14, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        );

      case 'mixed':
        // 图文混合消息
        List imageUrls = [];
        if (msg['images'] is List) {
          imageUrls = msg['images'];
        } else if (msg['images'] is String) {
          try { imageUrls = jsonDecode(msg['images']); } catch (_) {}
        }
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Text(content, style: TextStyle(fontSize: 15, color: textColor, height: 1.4)),
              ),
            if (imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: _buildImageGrid(imageUrls, maxWidth - 12),
              ),
          ]),
        );

      default: // text
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
          child: Text(content, style: TextStyle(fontSize: 15, color: textColor, height: 1.4)),
        );
    }
  }

  // 图片网格（类似Telegram）
  Widget _buildImageGrid(List imageUrls, double maxWidth) {
    final count = imageUrls.length;
    if (count == 1) {
      return GestureDetector(
        onTap: () => _previewImage(imageUrls[0]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrls[0], fit: BoxFit.cover, height: 180, width: maxWidth,
            errorBuilder: (_, __, ___) => Container(height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))),
      );
    }

    // 多图网格
    final cols = count <= 4 ? 2 : 3;
    final spacing = 3.0;
    final itemWidth = (maxWidth - spacing * (cols - 1)) / cols;
    final itemHeight = itemWidth;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: imageUrls.take(9).toList().asMap().entries.map((entry) {
        final url = entry.value.toString();
        return GestureDetector(
          onTap: () => _previewImage(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(url, fit: BoxFit.cover, width: itemWidth, height: itemHeight,
              errorBuilder: (_, __, ___) => Container(width: itemWidth, height: itemHeight, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 20))),
          ),
        );
      }).toList(),
    );
  }

  void _previewImage(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewPage(imageUrl: url)));
  }

  void _showCallDialog(bool isVideo) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(isVideo ? '视频通话' : '语音通话'),
      content: Text('即将向 $_displayTitle 发起${isVideo ? "视频" : "语音"}通话'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _initiateCall(isVideo); }, child: const Text('呼叫')),
      ],
    ));
  }

  void _initiateCall(bool isVideo) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallPage(
        targetUserId: widget.targetUserId ?? '',
        targetUserName: _displayTitle,
        callType: isVideo ? CallType.video : CallType.voice,
        isIncoming: false,
      ),
    ));
  }

  void _showMessageMenu(dynamic msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.primary),
            title: const Text('复制'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), behavior: SnackBarBehavior.floating));
            },
          ),
          if (isMe) ListTile(
            leading: const Icon(Icons.undo, color: AppColors.warning),
            title: const Text('撤回消息'),
            onTap: () async {
              Navigator.pop(ctx);
              final r = await ApiService.recallMessage(msg['id']);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message), behavior: SnackBarBehavior.floating));
              if (r.isSuccess) _loadMessages(silent: true);
            },
          ),
        ]),
      )),
    );
  }

  // 已选图片预览栏
  Widget _buildSelectedImagesBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + (_selectedImages.length < 9 ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _selectedImages.length) {
            // 添加更多按钮
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 64, height: 64, margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                child: const Icon(Icons.add, color: Colors.grey),
              ),
            );
          }
          final file = _selectedImages[i];
          return Stack(children: [
            Container(
              width: 64, height: 64, margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: file.bytes != null
                  ? Image.memory(Uint8List.fromList(file.bytes!), fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
              ),
            ),
            Positioned(top: 0, right: 0, child: GestureDetector(
              onTap: () => setState(() => _selectedImages.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            )),
          ]);
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: AppColors.cardBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          // Emoji按钮
          if (_enableEmoji)
            IconButton(
              icon: Icon(_showEmojiPanel ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppColors.textSecondary, size: 24),
              onPressed: () => setState(() { _showEmojiPanel = !_showEmojiPanel; _showAttachPanel = false; }),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // 输入框
          Expanded(child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: _selectedImages.isNotEmpty ? '添加文字说明...' : '输入消息...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              maxLines: 4, minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
              onTap: () => setState(() { _showEmojiPanel = false; _showAttachPanel = false; }),
            ),
          )),
          // 附件按钮
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 24),
            onPressed: () => setState(() { _showAttachPanel = !_showAttachPanel; _showEmojiPanel = false; }),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // 发送按钮
          const SizedBox(width: 4),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: IconButton(
              icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sending ? null : _sendTextMessage,
            ),
          ),
        ]),
      ]),
    );
  }

  // 附件面板
  Widget _buildAttachPanel() {
    final items = <_AttachItem>[];
    if (_enableImageSend) items.add(_AttachItem(icon: Icons.photo, label: '图片', color: Colors.green, onTap: _pickImages));
    if (_enableVideoSend) items.add(_AttachItem(icon: Icons.videocam, label: '视频', color: Colors.blue, onTap: _pickVideo));
    if (_enableFileSend) items.add(_AttachItem(icon: Icons.insert_drive_file, label: '文件', color: Colors.orange, onTap: _pickFile));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: items.map((item) => GestureDetector(
          onTap: item.onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        )).toList(),
      ),
    );
  }
}

class _AttachItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _AttachItem({required this.icon, required this.label, required this.color, required this.onTap});
}
