// ivis.3tier.frontend/lib/viewmodel/repository/device_registry_repository.dart
// 장치 레지스트리 CRUD + 카카오 주소 검색 레포지토리

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_repository.dart';

class DeviceRegistryRepository extends BaseRepository {
  static const String _listPath           = '/api/device-registry/list';
  static const String _upsertPath         = '/api/device-registry/upsert';
  static const String _deletePath         = '/api/device-registry/delete';
  static const String _geocodePath        = '/api/device-registry/geocode';
  static const String _searchPath         = '/api/device-registry/search';
  static const String _reverseGeocodePath = '/api/device-registry/reverseGeocode';

  // ── 목록 조회 ────────────────────────────────────────────────────────────────

  /// [deviceType] 'vehicle' | 'infra' | null (전체)
  Future<List<Map<String, dynamic>>> requestList({String? deviceType}) async {
    final Uri url = buildApiUri(_listPath);
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{
          if (deviceType != null) 'device_type': deviceType,
        }),
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      return handleResponse(response, (dynamic j) {
        final dynamic body = j['body'];
        if (body is List) {
          return body
              .map((dynamic e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.list $e');
      return <Map<String, dynamic>>[];
    }
  }

  // ── 등록 / 수정 ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> requestUpsert({
    required String deviceType,
    int? deviceId,
    String? name,
    double? locationLat,
    double? locationLng,
    String? locationAddress,
    String? homeStation,
    String? memo,
    bool isActive = true,
  }) async {
    final Uri url = buildApiUri(_upsertPath);
    final Map<String, dynamic> payload = <String, dynamic>{
      'device_type': deviceType,
      'is_active'  : isActive,
      if (deviceId        != null)                               'device_id'        : deviceId,
      if (name            != null && name.isNotEmpty)            'name'             : name,
      if (locationLat     != null)                               'location_lat'     : locationLat,
      if (locationLng     != null)                               'location_lng'     : locationLng,
      if (locationAddress != null && locationAddress.isNotEmpty) 'location_address' : locationAddress,
      if (homeStation     != null && homeStation.isNotEmpty)     'home_station'     : homeStation,
      if (memo            != null && memo.isNotEmpty)            'memo'             : memo,
    };
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(payload),
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      return handleResponse(response, (dynamic j) {
        final dynamic body = j['body'];
        if (body is Map) return Map<String, dynamic>.from(body);
        return null;
      });
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.upsert $e');
      return null;
    }
  }

  // ── 삭제 ────────────────────────────────────────────────────────────────────

  Future<bool> requestDelete(int id) async {
    final Uri url = buildApiUri(_deletePath);
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'id': id}),
      ).timeout(requestTimeout);
      if (response.statusCode != 200) return false;
      final dynamic j = jsonDecode(utf8.decode(response.bodyBytes));
      return j?['code'] == '0000';
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.delete $e');
      return false;
    }
  }

  // ── 카카오 키워드 검색 (여러 결과) ───────────────────────────────────────────

  /// 한국어 검색어로 장소/주소 검색. 최대 6개 결과 반환.
  /// 각 항목: { 'place_name', 'address_name', 'road_address', 'lat', 'lng' }
  Future<List<Map<String, dynamic>>> requestSearch(String query) async {
    final Uri url = buildApiUri(_searchPath);
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'query': query}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      return handleResponse(response, (dynamic j) {
        if (j['code'] != '0000') return <Map<String, dynamic>>[];
        final dynamic body = j['body'];
        if (body is List) {
          return body.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.search $e');
      return <Map<String, dynamic>>[];
    }
  }

  // ── 카카오 주소 → 좌표 변환 ──────────────────────────────────────────────────

  /// 반환: { 'address': String, 'lat': double, 'lng': double } 또는 null
  Future<Map<String, dynamic>?> requestGeocode(String address) async {
    final Uri url = buildApiUri(_geocodePath);
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'address': address}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return handleResponse(response, (dynamic j) {
        if (j['code'] != '0000') return null;
        final dynamic body = j['body'];
        if (body is Map) return Map<String, dynamic>.from(body);
        return null;
      });
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.geocode $e');
      return null;
    }
  }

  // 좌표 → 한국어 주소 변환
  Future<String?> requestReverseGeocode(double lat, double lng) async {
    final Uri url = buildApiUri(_reverseGeocodePath);
    try {
      final http.Response response = await safePost(
        url,
        body: jsonEncode(<String, dynamic>{'lat': lat, 'lng': lng}),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return handleResponse(response, (dynamic j) {
        if (j['code'] != '0000') return null;
        return j['body']?['address'] as String?;
      });
    } catch (e) {
      debugPrint('[Exception] DeviceRegistry.reverseGeocode $e');
      return null;
    }
  }
}
