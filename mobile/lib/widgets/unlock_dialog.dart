import 'package:flutter/material.dart';
import '../models/note.dart';

/// Shows a dialog asking the user for PIN/password to unlock a secret note.
/// Returns the entered credential, or null if cancelled.
Future<String?> showUnlockDialog(BuildContext context, Note note) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _UnlockDialog(note: note),
  );
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.note});
  final Note note;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final val = _controller.text.trim();
    if (val.isEmpty) {
      setState(() => _error = 'Please enter your PIN or password.');
      return;
    }
    Navigator.pop(context, val);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_open, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Unlock "${widget.note.title}"',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'PIN or password',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
