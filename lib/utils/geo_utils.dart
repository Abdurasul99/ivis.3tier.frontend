// ivis.3tier.frontend/lib/utils/geo_utils.dart

import 'dart:math';

double degreesToRadians(double degrees) {
  return degrees * pi / 180.0;
}

double radiansToDegrees(double radiansValue) {
  return radiansValue * 180.0 / pi;
}

double normalizeHeadingDegrees(double heading) {
  double normalized = heading % 360.0;
  if (normalized < 0.0) {
    normalized += 360.0;
  }
  return normalized;
}

double shortestAngleDelta(double fromDegrees, double toDegrees) {
  double delta = normalizeHeadingDegrees(toDegrees) - normalizeHeadingDegrees(fromDegrees);
  if (delta > 180.0) {
    delta -= 360.0;
  }
  if (delta < -180.0) {
    delta += 360.0;
  }
  return delta;
}

class Utm52NCoordinate {
  final double eastingMeters;
  final double northingMeters;

  const Utm52NCoordinate({
    required this.eastingMeters,
    required this.northingMeters,
  });
}

class Wgs84Coordinate {
  final double latitudeDegrees;
  final double longitudeDegrees;

  const Wgs84Coordinate({
    required this.latitudeDegrees,
    required this.longitudeDegrees,
  });
}

Utm52NCoordinate convertWgs84ToUtmZone52N({
  required double latitudeDegrees,
  required double longitudeDegrees,
}) {
  const double equatorialRadiusMeters = 6378137.0;
  const double flattening = 1.0 / 298.257223563;
  const double k0 = 0.9996;
  const int zoneNumber = 52;
  const double falseEastingMeters = 500000.0;

  final double eccentricitySquared = flattening * (2.0 - flattening);
  final double eccentricityPrimeSquared = eccentricitySquared / (1.0 - eccentricitySquared);

  final double latitudeRadians = degreesToRadians(latitudeDegrees);
  final double longitudeRadians = degreesToRadians(longitudeDegrees);

  final double centralMeridianDegrees = (zoneNumber - 1) * 6.0 - 180.0 + 3.0;
  final double centralMeridianRadians = degreesToRadians(centralMeridianDegrees);

  final double sinLatitude = sin(latitudeRadians);
  final double cosLatitude = cos(latitudeRadians);
  final double tanLatitude = tan(latitudeRadians);

  final double n = equatorialRadiusMeters / sqrt(1.0 - eccentricitySquared * sinLatitude * sinLatitude);
  final double t = tanLatitude * tanLatitude;
  final double c = eccentricityPrimeSquared * cosLatitude * cosLatitude;
  final double a = cosLatitude * (longitudeRadians - centralMeridianRadians);

  final double m = equatorialRadiusMeters *
      ((1.0 -
                  eccentricitySquared / 4.0 -
                  3.0 * eccentricitySquared * eccentricitySquared / 64.0 -
                  5.0 * eccentricitySquared * eccentricitySquared * eccentricitySquared / 256.0) *
              latitudeRadians -
          (3.0 * eccentricitySquared / 8.0 +
                  3.0 * eccentricitySquared * eccentricitySquared / 32.0 +
                  45.0 * eccentricitySquared * eccentricitySquared * eccentricitySquared / 1024.0) *
              sin(2.0 * latitudeRadians) +
          (15.0 * eccentricitySquared * eccentricitySquared / 256.0 +
                  45.0 * eccentricitySquared * eccentricitySquared * eccentricitySquared / 1024.0) *
              sin(4.0 * latitudeRadians) -
          (35.0 * eccentricitySquared * eccentricitySquared * eccentricitySquared / 3072.0) *
              sin(6.0 * latitudeRadians));

  final double eastingMeters = falseEastingMeters +
      k0 *
          n *
          (a +
              (1.0 - t + c) * pow(a, 3).toDouble() / 6.0 +
              (5.0 - 18.0 * t + t * t + 72.0 * c - 58.0 * eccentricityPrimeSquared) * pow(a, 5).toDouble() / 120.0);

  double northingMeters = k0 *
      (m +
          n *
              tanLatitude *
              (a * a / 2.0 +
                  (5.0 - t + 9.0 * c + 4.0 * c * c) * pow(a, 4).toDouble() / 24.0 +
                  (61.0 - 58.0 * t + t * t + 600.0 * c - 330.0 * eccentricityPrimeSquared) *
                      pow(a, 6).toDouble() /
                      720.0));

  if (latitudeDegrees < 0.0) {
    northingMeters += 10000000.0;
  }

  return Utm52NCoordinate(eastingMeters: eastingMeters, northingMeters: northingMeters);
}

