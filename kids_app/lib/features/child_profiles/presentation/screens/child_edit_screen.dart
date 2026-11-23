import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/widgets/reauth_dialog.dart';
import '../../domain/child_profile.dart';
import '../child_providers.dart';
import '../widgets/birth_month_picker.dart';

/// P02 edit: nickname, birth month, buddy; delete (owner, fresh code).
class ChildEditScreen extends ConsumerWidget {
  const ChildEditScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final child = children.value?.where((c) => c.id == childId).firstOrNull;
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: Text(child?.nickname ?? 'Child'),
          leading: BackButton(onPressed: () => context.go(Routes.children)),
        ),
        body: switch (children) {
          AsyncValue(hasValue: false, isLoading: true) => GrownUpPage(
            children: [
              LoadingRegion(
                child: Column(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      const Skeleton(
                        height: Sizes.tapUi + Space.s5,
                        color: AppColors.uiBorder,
                      ),
                      const SizedBox(height: Space.s5),
                    ],
                  ],
                ),
              ),
            ],
          ),
          AsyncValue(hasValue: false, :final error?) => GrownUpErrorView(
            error: error,
            onRetry: () => ref.read(childrenProvider.notifier).reload(),
          ),
          _ when child == null => EmptyStateView(
            title: 'Profile not found',
            message: 'It may have been deleted on another device.',
            action: OutlinedButton(
              onPressed: () => context.go(Routes.children),
              child: const Text('Back to children'),
            ),
          ),
          _ => _ChildForm(key: ValueKey(child.id), child: child),
        },
      ),
    );
  }
}

class _ChildForm extends ConsumerStatefulWidget {
  const _ChildForm({super.key, required this.child});

  final ChildProfile child;

  @override
  ConsumerState<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends ConsumerState<_ChildForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.child.nickname);
  late int _month = widget.child.birthYearMonth.month;
  late int _year = widget.child.birthYearMonth.year;
  late String? _avatarId = widget.child.avatarId;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  BirthYearMonth get _birth => BirthYearMonth(_year, _month);

  bool get _dirty =>
      _name.text.trim() != widget.child.nickname ||
      _birth != widget.child.birthYearMonth ||
      _avatarId != widget.child.avatarId;

  Future<void> _pickBuddy() async {
    final query = _avatarId == null
        ? ''
        : '?selected=${Uri.encodeQueryComponent(_avatarId!)}';
    final picked = await context.push<String>(
      '${Routes.childBuddy(widget.child.id)}$query',
    );
    if (picked != null && mounted) setState(() => _avatarId = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final birthProblem = _birth.validate(ref.read(clockProvider)());
    if (birthProblem != null) {
      setState(() => _error = birthProblem.message);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(childrenProvider.notifier)
          .edit(
            widget.child.id,
            ChildDetails(
              nickname: _name.text,
              birthYearMonth: _birth,
              avatarId: _avatarId,
            ),
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
      context.go(Routes.children);
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final name = widget.child.nickname;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name’s profile?'),
        content: Text(
          'This deletes $name’s progress, stars and stickers from every device, right away. It can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.uiDanger,
              foregroundColor: AppColors.uiOnDanger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete profile'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(childrenProvider.notifier);
    try {
      try {
        await notifier.remove(widget.child.id);
      } on ReauthRequiredFailure {
        if (!mounted) return;
        setState(() => _deleting = false); // no spinner behind the dialog
        if (!await confirmWithEmailCode(context)) return;
        if (!mounted) return;
        setState(() => _deleting = true);
        await notifier.remove(widget.child.id);
      }
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$name’s profile was deleted.')));
      context.go(Routes.children);
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final busy = _saving || _deleting;
    final years = [for (var y = now.year - 12; y <= now.year - 1; y++) y];
    if (!years.contains(_year)) years.insert(0, _year);
    final wide = WindowClass.of(context).isAtLeastMedium;

    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: GrownUpPage(
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(Space.s5),
                  decoration: const BoxDecoration(
                    color: AppColors.kidsMeSoft,
                    shape: BoxShape.circle,
                  ),
                  child: BuddyArt(
                    ref.watch(buddyArtIndexProvider(_avatarId)),
                    size: Sizes.kidsBuddyTile,
                  ),
                ),
                const SizedBox(height: Space.s3),
                OutlinedButton.icon(
                  onPressed: busy ? null : _pickBuddy,
                  icon: const Icon(Icons.face_retouching_natural_rounded),
                  label: const Text('Change buddy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s7),
          TextFormField(
            controller: _name,
            enabled: !busy,
            maxLength: nicknameMaxLength,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              helperText: 'Only shown in the app. No last names.',
            ),
            validator: (v) => validateNickname(v ?? '')?.message,
          ),
          const SizedBox(height: Space.s5),
          Text('Birth month and year', style: UiText.h3),
          const SizedBox(height: Space.s3),
          Builder(
            builder: (context) {
              final month = DropdownButtonFormField<int>(
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(monthNamesLong[m - 1]),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (m) => setState(() => _month = m ?? _month),
              );
              final year = DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [
                  for (final y in years.reversed)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: busy
                    ? null
                    : (y) => setState(() => _year = y ?? _year),
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: month),
                        const SizedBox(width: Space.s5),
                        Expanded(child: year),
                      ],
                    )
                  : Column(
                      children: [
                        month,
                        const SizedBox(height: Space.s5),
                        year,
                      ],
                    );
            },
          ),
          const SizedBox(height: Space.s3),
          Text(
            'We keep only the month and year, to suggest the right activities.',
            style: UiText.small,
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.s5),
            FormErrorText(_error!),
          ],
          const SizedBox(height: Space.s7),
          PrimaryButton(
            label: 'Save changes',
            busy: _saving,
            onPressed: busy || !_dirty ? null : _save,
          ),
          const SizedBox(height: Space.s7),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.childMedia(widget.child.id)),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Media and screen time'),
          ),
          const SizedBox(height: Space.s4),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.childReport(widget.child.id)),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Progress report'),
          ),
          const SizedBox(height: Space.s4),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.childRewards(widget.child.id)),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Rewards and goals'),
          ),
          const SizedBox(height: Space.s9),
          const Divider(),
          const SizedBox(height: Space.s5),
          Text('Delete this profile', style: UiText.h3),
          const SizedBox(height: Space.s2),
          Text(
            'Deletes this child’s profile and all of their progress now. We may ask for an email code first.',
            style: UiText.small,
          ),
          const SizedBox(height: Space.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.uiDanger,
                side: const BorderSide(color: AppColors.uiDanger),
              ),
              onPressed: busy ? null : _delete,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: Sizes.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text('Delete ${widget.child.nickname}’s profile'),
            ),
          ),
        ],
      ),
    );
  }
}
