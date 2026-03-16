/// Build-time configurable base URL.
/// Override with: flutter build apk --dart-define=API_BASE_URL=http://your-server/api
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api', // Android emulator → host loopback
);
