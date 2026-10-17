import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/family.dart';
import 'package:careway/data/models/user.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:careway/domain/needs.dart';

import '../fakes/fake_repos.dart';

final now = DateTime.utc(2026, 10, 17, 8);
final appt = DateTime.utc(2026, 10, 26, 1); // Mon 26 Oct, 9:00 AM local

const guardian = AppUser(
  uid: 'g1',
  name: 'Aisyah binti Hassan',
  email: 'aisyah@careway.demo',
  phone: '+60 17-882 4410',
  area: 'Elmina, Shah Alam',
  role: UserRole.guardian,
  familyId: 'f1',
  savedPlaces: [SavedPlace(label: 'Home', address: '12, Jalan Elmina Lakeside', lat: 3.1885, lng: 101.5165)],
);

const family = Family(id: 'f1', name: 'Ahmad family', adminUid: 'g1', memberUids: ['g1'], memberNames: {'g1': 'Aisyah (daughter)'});

const zainab = Patient(
  id: 'p1',
  name: 'Zainab binti Ahmad',
  age: 72,
  relationship: 'Parent',
  phone: '012-345 6789',
  mobility: Mobility.stick,
  extraHelp: ['Hearing'],
  conditions: 'Type 2 diabetes, high blood pressure, knee osteoarthritis',
  allergy: 'Penicillin',
  talkNotes: 'Speaks Malay, some English.',
);

Booking booking({
  String id = 'b1',
  BookingStatus status = BookingStatus.confirmed,
  int level = 1,
  DateTime? apptAt,
  List<VisitStep> steps = const [],
  String? caregiverName = 'Farid A.',
  PriceInfo price = const PriceInfo(),
  VisitSummary? summary,
  Rating? rating,
  String? groupId,
  String? notMatchedReason,
  DateTime? offerExpiresAt,
  String? offerCaregiverName,
  List<String> caregiverSkills = const ['wheelchair', 'medicineCollection'],
  List<String> caregiverLanguages = const ['Malay', 'English'],
  bool waitlist = false,
}) =>
    Booking(
      id: id,
      familyId: 'f1',
      guardianUid: 'g1',
      patientId: 'p1',
      patient: const PatientSnapshot(name: 'Zainab binti Ahmad', age: 72, mobility: Mobility.stick),
      level: level,
      pickup: const PlaceRef(label: 'Elmina Lakeside pickup bay', lat: 3.187, lng: 101.518),
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      apptAt: apptAt ?? appt,
      pickupAt: (apptAt ?? appt).subtract(const Duration(minutes: 75)),
      status: status,
      caregiverId: caregiverName == null ? null : 'cg1',
      caregiverName: caregiverName,
      caregiverSkills: caregiverSkills,
      caregiverLanguages: caregiverLanguages,
      waitlist: waitlist,
      lockAt: (apptAt ?? appt).subtract(const Duration(hours: 25, minutes: 15)),
      steps: steps,
      price: price,
      summary: summary,
      rating: rating,
      groupId: groupId ?? (level == 1 ? 'grp' : null),
      notMatchedReason: notMatchedReason,
      offerExpiresAt: offerExpiresAt,
      offerCaregiverName: offerCaregiverName,
      createdAt: now,
    );

/// A signed-in guardian with family f1 and optional patients/bookings.
Fakes guardianFakes({List<Patient> patients = const [zainab], List<Booking> bookings = const []}) => Fakes(
      uid: 'g1',
      users: [guardian],
      families: [family],
      patients: {'f1': patients},
      bookings: bookings,
    );
