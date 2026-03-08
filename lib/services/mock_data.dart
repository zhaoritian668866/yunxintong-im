import '../models/models.dart';

class MockData {
  // ==================== 会话列表 ====================
  static List<Conversation> get conversations => [
    Conversation(id: '1', name: '产品部群组', avatar: '', lastMessage: '大家记得提交周报！', lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)), unreadCount: 3, isGroup: true, isPinned: true),
    Conversation(id: '2', name: '李明', avatar: '', lastMessage: '下周一下午的会议能参加吗？', lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)), unreadCount: 12, isPinned: true),
    Conversation(id: '3', name: '项目讨论组', avatar: '', lastMessage: '新版设计稿已更新，请查收', lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)), unreadCount: 1, isGroup: true),
    Conversation(id: '4', name: '王芳', avatar: '', lastMessage: '好的，我收到了。', lastMessageTime: DateTime.now().subtract(const Duration(days: 1))),
    Conversation(id: '5', name: '张伟', avatar: '', lastMessage: '周末一起去爬山吗？', lastMessageTime: DateTime.now().subtract(const Duration(days: 1))),
    Conversation(id: '6', name: '技术团队', avatar: '', lastMessage: '服务器维护通知：今晚12点', lastMessageTime: DateTime.now().subtract(const Duration(days: 2)), isGroup: true),
    Conversation(id: '7', name: '赵丽', avatar: '', lastMessage: '生日快乐！', lastMessageTime: DateTime.now().subtract(const Duration(days: 2))),
    Conversation(id: '8', name: '全体通知', avatar: '', lastMessage: '公司年会定于下个月15日举行', lastMessageTime: DateTime.now().subtract(const Duration(days: 3)), isGroup: true),
  ];

  // ==================== 聊天消息 ====================
  static List<Message> getChatMessages(String conversationId) {
    if (conversationId == '2') {
      return [
        Message(id: '1', senderId: 'liming', senderName: '李明', content: '你好，明天的会议准备好了吗？', timestamp: DateTime.now().subtract(const Duration(minutes: 30))),
        Message(id: '2', senderId: 'me', senderName: '我', content: '已经准备好了，我把文档发给你', timestamp: DateTime.now().subtract(const Duration(minutes: 28)), isMe: true),
        Message(id: '3', senderId: 'liming', senderName: '李明', content: '好的，谢谢！', timestamp: DateTime.now().subtract(const Duration(minutes: 27))),
        Message(id: '4', senderId: 'me', senderName: '我', content: '会议记录_2024.pdf', type: MessageType.file, fileName: '会议记录_2024.pdf', timestamp: DateTime.now().subtract(const Duration(minutes: 25)), isMe: true),
        Message(id: '5', senderId: 'liming', senderName: '李明', content: '收到了，我看一下', timestamp: DateTime.now().subtract(const Duration(minutes: 20))),
        Message(id: '6', senderId: 'me', senderName: '我', content: '好的，有问题随时找我', timestamp: DateTime.now().subtract(const Duration(minutes: 15)), isMe: true),
      ];
    }
    if (conversationId == '1') {
      return [
        Message(id: '1', senderId: 'wangfang', senderName: '王芳', content: '大家记得提交周报！', timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
        Message(id: '2', senderId: 'liming', senderName: '李明', content: '收到，我下午提交', timestamp: DateTime.now().subtract(const Duration(minutes: 8))),
        Message(id: '3', senderId: 'me', senderName: '张伟', content: '已提交了', timestamp: DateTime.now().subtract(const Duration(minutes: 7)), isMe: true),
        Message(id: '4', senderId: 'zhaoli', senderName: '赵丽', content: '好的，我也马上', timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
        Message(id: '5', senderId: 'wangfang', senderName: '王芳', content: '', type: MessageType.voice, voiceDuration: 15, timestamp: DateTime.now().subtract(const Duration(minutes: 3))),
      ];
    }
    return [
      Message(id: '1', senderId: 'other', senderName: '对方', content: '你好！', timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
      Message(id: '2', senderId: 'me', senderName: '我', content: '你好，有什么事吗？', timestamp: DateTime.now().subtract(const Duration(minutes: 8)), isMe: true),
    ];
  }

  // ==================== 联系人列表 ====================
  static List<Contact> get contacts => [
    Contact(id: '1', name: '白雪', department: '财务部', position: '会计', isOnline: true, pinyin: 'B'),
    Contact(id: '2', name: '陈静', department: '人事部', position: '人事专员', isOnline: true, pinyin: 'C'),
    Contact(id: '3', name: '曹磊', department: '技术部', position: '后端工程师', isOnline: false, pinyin: 'C'),
    Contact(id: '4', name: '陈强', department: '研发部', position: '前端工程师', isOnline: true, pinyin: 'C'),
    Contact(id: '5', name: '李明', department: '研发部', position: '高级工程师', isOnline: true, pinyin: 'L'),
    Contact(id: '6', name: '李娜', department: '市场部', position: '市场经理', isOnline: false, pinyin: 'L'),
    Contact(id: '7', name: '刘军', department: '技术支持', position: '技术支持', isOnline: true, pinyin: 'L'),
    Contact(id: '8', name: '王芳', department: '产品部', position: '产品经理', isOnline: true, pinyin: 'W'),
    Contact(id: '9', name: '王强', department: '销售部', position: '销售主管', isOnline: false, pinyin: 'W'),
    Contact(id: '10', name: '张伟', department: '研发部', position: '高级工程师', isOnline: true, pinyin: 'Z'),
    Contact(id: '11', name: '赵丽', department: '行政部', position: '行政助理', isOnline: true, pinyin: 'Z'),
  ];

  // ==================== 租户列表 ====================
  static List<Tenant> get tenants => [
    Tenant(id: '1', enterpriseId: 'ENT-001', name: '创新科技有限公司', contactPerson: '张伟', contactPhone: '13800138001', serverIp: '192.168.1.10', status: TenantStatus.running, createdAt: DateTime(2024, 1, 15), expiresAt: DateTime(2025, 12, 31), employeeCount: 256),
    Tenant(id: '2', enterpriseId: 'ENT-002', name: '环球信息技术', contactPerson: '李娜', contactPhone: '13800138002', serverIp: '192.168.1.11', status: TenantStatus.running, createdAt: DateTime(2024, 3, 20), expiresAt: DateTime(2025, 11, 15), employeeCount: 128),
    Tenant(id: '3', enterpriseId: 'ENT-003', name: '未来通信集团', contactPerson: '王强', contactPhone: '13800138003', serverIp: '192.168.1.12', status: TenantStatus.stopped, createdAt: DateTime(2024, 5, 10), expiresAt: DateTime(2024, 10, 1), employeeCount: 512),
    Tenant(id: '4', enterpriseId: 'ENT-004', name: '云端互联网络', contactPerson: '刘洋', contactPhone: '13800138004', serverIp: '192.168.1.13', status: TenantStatus.running, createdAt: DateTime(2024, 7, 1), expiresAt: DateTime(2026, 1, 20), employeeCount: 64),
    Tenant(id: '5', enterpriseId: 'ENT-005', name: '蓝天信息系统', contactPerson: '陈静', contactPhone: '13800138005', serverIp: '192.168.1.14', status: TenantStatus.running, createdAt: DateTime(2024, 8, 15), expiresAt: DateTime(2025, 9, 30), employeeCount: 96),
    Tenant(id: '6', enterpriseId: 'ENT-006', name: '卓越网络服务', contactPerson: '周杰', contactPhone: '13800138006', serverIp: '192.168.1.15', status: TenantStatus.stopped, createdAt: DateTime(2024, 2, 28), expiresAt: DateTime(2024, 12, 1), employeeCount: 32),
  ];

  // ==================== 服务器列表 ====================
  static List<ServerInfo> get servers => [
    ServerInfo(id: '1', name: '服务器-01', ip: '192.168.1.10', status: ServerStatus.online, cpuUsage: 65, memoryUsage: 48, diskUsage: 72, tenantName: '创新科技有限公司'),
    ServerInfo(id: '2', name: '服务器-02', ip: '192.168.1.11', status: ServerStatus.offline, cpuUsage: 5, memoryUsage: 10, diskUsage: 30, tenantName: '环球信息技术'),
    ServerInfo(id: '3', name: '服务器-03', ip: '192.168.1.12', status: ServerStatus.online, cpuUsage: 78, memoryUsage: 60, diskUsage: 50, tenantName: '未来通信集团'),
    ServerInfo(id: '4', name: '服务器-04', ip: '192.168.1.13', status: ServerStatus.online, cpuUsage: 40, memoryUsage: 35, diskUsage: 68, tenantName: '云端互联网络'),
    ServerInfo(id: '5', name: '服务器-05', ip: '192.168.1.14', status: ServerStatus.online, cpuUsage: 55, memoryUsage: 50, diskUsage: 45, tenantName: '蓝天信息系统'),
    ServerInfo(id: '6', name: '服务器-06', ip: '192.168.1.15', status: ServerStatus.offline, cpuUsage: 2, memoryUsage: 8, diskUsage: 20, tenantName: '卓越网络服务'),
  ];

  // ==================== 员工列表 ====================
  static List<Employee> get employees => [
    Employee(id: '1', name: '李强', employeeNo: '10001', department: '研发部', position: '高级工程师', isOnline: true, deviceCount: 3),
    Employee(id: '2', name: '王芳', employeeNo: '10002', department: '市场部', position: '市场经理', isOnline: true, deviceCount: 2),
    Employee(id: '3', name: '张伟', employeeNo: '10003', department: '销售部', position: '销售主管', isOnline: false, deviceCount: 1),
    Employee(id: '4', name: '赵丽', employeeNo: '10004', department: '人事部', position: '人事专员', isOnline: true, deviceCount: 2),
    Employee(id: '5', name: '刘军', employeeNo: '10005', department: '技术支持部', position: '技术支持', isOnline: false, deviceCount: 1),
    Employee(id: '6', name: '陈静', employeeNo: '10006', department: '财务部', position: '会计', isOnline: true, deviceCount: 2),
    Employee(id: '7', name: '杨勇', employeeNo: '10007', department: '行政部', position: '行政助理', isOnline: false, deviceCount: 1),
  ];

  // ==================== 部门列表 ====================
  static List<Department> get departments => [
    Department(id: '1', name: '研发部', memberCount: 45, managerName: '李强'),
    Department(id: '2', name: '市场部', memberCount: 28, managerName: '王芳'),
    Department(id: '3', name: '销售部', memberCount: 35, managerName: '张伟'),
    Department(id: '4', name: '人事部', memberCount: 12, managerName: '赵丽'),
    Department(id: '5', name: '技术支持部', memberCount: 18, managerName: '刘军'),
    Department(id: '6', name: '财务部', memberCount: 8, managerName: '陈静'),
    Department(id: '7', name: '行政部', memberCount: 10, managerName: '杨勇'),
  ];
}
