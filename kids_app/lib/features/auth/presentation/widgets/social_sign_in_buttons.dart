import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/providers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_repository.dart';

/// "Continue with Apple / Google" + an "or with email" divider. Shown only when the provider
/// is switched on in the build config AND set up in Supabase with the family's own keys
/// (setup-guide §4). Apple must be offered whenever Google is, on iOS (App Store rule).
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({
    super.key,
    required this.config,
    this.enabled = true,
  });

  final AppConfig config;
  final bool enabled;

  Future<void> _go(
    BuildContext context,
    WidgetRef ref,
    SocialProvider p,
  ) async {
    try {
      await ref.read(authRepositoryProvider).signInWithProvider(p);
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apple = config.enableAppleSignIn;
    final google = config.enableGoogleSignIn && apple;
    if (!apple && !google) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (apple)
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _go(context, ref, SocialProvider.apple)
                : null,
            icon: const Icon(Icons.apple),
            label: const Text('Continue with Apple'),
          ),
        if (google) ...[
          const SizedBox(height: Space.s3),
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _go(context, ref, SocialProvider.google)
                : null,
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: const Text('Continue with Google'),
          ),
        ],
        const SizedBox(height: Space.s5),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s4),
              child: Text('or with email', style: UiText.small),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Space.s5),
      ],
    );
  }
}
