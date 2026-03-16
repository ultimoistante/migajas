import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/auth_repository.dart';
import '../models/user.dart';
import '../models/setup_status.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool loading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.loading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? loading,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        error: clearError ? null : (error ?? this.error),
        loading: loading ?? this.loading,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  final _repo = AuthRepository();

  @override
  AuthState build() {
    // Watch for forced logouts from the API client
    ApiClient.instance.onForceLogout.listen((_) => _onForceLogout());
    _tryRestoreSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> _tryRestoreSession() async {
    final token = ApiClient.instance.accessToken;
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repo.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Try refresh
      final refreshed = await ApiClient.instance.tryRefresh();
      if (refreshed) {
        try {
          final user = await _repo.getMe();
          state = state.copyWith(status: AuthStatus.authenticated, user: user);
          return;
        } catch (_) {}
      }
      state = state.copyWith(
          status: AuthStatus.unauthenticated, clearUser: true);
    }
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result =
          await _repo.login(usernameOrEmail: usernameOrEmail, password: password);
      await ApiClient.instance.setTokens(
        result.accessToken,
        result.refreshCookie ?? '',
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        loading: false,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
          loading: false, error: _extractMessage(e), status: AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<bool> register(
      String username, String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.register(
          username: username, email: email, password: password);
      state = state.copyWith(loading: false);
      return true;
    } on Exception catch (e) {
      state =
          state.copyWith(loading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    await ApiClient.instance.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _onForceLogout() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<SetupStatus> getSetupStatus() => _repo.getSetupStatus();

  Future<bool> setup({
    required String username,
    required String email,
    required String password,
    required bool allowSelfRegistration,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.setup(
        username: username,
        email: email,
        password: password,
        allowSelfRegistration: allowSelfRegistration,
      );
      state = state.copyWith(loading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<bool> setVault(String type, String credential) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.setVault(type: type, credential: credential);
      state = state.copyWith(loading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: _extractMessage(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _extractMessage(Exception e) {
    if (e is Exception) {
      final s = e.toString();
      // Try to parse Dio response body message
      final m = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(s);
      if (m != null) return m.group(1)!;
      return s.replaceFirst('Exception: ', '');
    }
    return e.toString();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
