import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'base_repository.dart';

class ActivityWeatherSummary {
  final double? currentTempC;
  final double? maxTempC;
  final double? minTempC;
  final int? weatherCode;
  final String? timezone;
  final String? locationName; // 카카오 역지오코딩으로 얻은 실시간 위치명

  const ActivityWeatherSummary({
    required this.currentTempC,
    required this.maxTempC,
    required this.minTempC,
    required this.weatherCode,
    required this.timezone,
    this.locationName,
  });
}

class WeatherRepository extends BaseRepository {
  static const String _weatherPath = '/api/activity/weather';

  Future<ActivityWeatherSummary?> requestWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final http.Response response = await safePost(
        buildApiUri(_weatherPath),
        body: jsonEncode(<String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[WeatherRepository.requestWeather] statusCode ${response.statusCode}',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic body = decoded['body'];
      if (body is! Map<String, dynamic>) {
        return null;
      }

      return ActivityWeatherSummary(
        currentTempC: _toDouble(body['current_temp_c']),
        maxTempC: _toDouble(body['max_temp_c']),
        minTempC: _toDouble(body['min_temp_c']),
        weatherCode: _toInt(body['weather_code']),
        timezone: body['timezone']?.toString(),
        locationName: body['location_name']?.toString(),
      );
    } catch (error) {
      debugPrint('[WeatherRepository.requestWeather] $error');
      return null;
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
