import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static Future<void> setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> clearToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<void> setUser(dynamic user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<void> clearUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  static Future<void> setProjectId(String projectId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_id', projectId);
  }

  static Future<String?> getProjectId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('project_id');
  }

  static Future<void> clearProjectId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('project_id');
    await prefs.remove('project_name');
  }

  static Future<void> setProjectName(String projectName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_name', projectName);
  }

  static Future<String?> getProjectName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('project_name');
  }

  static Future<void> clearAll() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('project_id');
    await prefs.remove('project_name');
  }
}
