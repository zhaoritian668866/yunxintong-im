import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // SaaS平台API地址 - 动态获取当前域名（同域）
  static String get saasBaseUrl {
    if (kIsWeb) {
      return Uri.base.origin + '/api';
    }
    return 'http://localhost:8088/api';
  }

  // 企业ID（用于代理路径）
  static String _enterpriseId = '';
  static String get enterpriseId => _enterpriseId;
  static set enterpriseId(String v) => _enterpriseId = v;

  // 企业API地址 - 通过代理路径访问（同域，无跨域问题）
  // 格式: {saasBaseUrl}/proxy/{enterprise_id}
  static String get enterpriseApiUrl {
    if (_enterpriseId.isEmpty) return '';
    if (kIsWeb) {
      return Uri.base.origin + '/api/proxy/$_enterpriseId';
    }
    return 'http://localhost:8088/api/proxy/$_enterpriseId';
  }

  // 企业直连地址（企业管理后台部署在企业服务器上时使用）
  static String _enterpriseDirectUrl = '';
  static String get enterpriseDirectUrl => _enterpriseDirectUrl;
  static set enterpriseDirectUrl(String v) => _enterpriseDirectUrl = v;

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
    await prefs.setString('enterprise_id', _enterpriseId);
    await prefs.setString('enterprise_direct_url', _enterpriseDirectUrl);
    await prefs.setString('enterprise_ws_url', enterpriseWsUrl);
    await prefs.setString('enterprise_name', enterpriseName);
    await prefs.setString('user_token', _userToken);
    await prefs.setString('saas_token', _saasToken);
    await prefs.setString('admin_token', _adminToken);
  }

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _enterpriseId = prefs.getString('enterprise_id') ?? '';
    _enterpriseDirectUrl = prefs.getString('enterprise_direct_url') ?? '';
    enterpriseWsUrl = prefs.getString('enterprise_ws_url') ?? '';
    enterpriseName = prefs.getString('enterprise_name') ?? '';
    _userToken = prefs.getString('user_token') ?? '';
    _saasToken = prefs.getString('saas_token') ?? '';
    _adminToken = prefs.getString('admin_token') ?? '';
  }

  static Future<void> clearUserSession() async {
    _userToken = '';
    _enterpriseId = '';
    _enterpriseDirectUrl = '';
    enterpriseWsUrl = '';
    enterpriseName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('enterprise_id');
    await prefs.remove('enterprise_direct_url');
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

  // 获取企业API基础URL（代理模式或直连模式）
  static String get _entApiBase {
    // 如果有直连地址（企业管理后台场景），优先使用
    if (_enterpriseDirectUrl.isNotEmpty) return _enterpriseDirectUrl;
    // 否则使用代理模式
    return enterpriseApiUrl;
  }

  // ==================== SaaS平台接口 ====================

  static Future<ApiResponse> resolveEnterprise(String eid) async {
    return _request('POST', '$saasBaseUrl/auth/resolve', body: {'enterprise_id': eid});
  }

  static Future<ApiResponse> saasLogin(String username, String password) async {
    return _request('POST', '$saasBaseUrl/saas/login', body: {'username': username, 'password': password});
  }

  static Future<ApiResponse> saasDashboard() async {
    return _request('GET', '$saasBaseUrl/saas/dashboard', token: _saasToken);
  }

  static Future<ApiResponse> saasTenants({int page = 1, String? keyword, String? status}) async {
    var url = '$saasBaseUrl/saas/tenants?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (status != null) url += '&status=$status';
    return _request('GET', url, token: _saasToken);
  }

  static Future<ApiResponse> saasCreateTenant(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/tenants', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasUpdateTenant(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/tenants/$id', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasDeleteTenant(String id) async {
    return _request('DELETE', '$saasBaseUrl/saas/tenants/$id', token: _saasToken);
  }

  static Future<ApiResponse> saasServers() async {
    return _request('GET', '$saasBaseUrl/saas/servers', token: _saasToken);
  }

  static Future<ApiResponse> saasCreateServer(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/servers', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasUpdateServer(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/servers/$id', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasDeleteServer(String id) async {
    return _request('DELETE', '$saasBaseUrl/saas/servers/$id', token: _saasToken);
  }

  static Future<ApiResponse> saasDeployLogs() async {
    return _request('GET', '$saasBaseUrl/saas/deploys', token: _saasToken);
  }

  static Future<ApiResponse> saasDeploy(String tenantId, dynamic serverInfo) async {
    final body = <String, dynamic>{'tenant_id': tenantId};
    if (serverInfo is String) {
      body['server_id'] = serverInfo;
    } else if (serverInfo is Map) {
      body.addAll(Map<String, dynamic>.from(serverInfo));
    }
    return _request('POST', '$saasBaseUrl/saas/deploy', body: body, token: _saasToken);
  }

  static Future<ApiResponse> saasUndeployedTenants() async {
    return _request('GET', '$saasBaseUrl/saas/tenants/undeployed', token: _saasToken);
  }

  static Future<ApiResponse> saasAvailableServers() async {
    return _request('GET', '$saasBaseUrl/saas/servers/available', token: _saasToken);
  }

  // ==================== 企业服务器接口（用户端 - 通过代理） ====================

  static Future<ApiResponse> userRegister(String username, String password, {String? nickname, String? phone}) async {
    return _request('POST', '$_entApiBase/auth/register', body: {'username': username, 'password': password, 'nickname': nickname, 'phone': phone});
  }

  static Future<ApiResponse> userLogin(String username, String password) async {
    return _request('POST', '$_entApiBase/auth/login', body: {'username': username, 'password': password});
  }

  static Future<ApiResponse> userProfile() async {
    return _request('GET', '$_entApiBase/auth/profile', token: _userToken);
  }

  static Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    return _request('PUT', '$_entApiBase/auth/profile', body: data, token: _userToken);
  }

  static Future<ApiResponse> getConversations() async {
    return _request('GET', '$_entApiBase/im/conversations', token: _userToken);
  }

  static Future<ApiResponse> getMessages(String conversationId, {int page = 1}) async {
    return _request('GET', '$_entApiBase/im/messages/$conversationId?page=$page', token: _userToken);
  }

  static Future<ApiResponse> sendMessage(String conversationId, String content, {String type = 'text'}) async {
    return _request('POST', '$_entApiBase/im/messages', body: {'conversation_id': conversationId, 'content': content, 'type': type}, token: _userToken);
  }

  static Future<ApiResponse> recallMessage(String messageId) async {
    return _request('PUT', '$_entApiBase/im/messages/$messageId/recall', token: _userToken);
  }

  static Future<ApiResponse> getContacts() async {
    return _request('GET', '$_entApiBase/im/contacts', token: _userToken);
  }

  static Future<ApiResponse> createConversation(String type, {String? name, List<String>? memberIds}) async {
    return _request('POST', '$_entApiBase/im/conversations', body: {'type': type, 'name': name, 'member_ids': memberIds}, token: _userToken);
  }

  static Future<ApiResponse> pinConversation(String id, bool pinned) async {
    return _request('PUT', '$_entApiBase/im/conversations/$id/pin', body: {'is_pinned': pinned}, token: _userToken);
  }

  static Future<ApiResponse> muteConversation(String id, bool muted) async {
    return _request('PUT', '$_entApiBase/im/conversations/$id/mute', body: {'is_muted': muted}, token: _userToken);
  }

  // ==================== 企业管理后台接口 ====================

  static Future<ApiResponse> adminLogin(String username, String password) async {
    return _request('POST', '$_entApiBase/admin/login', body: {'username': username, 'password': password});
  }

  static Future<ApiResponse> adminDashboard() async {
    return _request('GET', '$_entApiBase/admin/dashboard', token: _adminToken);
  }

  static Future<ApiResponse> adminEmployees({int page = 1, String? keyword, String? departmentId}) async {
    var url = '$_entApiBase/admin/employees?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (departmentId != null) url += '&department_id=$departmentId';
    return _request('GET', url, token: _adminToken);
  }

  static Future<ApiResponse> adminCreateEmployee(Map<String, dynamic> data) async {
    return _request('POST', '$_entApiBase/admin/employees', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminUpdateEmployee(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$_entApiBase/admin/employees/$id', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminDeleteEmployee(String id) async {
    return _request('DELETE', '$_entApiBase/admin/employees/$id', token: _adminToken);
  }

  static Future<ApiResponse> adminDepartments() async {
    return _request('GET', '$_entApiBase/admin/departments', token: _adminToken);
  }

  static Future<ApiResponse> adminCreateDepartment(Map<String, dynamic> data) async {
    return _request('POST', '$_entApiBase/admin/departments', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminUpdateDepartment(String id, Map<String, dynamic> data) async {
    return _request('PUT', '$_entApiBase/admin/departments/$id', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminDeleteDepartment(String id) async {
    return _request('DELETE', '$_entApiBase/admin/departments/$id', token: _adminToken);
  }

  static Future<ApiResponse> adminSettings() async {
    return _request('GET', '$_entApiBase/admin/settings', token: _adminToken);
  }

  static Future<ApiResponse> adminUpdateSettings(Map<String, dynamic> data) async {
    return _request('PUT', '$_entApiBase/admin/settings', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminChatConversations({String? type, String? keyword, int page = 1}) async {
    var url = '$_entApiBase/admin/chat-records/conversations?page=$page';
    if (type != null) url += '&type=$type';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  static Future<ApiResponse> adminChatMessages(String conversationId, {int page = 1, String? keyword}) async {
    var url = '$_entApiBase/admin/chat-records/messages/$conversationId?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  static Future<ApiResponse> adminSearchMessages({String? keyword, String? senderId, int page = 1}) async {
    var url = '$_entApiBase/admin/chat-records/search?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    if (senderId != null) url += '&sender_id=$senderId';
    return _request('GET', url, token: _adminToken);
  }

  static Future<ApiResponse> adminUserMessages(String userId, {int page = 1, String? keyword}) async {
    var url = '$_entApiBase/admin/chat-records/user/$userId?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  // ==================== SaaS订单接口 ====================

  static Future<ApiResponse> saasGetOrders({String? status, String? keyword, int page = 1}) async {
    var url = '$saasBaseUrl/saas/orders?page=$page';
    if (status != null) url += '&status=$status';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _saasToken);
  }

  static Future<ApiResponse> saasCreateOrder(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/orders', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasUpdateOrder(dynamic id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/orders/$id', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasDeleteOrder(dynamic id) async {
    return _request('DELETE', '$saasBaseUrl/saas/orders/$id', token: _saasToken);
  }

  // ==================== SaaS设置接口 ====================

  static Future<ApiResponse> saasGetSettings() async {
    return _request('GET', '$saasBaseUrl/saas/settings', token: _saasToken);
  }

  static Future<ApiResponse> saasUpdateSettings(Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/settings', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasCreateAdmin(Map<String, dynamic> data) async {
    return _request('POST', '$saasBaseUrl/saas/admins', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasUpdateAdmin(dynamic id, Map<String, dynamic> data) async {
    return _request('PUT', '$saasBaseUrl/saas/admins/$id', body: data, token: _saasToken);
  }

  static Future<ApiResponse> saasDeleteAdmin(dynamic id) async {
    return _request('DELETE', '$saasBaseUrl/saas/admins/$id', token: _saasToken);
  }

  // ==================== 企业群组管理接口 ====================

  static Future<ApiResponse> adminGetGroups({String? keyword, int page = 1}) async {
    var url = '$_entApiBase/admin/groups?page=$page';
    if (keyword != null && keyword.isNotEmpty) url += '&keyword=$keyword';
    return _request('GET', url, token: _adminToken);
  }

  static Future<ApiResponse> adminCreateGroup(Map<String, dynamic> data) async {
    return _request('POST', '$_entApiBase/admin/groups', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminUpdateGroup(dynamic id, Map<String, dynamic> data) async {
    return _request('PUT', '$_entApiBase/admin/groups/$id', body: data, token: _adminToken);
  }

  static Future<ApiResponse> adminDeleteGroup(dynamic id) async {
    return _request('DELETE', '$_entApiBase/admin/groups/$id', token: _adminToken);
  }

  static Future<ApiResponse> adminGetGroupMembers(dynamic groupId) async {
    return _request('GET', '$_entApiBase/admin/groups/$groupId/members', token: _adminToken);
  }

  static Future<ApiResponse> adminAddGroupMember(dynamic groupId, String userId) async {
    return _request('POST', '$_entApiBase/admin/groups/$groupId/members', body: {'user_id': userId}, token: _adminToken);
  }

  static Future<ApiResponse> adminRemoveGroupMember(dynamic groupId, dynamic userId) async {
    return _request('DELETE', '$_entApiBase/admin/groups/$groupId/members/$userId', token: _adminToken);
  }

  // ==================== 别名方法 ====================

  static Future<ApiResponse> saasGetStats() => saasDashboard();
  static Future<ApiResponse> saasGetTenants({int page = 1, String? keyword, String? status}) => saasTenants(page: page, keyword: keyword, status: status);
  static Future<ApiResponse> saasGetServers() => saasServers();
  static Future<ApiResponse> saasAddServer(Map<String, dynamic> data) => saasCreateServer(data);

  static void clearToken() { _userToken = ''; _saasToken = ''; _adminToken = ''; }

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
  static Future<ApiResponse> enterpriseGetChatRecords({String? keyword, String? senderId, int page = 1, String? type}) => adminChatConversations(type: type, keyword: keyword, page: page);
}