Wgs84Coordinate convertUtmZone52NToWgs84({
  required double eastingMeters,
  required double northingMeters,
}) {
  const double equatorialRadiusMeters = 6378137.0;
  const double flattening = 1.0 / 298.257223563;
  const double k0 = 0.9996;
  const int zoneNumber = 52;
  const double falseEastingMeters = 500000.0;
  const double falseNorthingMeters = 0.0;

  final double eccentricitySquared = flattening * (2.0 - flattening);
  final double eccentricityPrimeSquared = eccentricitySquared / (1.0 - eccentricitySquared);

  final double e1 = (1.0 - sqrt(1.0 - eccentricitySquared)) / (1.0 + sqrt(1.0 - eccentricitySquared));
  final double x = eastingMeters - falseEastingMeters;
  final double y = northingMeters - falseNorthingMeters;
  final double centralMeridianDegrees = (zoneNumber - 1) * 6.0 - 180.0 + 3.0;
  final double m = y / k0;
  final double mu = m /
      (equatorialRadiusMeters *
          (1.0 -
              eccentricitySquared / 4.0 -
              3.0 * eccentricitySquared * eccentricitySquared / 64.0 -
              5.0 * eccentricitySquared * eccentricitySquared * eccentricitySquared / 256.0));

  final double phi1Rad = mu +
      (3.0 * e1 / 2.0 - 27.0 * e1 * e1 * e1 / 32.0) * sin(2.0 * mu) +
      (21.0 * e1 * e1 / 16.0 - 55.0 * e1 * e1 * e1 * e1 / 32.0) * sin(4.0 * mu) +
      (151.0 * e1 * e1 * e1 / 96.0) * sin(6.0 * mu) +
      (1097.0 * e1 * e1 * e1 * e1 / 512.0) * sin(8.0 * mu);

  final double sinPhi1 = sin(phi1Rad);
  final double cosPhi1 = cos(phi1Rad);
  final double tanPhi1 = tan(phi1Rad);
  final double n1 = equatorialRadiusMeters / sqrt(1.0 - eccentricitySquared * sinPhi1 * sinPhi1);
  final double t1 = tanPhi1 * tanPhi1;
  final double c1 = eccentricityPrimeSquared * cosPhi1 * cosPhi1;
  final double r1 =
      equatorialRadiusMeters * (1.0 - eccentricitySquared) / pow(1.0 - eccentricitySquared * sinPhi1 * sinPhi1, 1.5);

  final double d = x / (n1 * k0);

  final double latitudeRadians = phi1Rad -
      (n1 * tanPhi1 / r1) *
          (d * d / 2.0 -
              (5.0 + 3.0 * t1 + 10.0 * c1 - 4.0 * c1 * c1 - 9.0 * eccentricityPrimeSquared) * d * d * d * d / 24.0 +
              (61.0 + 90.0 * t1 + 298.0 * c1 + 45.0 * t1 * t1 - 252.0 * eccentricityPrimeSquared - 3.0 * c1 * c1) *
                  d *
                  d *
                  d *
                  d *
                  d *
                  d /
                  720.0);

  final double longitudeRadians = degreesToRadians(centralMeridianDegrees) +
      (d -
              (1.0 + 2.0 * t1 + c1) * d * d * d / 6.0 +
              (5.0 - 2.0 * c1 + 28.0 * t1 - 3.0 * c1 * c1 + 8.0 * eccentricityPrimeSquared + 24.0 * t1 * t1) *
                  d *
                  d *
                  d *
                  d *
                  d /
                  120.0) /
          cosPhi1;

  return Wgs84Coordinate(
    latitudeDegrees: radiansToDegrees(latitudeRadians),
    longitudeDegrees: radiansToDegrees(longitudeRadians),
  );
}

double euclideanDistanceMeters({
  required double x1Meters,
  required double y1Meters,
  required double x2Meters,
  required double y2Meters,
}) {
  final double deltaX = x2Meters - x1Meters;
  final double deltaY = y2Meters - y1Meters;
  return sqrt(deltaX * deltaX + deltaY * deltaY);
}

double headingDegreesFromUtm({
  required double fromEastingMeters,
  required double fromNorthingMeters,
  required double toEastingMeters,
  required double toNorthingMeters,
}) {
  final double deltaEasting = toEastingMeters - fromEastingMeters;
  final double deltaNorthing = toNorthingMeters - fromNorthingMeters;
  final double radiansFromNorth = atan2(deltaEasting, deltaNorthing);
  final double degreesFromNorth = radiansToDegrees(radiansFromNorth);
  return normalizeHeadingDegrees(degreesFromNorth);
}

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusMeters = 6371000.0;
  final double dLat = degreesToRadians(lat2 - lat1);
  final double dLon = degreesToRadians(lon2 - lon1);
  final double h = sin(dLat / 2) * sin(dLat / 2) +
      cos(degreesToRadians(lat1)) * cos(degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return earthRadiusMeters * 2.0 * atan2(sqrt(h), sqrt(1.0 - h));
}

double bearingBetween(double fromLat, double fromLon, double toLat, double toLon) {
  final double lat1 = degreesToRadians(fromLat);
  final double lat2 = degreesToRadians(toLat);
  final double dLon = degreesToRadians(toLon - fromLon);
  final double y = sin(dLon) * cos(lat2);
  final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  return normalizeHeadingDegrees(radiansToDegrees(atan2(y, x)));
}

bool looksLikeWgsLonLat(double x, double y) {
  return x.abs() <= 180.0 && y.abs() <= 90.0;
}

bool isValidUtmEasting(double e) {
  return e.isFinite && e >= 100000.0 && e <= 900000.0;
}

bool isValidUtmNorthing(double n) {
  return n.isFinite && n >= 0.0 && n <= 10000000.0;
}

bool isValidUtmCoordinate(double easting, double northing) {
  return isValidUtmEasting(easting) && isValidUtmNorthing(northing);
}

bool validateStrictUtmPair({
  required double easting,
  required double northing,
}) {
  if (looksLikeWgsLonLat(easting, northing)) {
    return false;
  }
  if (!isValidUtmEasting(easting)) {
    return false;
  }
  if (!isValidUtmNorthing(northing)) {
    return false;
  }
  return true;
}

bool isValidLatLng(double lat, double lon) {
  return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
}

Utm52NCoordinate lerpUtm(Utm52NCoordinate a, Utm52NCoordinate b, double t) {
  return Utm52NCoordinate(
    eastingMeters: a.eastingMeters + (b.eastingMeters - a.eastingMeters) * t,
    northingMeters: a.northingMeters + (b.northingMeters - a.northingMeters) * t,
  );
}
