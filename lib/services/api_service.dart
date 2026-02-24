import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/storage_util.dart';
import '../utils/app_exceptions.dart';

class ApiService {
  /// Check if error response indicates insufficient permissions
  static bool _isPermissionError(Map<String, dynamic>? data) {
    if (data == null) return false;
    final message = data['message']?.toString().toLowerCase() ?? '';
    return message.contains('insufficient permissions') ||
           message.contains('access denied') ||
           message.contains('not authorized');
  }

  /// Helper method to handle API response and throw appropriate exceptions
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    // Check for permission errors
    if (_isPermissionError(data)) {
      throw PermissionException(
        data['message']?.toString() ?? 'Insufficient permissions. You do not have access to this module.',
      );
    }

    // Check for other failures
    if (data['success'] == false) {
      throw AppException(data['message']?.toString() ?? 'Request failed');
    }

    // Generic error handling
    if (response.statusCode >= 500) {
      throw ServerException();
    }

    throw AppException('Request failed with status ${response.statusCode}');
  }

  static Future<Map<String, String>> _getHeaders({bool includeProjectId = true}) async {
    String? token = await StorageUtil.getToken();
    Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    if (includeProjectId) {
      String? projectId = await StorageUtil.getProjectId();
      if (projectId != null && projectId.isNotEmpty) {
        headers['X-Project-ID'] = projectId;
      }
    }

    return headers;
  }

  // ======================================================= PROJECTS =======================================================

  static Future<Map<String, dynamic>> fetchProjects() async {
    final headers = await _getHeaders(includeProjectId: false);
    final response = await http.get(
      Uri.parse('$apiUrl/projects'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load projects');
    }
  }

  // ======================================================= STATS & MEMBERS =======================================================

  static Future<Map<String, dynamic>> fetchStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/members'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // Fetch Members
  static Future<Map<String, dynamic>> fetchMembers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/members'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // ======================================================= MESSAGING =======================================================

  static Future<Map<String, dynamic>> fetchChannels() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/channels'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> fetchDirectConversations() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/direct-conversations'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load direct conversations');
    }
  }

  static Future<Map<String, dynamic>> fetchChannelMessages(String channelId, {int page = 1, int limit = 50}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/channels/$channelId/messages?page=$page&limit=$limit&order=desc'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load channel messages');
    }
  }

  static Future<Map<String, dynamic>> sendChannelMessage(String channelId, String body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/channels/$channelId/messages'),
      headers: headers,
      body: json.encode({'body': body}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchDirectMessages(String conversationId, {int page = 1, int limit = 50}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/direct-conversations/$conversationId/messages?page=$page&limit=$limit&order=desc'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load direct messages');
    }
  }

  static Future<Map<String, dynamic>> sendDirectMessage(String conversationId, String body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/direct-conversations/$conversationId/messages'),
      headers: headers,
      body: json.encode({'body': body}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> markConversationAsRead(String conversationId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$apiUrl/direct-conversations/$conversationId/read'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to mark as read');
    }
  }

  // Create a new channel
  static Future<Map<String, dynamic>> createChannel({
    required String name,
    String? description,
    required List<dynamic> memberIds,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/channel'),
      headers: headers,
      body: json.encode({
        'name': name,
        'description': description,
        'member_ids': memberIds,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['error'] ?? errorBody['message'] ?? 'Failed to create channel');
    }
  }

  // Start a direct conversation
  static Future<Map<String, dynamic>> startDirectConversation(dynamic userId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/direct-conversations'),
      headers: headers,
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['error'] ?? errorBody['message'] ?? 'Failed to start conversation');
    }
  }

  // Fetch project users
  static Future<Map<String, dynamic>> fetchProjectUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/project_users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load project users');
    }
  }

  // ======================================================= DECISIONS =======================================================

  static Future<Map<String, dynamic>> fetchDecisions({
    int page = 1,
    int perPage = 15,
    String sortBy = 'created_at',
    String sortDir = 'desc',
  }) async {
    final headers = await _getHeaders();
    final queryParameters = {
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'per_page': perPage.toString(),
      'page': page.toString(),
    };

    final response = await http.get(
      Uri.parse('$apiUrl/decisions').replace(queryParameters: queryParameters),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load decisions');
    }
  }

  static Future<Map<String, dynamic>> fetchDecisionDetail(String decisionId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/decisions/$decisionId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load decision details');
    }
  }

  static Future<Map<String, dynamic>> fetchDecisionTimeline(String decisionId, {int perPage = 50}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/decisions/$decisionId/timeline?per_page=$perPage'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load timeline');
    }
  }

  static Future<Map<String, dynamic>> fetchDecisionComments(String decisionId, {bool threaded = true}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/decisions/$decisionId/comments?threaded=${threaded ? 'true' : 'false'}'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load comments');
    }
  }

  // ======================================================= NOTICES =======================================================

  static Future<Map<String, dynamic>> fetchNotices() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/notices'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // ======================================================= FILES =======================================================

  static Future<Map<String, dynamic>> fetchFiles() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/files'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // Fetch users
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // ======================================================= DEPOSIT =======================================================

  // Fetch deposit details
  static Future<Map<String, dynamic>> fetchDepositDetails(String depositId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/deposit/$depositId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load deposit details');
    }
  }

  // Add deposit
  static Future<Map<String, dynamic>> depositAdd(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/deposit'),
      headers: headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add deposit: ${response.body}');
    }
  }

  // Fetch deposits
  static Future<Map<String, dynamic>> fetchDeposits({
    int page = 1,
    int limit = 10,
    String sort = 'created_at',
    String order = 'desc',
    String? search,
    String? depositTypeId,
    String? depositTypeCategoryId,
    String? dateFrom,
    String? dateTo,
    String? amountMin,
    String? amountMax,
  }) async {
    final headers = await _getHeaders();
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
      'order': order,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (depositTypeId != null && depositTypeId.trim().isNotEmpty) 'deposit_type_id': depositTypeId.trim(),
      if (depositTypeCategoryId != null && depositTypeCategoryId.trim().isNotEmpty)
        'deposit_type_category_id': depositTypeCategoryId.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
      if (amountMin != null && amountMin.trim().isNotEmpty) 'amount_min': amountMin.trim(),
      if (amountMax != null && amountMax.trim().isNotEmpty) 'amount_max': amountMax.trim(),
    };

    final uri = Uri.parse('$apiUrl/deposits').replace(queryParameters: queryParameters);
    final response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load deposits');
    }
  }

  // Fetch deposit types
  static Future<Map<String, dynamic>> fetchDepositTypes() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/deposit_types'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load deposit types');
    }
  }

  // Fetch expenses
  static Future<Map<String, dynamic>> fetchExpenses() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/expenses'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // Add expense
  static Future<Map<String, dynamic>> expenseAdd(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/expense'),
      headers: headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add expense: ${response.body}');
    }
  }

  // Fetch expense types
  static Future<Map<String, dynamic>> fetchExpenseTypes() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/expense_types'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load expense types');
    }
  }
}
