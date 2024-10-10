import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/storage_util.dart';

class AuthService {
  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)['token'];
      await StorageUtil.setToken(token);
      return token;
    }
    return '';
  }

  static Future<void> logout() async {
    await StorageUtil.clearToken();
  }

  static Future<bool> isLoggedIn() async {
    String? token = await StorageUtil.getToken();
    return token != null;
  }
}
