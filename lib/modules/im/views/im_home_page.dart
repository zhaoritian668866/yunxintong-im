import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'workbench_page.dart';
import 'profile_page.dart';

class ImHomePage extends StatefulWidget {
  const ImHomePage({super.key});

  @override
  State<ImHomePage> createState() => _ImHomePageState();
}

class _ImHomePageState extends State<ImHomePage> {
  int _currentIndex = 0;
  int _totalUnread = 0;

  final List<Widget> _pages = const [
    ChatListPage(),
    ContactsPage(),
    WorkbenchPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
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
      if (mounted) setState(() => _totalUnread = total);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
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
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.grid_view_outlined, 2),
              activeIcon: _buildNavIcon(Icons.grid_view, 2, active: true),
              label: '工作台',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person_outline, 3),
              activeIcon: _buildNavIcon(Icons.person, 3, active: true),
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
      return Badge(label: Text('$badgeCount', style: const TextStyle(fontSize: 10, color: Colors.white)), child: iconWidget);
    }
    return iconWidget;
  }
}
