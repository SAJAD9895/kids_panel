import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../domain/auth_repository.dart';
import '../auth_providers.dart';

/// P17: confirm it's really the parent before a destructive action (deleting a child).
/// Sends a fresh code to the account email; a verified code renews the sign-in time the
/// server checks. Returns true when confirmed.
Future<bool> confirmWithEmailCode(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReauthDialog(),
    ) ??
    false;

class _ReauthDialog extends ConsumerStatefulWidget {
  const _ReauthDialog();

  @override
  ConsumerState<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends ConsumerState<_ReauthDialog> {
  final _code = TextEditingController();
  bool _sending = true;
  bool _busy = false;
  String? _error;

  String? get _email => ref.read(authStateProvider).value?.email;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final email = _email;
      if (email == null) throw const UnauthorizedFailure();
      await ref
          .read(authRepositoryProvider)
          .sendEmailCode(email: email, createUser: false);
    } on Failure catch (f) {
      _error = f.message;
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _confirm() async {
    if (_code.text.length != CodeInput.length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(email: _email!, code: _code.text);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = f.message;
          _code.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return AlertDialog(
      title: const Text('Confirm it’s you'),
      content: SizedBox(
        width: Sizes.uiFormW - Space.s12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sending
                  ? 'Sending a code…'
                  : 'For your security, enter the 6-digit code we just sent to ${email == null ? 'your email' : maskEmail(email)}.',
              style: UiText.body,
            ),
            const SizedBox(height: Space.s6),
            CodeInput(
              controller: _code,
              hasError: _error != null,
              onCompleted: (_) => _confirm(),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.s5),
              FormErrorText(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy || _sending ? null : _send,
          child: const Text('Send a new code'),
        ),
        FilledButton(
          onPressed: _busy || _sending ? null : _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
