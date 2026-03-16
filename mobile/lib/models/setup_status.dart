class SetupStatus {
  final bool initialized;
  final bool allowSelfRegistration;

  const SetupStatus({
    required this.initialized,
    required this.allowSelfRegistration,
  });

  factory SetupStatus.fromJson(Map<String, dynamic> j) => SetupStatus(
        initialized: (j['initialized'] as bool?) ?? false,
        allowSelfRegistration: (j['allow_self_registration'] as bool?) ?? true,
      );
}
