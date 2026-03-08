import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse {
  final int code;
  final String message;
  final dynamic data;
  ApiResponse({required this.code, required this.message, this.data});
  bool get isSuccess => code == 200;
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(code: json['code'] ?? 500, message: json['message'] ?? '', data: json['data']);
  }
}

class ApiService {
  // SaaS平台地址（固定，部署在你的服务器上）
  static String saasBaseUrl = 'https://3000-i2n18dh7l6sqyame3d6u0-92687a5f.sg1.manus.computer/api';

  // 企业API地址（动态，用户输入企业ID后获取）
  static String enterpriseApiUrl = '';
  static String enterpriseWsUrl = '';
  static String enterpriseName = '';

  // 当前用户Token
  static String _userToken = '';
  static String _saasToken = '';
  static String _adminToken = '';

  static void setUserToken(String t) => _userToken = t;
  static void setSaasToken(String t) => _saasToken = t;
  static void setAdminToken(String t) => _adminToken = t;
  static String get userToken => _userToken;
  static String get saasToken => _saasToken;
  static String get adminToken => _adminToken;

  // 持久化存储
  static Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enterprise_api_url', enterpriseApiUrl);
    await prefs.setString('enterprise_ws_url', enterpriseWsUrl);
    await prefs.setString('enterprise_name', enterpriseName);
    await prefs.setString('user_token', _userToken);
    await prefs.setString('saas_token', _saasToken);
    await prefs.setString('admin_token', _adminToken);
  }

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    enterpriseApiUrl = prefs.getString('enterprise_api_url') ?? '';
    enterpriseWsUrl = prefs.getString('enterprise_ws_url') ?? '';
    enterpriseName = prefs.getString('enterprise_name') ?? '';
    _userToken = prefs.getString('user_token') ?? '';
    _saasToken = prefs.getString('saas_token') ?? '';
    _adminToken = prefs.getString('admin_token') ?? '';
  }

  static Future<void> clearUserSession() async {
    _userToken = '';
    enterpriseApiUrl = '';
    enterpriseWsUrl = '';
    enterpriseName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('enterprise_api_url');
    await prefs.remove('enterprise_ws_url');
    await prefs.remove('enterprise_name');
    await prefs.remove('user_token');
  }

  static Future<void> clearSaasSession() async {
    _saasToken = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saas_token');
  }

  static Future<void> clearAdminSession() async {
    _adminToken = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
  }

  // ==================== 通用请求方法 ====================

  static Future<ApiResponse> _request(String method, String url, {Map<String, dynamic>? body, String? token}) async {
    try {
      final uri = Uri.parse(url);
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 15));
      } else if (method == 'PUT') {
        response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 15));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        return ApiResponse(code: 500, message: '不支持的请求方法');
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return ApiResponse.fromJson(json);
    } catch (e) {
      return ApiResponse(code: 500, message: '网络请求失败: $e');
    }
  }

  // ==================== SaaS平台接口 ====================

  /// 解析企业ID → 获取企业API地址
  static Future<ApiResponse> resolveEnterprise(String enterpriseId) async {
    return _request('POST', '$saasBaseUrl/auth/resolve', body: {'enterprise_id': enterpriseId});
  }

  /// SaaS管理员登录
  static Future<ApiResponse> saasLogin(String username, String password) async {
    return _request('POST', '$saasBaseUrl/saas/login', body: {'username': username, 'password': password});
  }

  /// SaaS仪表盘
  static Future<ApiResponse> saasDashboard() async {
    return _request('GET', '$saasBaseUrl/saas/dashboard', token: _saasToken);
  }

  /// SaaS租户列表
  static Future<ApiResponse> saasTenants({int page = 1, String? keyword, String? status}) async {
    var url = '$saasBaseUrl/saas/tenants?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (status != null) url += '&status=$status';
    return _request('GET', url, token: _saasToken);
  }

  /// SaaS创建租户
  static Future<ApiResponse> saasCreateTenant(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/tenants', body: data, token: _saasToken);
  }

  /// SaaS更新租户
  static Future<ApiResponse> saasUpdateTenant(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/tenants/$id', body: data, token: _saasToken);
  }

  /// SaaS删除租户
  static Future<ApiResponse> saasDeleteTenant(String id) async {
    return _request('DELETE', '$saasBaseUrl/saas/tenants/$id', token: _saasToken);
  }

  /// SaaS服务器列表
  static Future<ApiResponse> saasServers() async {
    return _request('GET', '$saasBaseUrl/saas/servers', token: _saasToken);
  }

  /// SaaS添加服务器
  static Future<ApiResponse> saasCreateServer(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/servers', body: data, token: _saasToken);
  }

  /// SaaS更新服务器
  static Future<ApiResponse> saasUpdateServer(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/servers/$id', body: data, token: _saasToken);
  }

  /// SaaS删除服务器
  static Future<ApiResponse> saasDeleteServer(String id) async {
    return _request('DELETE', '$saasBaseUrl/saas/servers/$id', token: _saasToken);
  }

  /// SaaS部署记录
  static Future<ApiResponse> saasDeployLogs() async {
    return _request('GET', '$saasBaseUrl/saas/deploys', token: _saasToken);
  }

  /// SaaS一键部署
  static Future<ApiResponse> saasDeploy(String tenantId, dynamic serverInfo) async {
    final body = <String, dynamic>{'tenant_id': tenantId};
    if (serverInfo is String) {
      body['server_id'] = serverInfo;
    } else if (serverInfo is Map) {
      body.addAll(Map<String, dynamic>.from(serverInfo));
    }
    return _request('POST', '$saasBaseUrl/saas/deploy', body: body, token: _saasToken);
  }

  /// SaaS未部署租户
  static Future<ApiResponse> saasUndeployedTenants() async {
    return _request('GET', '$saasBaseUrl/saas/tenants/undeployed', token: _saasToken);
  }

  /// SaaS可用服务器
  static Future<ApiResponse> saasAvailableServers() async {
    return _request('GET', '$saasBaseUrl/saas/servers/available', token: _saasToken);
  }

  // ==================== 企业服务器接口（用户端） ====================

  /// 用户注册
  static Future<ApiResponse> userRegister(String username, String password, {String? nickname, String? phone}) async {
    return _request('POST', '$enterpriseApiUrl/auth/register', body: {'username': username, 'password': password, 'nickname': nickname, 'phone': phone});
  }

  /// 用户登录
  static Future<ApiResponse> userLogin(String username, String password) async {
    return _request('POST', '$enterpriseApiUrl/auth/login', body: {'username': username, 'password': password});
  }

  /// 获取个人信息
  static Future<ApiResponse> userProfile() async {
    return _request('GET', '$enterpriseApiUrl/auth/profile', token: _userToken);
  }

  /// 修改个人信息
  static Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    return _request('PUT', '$enterpriseApiUrl/auth/profile', body: data, token: _userToken);
  }

  /// 会话列表
  static Future<ApiResponse> getConversations() async {
    return _request('GET', '$enterpriseApiUrl/im/conversations', token: _userToken);
  }

  /// 消息列表
  static Future<ApiResponse> getMessages(String conversationId, {int page = 1}) async {
    return _request('GET', '$enterpriseApiUrl/im/messages/$conversationId?page=$page', token: _userToken);
  }

  /// 发送消息
  static Future<ApiResponse> sendMessage(String conversationId, String content, {String type = 'text'}) async {
    return _request('POST', '$enterpriseApiUrl/im/messages', body: {'conversation_id': conversationId, 'content': content, 'type': type}, token: _userToken);
  }

  /// 撤回消息
  static Future<ApiResponse> recallMessage(String messageId) async {
    return _request('PUT', '$enterpriseApiUrl/im/messages/$messageId/recall', token: _userToken);
  }

  /// 通讯录
  static Future<ApiResponse> getContacts() async {
    return _request('GET', '$enterpriseApiUrl/im/contacts', token: _userToken);
  }

  /// 创建会话
  static Future<ApiResponse> createConversation(String type, {String? name, List<String>? memberIds}) async {
    return _request('POST', '$enterpriseApiUrl/im/conversations', body: {'type': type, 'name': name, 'member_ids': memberIds}, token: _userToken);
  }

  /// 置顶
  static Future<ApiResponse> pinConversation(String id, bool pinned) async {
    return _request('PUT', '$enterpriseApiUrl/im/conversations/$id/pin', body: {'is_pinned': pinned}, token: _userToken);
  }

  /// 免打扰
  static Future<ApiResponse> muteConversation(String id, bool muted) async {
    return _request('PUT', '$enterpriseApiUrl/im/conversations/$id/mute', body: {'is_muted': muted}, token: _userToken);
  }

  // ==================== 企业管理后台接口 ====================

  /// 企业管理员登录
  static Future<ApiResponse> adminLogin(String username, String password) async {
    return _request('POST', '$enterpriseApiUrl/admin/login', body: {'username': username, 'password': password});
  }

  /// 企业仪表盘
  static Future<ApiResponse> adminDashboard() async {
    return _request('GET', '$enterpriseApiUrl/admin/dashboard', token: _adminToken);
  }

  /// 员工列表
  static Future<ApiResponse> adminEmployees({int page = 1, String? keyword, String? departmentId}) async {
    var url = '$enterpriseApiUrl/admin/employees?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (departmentId != null) url += '&department_id=$departmentId';
    return _request('GET', url, token: _adminToken);
  }

  /// 添加员工
  static Future<ApiResponse> adminCreateEmployee(Map<String, dynamic> data) async {
    return _request('POST', '$enterpriseApiUrl/admin/employees', body: data, token: _adminToken);
  }

  /// 更新员工
  static Future<ApiResponse> adminUpdateEmployee(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$enterpriseApiUrl/admin/employees/$id', body: data, token: _adminToken);
  }

  /// 删除员工
  static Future<ApiResponse> adminDeleteEmployee(String id) async {
    return _request('DELETE', '$enterpriseApiUrl/admin/employees/$id', token: _adminToken);
  }

  /// 部门列表
  static Future<ApiResponse> adminDepartments() async {
    return _request('GET', '$enterpriseApiUrl/admin/departments', token: _adminToken);
  }

  /// 创建部门
  static Future<ApiResponse> adminCreateDepartment(Map<String, dynamic> data) async {
    return _request('POST', '$enterpriseApiUrl/admin/departments', body: data, token: _adminToken);
  }

  /// 更新部门
  static Future<ApiResponse> adminUpdateDepartment(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$enterpriseApiUrl/admin/departments/$id', body: data, token: _adminToken);
  }

  /// 删除部门
  static Future<ApiResponse> adminDeleteDepartment(String id) async {
    return _request('DELETE', '$enterpriseApiUrl/admin/departments/$id', token: _adminToken);
  }

  /// 企业设置
  static Future<ApiResponse> adminSettings() async {
    return _request('GET', '$enterpriseApiUrl/admin/settings', token: _adminToken);
  }

  /// 更新企业设置
  static Future<ApiResponse> adminUpdateSettings(Map<String, dynamic> data) async {
    return _request('PUT', '$enterpriseApiUrl/admin/settings', body: data, token: _adminToken);
  }

  /// 聊天记录 - 会话列表
  static Future<ApiResponse> adminChatConversations({String? type, String? keyword, int page = 1}) async {
    var url = '$enterpriseApiUrl/admin/chat-records/conversations?page=$page';
    if (type != null) url += '&type=$type';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  /// 聊天记录 - 指定会话消息
  static Future<ApiResponse> adminChatMessages(String conversationId, {int page = 1, String? keyword}) async {
    var url = '$enterpriseApiUrl/admin/chat-records/messages/$conversationId?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  /// 聊天记录 - 全局搜索
  static Future<ApiResponse> adminSearchMessages({String? keyword, String? senderId, int page = 1}) async {
    var url = '$enterpriseApiUrl/admin/chat-records/search?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (senderId != null) url += '&sender_id=$senderId';
    return _request('GET', url, token: _adminToken);
  }

  /// 聊天记录 - 指定用户
  static Future<ApiResponse> adminUserMessages(String userId, {int page = 1, String? keyword}) async {
    var url = '$enterpriseApiUrl/admin/chat-records/user/$userId?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  // ==================== SaaS管理别名（前端页面使用） ====================

  static Future<ApiResponse> saasGetStats() => saasDashboard();
  static Future<ApiResponse> saasGetTenants({int page = 1, String? keyword, String? status}) => saasTenants(page: page, keyword: keyword, status: status);
  static Future<ApiResponse> saasGetServers() => saasServers();
  static Future<ApiResponse> saasAddServer(Map<String, dynamic> data) => saasCreateServer(data);

  // ==================== 企业管理别名（前端页面使用） ====================

  static void clearToken() {
    _userToken = '';
    _saasToken = '';
    _adminToken = '';
  }

  static Future<ApiResponse> enterpriseGetStats() => adminDashboard();
  static Future<ApiResponse> enterpriseGetEmployees() => adminEmployees();
  static Future<ApiResponse> enterpriseGetDepartments() => adminDepartments();
  static Future<ApiResponse> enterpriseGetSettings() => adminSettings();
  static Future<ApiResponse> enterpriseUpdateSettings(Map<String, dynamic> data) => adminUpdateSettings(data);
  static Future<ApiResponse> enterpriseAddEmployee(Map<String, dynamic> data) => adminCreateEmployee(data);
  static Future<ApiResponse> enterpriseUpdateEmployee(dynamic id, Map<String, dynamic> data) => adminUpdateEmployee(id.toString(), data);
  static Future<ApiResponse> enterpriseDeleteEmployee(dynamic id) => adminDeleteEmployee(id.toString());
  static Future<ApiResponse> enterpriseAddDepartment(Map<String, dynamic> data) => adminCreateDepartment(data);
  static Future<ApiResponse> enterpriseUpdateDepartment(dynamic id, Map<String, dynamic> data) => adminUpdateDepartment(id.toString(), data);
  static Future<ApiResponse> enterpriseDeleteDepartment(dynamic id) => adminDeleteDepartment(id.toString());
  static Future<ApiResponse> enterpriseGetChatRecords({String? keyword, String? senderId, int page = 1}) => adminSearchMessages(keyword: keyword, senderId: senderId, page: page);
}
