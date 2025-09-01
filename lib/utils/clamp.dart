// lib/utils/clamp.dart

int clampIdx(int? raw, int max) {
  if (raw == null) return 0;
  if (raw < 0 || raw >= max) return 0;
  return raw;
}

T clamp<T extends num>(T value, T min, T max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int clampInt(int value, int min, int max) => clamp<int>(value, min, max);

double clampDouble(double value, double min, double max) => clamp<double>(value, min, max);
