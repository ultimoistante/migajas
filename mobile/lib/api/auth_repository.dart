import 'package:dio/dio.dart';
import 'api_client.dart';
import '../config.dart';
import '../models/user.dart';
import '../models/setup_status.dart';

class AuthRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<SetupStatus> getSetupStatus() async {
    // Public endpoint — use a fresh Dio without auth headers
    final r = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).get('/setup/status');
    return SetupStatus.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> setup({
    required String username,
    required String email,
    required String password,
    required bool allowSelfRegistration,
  }) async {
    await _dio.post('/setup', data: {
      'username': username,
      'email': email,
      'password': password,
      'allow_self_registration': allowSelfRegistration,
    });
  }

  /// Returns the access token string on success.
  Future<({String accessToken, String? refreshCookie, User user})> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final r = await _dio.post('/auth/login', data: {
      'username_or_email': usernameOrEmail,
      'password': password,
    });
    final data = r.data as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    // Extract refresh token from Set-Cookie header
    String? refreshCookie;
    final setCookie = r.headers.value('set-cookie');
    if (setCookie != null) {
      final m = RegExp(r'refresh_token=([^;]+)').firstMatch(setCookie);
      refreshCookie = m?.group(1);
    }

    return (accessToken: accessToken, refreshCookie: refreshCookie, user: user);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }

  Future<User> getMe() async {
    final r = await _dio.get('/auth/me');
    return User.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> setVault({
    required String type,   // 'pin' | 'password'
    required String credential,
  }) async {
    await _dio.post('/auth/vault', data: {
      'type': type,
      'credential': credential,
    });
  }
}
