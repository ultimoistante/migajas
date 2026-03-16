import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api/api_client.dart';
import 'providers/theme_provider.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.init();
  runApp(const ProviderScope(child: MigajasApp()));
}

final _routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));

class MigajasApp extends ConsumerWidget {
  const MigajasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'migajas',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
