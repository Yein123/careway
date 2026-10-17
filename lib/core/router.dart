import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user.dart';
import '../data/providers.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/booking/book_screen.dart';
import '../features/booking/choose_help_screen.dart';
import '../features/booking/escort_review_screen.dart';
import '../features/booking/group_list_screen.dart';
import '../features/family/family_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/family/patient_profile_screen.dart';
import '../features/onboarding/get_started_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/shell/shells.dart';

const publicRoutes = {'/', '/start', '/signin', '/cg/signin'};

/// Re-runs the router redirect when sign-in state or the user profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

/// Signed out → public pages only. Caregivers stay under /cg; guardians are
/// kept out of /cg. While the profile is loading (e.g. right after sign-up)
/// the current page is kept.
String? roleRedirect(Ref ref, String location) {
  final public = publicRoutes.contains(location);
  final auth = ref.read(authStateProvider);
  if (!auth.hasValue) return null;
  final uid = auth.value;
  if (uid == null) return public ? null : '/';
  final user = ref.read(currentUserProvider).value;
  if (user == null) return null;
  final inCaregiverApp = location == '/cg' || location.startsWith('/cg/');
  if (user.role == UserRole.caregiver) {
    return (!inCaregiverApp || location == '/cg/signin') ? '/cg' : null;
  }
  return (public || inCaregiverApp) ? '/home' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => roleRedirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/start', builder: (_, _) => const GetStartedScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/book',
        builder: (_, s) => BookScreen(service: s.uri.queryParameters['service']),
        routes: [
          GoRoute(path: 'help', builder: (_, _) => const ChooseHelpScreen()),
          GoRoute(path: 'groups', builder: (_, _) => const GroupListScreen()),
          GoRoute(path: 'escort', builder: (_, _) => const EscortReviewScreen()),
          GoRoute(path: 'not-found', builder: (_, s) => PlaceholderTab('Not found: ${s.uri.queryParameters['reason']}')),
        ],
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (_, s) => PlaceholderTab('Booking ${s.pathParameters['id']}'),
        routes: [
          GoRoute(path: 'pending', builder: (_, s) => PlaceholderTab('Pending ${s.pathParameters['id']}')),
        ],
      ),
      GoRoute(
        path: '/cg/signin',
        builder: (_, _) => const SignInScreen(caregiver: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => GuardianShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/visits',
                builder: (_, _) => const PlaceholderTab('Visits'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/family',
                builder: (_, _) => const FamilyScreen(),
                routes: [
                  GoRoute(path: 'patient/new', builder: (_, _) => const NewPatientScreen()),
                  GoRoute(
                    path: 'patient/:pid',
                    builder: (_, s) => PatientProfileScreen(patientId: s.pathParameters['pid']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const PlaceholderTab('Account'),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CaregiverShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cg',
                builder: (_, _) => const PlaceholderTab('Today'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cg/schedule',
                builder: (_, _) => const PlaceholderTab('Schedule'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cg/patients',
                builder: (_, _) => const PlaceholderTab('Patients'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cg/account',
                builder: (_, _) => const PlaceholderTab('Account'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
