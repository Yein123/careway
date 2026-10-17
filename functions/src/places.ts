// Mirrors lib/config/places.dart.
export interface Place {
  id: string;
  name: string;
  area: string;
  lat: number;
  lng: number;
}

export const HOSPITALS: Place[] = [
  { id: 'hsb', name: 'Hospital Sungai Buloh', area: 'Sungai Buloh', lat: 3.2196, lng: 101.5826 },
  { id: 'hsa', name: 'Hospital Shah Alam', area: 'Shah Alam', lat: 3.0715, lng: 101.49 },
  { id: 'htar', name: 'Hospital Tengku Ampuan Rahimah, Klang', area: 'Klang', lat: 3.0205, lng: 101.4409 },
  { id: 'kke', name: 'Klinik Kesihatan Elmina', area: 'Elmina', lat: 3.1797, lng: 101.5079 },
];

export const PICKUP_POINTS: Place[] = [
  { id: 'elmina-lakeside', name: 'Elmina Lakeside pickup bay', area: 'Elmina', lat: 3.187, lng: 101.518 },
  { id: 'elmina-west', name: 'Elmina West, near the surau', area: 'Elmina', lat: 3.185, lng: 101.505 },
  { id: 'denai-alam', name: 'Denai Alam community hall', area: 'Denai Alam', lat: 3.13, lng: 101.54 },
];

export function placeById(id: string): Place | undefined {
  return [...HOSPITALS, ...PICKUP_POINTS].find((p) => p.id === id);
}

const MYT_OFFSET_MS = 8 * 3600_000;

/** Local (Malaysia, UTC+8) date 'yyyy-MM-dd'. */
export function mytDate(d: Date): string {
  return new Date(d.getTime() + MYT_OFFSET_MS).toISOString().slice(0, 10);
}

/** Local time like '9:00 AM'. */
export function mytTime(d: Date): string {
  const l = new Date(d.getTime() + MYT_OFFSET_MS);
  const h = l.getUTCHours();
  const m = l.getUTCMinutes().toString().padStart(2, '0');
  return `${h % 12 === 0 ? 12 : h % 12}:${m} ${h < 12 ? 'AM' : 'PM'}`;
}
