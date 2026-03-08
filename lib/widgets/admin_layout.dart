import 'package:flutter/material.dart';
import '../config/theme.dart';

class AdminMenuItem {
  final IconData icon;
  final String label;
  final String route;
  const AdminMenuItem({required this.icon, required this.label, required this.route});
}

class AdminLayout extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<AdminMenuItem> menuItems;
  final int selectedIndex;
  final ValueChanged<int> onMenuSelected;
  final Widget body;
  final VoidCallback? onLogout;

  const AdminLayout({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.menuItems,
    required this.selectedIndex,
    required this.onMenuSelected,
    required this.body,
    this.onLogout,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        drawer: _buildDrawer(),
        body: widget.body,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // 侧边栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 72 : 240,
            child: _buildSidebar(),
          ),
          // 主内容
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo区域
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        if (widget.subtitle.isNotEmpty)
                          Text(widget.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // 菜单项
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.menuItems.length,
              itemBuilder: (context, index) {
                final item = widget.menuItems[index];
                final isSelected = index == widget.selectedIndex;
                return Tooltip(
                  message: _sidebarCollapsed ? item.label : '',
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 8 : 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.sidebarActive.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 16),
                      leading: Icon(item.icon, color: isSelected ? AppColors.primaryLight : AppColors.sidebarText, size: 20),
                      title: _sidebarCollapsed ? null : Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.sidebarText,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      onTap: () => widget.onMenuSelected(index),
                    ),
                  ),
                );
              },
            ),
          ),
          // 收起按钮
          Container(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              icon: Icon(
                _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: AppColors.sidebarText,
              ),
              onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Text(
            widget.menuItems[widget.selectedIndex].label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: const Text('管', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          if (widget.onLogout != null) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('退出'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.sidebarBg,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              ...widget.menuItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == widget.selectedIndex;
                return ListTile(
                  leading: Icon(item.icon, color: isSelected ? AppColors.primaryLight : AppColors.sidebarText),
                  title: Text(item.label, style: TextStyle(color: isSelected ? Colors.white : AppColors.sidebarText)),
                  selected: isSelected,
                  selectedTileColor: AppColors.sidebarActive.withValues(alpha: 0.2),
                  onTap: () {
                    widget.onMenuSelected(index);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
