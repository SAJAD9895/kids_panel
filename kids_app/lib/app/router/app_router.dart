import '../../features/media/presentation/screens/audio_screens.dart';
import '../../features/parents/domain/parent_reports.dart';
import '../../features/parents/presentation/screens/child_report_screen.dart';
import '../../features/parents/presentation/screens/notifications_screens.dart';
import '../../features/parents/presentation/screens/privacy_screen.dart';
import '../../features/parents/presentation/screens/subscription_screen.dart';
import '../../features/rewards/domain/rewards.dart' show parseDay;
import '../../features/parents/presentation/screens/child_rewards_screen.dart';
import '../../features/rewards/presentation/screens/rewards_screen.dart';
import '../../features/media/presentation/screens/media_library_screen.dart';
import '../../features/media/presentation/screens/story_reader_screen.dart';
import '../../features/media/presentation/screens/video_screens.dart';
import '../../features/parents/presentation/screens/media_controls_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock/clock.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/gate/gate_controller.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/verify_code_screen.dart';
import '../../features/child_profiles/presentation/child_providers.dart';
import '../../features/child_profiles/presentation/screens/avatar_picker_screen.dart';
import '../../features/child_profiles/presentation/screens/child_details_screen.dart';
import '../../features/child_profiles/presentation/screens/child_edit_screen.dart';
import '../../features/child_profiles/presentation/screens/children_screen.dart';
import '../../features/child_profiles/presentation/screens/who_is_playing_screen.dart';
import '../../features/kids_home/presentation/screens/kids_home_screen.dart';
import '../../features/onboarding/presentation/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/finish_setup_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/parents/presentation/screens/parental_gate_screen.dart';
import '../../features/parents/presentation/screens/parents_home_screen.dart';
import '../../features/kids_home/presentation/widgets/kids_shell.dart';
import '../../features/learning/presentation/screens/course_screens.dart';
import '../../features/learning/presentation/screens/learn_screens.dart';
import '../../features/learning/presentation/screens/me_and_shelves.dart';
import '../../features/learning/presentation/screens/subject_screens.dart';
import '../../features/play/presentation/activity_player_screen.dart';
import 'guards.dart';
import 'routes.dart';

