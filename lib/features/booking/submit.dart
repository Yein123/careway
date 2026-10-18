import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import 'booking_draft.dart';

/// The draft's patient, if loaded.
Patient? draftPatient(WidgetRef ref) {
  final id = ref.watch(bookingDraftProvider).patientId;
  for (final p in ref.watch(allPatientsProvider).value ?? const <Patient>[]) {
    if (p.id == id) return p;
  }
  return null;
}

/// Sends the draft to requestBooking and routes by outcome: pending, waitlist
/// (draft booking), or Group not found when the seat/group is gone.
Future<void> submitDraft(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final draft = ref.read(bookingDraftProvider);
  try {
    final r = await ref.read(careWayApiProvider).requestBooking(draft.toRequest());
    router.go(r.status == 'draft' ? '/booking/${r.bookingId}' : '/booking/${r.bookingId}/pending');
  } on CareWayException catch (e) {
    if (e.code == 'seat-taken' || e.code == 'group-full') {
      router.go('/book/not-found?reason=${e.code}');
    } else {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}
