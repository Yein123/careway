import 'package:careway/config/places.dart';
import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/family.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:careway/domain/needs.dart';
import 'package:careway/domain/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Booking round-trips through a Firestore map', () {
    final b = Booking(
      id: 'b1',
      familyId: 'f1',
      guardianUid: 'u1',
      patientId: 'p1',
      patient: const PatientSnapshot(name: 'Zainab binti Ahmad', age: 72, mobility: Mobility.stick),
      level: 1,
      pickup: const PlaceRef(label: 'Elmina Lakeside pickup bay', lat: 3.187, lng: 101.518),
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      apptAt: DateTime.utc(2026, 10, 26, 1),
      groupId: 'g1',
      package: GroupPackage.saver,
      addons: const {Addon.language},
      language: 'Tamil',
      caregiverId: 'cg1',
      caregiverName: 'Farid A.',
      status: BookingStatus.awaitingPayment,
      price: const PriceInfo(lines: [PriceLine('Group Saver', 2200), PriceLine('Language help', 800)], paidSen: 0),
      steps: [VisitStep('picked_up', DateTime.utc(2026, 10, 26, 0, 48))],
      rating: const Rating(stars: 5, tags: ['Kind'], text: 'Thank you'),
      createdAt: DateTime.utc(2026, 10, 17),
    );
    expect(Booking.fromMap('b1', b.toMap()), b);
    expect(Booking.fromMap('b1', b.toMap()).status, BookingStatus.awaitingPayment);
  });

  test('Patient round-trips and has initials', () {
    final p = Patient(
      id: 'p1',
      name: 'Zainab binti Ahmad',
      age: 72,
      relationship: 'Parent',
      phone: '012-345 6789',
      mobility: Mobility.stick,
      extraHelp: const ['Hard of hearing'],
      allergy: 'Penicillin',
      contacts: const [Contact(name: 'Aisyah', role: 'Main guardian', phone: '017-882 4410')],
      updatedAt: DateTime.utc(2026, 10, 14),
    );
    expect(Patient.fromMap('p1', p.toMap()), p);
    expect(p.initials, 'ZA');
  });

  test('places lookup by id', () {
    expect(placeById('hsb').name, 'Hospital Sungai Buloh');
    expect(pickupPoints.map((p) => p.name), contains('Elmina Lakeside pickup bay'));
  });
}
