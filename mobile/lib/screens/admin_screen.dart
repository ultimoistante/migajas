import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/admin_repository.dart';
import '../models/user.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _repo = AdminRepository();
  List<User> _users = [];
  bool _loading = true;
  bool _selfReg = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final users = await _repo.getUsers();
      final selfReg = await _repo.getSelfRegistrationEnabled();
      setState(() {
        _users = users;
        _selfReg = selfReg;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _toggleSelfReg(bool value) async {
    await _repo.setSelfRegistration(value);
    setState(() => _selfReg = value);
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Delete "${user.username}"? All their notes will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deleteUser(user.id);
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
    }
  }

  Future<void> _showUserDialog({User? user}) async {
    final usernameCtrl =
        TextEditingController(text: user?.username ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final passwordCtrl = TextEditingController();
    bool isAdmin = user?.isAdmin ?? false;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDlg) => AlertDialog(
          title: Text(user == null ? 'New user' : 'Edit user'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Username', border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || !v.contains('@')
                          ? 'Valid email required'
                          : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        user == null ? 'Password' : 'New password (optional)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (user == null && (v == null || v.length < 8)) {
                      return 'Min 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Admin'),
                  value: isAdmin,
                  onChanged: (v) => setStateDlg(() => isAdmin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        if (user == null) {
          final created = await _repo.createUser(
            username: usernameCtrl.text.trim(),
            email: emailCtrl.text.trim(),
            password: passwordCtrl.text,
            isAdmin: isAdmin,
          );
          setState(() => _users = [..._users, created]);
        } else {
          final updated = await _repo.updateUser(
            user.id,
            username: usernameCtrl.text.trim(),
            email: emailCtrl.text.trim(),
            password: passwordCtrl.text,
            isAdmin: isAdmin,
          );
          setState(() => _users =
              [for (final u in _users) if (u.id == user.id) updated else u]);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Self-registration setting
                SwitchListTile(
                  title: const Text('Allow self-registration'),
                  subtitle: const Text(
                      'New users can create accounts without admin invitation'),
                  value: _selfReg,
                  onChanged: _toggleSelfReg,
                ),
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Users (${_users.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ..._users.map((u) => ListTile(
                      leading: CircleAvatar(child: Text(u.username[0].toUpperCase())),
                      title: Row(
                        children: [
                          Text(u.username),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 6),
                            const Chip(
                              label: Text('admin',
                                  style: TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(u.email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showUserDialog(user: u),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteUser(u),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }
}
