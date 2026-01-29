import 'dart:math';

class QiblaService {
  // Kaaba (Masjid al-Haram) coordinates
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLon = 39.826206;

  /// Returns initial bearing from (lat, lon) to Kaaba in degrees (0..360),
  /// where 0 = North, 90 = East, 180 = South, 270 = West.
  static double bearingDegrees({
    required double latitude,
    required double longitude,
  }) {
    final lat1 = _degToRad(latitude);
    final lon1 = _degToRad(longitude);
    final lat2 = _degToRad(_kaabaLat);
    final lon2 = _degToRad(_kaabaLon);

    final dLon = lon2 - lon1;

    final y = sin(dLon) * cos(lat2);
    final x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final bearingRad = atan2(y, x);
    final bearingDeg = (_radToDeg(bearingRad) + 360.0) % 360.0;
    return bearingDeg;
  }

  static double _degToRad(double deg) => deg * pi / 180.0;
  static double _radToDeg(double rad) => rad * 180.0 / pi;
}
