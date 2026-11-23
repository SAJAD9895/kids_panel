import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../onboarding/presentation/onboarding_providers.dart';
import '../../domain/auth_repository.dart';
import '../auth_providers.dart';
import '../widgets/social_sign_in_buttons.dart';

/// K03: the grown-up step of sign-up. Email (a link + 6-digit code is sent) and the consents.
/// Consent is given BEFORE any child data reaches the server: the child draft is only sent
/// after sign-in, together with these consents, in one call.
///
/// When the parent is already signed in (signed in from "I already have an account" but has
/// no family yet), only the consents are asked.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  late ConsentChoices _consents = ref.read(consentChoicesProvider);
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool signedIn}) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_consents.requiredGiven) return;
    if (!signedIn && !isValidEmail(_email.text)) return;

    if (signedIn) {
      // The router moves on to "finish setup" as soon as the consents are stored.
      ref.read(consentChoicesProvider.notifier).update(_consents);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(emailCodeProvider.notifier)
          .send(_email.text, EmailCodePurpose.signUp);
      ref.read(consentChoicesProvider.notifier).update(_consents);
      if (mounted) context.go(Routes.verifyCode);
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(authStateProvider).value;
    final signedIn = user != null;
    final missingConsent = _submitted && !_consents.requiredGiven;
    final badEmail = _submitted && !signedIn && !isValidEmail(_email.text);

    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        body: GrownUpZone(
          bubble: 'This part is for grown-ups!',
          leading: KidsIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: _busy ? null : () => context.go(Routes.setupBuddy),
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: GrownUpTag(label: 'For grown-ups · step 3 of 3'),
                ),
                const SizedBox(height: Space.s5),
                Semantics(
                  header: true,
                  child: Text(
                    signedIn ? 'One last step' : 'Create your family account',
                    style: UiText.h1,
                  ),
                ),
                const SizedBox(height: Space.s2),
                Text(
                  signedIn
                      ? 'You’re signed in as ${user.email ?? 'a parent'}. Please confirm the following to finish.'
                      : 'One account for all your children and devices.',
                  style: UiText.small,
                ),
                const SizedBox(height: Space.s6),
                if (!signedIn) ...[
                  SocialSignInButtons(config: config, enabled: !_busy),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      helperText:
                          'We’ll email you a sign-in link and a 6-digit code.',
                      errorText: badEmail
                          ? 'Enter an email address like name@example.com.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: Space.s5),
                ],
                CheckRow(
                  value: _consents.termsAndPrivacy,
                  onChanged: (v) => setState(
                    () => _consents = _consents.copyWith(termsAndPrivacy: v),
                  ),
                  label: const Text(
                    'I agree to the Terms and the Privacy Policy. (required)',
                  ),
                ),
                CheckRow(
                  value: _consents.childData,
                  onChanged: (v) => setState(
                    () => _consents = _consents.copyWith(childData: v),
                  ),
                  label: const Text(
                    'I’m the parent or guardian, and I agree to my child’s learning data being used to run the app. (required)',
                  ),
                ),
                CheckRow(
                  value: _consents.marketing,
                  onChanged: (v) => setState(
                    () => _consents = _consents.copyWith(marketing: v),
                  ),
                  label: const Text(
                    'Send me tips and news by email. (optional)',
                  ),
                ),
                Wrap(
                  spacing: Space.s3,
                  children: [
                    TextButton(
                      onPressed: () => _open(config.termsUrl),
                      child: const Text('Read the Terms'),
                    ),
                    TextButton(
                      onPressed: () => _open(config.privacyUrl),
                      child: const Text('Read the Privacy Policy'),
                    ),
                  ],
                ),
                if (missingConsent) ...[
                  const SizedBox(height: Space.s3),
                  const FormErrorText(
                    'Please tick both required boxes to continue.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Space.s3),
                  FormErrorText(_error!),
                ],
                const SizedBox(height: Space.s5),
                PrimaryButton(
                  label: signedIn ? 'Finish setup' : 'Send my code',
                  busy: _busy,
                  onPressed: () => _submit(signedIn: signedIn),
                ),
                if (!signedIn) ...[
                  const SizedBox(height: Space.s3),
                  TextButton(
                    onPressed: _busy ? null : () => context.go(Routes.signIn),
                    child: const Text('I already have an account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
