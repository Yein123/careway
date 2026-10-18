import 'package:flutter/painting.dart';

/// Community health events shown on Home (static content from the design).
class HealthEvent {
  const HealthEvent({
    required this.tag,
    required this.title,
    required this.where,
    required this.when,
    required this.cost,
    required this.alt,
    required this.image,
    required this.background,
    required this.alignment,
    required this.description,
  });

  final String tag;
  final String title;
  final String where;
  final String when;
  final String cost;
  final String alt;
  final String image;
  final Color background;
  final Alignment alignment;
  final String description;
}

const healthEvents = [
  HealthEvent(
    tag: 'FREE · SAT 7 NOV',
    title: 'Free health screening',
    where: 'Elmina Community Hall',
    when: '8 AM–12 PM',
    cost: 'Free',
    alt: 'Health screenings: heart and stethoscope',
    image: 'assets/images/event_screening.jpg',
    background: Color(0xFFFFFFFF),
    alignment: Alignment.centerLeft,
    description:
        'Blood pressure, blood sugar and cholesterol checks, with a doctor on site to explain your results. Bring your MyKad.',
  ),
  HealthEvent(
    tag: 'AGE 60+ · NOV',
    title: 'Flu vaccination for seniors',
    where: 'Klinik Kesihatan Elmina',
    when: 'Weekdays, 8 AM–4 PM',
    cost: 'Free for 60 and above',
    alt: 'Older man getting a vaccine',
    image: 'assets/images/event_flu.jpg',
    background: Color(0xFFDDF2F7),
    alignment: Alignment(0, -0.4),
    description:
        'Walk in during clinic hours. Takes about 30 minutes including a short wait after the injection.',
  ),
  HealthEvent(
    tag: 'RM 30 · SAT 21 NOV',
    title: 'Eye check-up day',
    where: 'Hospital Shah Alam, Eye clinic',
    when: '9 AM–1 PM',
    cost: 'RM 30',
    alt: "Doctor examining a child's eyes",
    image: 'assets/images/event_eye.jpg',
    background: Color(0xFFEEEEEE),
    alignment: Alignment.center,
    description:
        'Screening for cataract and glaucoma. Eyes may be dilated, so it is best not to drive home.',
  ),
];
