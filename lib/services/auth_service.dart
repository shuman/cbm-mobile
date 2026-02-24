import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/storage_util.dart';

const _timeout = Duration(seconds: 30);

class AuthService {
  String? _extractToken(Map<String, dynamic> responseData) {
    final directToken = responseData['token']?.toString();
    if (directToken != null && directToken.isNotEmpty) return directToken;

    final directAccessToken = responseData['access_token']?.toString();
    if (directAccessToken != null && directAccessToken.isNotEmpty) return directAccessToken;

    final directJwtToken = responseData['jwt_token']?.toString();
    if (directJwtToken != null && directJwtToken.isNotEmpty) return directJwtToken;

    final directJwt = responseData['jwt']?.toString();
    if (directJwt != null && directJwt.isNotEmpty) return directJwt;

    final items = responseData['items'];
    if (items is Map<String, dynamic>) {
      final itemsToken = items['token']?.toString();
      if (itemsToken != null && itemsToken.isNotEmpty) return itemsToken;

      final itemsAccessToken = items['access_token']?.toString();
      if (itemsAccessToken != null && itemsAccessToken.isNotEmpty) return itemsAccessToken;

      final itemsJwtToken = items['jwt_token']?.toString();
      if (itemsJwtToken != null && itemsJwtToken.isNotEmpty) return itemsJwtToken;

      final itemsJwt = items['jwt']?.toString();
      if (itemsJwt != null && itemsJwt.isNotEmpty) return itemsJwt;
    }

    final data = responseData['data'];
    if (data is Map<String, dynamic>) {
      final dataToken = data['token']?.toString();
      if (dataToken != null && dataToken.isNotEmpty) return dataToken;

      final dataAccessToken = data['access_token']?.toString();
      if (dataAccessToken != null && dataAccessToken.isNotEmpty) return dataAccessToken;

      final dataJwtToken = data['jwt_token']?.toString();
      if (dataJwtToken != null && dataJwtToken.isNotEmpty) return dataJwtToken;

      final dataJwt = data['jwt']?.toString();
      if (dataJwt != null && dataJwt.isNotEmpty) return dataJwt;
    }

    return null;
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> responseData) {
    final directUser = responseData['user'];
    if (directUser is Map<String, dynamic>) return directUser;

    final items = responseData['items'];
    if (items is Map<String, dynamic> && items['user'] is Map<String, dynamic>) {
      return items['user'] as Map<String, dynamic>;
    }

    final data = responseData['data'];
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }

    return null;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (kDebugMode) {
        debugPrint('[Auth] Login request to $apiUrl/login');
        debugPrint('[Auth] Timeout: ${_timeout.inSeconds}s');
      }

      final response = await http
          .post(
            Uri.parse('$apiUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'login': email,
              'password': password,
              'remember_me': true,
              'remember': true,
            }),
          )
          .timeout(Duration(seconds: 10), onTimeout: () {
            if (kDebugMode) debugPrint('[Auth] Request timed out!');
            throw Exception('Request timed out. Check if backend is running at $apiUrl');
          });

      if (kDebugMode) {
        debugPrint('[Auth] Response: ${response.statusCode}');
        debugPrint('[Auth] Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check for explicit failure in success field
        if (responseData['success'] == false || responseData['success'] == 0) {
          return {
            'success': false,
            'error': responseData['error']?.toString() ??
                     responseData['message']?.toString() ??
                     'Login failed',
          };
        }

        if (responseData['requires_2fa'] == true) {
          return {
            'requires_2fa': true,
            'two_fa_token': responseData['two_fa_token'],
            'message': responseData['message'] ?? 'Two-factor authentication required.',
          };
        }

        final token = _extractToken(responseData);
        final user = _extractUser(responseData);

        if (kDebugMode) {
          debugPrint('[Auth] Extracted token: ${token != null ? "exists (${token.length} chars)" : "null"}');
          debugPrint('[Auth] Extracted user: ${user != null ? "exists" : "null"}');
        }

        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'error': 'Invalid login response: token missing',
          };
        }

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
        'error': 'Cannot reach server at $apiUrl. Is the backend running?',
      };
    } on FormatException catch (formatError) {
      if (kDebugMode) debugPrint('[Auth] Format error: $formatError');
      return {
        'success': false,
        'error': 'Invalid server response',
      };
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[Auth] Exception: $e');
      final msg = e.toString();
      return {
        'success': false,
        'error': msg.contains('timed out')
            ? 'Backend not responding. Check if server is running at $apiUrl'
            : 'Network error: $msg',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Unexpected error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> verify2FA(
    String twoFaToken,
    String code,
  ) async {
    try {
      if (kDebugMode) debugPrint('[Auth] 2FA verify request to $apiUrl/2fa/verify');

      final response = await http
          .post(
            Uri.parse('$apiUrl/2fa/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'two_fa_token': twoFaToken,
              'two_factor_token': twoFaToken,
              'token': twoFaToken,
              'code': code,
              'otp': code,
              'verification_code': code,
              'remember_me': true,
              'remember': true,
            }),
          )
          .timeout(_timeout, onTimeout: () {
            throw Exception('Request timed out after ${_timeout.inSeconds}s');
          });

      if (kDebugMode) {
        debugPrint('[Auth] 2FA verify response: ${response.statusCode}');
        debugPrint('[Auth] 2FA verify body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = _extractToken(responseData);
        final user = _extractUser(responseData);

        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'error': 'Invalid verify response: token missing',
          };
        }

        await StorageUtil.setToken(token);
        await StorageUtil.setUser(user);

        return {
          'success': true,
          'token': token,
          'user': user,
        };
      }

      try {
        final errorData = jsonDecode(response.body);
        String? errorMessage = errorData['error']?.toString() ?? errorData['message']?.toString();

        if ((errorMessage == null || errorMessage.isEmpty) && errorData['errors'] is Map) {
          final errorsMap = errorData['errors'] as Map;
          final firstEntry = errorsMap.entries.isNotEmpty ? errorsMap.entries.first : null;
          final firstValue = firstEntry?.value;
          if (firstValue is List && firstValue.isNotEmpty) {
            errorMessage = firstValue.first.toString();
          } else if (firstValue != null) {
            errorMessage = firstValue.toString();
          }
        }

        return {
          'success': false,
          'error': errorMessage ?? '2FA verification failed',
        };
      } catch (_) {
        return {
          'success': false,
          'error': '2FA verification failed (${response.statusCode})',
        };
      }
    } on http.ClientException catch (clientError) {
      if (kDebugMode) debugPrint('[Auth] 2FA client error: $clientError');
      return {
        'success': false,
        'error': 'Cannot reach server. Is the backend running at $apiUrl?',
      };
    } on FormatException catch (formatError) {
      if (kDebugMode) debugPrint('[Auth] 2FA format error: $formatError');
      return {
        'success': false,
        'error': 'Invalid server response',
      };
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[Auth] 2FA error: $e');
      final msg = e.toString();
      return {
        'success': false,
        'error': msg.contains('timed out')
            ? 'Server took too long to respond. Check backend.'
            : 'Network error: $msg',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 2FA error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<void> logout() async {
    await StorageUtil.clearToken();
  }

  Future<bool> isLoggedIn() async {
    String? token = await StorageUtil.getToken();
    return token != null;
  }
}
