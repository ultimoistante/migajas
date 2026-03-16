import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_repository.dart';
import '../models/setup_status.dart';

enum SetupPhase { loading, needsSetup, done }

class SetupNotifier extends Notifier<AsyncValue<SetupStatus>> {
  final _repo = AuthRepository();

  @override
  AsyncValue<SetupStatus> build() {
    _check();
    return const AsyncValue.loading();
  }

  Future<void> _check() async {
    try {
      final status = await _repo.getSetupStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _check();
}

final setupProvider =
    NotifierProvider<SetupNotifier, AsyncValue<SetupStatus>>(SetupNotifier.new);

/// Derived: what phase we are in
final setupPhaseProvider = Provider<SetupPhase>((ref) {
  final s = ref.watch(setupProvider);
  return s.when(
    loading: () => SetupPhase.loading,
    error: (_, __) => SetupPhase.loading,
    data: (status) =>
        status.initialized ? SetupPhase.done : SetupPhase.needsSetup,
  );
});
