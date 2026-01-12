import 'package:get/get.dart';

import '../../model/infra_model.dart';
import '../repository/infra_repository.dart';
import 'user_controller.dart';

enum MessageScope { vehicle, infra, detected }

class InfraController extends GetxController {
  final InfraRepository infraRepository = InfraRepository();

  Message? latestMessage;

  List<Message> currentHistoryMessages = <Message>[];
  int currentHistoryTotalCount = 0;

  bool isLoading = false;
  MessageScope scope = MessageScope.vehicle;

  int? selectedInfraId;
  List<int> infraIdentifiers = <int>[];

  int? fromEpochMilliseconds;
  int? toEpochMilliseconds;

  bool get hasToken {
    try {
      return (Get.find<UserController>().accessToken ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void setSelectedInfraId(int? infraId) {
    selectedInfraId = infraId;
    update();
  }

  Future<void> setScope(MessageScope newScope) async {
    if (scope == newScope) {
      return;
    }
    scope = newScope;
    latestMessage = null;
    currentHistoryMessages = <Message>[];
    currentHistoryTotalCount = 0;
    update();
  }

  int _toInteger(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  int? _parseIsoOrEpochToMilliseconds(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final int? directNumber = int.tryParse(trimmed);
    if (directNumber != null) return directNumber;

    try {
      final DateTime parsed = DateTime.parse(trimmed).toUtc();
      return parsed.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  Future<void> reqLoadInfraIdentifiers() async {
    if (!hasToken) {
      infraIdentifiers = <int>[];
      update();
      return;
    }

    try {
      final List<int> list = await infraRepository.requestInfraIdentifiers();
      infraIdentifiers = list.toSet().toList()..sort();
    } catch (_) {
      infraIdentifiers = <int>[];
    }

    update();
  }

  Future<void> refreshAll({
    String? fromIsoOrEpoch,
    String? toIsoOrEpoch,
    int? vehicleId,
  }) async {
    if (!hasToken) {
      latestMessage = null;
      currentHistoryMessages = <Message>[];
      currentHistoryTotalCount = 0;
      update();
      return;
    }

    fromEpochMilliseconds = _parseIsoOrEpochToMilliseconds(fromIsoOrEpoch);
    toEpochMilliseconds = _parseIsoOrEpochToMilliseconds(toIsoOrEpoch);

    try {
      await Future.wait(<Future<void>>[
        loadLatest(vehicleId: vehicleId),
        loadFirstPage(vehicleId: vehicleId),
      ]);
    } catch (_) {
      latestMessage = null;
      currentHistoryMessages = <Message>[];
      currentHistoryTotalCount = 0;
    } finally {
      update();
    }
  }

  Future<void> loadLatest({int? vehicleId}) async {
    if (!hasToken) {
      latestMessage = null;
      return;
    }

    try {
      if (scope == MessageScope.vehicle) {
        if (vehicleId == null) {
          latestMessage = null;
          return;
        }
        latestMessage = await infraRepository.requestLatestVehicle(vehicleId);
        return;
      }

      if (scope == MessageScope.infra) {
        final int? infraId = selectedInfraId;
        if (infraId == null) {
          latestMessage = null;
          return;
        }
        latestMessage = await infraRepository.requestLatestInfra(infraId);
        return;
      }

      latestMessage = null;
    } catch (_) {
      latestMessage = null;
    }
  }

  Future<void> loadFirstPage({int? vehicleId, int limit = 18}) async {
    if (!hasToken) {
      currentHistoryMessages = <Message>[];
      currentHistoryTotalCount = 0;
      return;
    }

    isLoading = true;
    update();

    try {
      final Map<String, dynamic> meta = scope == MessageScope.vehicle
          ? await infraRepository.requestHistoryVehicleWithMeta(
              vehicleId: vehicleId,
              fromEpochMs: fromEpochMilliseconds,
              toEpochMs: toEpochMilliseconds,
              limit: limit,
              offset: 0,
            )
          : await infraRepository.requestHistoryInfraWithMeta(
              infraId: selectedInfraId,
              fromEpochMs: fromEpochMilliseconds,
              toEpochMs: toEpochMilliseconds,
              limit: limit,
              offset: 0,
            );

      final dynamic itemsDynamic = meta['items'];
      final dynamic totalDynamic = meta['totalCount'];

      currentHistoryMessages = itemsDynamic is List<Message> ? itemsDynamic : <Message>[];
      currentHistoryTotalCount = _toInteger(totalDynamic);
    } catch (_) {
      currentHistoryMessages = <Message>[];
      currentHistoryTotalCount = 0;
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<Map<String, dynamic>> fetchVehicleHistoryPageWithMeta({
    int? vehicleId,
    required int offset,
    required int limit,
  }) async {
    if (!hasToken) {
      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    }

    final Map<String, dynamic> meta = await infraRepository.requestHistoryVehicleWithMeta(
      vehicleId: vehicleId,
      fromEpochMs: fromEpochMilliseconds,
      toEpochMs: toEpochMilliseconds,
      limit: limit,
      offset: offset,
    );

    final dynamic items = meta['items'];
    final dynamic total = meta['totalCount'];

    final List<Message> list = items is List<Message> ? items : <Message>[];
    final int totalCount = _toInteger(total);

    return <String, dynamic>{'items': list, 'totalCount': totalCount};
  }

  Future<Map<String, dynamic>> fetchInfraHistoryPageWithMeta({
    int? infraId,
    required int offset,
    required int limit,
  }) async {
    if (!hasToken) {
      return <String, dynamic>{'items': <Message>[], 'totalCount': 0};
    }

    final Map<String, dynamic> meta = await infraRepository.requestHistoryInfraWithMeta(
      infraId: infraId,
      fromEpochMs: fromEpochMilliseconds,
      toEpochMs: toEpochMilliseconds,
      limit: limit,
      offset: offset,
    );

    final dynamic items = meta['items'];
    final dynamic total = meta['totalCount'];

    final List<Message> list = items is List<Message> ? items : <Message>[];
    final int totalCount = _toInteger(total);

    return <String, dynamic>{'items': list, 'totalCount': totalCount};
  }
}
