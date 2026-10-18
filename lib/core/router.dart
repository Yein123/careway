import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user.dart';
import '../data/providers.dart';
import '../features/account/account_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/account/account_subpages.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/booking/book_screen.dart';
import '../features/booking/choose_help_screen.dart';
import '../features/booking/escort_review_screen.dart';
import '../features/booking/confirmed_screen.dart';
import '../features/booking/group_list_screen.dart';
import '../features/booking/not_found_screen.dart';
import '../features/booking/package_screen.dart';
import '../features/booking/payment_screen.dart';
import '../features/booking/pending_screen.dart';
import '../features/booking/upcoming_screen.dart';
import '../features/caregiver/cg_home_screen.dart';
import '../features/caregiver/cg_job_screens.dart';
import '../features/caregiver/cg_tabs.dart';
import '../features/delivery/delivery_list_screen.dart';
import '../features/delivery/delivery_request_screen.dart';
import '../features/delivery/delivery_status_screen.dart';
import '../features/family/family_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/family/patient_profile_screen.dart';
import '../features/onboarding/get_started_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/shell/shells.dart';
import '../features/visits/live_visit_screen.dart';
import '../features/visits/visits_screen.dart';

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
  if (user.role == UserRole.admin) return location == '/admin' ? null : '/admin';
  if (location == '/admin') return user.role == UserRole.caregiver ? '/cg' : '/home';
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
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/start', builder: (_, _) => const GetStartedScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/delivery/new', builder: (_, _) => const DeliveryRequestScreen()),
      GoRoute(
        path: '/delivery/:id',
        builder: (_, s) => DeliveryStatusScreen(deliveryId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'live', builder: (_, s) => DeliveryStatusScreen(deliveryId: s.pathParameters['id']!)),
          GoRoute(path: 'done', builder: (_, s) => DeliveryStatusScreen(deliveryId: s.pathParameters['id']!)),
          GoRoute(path: 'rate', builder: (_, s) => DeliveryRateScreen(deliveryId: s.pathParameters['id']!)),
          GoRoute(
            path: 'feedback',
            builder: (_, s) => DeliveryFeedbackScreen(
              deliveryId: s.pathParameters['id']!,
              stars: int.tryParse(s.uri.queryParameters['stars'] ?? '') ?? 5,
            ),
          ),
          GoRoute(path: 'thanks', builder: (_, s) => DeliveryThanksScreen(deliveryId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(
        path: '/book',
        builder: (_, s) => BookScreen(service: s.uri.queryParameters['service']),
        routes: [
          GoRoute(path: 'help', builder: (_, _) => const ChooseHelpScreen()),
          GoRoute(path: 'groups', builder: (_, s) => GroupListScreen(startNew: s.uri.queryParameters['new'] == '1')),
          GoRoute(path: 'escort', builder: (_, _) => const EscortReviewScreen()),
          GoRoute(path: 'not-found', builder: (_, s) => NotFoundScreen(reason: s.uri.queryParameters['reason'])),
        ],
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (_, s) => UpcomingScreen(bookingId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'pending', builder: (_, s) => PendingScreen(bookingId: s.pathParameters['id']!)),
          GoRoute(path: 'package', builder: (_, s) => PackageScreen(bookingId: s.pathParameters['id']!)),
          GoRoute(path: 'not-found', builder: (_, s) => NotFoundScreen(bookingId: s.pathParameters['id']!)),
          GoRoute(path: 'pay', builder: (_, s) => PaymentScreen(bookingId: s.pathParameters['id']!)),
          GoRoute(path: 'confirmed', builder: (_, s) => ConfirmedScreen(bookingId: s.pathParameters['id']!)),
          GoRoute(path: 'live', builder: (_, s) => LiveVisitScreen(bookingId: s.pathParameters['id']!)),
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
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomeScreen(),
              ),
              GoRoute(path: '/deliveries', builder: (_, _) => const DeliveryListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/visits', builder: (_, _) => const VisitsScreen()),
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
                builder: (_, s) => AccountScreen(section: s.uri.queryParameters['section']),
                routes: [
                  GoRoute(path: 'payments', builder: (_, _) => const PaymentsScreen()),
                  GoRoute(path: 'receipts', builder: (_, _) => const ReceiptsScreen()),
                  GoRoute(path: 'places', builder: (_, _) => const PlacesScreen()),
                  GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
                  GoRoute(path: 'language', builder: (_, _) => const LanguageScreen()),
                  GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
                ],
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
                builder: (_, _) => const CgHomeScreen(),
                routes: [
                  GoRoute(path: 'notifications', builder: (_, _) => const NotificationsScreen()),
                  GoRoute(path: 'job/:id', builder: (_, s) => CgJobScreen(bookingId: s.pathParameters['id']!)),
                  GoRoute(path: 'job/:id/steps', builder: (_, s) => CgStepsScreen(bookingId: s.pathParameters['id']!)),
                  GoRoute(path: 'job/:id/summary', builder: (_, s) => CgSummaryScreen(bookingId: s.pathParameters['id']!)),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cg/schedule', builder: (_, _) => const CgScheduleScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cg/patients', builder: (_, _) => const CgPatientsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cg/account', builder: (_, _) => const CgAccountScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