/// Reads the session from providers into a [GuardState].
GuardState readGuardState(Ref ref) {
  final auth = ref.read(authStateProvider);
  final family = ref.read(familyStatusProvider);
  return GuardState(
    auth: auth.isLoading && !auth.hasValue
        ? AuthStatus.unknown
        : (auth.value == null ? AuthStatus.signedOut : AuthStatus.signedIn),
    family: family.isLoading || family.hasError || family.value == null
        ? FamilyStatus.unknown
        : (family.value! ? FamilyStatus.exists : FamilyStatus.none),
    onboardingReady: ref.read(onboardingReadyProvider),
    childDraftReady: ref
        .read(childDraftProvider(ChildFlow.onboarding))
        .hasDetails,
    childSelected: ref.read(selectedChildIdProvider) != null,
    gateOpen: ref.read(gateProvider).isOpen(ref.read(clockProvider)()),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump() => refresh.value++;
  ref.listen(authStateProvider, (_, _) => bump());
  ref.listen(familyStatusProvider, (_, _) => bump());
  ref.listen(onboardingReadyProvider, (_, _) => bump());
  ref.listen(
    childDraftProvider(ChildFlow.onboarding).select((d) => d.hasDetails),
    (_, _) => bump(),
  );
  ref.listen(selectedChildIdProvider, (_, _) => bump());
  ref.listen(gateProvider.select((g) => g.unlockedUntil), (_, _) => bump());

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(readGuardState(ref), state.uri),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: Routes.setupChild,
        builder: (_, _) => const ChildDetailsScreen(flow: ChildFlow.onboarding),
      ),
      GoRoute(
        path: Routes.setupBuddy,
        builder: (_, _) =>
            const AvatarPickerScreen.step(flow: ChildFlow.onboarding),
      ),
      GoRoute(
        path: Routes.setupGrownUp,
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.setupFinish,
        builder: (_, _) => const FinishSetupScreen(),
      ),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.verifyCode,
        builder: (_, _) => const VerifyCodeScreen(),
      ),
      GoRoute(
        path: Routes.whoIsPlaying,
        builder: (_, _) => const WhoIsPlayingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            KidsShell(location: state.uri.path, child: child),
        routes: [
          _kid(Routes.kids, (_) => const KidsHomeScreen()),
          _kid(Routes.learn, (_) => const LearnScreen()),
          _kid(Routes.watch, (_) => const MediaLibraryScreen(surface: 'watch')),
          _kid(
            '${Routes.watch}/:id',
            (s) => VideoDetailsScreen(activityId: s.pathParameters['id']!),
          ),
          _kid(
            Routes.listen,
            (_) => const MediaLibraryScreen(surface: 'listen'),
          ),
          _kid(Routes.me, (_) => const MeScreen()),
          _kid(Routes.rewards, (_) => const RewardsScreen()),
          _kid(Routes.subjects, (_) => const SubjectsScreen()),
          _kid(
            '${Routes.subjects}/:key',
            (s) => SubjectScreen(subjectKey: s.pathParameters['key']!),
          ),
          _kid(
            '${Routes.kids}/paths/:id',
            (s) => LearningPathScreen(pathId: s.pathParameters['id']!),
          ),
          _kid(Routes.courses, (_) => const CourseListScreen()),
          _kid(
            '${Routes.courses}/:id',
            (s) => CourseScreen(courseId: s.pathParameters['id']!),
          ),
          _kid(
            '${Routes.courses}/:id/lessons/:lessonId',
            (s) => LessonScreen(
              courseId: s.pathParameters['id']!,
              lessonId: s.pathParameters['lessonId']!,
            ),
          ),
          _kid(
            '${Routes.kids}/activities/:id',
            (s) => ActivityScreen(
              activityId: s.pathParameters['id']!,
              courseId: s.uri.queryParameters['course'],
              stepId: s.uri.queryParameters['step'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '${Routes.kids}/play/:id',
        builder: (_, s) => ActivityPlayerScreen(
          key: ValueKey(s.uri.toString()),
          args: (
            activityId: s.pathParameters['id']!,
            courseId: s.uri.queryParameters['course'],
            stepId: s.uri.queryParameters['step'],
            source: playSourceFrom(
              s.uri.queryParameters['from'],
              fromCourse: s.uri.queryParameters['course'] != null,
            ),
          ),
        ),
      ),
      // Media players are full screen (no rail), like the game player.
      GoRoute(
        path: '${Routes.watch}/:id/play',
        builder: (_, s) => VideoPlayerScreen(
          key: ValueKey(s.uri.toString()),
          activityId: s.pathParameters['id']!,
          stepId: s.uri.queryParameters['step'],
        ),
      ),
      GoRoute(
        path: '${Routes.listen}/songs/:id',
        builder: (_, s) =>
            SongPlayerScreen(activityId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.listen}/stories/:id',
        builder: (_, s) => StoryReaderScreen(
          key: ValueKey(s.uri.toString()),
          activityId: s.pathParameters['id']!,
          stepId: s.uri.queryParameters['step'],
        ),
      ),
      GoRoute(
        path: Routes.meBuddy,
        builder: (_, state) => AvatarPickerScreen.pick(
          selectedId: state.uri.queryParameters['selected'],
        ),
      ),
      GoRoute(
        path: Routes.gate,
        builder: (_, state) =>
            ParentalGateScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.parents,
        builder: (_, _) => const ParentsHomeScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const NotificationsScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (_, _) => const NotificationSettingsScreen(),
              ),
            ],
          ),
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
          GoRoute(
            path: 'subscription',
            builder: (_, _) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: 'children',
            builder: (_, _) => const ChildrenScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const ChildDetailsScreen(flow: ChildFlow.addChild),
                routes: [
                  GoRoute(
                    path: 'buddy',
                    builder: (_, _) =>
                        const AvatarPickerScreen.step(flow: ChildFlow.addChild),
                  ),
                ],
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ChildEditScreen(childId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'buddy',
                    builder: (_, state) => AvatarPickerScreen.pick(
                      selectedId: state.uri.queryParameters['selected'],
                    ),
                  ),
                  GoRoute(
                    path: 'media',
                    builder: (_, state) => MediaControlsScreen(
                      childId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'rewards',
                    builder: (_, state) => ChildRewardsScreen(
                      childId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'report',
                    builder: (_, state) => ChildReportScreen(
                      key: ValueKey(state.uri.toString()),
                      childId: state.pathParameters['id']!,
                      period: ReportPeriod.parse(
                        state.uri.queryParameters['period'],
                      ),
                      date: parseDay(state.uri.queryParameters['date']),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// A Kids Area page with a soft fade-and-rise transition (none with "reduce motion").
GoRoute _kid(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: build(state),
        transitionDuration: Motion.base,
        reverseTransitionDuration: Motion.fast,
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Motion.easeDecelerate,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
