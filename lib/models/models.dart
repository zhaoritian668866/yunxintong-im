// ==================== 用户模型 ====================
class User {
  final String id;
  final String name;
  final String avatar;
  final String phone;
  final String email;
  final String department;
  final String position;
  final bool isOnline;
  final int deviceCount;

  User({
    required this.id,
    required this.name,
    this.avatar = '',
    this.phone = '',
    this.email = '',
    this.department = '',
    this.position = '',
    this.isOnline = false,
    this.deviceCount = 1,
  });
}

// ==================== 消息模型 ====================
enum MessageType { text, image, file, voice, system }

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isMe;
  final String? fileName;
  final int? voiceDuration;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = '',
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isMe = false,
    this.fileName,
    this.voiceDuration,
  });
}

// ==================== 会话模型 ====================
class Conversation {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final bool isPinned;

  Conversation({
    required this.id,
    required this.name,
    this.avatar = '',
    this.lastMessage = '',
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.isPinned = false,
  });
}

// ==================== 联系人模型 ====================
class Contact {
  final String id;
  final String name;
  final String avatar;
  final String department;
  final String position;
  final bool isOnline;
  final String pinyin;

  Contact({
    required this.id,
    required this.name,
    this.avatar = '',
    this.department = '',
    this.position = '',
    this.isOnline = false,
    this.pinyin = '',
  });
}

// ==================== 租户模型 ====================
enum TenantStatus { running, stopped, deploying, error }

class Tenant {
  final String id;
  final String enterpriseId;
  final String name;
  final String contactPerson;
  final String contactPhone;
  final String serverIp;
  final TenantStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int employeeCount;

  Tenant({
    required this.id,
    required this.enterpriseId,
    required this.name,
    this.contactPerson = '',
    this.contactPhone = '',
    this.serverIp = '',
    this.status = TenantStatus.stopped,
    required this.createdAt,
    required this.expiresAt,
    this.employeeCount = 0,
  });
}

// ==================== 服务器模型 ====================
enum ServerStatus { online, offline, maintenance }

class ServerInfo {
  final String id;
  final String name;
  final String ip;
  final int port;
  final ServerStatus status;
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final String? tenantName;
  final String? tenantId;

  ServerInfo({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 22,
    this.status = ServerStatus.offline,
    this.cpuUsage = 0,
    this.memoryUsage = 0,
    this.diskUsage = 0,
    this.tenantName,
    this.tenantId,
  });
}

// ==================== 员工模型 ====================
class Employee {
  final String id;
  final String name;
  final String employeeNo;
  final String department;
  final String position;
  final String phone;
  final String avatar;
  final bool isOnline;
  final int deviceCount;
  final bool isEnabled;

  Employee({
    required this.id,
    required this.name,
    required this.employeeNo,
    this.department = '',
    this.position = '',
    this.phone = '',
    this.avatar = '',
    this.isOnline = false,
    this.deviceCount = 1,
    this.isEnabled = true,
  });
}

// ==================== 部门模型 ====================
class Department {
  final String id;
  final String name;
  final int memberCount;
  final String? parentId;
  final String? managerName;

  Department({
    required this.id,
    required this.name,
    this.memberCount = 0,
    this.parentId,
    this.managerName,
  });
}
