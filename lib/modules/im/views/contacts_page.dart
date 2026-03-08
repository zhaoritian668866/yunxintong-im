import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = MockData.contacts;
    // 按拼音分组
    final Map<String, List<Contact>> grouped = {};
    for (final c in contacts) {
      grouped.putIfAbsent(c.pinyin, () => []).add(c);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          // 快捷入口
          Container(
            color: AppColors.cardBg,
            child: Column(
              children: [
                _buildQuickEntry(Icons.group, '群组', AppColors.primary, '5'),
                const Divider(height: 0.5, indent: 56),
                _buildQuickEntry(Icons.business, '部门', AppColors.success, '7'),
                const Divider(height: 0.5, indent: 56),
                _buildQuickEntry(Icons.person_add, '新的好友', AppColors.warning, '2'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 联系人列表
          ...sortedKeys.map((key) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: AppColors.background,
                  child: Text(key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                ...grouped[key]!.map((contact) => _ContactTile(contact: contact)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickEntry(IconData icon, String title, Color color, String count) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
      onTap: () {},
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBg,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                contact.name.isNotEmpty ? contact.name[0] : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: contact.isOnline ? AppColors.online : AppColors.offline,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBg, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        title: Text(contact.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${contact.department} | ${contact.position}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        onTap: () {},
      ),
    );
  }
}
