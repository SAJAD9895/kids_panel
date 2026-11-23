import 'dart:async';

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
import '../../../../demo/demo_backend.dart';
import '../../domain/auth_repository.dart';
import '../auth_providers.dart';

/// K04: type the 6-digit code from the email (or tap the link in it, which signs in too).
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  /// Supabase's minimum interval between emails to the same address.
  static const resendAfter = Duration(seconds: 60);

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != CodeInput.length) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Success signs the parent in; the router moves on by itself.
      await ref.read(emailCodeProvider.notifier).verify(_code.text);
    } on Failure catch (f) {
      if (mounted) {
        setState(() {
          _error = f.message;
          _code.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(emailCodeProvider.notifier).resend();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('We sent a new code.')));
      }
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    }
  }

  void _changeEmail(EmailCodeRequest? request) {
    final back = request?.purpose == EmailCodePurpose.signUp
        ? Routes.setupGrownUp
        : Routes.signIn;
    ref.read(emailCodeProvider.notifier).clear();
    context.go(back);
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(emailCodeProvider);
    final demo = ref.watch(appConfigProvider).isDemo;
    final wait = request == null
        ? Duration.zero
        : VerifyCodeScreen.resendAfter -
              DateTime.now().difference(request.sentAt);
    final canResend = wait <= Duration.zero && !_busy;

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        body: GrownUpZone(
          character: Character.nova,
          leading: KidsIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: () => _changeEmail(request),
          ),
          child: request == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Let’s start again', style: UiText.h1),
                    const SizedBox(height: Space.s3),
                    Text(
                      'We don’t know which email to check. Enter it again to get a new code.',
                      style: UiText.body,
                    ),
                    const SizedBox(height: Space.s6),
                    PrimaryButton(
                      label: 'Enter my email',
                      onPressed: () => context.go(Routes.signIn),
                    ),
                  ],
                )
              : Column(
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
                      child: Text('Check your email', style: UiText.h1),
                    ),
                    const SizedBox(height: Space.s2),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Enter the code we sent to '),
                          TextSpan(
                            text: maskEmail(request.email),
                            style: UiText.bodyStrong.copyWith(
                              fontSize: UiType.small.size,
                            ),
                          ),
                          const TextSpan(
                            text: ', or tap the link in the email.',
                          ),
                        ],
                      ),
                      style: UiText.small,
                    ),
                    if (demo) ...[
                      const SizedBox(height: Space.s4),
                      Container(
                        padding: const EdgeInsets.all(Space.s4),
                        decoration: BoxDecoration(
                          color: AppColors.uiInfoSoft,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Text(
                          'Demo mode: no email is sent. The code is ${DemoBackend.code}.',
                          style: UiText.small.copyWith(color: AppColors.uiInfo),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.s6),
                    Text('6-digit code', style: UiText.bodyStrong),
                    const SizedBox(height: Space.s3),
                    CodeInput(
                      controller: _code,
                      hasError: _error != null,
                      onCompleted: (_) => _verify(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.s5),
                      FormErrorText(_error!),
                    ],
                    const SizedBox(height: Space.s4),
                    Text(
                      canResend
                          ? 'Didn’t get it? Check your spam folder, or send a new code.'
                          : 'Didn’t get it? You can send a new code in 0:${wait.inSeconds.clamp(0, 59).toString().padLeft(2, '0')}. Check spam too.',
                      style: UiText.small,
                    ),
                    const SizedBox(height: Space.s6),
                    PrimaryButton(
                      label: 'Sign in',
                      busy: _busy,
                      onPressed: _code.text.length == CodeInput.length
                          ? _verify
                          : null,
                    ),
                    const SizedBox(height: Space.s2),
                    TextButton(
                      onPressed: canResend ? _resend : null,
                      child: const Text('Send a new code'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _changeEmail(request),
                      child: const Text('Use a different email'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
