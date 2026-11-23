import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../domain/auth_repository.dart';
import '../auth_providers.dart';
import '../widgets/social_sign_in_buttons.dart';

/// Sign in to an existing family (F03): email code (K04) by default, password optional (P16).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _usePassword = false;
  bool _obscure = true;
  bool _busy = false;
  bool _submitted = false;
  Failure? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!isValidEmail(_email.text) ||
        (_usePassword && _password.text.isEmpty)) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (_usePassword) {
        // Success changes the auth state; the router takes the parent on from here.
        await ref
            .read(authRepositoryProvider)
            .signInWithPassword(email: _email.text, password: _password.text);
      } else {
        await ref
            .read(emailCodeProvider.notifier)
            .send(_email.text, EmailCodePurpose.signIn);
        if (mounted) context.go(Routes.verifyCode);
      }
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final badEmail = _submitted && !isValidEmail(_email.text);
    final noPassword = _submitted && _usePassword && _password.text.isEmpty;

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        body: GrownUpZone(
          character: Character.nova,
          bubble: 'Welcome back!',
          leading: KidsIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: _busy ? null : () => context.go(Routes.welcome),
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: GrownUpTag(
                    label: 'For grown-ups',
                    icon: Icons.lock_outline_rounded,
                  ),
                ),
                const SizedBox(height: Space.s5),
                Semantics(
                  header: true,
                  child: Text('Welcome back', style: UiText.h1),
                ),
                const SizedBox(height: Space.s2),
                Text(
                  _usePassword
                      ? 'Sign in with your email and password.'
                      : 'We’ll email you a link and a 6-digit code.',
                  style: UiText.small,
                ),
                const SizedBox(height: Space.s6),
                SocialSignInButtons(config: config, enabled: !_busy),
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  autocorrect: false,
                  textInputAction: _usePassword
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) => _usePassword ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: badEmail
                        ? 'Enter an email address like name@example.com.'
                        : null,
                  ),
                ),
                if (_usePassword) ...[
                  const SizedBox(height: Space.s5),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: noPassword ? 'Enter your password.' : null,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Space.s5),
                  FormErrorText(_error!.message),
                  if (_error is AccountNotFoundFailure)
                    TextButton(
                      onPressed: () => context.go(Routes.setupChild),
                      child: const Text('Set up a new family'),
                    ),
                ],
                const SizedBox(height: Space.s6),
                PrimaryButton(
                  label: _usePassword ? 'Sign in' : 'Email me a code',
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: Space.s2),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _usePassword = !_usePassword;
                          _error = null;
                          _submitted = false;
                        }),
                  child: Text(
                    _usePassword
                        ? 'Use an email code instead'
                        : 'Use a password instead',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => context.go(Routes.setupChild),
                  child: const Text('New here? Set up a family'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
