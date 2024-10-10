import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/storage_util.dart';

class ApiService {
  static Future<Map<String, dynamic>> fetchStats() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats');
    }
  }

  // Fetch Members
  static Future<Map<String, dynamic>> fetchMembers() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load members');
    }
  }

  // Fetch users
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // Add deposit
  static Future<Map<String, dynamic>> depositAdd(Map<String, dynamic> data) async {
    String? token = await StorageUtil.getToken();
    final response = await http.post(
      Uri.parse('$apiUrl/deposit'),
      headers: {
        'Authorization': 'Bearer $token',
        },
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  // Fetch deposits
  static Future<Map<String, dynamic>> fetchDeposits() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/deposits?order=desc&sort=created_at&limit=100'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load deposits');
    }
  }

  // Fetch deposit types
  static Future<Map<String, dynamic>> fetchDepositTypes() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/deposit_types'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load deposit types');
    }
  }

  // Fetch expenses
  static Future<Map<String, dynamic>> fetchExpenses() async {
    String? token = await StorageUtil.getToken();
    final response = await http.get(
      Uri.parse('$apiUrl/expenses'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load expenses');
    }
  }
}
