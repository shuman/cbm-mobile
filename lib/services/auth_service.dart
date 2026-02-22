import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/storage_util.dart';

const _timeout = Duration(seconds: 30);

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (kDebugMode) debugPrint('[Auth] Login request to $apiUrl/login');
      
      final response = await http
          .post(
            Uri.parse('$apiUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'login': email, 'password': password}),
          )
          .timeout(_timeout, onTimeout: () {
            throw Exception('Request timed out after ${_timeout.inSeconds}s');
          });

      if (kDebugMode) debugPrint('[Auth] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
      
      if (responseData.containsKey('requires_2fa')) {
        return {
          'requires_2fa': true,
          'two_fa_token': responseData['two_fa_token'],
          'message': responseData['message'],
        };
      }
      
      final token = responseData['items']['token'];
      final user = responseData['items']['user'];
      
      await StorageUtil.setToken(token);
      await StorageUtil.setUser(user);
      
      return {
        'success': true,
        'token': token,
        'user': user,
      };
    } else {
      try {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Login failed',
        };
            } catch (parseError) {
              return {
                'success': false,
                'error': 'Login failed (${response.statusCode})',
              };
            }
    }
    } on http.ClientException catch (clientError) {
      if (kDebugMode) debugPrint('[Auth] Client error: $clientError');
      return {
        'success': false,
        'error': 'Cannot reach server. Is the backend running at $apiUrl?',
      };
    } on FormatException catch (formatError) {
      if (kDebugMode) debugPrint('[Auth] Format error: $formatError');
      return {
        'success': false,
        'error': 'Invalid server response',
      };
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[Auth] Error: $e');
      final msg = e.toString();
      return {
        'success': false,
        'error': msg.contains('timed out')
            ? 'Server took too long to respond. Check backend.'
            : 'Network error: $msg',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<void> logout() async {
    await StorageUtil.clearToken();
  }

  static Future<bool> isLoggedIn() async {
    String? token = await StorageUtil.getToken();
    return token != null;
  }
}
