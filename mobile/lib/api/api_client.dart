import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _storage = const FlutterSecureStorage();
  late final Dio dio;

  // In-memory access token
  String? _accessToken;
  bool _refreshing = false;
  final _refreshQueue = <Completer<void>>[];

  Future<void> init() async {
    _accessToken = await _storage.read(key: _kAccessTokenKey);

    dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor(this));
  }

  Future<void> setTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    await _storage.write(key: _kAccessTokenKey, value: accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
  }

  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    await _storage.write(key: _kAccessTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async =>
      _storage.read(key: _kRefreshTokenKey);

  Future<void> clearTokens() async {
    _accessToken = null;
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
  }

  String? get accessToken => _accessToken;

  // Called when auth completely fails — callers subscribe via a stream
  final _logoutController = StreamController<void>.broadcast();
  Stream<void> get onForceLogout => _logoutController.stream;
  void _forceLogout() => _logoutController.add(null);

  Future<bool> tryRefresh() async {
    if (_refreshing) {
      final c = Completer<void>();
      _refreshQueue.add(c);
      await c.future;
      return _accessToken != null;
    }

    _refreshing = true;
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        await clearTokens();
        _forceLogout();
        return false;
      }

      // Use a fresh Dio (no interceptor) to avoid recursion
      final refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
      final resp = await refreshDio.post(
        '/auth/refresh',
        options: Options(headers: {
          'Cookie': 'refresh_token=$refreshToken',
        }),
      );

      final newToken = resp.data['access_token'] as String;
      // Capture new refresh cookie if server rotates it
      final setCookie = resp.headers.value('set-cookie');
      if (setCookie != null) {
        final match = RegExp(r'refresh_token=([^;]+)').firstMatch(setCookie);
        if (match != null) {
          await _storage.write(
              key: _kRefreshTokenKey, value: match.group(1)!);
        }
      }
      await setAccessToken(newToken);

      for (final c in _refreshQueue) {
        c.complete();
      }
      _refreshQueue.clear();
      return true;
    } catch (_) {
      await clearTokens();
      _forceLogout();
      for (final c in _refreshQueue) {
        c.completeError('refresh_failed');
      }
      _refreshQueue.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }
}

// ---------------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _client.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      final refreshed = await _client.tryRefresh();
      if (refreshed) {
        // Retry original request with new token
        err.requestOptions.headers['Authorization'] =
            'Bearer ${_client.accessToken}';
        try {
          final response = await _client.dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }
}
