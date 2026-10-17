/// Static reference places with coordinates (spec §3). Mirrored in
/// functions/src/places.ts.
enum PlaceKind { hospital, clinic, pharmacy, pickupPoint }

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.area,
    required this.lat,
    required this.lng,
    required this.kind,
  });

  final String id;
  final String name;
  final String area;
  final double lat;
  final double lng;
  final PlaceKind kind;
}

const hospitals = [
  Place(id: 'hsb', name: 'Hospital Sungai Buloh', area: 'Sungai Buloh', lat: 3.2196, lng: 101.5826, kind: PlaceKind.hospital),
  Place(id: 'hsa', name: 'Hospital Shah Alam', area: 'Shah Alam', lat: 3.0715, lng: 101.4900, kind: PlaceKind.hospital),
  Place(id: 'htar', name: 'Hospital Tengku Ampuan Rahimah, Klang', area: 'Klang', lat: 3.0205, lng: 101.4409, kind: PlaceKind.hospital),
  Place(id: 'kke', name: 'Klinik Kesihatan Elmina', area: 'Elmina', lat: 3.1797, lng: 101.5079, kind: PlaceKind.clinic),
];

/// Pharmacies for medicine delivery: the hospital and clinic pharmacies.
const pharmacies = hospitals;

const pickupPoints = [
  Place(id: 'elmina-lakeside', name: 'Elmina Lakeside pickup bay', area: 'Elmina', lat: 3.1870, lng: 101.5180, kind: PlaceKind.pickupPoint),
  Place(id: 'elmina-west', name: 'Elmina West, near the surau', area: 'Elmina', lat: 3.1850, lng: 101.5050, kind: PlaceKind.pickupPoint),
  Place(id: 'denai-alam', name: 'Denai Alam community hall', area: 'Denai Alam', lat: 3.1300, lng: 101.5400, kind: PlaceKind.pickupPoint),
];

const clinicDepartments = [
  'Orthopaedic specialist clinic',
  'Diabetes / medical clinic',
  'Eye clinic',
  'Physiotherapy',
  'Dialysis',
  'Paediatric clinic',
];

const allPlaces = [...hospitals, ...pickupPoints];

Place placeById(String id) =>
    allPlaces.firstWhere((p) => p.id == id, orElse: () => throw ArgumentError.value(id, 'placeId'));
