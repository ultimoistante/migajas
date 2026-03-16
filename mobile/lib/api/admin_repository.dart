import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/user.dart';

class AdminRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<User>> getUsers() async {
    final r = await _dio.get('/admin/users');
    return (r.data as List<dynamic>)
        .map((j) => User.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<User> createUser({
    required String username,
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    final r = await _dio.post('/admin/users', data: {
      'username': username,
      'email': email,
      'password': password,
      'is_admin': isAdmin,
    });
    return User.fromJson(r.data as Map<String, dynamic>);
  }

  Future<User> updateUser(
    String id, {
    String? username,
    String? email,
    String? password,
    bool? isAdmin,
  }) async {
    final r = await _dio.put('/admin/users/$id', data: {
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      if (isAdmin != null) 'is_admin': isAdmin,
    });
    return User.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id) async {
    await _dio.delete('/admin/users/$id');
  }

  Future<bool> getSelfRegistrationEnabled() async {
    final r = await _dio.get('/admin/settings');
    return (r.data['allow_self_registration'] as bool?) ?? false;
  }

  Future<void> setSelfRegistration(bool enabled) async {
    await _dio.put('/admin/settings/self-registration', data: {
      'enabled': enabled,
    });
  }
}
