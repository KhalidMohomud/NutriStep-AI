import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'onboarding/steps.dart';
import 'screens/app_shell.dart';
import 'screens/building_screen.dart';
import 'screens/email_sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_step_screen.dart';
import 'screens/plan_includes_screen.dart';
import 'screens/plan_reveal_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/session.dart';

const _tabs = ['/home', '/scan', '/profile'];

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: session,
  // one guard for every tab, instead of one per screen
  redirect: (context, state) {
    final path = state.matchedLocation;
    final inTabs = _tabs.any(path.startsWith);

    if (inTabs && !session.isSignedIn) return '/';
    // signed in but no targets yet: everyone gets a plan before they get the app
    if (inTabs && session.profile == null) {
      return '/onboarding/${steps.first.key}';
    }
    if (path == '/' && session.isSignedIn && session.profile != null) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/sign-in',
      builder: (_, _) => const SignInScreen(),
      routes: [
        GoRoute(path: 'email', builder: (_, _) => const EmailSignInScreen()),
      ],
    ),
    GoRoute(
      path: '/onboarding/building',
      builder: (_, _) => const BuildingScreen(),
    ),
    GoRoute(
      path: '/onboarding/plan',
      builder: (_, _) => const PlanRevealScreen(),
    ),
    GoRoute(
      path: '/onboarding/plan-includes',
      builder: (_, _) => const PlanIncludesScreen(),
    ),
    GoRoute(
      path: '/onboarding/:step',
      redirect: (_, state) =>
          stepIndex(state.pathParameters['step']!) < 0 ? '/' : null,
      // go_router keys the page by the pattern, not the step, so without a key a
      // `go` from one step to the next would keep the previous step's state
      builder: (_, state) {
        final step = state.pathParameters['step']!;
        return OnboardingStepScreen(key: ValueKey(step), stepKey: step);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (_, _) => const PersonalDetailsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
