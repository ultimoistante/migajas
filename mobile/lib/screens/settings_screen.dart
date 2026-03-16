import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Vault form
  final _vaultCredCtrl = TextEditingController();
  String _vaultType = 'pin';
  bool _obscure = true;
  bool _savingVault = false;
  String? _vaultError;
  String? _vaultSuccess;

  @override
  void dispose() {
    _vaultCredCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveVault() async {
    if (_vaultCredCtrl.text.trim().isEmpty) return;
    setState(() {
      _savingVault = true;
      _vaultError = null;
      _vaultSuccess = null;
    });
    final ok = await ref.read(authProvider.notifier).setVault(
          _vaultType,
          _vaultCredCtrl.text.trim(),
        );
    setState(() {
      _savingVault = false;
      if (ok) {
        _vaultSuccess = 'Vault credential saved!';
        _vaultCredCtrl.clear();
      } else {
        _vaultError = ref.read(authProvider).error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user?.username ?? ''),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),

          // Theme
          ListTile(
            leading: Icon(themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            title: const Text('Theme'),
            subtitle: Text(themeMode == ThemeMode.dark
                ? 'Dark'
                : themeMode == ThemeMode.light
                    ? 'Light'
                    : 'System'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) {
                if (m != null) {
                  ref.read(themeProvider.notifier).setMode(m);
                }
              },
            ),
          ),
          const Divider(),

          // Vault configuration
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Secret vault',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Text(
            'Set a PIN or password to protect your secret notes.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pin', label: Text('PIN')),
              ButtonSegment(value: 'password', label: Text('Password')),
            ],
            selected: {_vaultType},
            onSelectionChanged: (s) =>
                setState(() => _vaultType = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vaultCredCtrl,
            obscureText: _obscure,
            keyboardType: _vaultType == 'pin'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: _vaultType == 'pin' ? 'PIN' : 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_vaultError != null) ...[
            const SizedBox(height: 6),
            Text(_vaultError!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ],
          if (_vaultSuccess != null) ...[
            const SizedBox(height: 6),
            Text(_vaultSuccess!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _savingVault ? null : _saveVault,
            child: _savingVault
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save vault credential'),
          ),
        ],
      ),
    );
  }
}
