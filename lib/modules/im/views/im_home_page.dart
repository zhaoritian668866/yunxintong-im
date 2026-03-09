import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../services/ws_service.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'workbench_page.dart';
import 'profile_page.dart';
import 'call_page.dart';

class ImHomePage extends StatefulWidget {
  const ImHomePage({super.key});

  @override
  State<ImHomePage> createState() => _ImHomePageState();
}

class _ImHomePageState extends State<ImHomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _totalUnread = 0;
  Timer? _unreadTimer;
  Map<String, dynamic> _features = {};
  bool _featuresLoaded = false;

  bool get _enableWorkbench {
    final v = _features['enable_workbench'];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return true;
  }

  List<Widget> get _pages => [
    const ChatListPage(),
    const ContactsPage(),
    if (_enableWorkbench) const WorkbenchPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeatures();
    _loadUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadUnreadCount();
    });

    // 连接WebSocket并设置来电回调
    _connectWebSocket();
  }

  /// 连接WebSocket并监听来电
  void _connectWebSocket() {
    final ws = WsService.instance;

    // 设置来电回调
    ws.onCallOffer = _handleIncomingCall;

    // 连接
    ws.connect();
  }

  /// 处理来电
  void _handleIncomingCall(Map<String, dynamic> data) {
    if (!mounted) return;

    final fromUserId = data['from_user_id'] ?? '';
    final callType = data['call_type'] ?? 'voice';
    final sdp = data['sdp'] ?? '';

    if (fromUserId.isEmpty || sdp.isEmpty) return;

    // 弹出来电页面
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallPage(
        targetUserId: fromUserId,
        targetUserName: fromUserId, // 暂时用userId，后续可以查询用户信息
        callType: callType == 'video' ? CallType.video : CallType.voice,
        isIncoming: true,
        incomingOffer: data,
      ),
    ));
  }

  Future<void> _loadFeatures() async {
    final res = await ApiService.getFeatures();
    if (mounted && res.isSuccess && res.data != null) {
      setState(() {
        _features = Map<String, dynamic>.from(res.data);
        _featuresLoaded = true;
        if (_currentIndex >= _pages.length) _currentIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadUnreadCount();
      // 恢复时重连WebSocket
      if (!WsService.instance.isConnected) {
        WsService.instance.reconnect();
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    final res = await ApiService.getConversations();
    if (res.isSuccess && res.data != null) {
      int total = 0;
      final rawData = res.data;
      final convList = rawData is List ? rawData : (rawData is Map ? (rawData['conversations'] ?? rawData['list'] ?? []) : []);
      for (var c in (convList as List? ?? [])) {
        total += (c['unread_count'] as int? ?? 0);
      }
      if (mounted && total != _totalUnread) {
        setState(() => _totalUnread = total);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 0) _loadUnreadCount();
          },
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.chat_bubble_outline, 0, badgeCount: _totalUnread),
              activeIcon: _buildNavIcon(Icons.chat_bubble, 0, active: true, badgeCount: _totalUnread),
              label: '消息',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.contacts_outlined, 1),
              activeIcon: _buildNavIcon(Icons.contacts, 1, active: true),
              label: '通讯录',
            ),
            if (_enableWorkbench)
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.grid_view_outlined, 2),
                activeIcon: _buildNavIcon(Icons.grid_view, 2, active: true),
                label: '工作台',
              ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person_outline, _enableWorkbench ? 3 : 2),
              activeIcon: _buildNavIcon(Icons.person, _enableWorkbench ? 3 : 2, active: true),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool active = false, int badgeCount = 0}) {
    Widget iconWidget = Icon(icon, size: 24, color: active ? AppColors.primary : AppColors.textSecondary);
    if (badgeCount > 0 && index == 0) {
      return Badge(label: Text(badgeCount > 99 ? '99+' : '$badgeCount', style: const TextStyle(fontSize: 10, color: Colors.white)), child: iconWidget);
    }
    return iconWidget;
  }
}
