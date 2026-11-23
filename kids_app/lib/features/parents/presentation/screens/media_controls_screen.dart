import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/routes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/grown_up.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/domain/progress.dart';
import '../../../learning/presentation/learning_providers.dart';

/// P03 Media and screen time, per child: videos on / off, songs and stories on / off, which
/// categories show, and an optional daily limit for watching and listening. Games are always
/// on. Saved through `PUT /children/:id/screen-time`; the server enforces it at every launch.
class MediaControlsScreen extends ConsumerWidget {
  const MediaControlsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref
        .watch(childrenProvider)
        .value
        ?.where((c) => c.id == childId)
        .firstOrNull;
    final progress = ref.watch(childProgressProvider(childId));
    final catalog = ref.watch(catalogProvider);
    return OrientationScope(
      policy: OrientationPolicy.grownUps,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${child?.nickname ?? 'Child'}: media and screen time'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.child(childId)),
          ),
        ),
        body: switch ((progress, catalog)) {
          (AsyncValue(value: final p?), AsyncValue(value: final c?)) => _Form(
            childId: childId,
            progress: p,
            catalog: c,
            name: child?.nickname ?? 'your child',
          ),
          (AsyncValue(hasError: true), _) ||
          (_, AsyncValue(hasError: true)) => GrownUpErrorView(
            error: progress.error ?? catalog.error ?? const ServerFailure(),
            onRetry: () {
              ref.invalidate(childProgressProvider(childId));
              ref.invalidate(catalogProvider);
            },
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({
    required this.childId,
    required this.progress,
    required this.catalog,
    required this.name,
  });

  final String childId;
  final ChildProgress progress;
  final Catalog catalog;
  final String name;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  static const limits = [null, 15, 30, 45, 60, 90, 120, 180];

  late bool _learn = widget.progress.sections.learn;
  late bool _together = widget.progress.sections.together;
  late bool _watch = widget.progress.sections.watch;
  late bool _listen = widget.progress.sections.listen;
  late final Set<String> _blocked = {
    ...widget.progress.controls.blockedCategoryIds,
  };
  late int? _limit = widget.progress.controls.dailyLimitMinutes;
  late final Set<String> _counted = {
    ...widget.progress.controls.limitedSections,
  };
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(mediaControlsRepositoryProvider)
          .saveControls(
            widget.childId,
            sections: SectionSwitches(
              learn: _learn,
              watch: _watch,
              listen: _listen,
              together: _together,
            ),
            controls: MediaControls(
              blockedCategoryIds: _blocked,
              dailyLimitMinutes: _limit,
              limitedSections: _counted,
            ),
          );
      ref.invalidate(childProgressProvider(widget.childId));
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.catalog.activities.where((a) => a.isMedia).toList();
    final cats = [
      for (final c in widget.catalog.categories)
        if (media.any((a) => a.categoryId == c.id)) c,
    ];
    return GrownUpPage(
      children: [
        Text('What ${widget.name} can open', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          'Games are always on. Switched-off items disappear from the Kids Area and can’t be opened. '
          'Everything shown is chosen for ${widget.name}’s age, from the birth month and year on the profile; '
          'change those there if they’re wrong.',
          style: UiText.small,
        ),
        SwitchListTile(
          title: const Text('Learning paths and courses'),
          subtitle: const Text('The Learn section'),
          value: _learn,
          onChanged: (v) => setState(() => _learn = v),
        ),
        SwitchListTile(
          title: const Text('Play together'),
          subtitle: const Text('Activities made for a grown-up and child'),
          value: _together,
          onChanged: (v) => setState(() => _together = v),
        ),
        SwitchListTile(
          title: const Text('Videos'),
          subtitle: const Text('The Watch section'),
          value: _watch,
          onChanged: (v) => setState(() => _watch = v),
        ),
        SwitchListTile(
          title: const Text('Songs and stories'),
          subtitle: const Text('The Listen section'),
          value: _listen,
          onChanged: (v) => setState(() => _listen = v),
        ),
        const SizedBox(height: Space.s6),
        Text('Categories', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          'Turn off a category to hide its videos, songs and stories.',
          style: UiText.small,
        ),
        for (final c in cats)
          SwitchListTile(
            title: Text(c.name.of()),
            subtitle: Text(
              '${media.where((a) => a.categoryId == c.id).length} items',
            ),
            value: !_blocked.contains(c.id),
            onChanged: (on) =>
                setState(() => on ? _blocked.remove(c.id) : _blocked.add(c.id)),
          ),
        const SizedBox(height: Space.s6),
        Text('Daily limit', style: UiText.h3),
        const SizedBox(height: Space.s2),
        Text(
          'When the time is used up, ${widget.name} sees “That’s all for today!” and can still play games.',
          style: UiText.small,
        ),
        const SizedBox(height: Space.s4),
        DropdownButtonFormField<int?>(
          initialValue: _limit,
          decoration: const InputDecoration(
            labelText: 'Watching and listening per day',
          ),
          items: [
            for (final l in limits)
              DropdownMenuItem(
                value: l,
                child: Text(l == null ? 'No limit' : '$l minutes'),
              ),
          ],
          onChanged: (v) => setState(() => _limit = v),
        ),
        if (_limit != null) ...[
          const SizedBox(height: Space.s4),
          Text('What counts towards the limit', style: UiText.small),
          CheckboxListTile(
            title: const Text('Videos'),
            value: _counted.contains('watch'),
            onChanged: (v) => setState(
              () => v! ? _counted.add('watch') : _counted.remove('watch'),
            ),
          ),
          CheckboxListTile(
            title: const Text('Songs and stories'),
            value: _counted.contains('listen'),
            onChanged: (v) => setState(
              () => v! ? _counted.add('listen') : _counted.remove('listen'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Space.s5),
          FormErrorText(_error!),
        ],
        const SizedBox(height: Space.s7),
        PrimaryButton(label: 'Save', busy: _saving, onPressed: _save),
      ],
    );
  }
}
