import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../i18n/app_locale.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/activity_controller.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/repository/device_registry_repository.dart';
import '../../viewmodel/repository/infra_repository.dart';
import '../../viewmodel/repository/vehicle_repository.dart';
import '../dialogs/ask_dialog.dart';

// ── 카카오 우편번호 JS interop ────────────────────────────────────────────────

@JS('openDaumPostcode')
external void _jsDaumPostcode(JSFunction callback);

// ── 스테이션 정의 ──────────────────────────────────────────────────────────────

class _Station {
  final String name;
  final double lat;
  final double lng;
  const _Station(this.name, this.lat, this.lng);
}

const List<_Station> _kStations = <_Station>[
  _Station('대구역', 35.875931, 128.596053),
  _Station('동대구역', 35.877992, 128.627778),
  _Station('수성구', 35.854300, 128.616000),
  _Station('범어역', 35.859167, 128.626111),
  _Station('칠성시장', 35.876110, 128.605000),
];

// ── 메인 위젯 ──────────────────────────────────────────────────────────────────

class TabDeviceManagement extends StatefulWidget {
  const TabDeviceManagement({super.key});

  @override
  State<TabDeviceManagement> createState() => _TabDeviceManagementState();
}

class _TabDeviceManagementState extends State<TabDeviceManagement> {
  // 레지스트리: key = 'vehicle_1' / 'infra_1'
  final Map<String, Map<String, dynamic>> _regMap = <String, Map<String, dynamic>>{};

  List<Map<String, dynamic>> _vTelemetry = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _iTelemetry = <Map<String, dynamic>>[];
  bool _loading = false;

  // 인라인 폼 상태
  bool _formOpen = false;
  String _formDeviceType = 'vehicle';
  _DeviceRow? _formExisting;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await Future.wait(<Future<void>>[_loadRegistry(), _loadTelemetry()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRegistry() async {
    final List<Map<String, dynamic>> rows = await DeviceRegistryRepository().requestList();
    _regMap.clear();
    for (final Map<String, dynamic> r in rows) {
      _regMap['${r['device_type']}_${r['device_id']}'] = r;
    }
  }

  Future<void> _loadTelemetry() async {
    final results = await Future.wait(<Future<List<Map<String, dynamic>>>>[
      VehicleRepository().requestVehicleManageList(),
      InfraRepository().requestInfraManageList(),
    ]);
    _vTelemetry = results[0];
    _iTelemetry = results[1];
  }

  // ── 행 생성 ──────────────────────────────────────────────────────────────────

  List<_DeviceRow> _buildRows(String deviceType) {
    final String idKey = deviceType == 'vehicle' ? 'vehicle_id' : 'infra_id';
    final List<Map<String, dynamic>> telList = deviceType == 'vehicle' ? _vTelemetry : _iTelemetry;

    final Map<int, Map<String, dynamic>> telMap = <int, Map<String, dynamic>>{};
    for (final Map<String, dynamic> t in telList) {
      final int id = int.tryParse(t[idKey]?.toString() ?? '') ?? 0;
      if (id > 0) telMap[id] = t;
    }

    final Set<int> seen = <int>{};
    final List<_DeviceRow> rows = <_DeviceRow>[];

    for (final MapEntry<String, Map<String, dynamic>> e in _regMap.entries) {
      if (!e.key.startsWith('${deviceType}_')) continue;
      final Map<String, dynamic> reg = e.value;
      final int id = int.tryParse(reg['device_id']?.toString() ?? '') ?? 0;
      seen.add(id);
      rows.add(_DeviceRow(
        registryId: int.tryParse(reg['id']?.toString() ?? '') ?? 0,
        deviceType: deviceType,
        deviceId: id,
        name: reg['name']?.toString(),
        homeStation: reg['home_station']?.toString(),
        locationAddress: reg['location_address']?.toString(),
        locationLat: _toDouble(reg['location_lat']),
        locationLng: _toDouble(reg['location_lng']),
        memo: reg['memo']?.toString(),
        lastSeen: telMap[id]?['last_seen']?.toString(),
        recordCount: telMap[id]?['record_count']?.toString() ?? '0',
        hasTelemetry: telMap.containsKey(id),
      ));
    }

    for (final MapEntry<int, Map<String, dynamic>> e in telMap.entries) {
      if (seen.contains(e.key)) continue;
      rows.add(_DeviceRow(
        registryId: 0,
        deviceType: deviceType,
        deviceId: e.key,
        lastSeen: e.value['last_seen']?.toString(),
        recordCount: e.value['record_count']?.toString() ?? '0',
        hasTelemetry: true,
      ));
    }

    rows.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    return rows;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ── 인라인 폼 열기/닫기 ──────────────────────────────────────────────────────

  void _openForm({required String deviceType, _DeviceRow? existing}) {
    setState(() {
      _formOpen = true;
      _formDeviceType = deviceType;
      _formExisting = existing;
    });
  }

  void _closeForm() {
    setState(() => _formOpen = false);
  }

  // ── 삭제 ─────────────────────────────────────────────────────────────────────

  Future<void> _delete(_DeviceRow row) async {
    final String label = row.deviceType == 'vehicle' ? t('차량') : t('인프라');
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => AskDialog(
        message: l10n('$label ${row.deviceId} 삭제', 'Delete $label ${row.deviceId}'),
        addMessage: l10n(
          '레지스트리 정보${row.hasTelemetry ? ' 및 모든 텔레메트리 데이터(이력 포함)' : ''}가 영구 삭제됩니다.\n계속하시겠습니까?',
          row.hasTelemetry
              ? 'The registry info and all telemetry history will be permanently deleted.\nDo you want to continue?'
              : 'The registry info will be permanently deleted.\nDo you want to continue?',
        ),
        leftText: t('삭제'),
        rightText: t('취소'),
      ),
    );
    if (result != 'LEFT') return;

    // 삭제 대상이 현재 폼에서 편집 중이면 폼 닫기
    if (_formOpen &&
        _formExisting?.deviceId == row.deviceId &&
        _formExisting?.deviceType == row.deviceType) {
      _closeForm();
    }

    final bool ok = row.deviceType == 'vehicle'
        ? await VehicleRepository().requestVehicleManageDelete(row.deviceId)
        : await InfraRepository().requestInfraManageDelete(row.deviceId);
    if (!ok) {
      Utils.showSnackBar(
        l10n('$label ${row.deviceId} 삭제 실패.', 'Failed to delete $label ${row.deviceId}.'),
        isError: true,
      );
      return;
    }

    Utils.showSnackBar(
      l10n('$label ${row.deviceId} 삭제 완료.', '$label ${row.deviceId} deleted.'),
    );
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().initialize();
    }
    if (Get.isRegistered<ActivityController>()) {
      unawaited(Get.find<ActivityController>().refreshCatalog());
    }
    await _loadAll();
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  t('DEVICE 관리'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    fontFamily: 'pretendard',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t('차량 및 인프라 장치를 등록하고 관리합니다.'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontFamily: 'pretendard',
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF6B7280)),
                  tooltip: t('새로고침'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 14, color: Colors.grey),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: _buildPanel('vehicle')),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _formOpen
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 360,
                                      child: _DeviceForm(
                                        key: ValueKey(
                                            '${_formDeviceType}_${_formExisting?.registryId ?? 'new'}'),
                                        deviceType: _formDeviceType,
                                        existing: _formExisting,
                                        onDone: (bool saved) async {
                                          _closeForm();
                                          if (saved) await _loadAll();
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildPanel('infra')),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 패널 (차량 or 인프라) ────────────────────────────────────────────────────

  Widget _buildPanel(String deviceType) {
    final bool isVehicle = deviceType == 'vehicle';
    final String label = isVehicle ? t('차량') : t('인프라');
    final List<_DeviceRow> rows = _buildRows(deviceType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 패널 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isVehicle ? const Color(0xFFE8F0FE) : const Color(0xFFE6F7F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isVehicle ? Icons.directions_car_rounded : Icons.cell_tower_rounded,
                        size: 13,
                        color: isVehicle ? const Color(0xFF1565C0) : const Color(0xFF00796B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n('$label 관리', '$label Management'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isVehicle ? const Color(0xFF1565C0) : const Color(0xFF00796B),
                          fontFamily: 'pretendard',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEnglishLocale ? '${rows.length} items' : '${rows.length}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontFamily: 'pretendard',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openForm(deviceType: deviceType),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005FB8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+ ${t('등록')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'pretendard',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          _deviceTableHeader(),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // 목록
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isVehicle ? Icons.directions_car_outlined : Icons.cell_tower_outlined,
                          size: 32,
                          color: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n('등록된 $label 없음', 'No registered $label'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD1D5DB),
                            fontFamily: 'pretendard',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF9FAFB)),
                    itemBuilder: (_, int i) => _deviceTableRow(rows[i], isVehicle),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 테이블 헤더 ──────────────────────────────────────────────────────────────

  // ignore: unused_element
  Widget _tableHeader(bool isVehicle) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: Row(
        children: <Widget>[
          _hCell(t('이름 / 번호'), flex: 3),
          _hCell(t('이름'), flex: 2),
          _hCell(t('위치'), flex: 3),
          _hCell(t('마지막 수신'), flex: 3),
          _hCell('', flex: 2),
        ],
      ),
    );
  }

  Widget _hCell(String t, {required int flex}) => Expanded(
        flex: flex,
        child: Text(t,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
              fontFamily: 'pretendard',
            )),
      );

  // ── 테이블 행 ────────────────────────────────────────────────────────────────

  // ignore: unused_element
  Widget _tableRow(_DeviceRow row, bool isVehicle) {
    // 현재 폼에서 편집 중인 행 하이라이트
    final bool isActive = _formOpen &&
        _formExisting?.deviceId == row.deviceId &&
        _formExisting?.deviceType == row.deviceType;

    final String location = row.locationAddress?.isNotEmpty == true
        ? row.locationAddress!
        : (row.homeStation?.isNotEmpty == true ? row.homeStation! : '-');

    final String locationDisplay =
        location.length > 18 ? '${location.substring(0, 18)}…' : location;

    final String lastSeen = row.lastSeen != null
        ? (row.lastSeen!.length >= 16 ? row.lastSeen!.substring(0, 16) : row.lastSeen!)
        : '-';

    return Container(
      color: isActive ? const Color(0xFFF0F7FF) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: <Widget>[
          // ID
          Expanded(
            flex: 1,
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isVehicle ? const Color(0xFFE8F0FE) : const Color(0xFFE6F7F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVehicle ? Icons.directions_car_rounded : Icons.cell_tower_rounded,
                    size: 11,
                    color: isVehicle ? const Color(0xFF1565C0) : const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 5),
                Text('${row.deviceId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                      fontFamily: 'pretendard',
                    )),
              ],
            ),
          ),
          // 이름
          Expanded(
            flex: 2,
            child: Text(
              row.name ?? '-',
              style: TextStyle(
                fontSize: 12,
                color: row.name != null ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                fontFamily: 'pretendard',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 위치
          Expanded(
            flex: 3,
            child: Text(
              locationDisplay,
              style: TextStyle(
                fontSize: 12,
                color: location != '-' ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                fontFamily: 'pretendard',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 마지막 수신
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                if (row.isOnline) ...<Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration:
                        const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    lastSeen,
                    style: TextStyle(
                      fontSize: 11,
                      color: lastSeen != '-' ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
                      fontFamily: 'pretendard',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 액션
          Expanded(
            flex: 2,
            child: Row(
              children: <Widget>[
                _actionBtn(
                  label: t('편집'),
                  icon: Icons.edit_outlined,
                  bg: const Color(0xFFF0F9FF),
                  border: const Color(0xFFBAE6FD),
                  fg: const Color(0xFF0369A1),
                  onTap: () => _openForm(deviceType: row.deviceType, existing: row),
                ),
                const SizedBox(width: 4),
                _actionBtn(
                  label: t('삭제'),
                  icon: Icons.delete_outline_rounded,
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  fg: const Color(0xFFDC2626),
                  onTap: () => _delete(row),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceTableHeader() {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      child: Row(
        children: <Widget>[
          _hCell(t('이름 / 번호'), flex: 3),
          _hCell(t('위치'), flex: 3),
          _hCell(l10n('상태 / 수신', 'Status / Last Seen'), flex: 3),
          _hCell('', flex: 2),
        ],
      ),
    );
  }

  String _devicePrimaryLabel(_DeviceRow row) {
    final String name = row.name?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return isEnglishLocale ? '#${row.deviceId}' : '${row.deviceId}번';
  }

  String? _deviceSecondaryLabel(_DeviceRow row) {
    final String name = row.name?.trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return isEnglishLocale ? '#${row.deviceId}' : '${row.deviceId}번';
  }

  Widget _deviceTableRow(_DeviceRow row, bool isVehicle) {
    final bool isActive = _formOpen &&
        _formExisting?.deviceId == row.deviceId &&
        _formExisting?.deviceType == row.deviceType;

    final String location = row.locationAddress?.isNotEmpty == true
        ? row.locationAddress!
        : (row.homeStation?.isNotEmpty == true ? row.homeStation! : '-');

    final String locationDisplay =
        location.length > 20 ? '${location.substring(0, 20)}…' : location;

    final String lastSeen = row.lastSeen != null
        ? (row.lastSeen!.length >= 16 ? row.lastSeen!.substring(0, 16) : row.lastSeen!)
        : '-';

    final String primaryLabel = _devicePrimaryLabel(row);
    final String? secondaryLabel = _deviceSecondaryLabel(row);

    return _HoverRow(
      isActive: isActive,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        child: Row(
          children: <Widget>[
            // 이름 / 번호
            Expanded(
              flex: 3,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isVehicle ? const Color(0xFFEBF3FF) : const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isVehicle ? Icons.directions_car_rounded : Icons.cell_tower_rounded,
                      size: 14,
                      color: isVehicle ? const Color(0xFF1565C0) : const Color(0xFF00796B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                            fontFamily: 'pretendard',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (secondaryLabel != null)
                          Text(
                            secondaryLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                              fontFamily: 'pretendard',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 위치
            Expanded(
              flex: 3,
              child: Row(
                children: <Widget>[
                  if (location != '-') ...<Widget>[
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFD1D5DB)),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      locationDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: location != '-' ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                        fontFamily: 'pretendard',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // 상태 / 수신
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 온라인/오프라인 배지 (lastSeen 5분 이내 = 온라인)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: row.isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: row.isOnline ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          row.isOnline ? l10n('온라인', 'Online') : l10n('오프라인', 'Offline'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: row.isOnline ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
                            fontFamily: 'pretendard',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lastSeen != '-') ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      lastSeen,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'pretendard',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 액션 버튼
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _actionBtn(
                    label: '편집',
                    icon: Icons.edit_outlined,
                    bg: const Color(0xFFF0F9FF),
                    border: const Color(0xFFBAE6FD),
                    fg: const Color(0xFF0369A1),
                    onTap: () => _openForm(deviceType: row.deviceType, existing: row),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    label: '삭제',
                    icon: Icons.delete_outline_rounded,
                    bg: const Color(0xFFFEF2F2),
                    border: const Color(0xFFFECACA),
                    fg: const Color(0xFFDC2626),
                    onTap: () => _delete(row),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 11, color: fg),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    fontFamily: 'pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 호버 행 래퍼 ──────────────────────────────────────────────────────────────

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.isActive, required this.child});
  final bool isActive;
  final Widget child;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (widget.isActive) {
      bg = const Color(0xFFEBF5FF);
    } else if (_hovered) {
      bg = const Color(0xFFF8FAFC);
    } else {
      bg = Colors.white;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: bg,
        child: widget.child,
      ),
    );
  }
}

// ── 데이터 모델 ───────────────────────────────────────────────────────────────

class _DeviceRow {
  final int registryId;
  final String deviceType;
  final int deviceId;
  final String? name;
  final String? homeStation;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final String? memo;
  final String? lastSeen;
  final String recordCount;
  final bool hasTelemetry;

  const _DeviceRow({
    required this.registryId,
    required this.deviceType,
    required this.deviceId,
    this.name,
    this.homeStation,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.memo,
    this.lastSeen,
    this.recordCount = '0',
    this.hasTelemetry = false,
  });

  // lastSeen이 5분 이내이면 온라인으로 판단
  bool get isOnline {
    if (lastSeen == null || lastSeen!.isEmpty) return false;
    final DateTime? dt = DateTime.tryParse(lastSeen!.replaceFirst(' ', 'T'));
    if (dt == null) return false;
    return DateTime.now().difference(dt).abs() <= const Duration(minutes: 5);
  }
}

// ── 인라인 등록/편집 폼 ───────────────────────────────────────────────────────

class _DeviceForm extends StatefulWidget {
  const _DeviceForm({
    super.key,
    required this.deviceType,
    required this.onDone,
    this.existing,
  });

  final String deviceType;
  final _DeviceRow? existing;
  // saved=true → 저장 후 닫기, saved=false → 취소
  final Future<void> Function(bool saved) onDone;

  @override
  State<_DeviceForm> createState() => _DeviceFormState();
}

class _DeviceFormState extends State<_DeviceForm> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _memoCtrl = TextEditingController();
  final TextEditingController _addrCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();

  // 위치 모드: true = 스테이션 선택, false = 직접 입력(카카오 검색)
  bool _useStation = true;
  String? _selectedStation;
  double? _lat;
  double? _lng;
  bool _saving = false;

  // 지도 위젯 키 (재생성 방지)
  final GlobalKey<_PinMapState> _mapKey = GlobalKey<_PinMapState>();

  bool get _isVehicle => widget.deviceType == 'vehicle';
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final _DeviceRow? e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name ?? '';
      _memoCtrl.text = e.memo ?? '';
      _addrCtrl.text = e.locationAddress ?? '';
      _lat = e.locationLat;
      _lng = e.locationLng;
      if (_lat != null) _latCtrl.text = _lat!.toStringAsFixed(6);
      if (_lng != null) _lngCtrl.text = _lng!.toStringAsFixed(6);

      final String? matchedStation = _findStation(e.homeStation) ?? _findStation(e.locationAddress);
      if (matchedStation != null) {
        _selectedStation = matchedStation;
        _useStation = true;
        if (_lat == null || _lng == null) {
          _applyStationCoords(matchedStation);
        }
      } else if (_addrCtrl.text.trim().isNotEmpty) {
        _useStation = false;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _addrCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  String? _findStation(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    for (final _Station s in _kStations) {
      if (s.name == v) return s.name;
    }
    return null;
  }

  void _applyStationCoords(String? name) {
    if (name == null) return;
    final _Station? st = _kStations.cast<_Station?>().firstWhere(
          (s) => s?.name == name,
          orElse: () => null,
        );
    if (st != null) {
      _lat = st.lat;
      _lng = st.lng;
    }
  }

  void _switchMode(bool useStation) {
    if (_useStation == useStation) return;
    setState(() {
      _useStation = useStation;
      if (useStation) {
        _applyStationCoords(_selectedStation);
      } else {
        _lat = null;
        _lng = null;
      }
    });
  }

  // 카카오 우편번호 팝업 → 주소 선택 → 좌표 변환
  Future<void> _openKakaoPostcode() async {
    final Completer<(String, String)> completer = Completer<(String, String)>();

    void cb(JSString road, JSString jibun) {
      if (!completer.isCompleted) {
        completer.complete((road.toDart, jibun.toDart));
      }
    }

    _jsDaumPostcode(cb.toJS);

    final (String road, String jibun) = await completer.future;
    final String addr = road.isNotEmpty ? road : jibun;
    if (addr.isEmpty || !mounted) return;

    setState(() => _addrCtrl.text = addr);

    // 주소 → 좌표 변환 (백엔드 geocode API) + 지도 카메라 자동 이동
    final Map<String, dynamic>? geo = await DeviceRegistryRepository().requestGeocode(addr);
    if (geo != null && mounted) {
      final double? lat = _toDouble(geo['lat']);
      final double? lng = _toDouble(geo['lng']);
      if (lat != null && lng != null) {
        _applyLatLng(lat, lng);
      }
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    String? locationAddress;
    String? homeStation;

    if (_useStation && _selectedStation != null) {
      locationAddress = _selectedStation;
      homeStation = _isVehicle ? _selectedStation : null;
    } else {
      locationAddress = _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim();
      homeStation = null;
    }

    final Map<String, dynamic>? row = await DeviceRegistryRepository().requestUpsert(
      deviceType: widget.deviceType,
      deviceId: _isEdit ? widget.existing!.deviceId : null,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      locationLat: _lat,
      locationLng: _lng,
      locationAddress: locationAddress,
      homeStation: homeStation,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (row != null) {
      Utils.showSnackBar(l10n('저장되었습니다.', 'Saved.'));
      await widget.onDone(true);
    } else {
      Utils.showSnackBar(l10n('저장에 실패했습니다.', 'Failed to save.'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String label = _isVehicle ? t('차량') : t('인프라');
    final String title = _isEdit
        ? l10n('$label ${widget.existing!.deviceId} 편집', 'Edit $label ${widget.existing!.deviceId}')
        : l10n('$label 등록', 'Register $label');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── 헤더 ────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _isVehicle ? const Color(0xFFE8F0FE) : const Color(0xFFE6F7F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _isVehicle ? Icons.directions_car_rounded : Icons.cell_tower_rounded,
                    size: 14,
                    color: _isVehicle ? const Color(0xFF1565C0) : const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      fontFamily: 'pretendard',
                    )),
                const Spacer(),
                // 닫기 버튼
                InkWell(
                  onTap: () => widget.onDone(false),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),

          // ── 폼 필드 (스크롤 가능) ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 장치 이름
                  _label(l10n('장치 이름', 'Device Name')),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 13, fontFamily: 'pretendard'),
                    decoration: _deco(
                        hint: _isVehicle
                            ? l10n('예) 차량 001', 'e.g. Vehicle 001')
                            : l10n('예) 교차로 카메라 001', 'e.g. Intersection Camera 001')),
                  ),
                  const SizedBox(height: 14),

                  // 위치 섹션
                  _label(t('위치')),
                  const SizedBox(height: 5),
                  _locationSection(),
                  const SizedBox(height: 14),

                  // 메모
                  _label(l10n('메모 (선택)', 'Memo (Optional)')),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _memoCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, fontFamily: 'pretendard'),
                    decoration: _deco(hint: l10n('메모를 입력하세요', 'Enter a memo')),
                  ),
                  const SizedBox(height: 14),

                  // 지도 핀 선택
                  _locationMapSection(),
                ],
              ),
            ),
          ),

          // ── 버튼 ─────────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _saving ? null : () => widget.onDone(false),
                  child: Text(t('취소'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontFamily: 'pretendard',
                      )),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005FB8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t('저장'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'pretendard',
                          )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 위치 섹션 ─────────────────────────────────────────────────────────────────

  Widget _locationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 모드 토글: [스테이션] [직접 입력]
        Row(
          children: <Widget>[
            _modeBtn(
              label: l10n('스테이션', 'Station'),
              icon: Icons.train_rounded,
              selected: _useStation,
              onTap: () => _switchMode(true),
            ),
            const SizedBox(width: 8),
            _modeBtn(
              label: t('직접 입력'),
              icon: Icons.location_on_outlined,
              selected: !_useStation,
              onTap: () => _switchMode(false),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_useStation) _stationDropdown() else _addressInputField(),

        // 좌표 직접 입력 필드 (항상 표시)
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(t('위도'),
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280), fontFamily: 'pretendard')),
                  const SizedBox(height: 3),
                  TextField(
                    controller: _latCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(fontSize: 13, fontFamily: 'pretendard'),
                    decoration: _deco(hint: l10n('예) 35.854300', 'e.g. 35.854300')),
                    onChanged: (String v) {
                      final double? parsed = double.tryParse(v.trim());
                      if (parsed != null && _lngCtrl.text.trim().isNotEmpty) {
                        final double? lng = double.tryParse(_lngCtrl.text.trim());
                        if (lng != null) _applyLatLngSilent(parsed, lng);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(t('경도'),
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280), fontFamily: 'pretendard')),
                  const SizedBox(height: 3),
                  TextField(
                    controller: _lngCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(fontSize: 13, fontFamily: 'pretendard'),
                    decoration: _deco(hint: l10n('예) 128.616000', 'e.g. 128.616000')),
                    onChanged: (String v) {
                      final double? parsed = double.tryParse(v.trim());
                      if (parsed != null && _latCtrl.text.trim().isNotEmpty) {
                        final double? lat = double.tryParse(_latCtrl.text.trim());
                        if (lat != null) _applyLatLngSilent(lat, parsed);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modeBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    size: 13, color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                    fontFamily: 'pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _stationDropdown() {
    final ThemeData baseTheme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Theme(
        data: baseTheme.copyWith(
          canvasColor: Colors.white,
          colorScheme: baseTheme.colorScheme.copyWith(surface: Colors.white),
        ),
        child: DropdownButton<String>(
          value: _selectedStation,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          hint: Text(t('스테이션을 선택하세요'),
              style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB), fontFamily: 'pretendard')),
          items: _kStations
              .map((s) => DropdownMenuItem<String>(
                    value: s.name,
                    child: Text(s.name,
                        style: const TextStyle(fontSize: 13, fontFamily: 'pretendard')),
                  ))
              .toList(),
          onChanged: (String? v) {
            if (v == null) return;
            setState(() => _selectedStation = v);
            // 스테이션 좌표 적용 + 지도 카메라 자동 이동
            final _Station? st =
                _kStations.cast<_Station?>().firstWhere((s) => s?.name == v, orElse: () => null);
            if (st != null) _applyLatLng(st.lat, st.lng);
          },
        ),
      ),
    );
  }

  Widget _addressInputField() => Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _addrCtrl,
              style: const TextStyle(fontSize: 13, fontFamily: 'pretendard'),
              decoration:
                  _deco(hint: l10n('예) 대구광역시 중구 태평로 141', 'e.g. 141 Taepyeong-ro, Jung-gu, Daegu')),
              onSubmitted: (_) => _openKakaoPostcode(),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: _openKakaoPostcode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005FB8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(t('검색'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'pretendard',
                  )),
            ),
          ),
        ],
      );

  // 텍스트 필드 입력으로부터 호출 — 필드는 건드리지 않고 핀+카메라만 이동
  void _applyLatLngSilent(double lat, double lng) {
    setState(() {
      _lat = lat;
      _lng = lng;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapKey.currentState?.moveTo(lat, lng);
    });
  }

  // 좌표 설정 + 텍스트 필드 + 지도 카메라 자동 이동
  void _applyLatLng(double lat, double lng) {
    setState(() {
      _lat = lat;
      _lng = lng;
      _latCtrl.text = lat.toStringAsFixed(6);
      _lngCtrl.text = lng.toStringAsFixed(6);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapKey.currentState?.moveTo(lat, lng);
    });
  }

  // ── 지도 핀 선택 섹션 ──────────────────────────────────────────────────────

  Widget _locationMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label(t('지도에서 위치 선택')),
        const SizedBox(height: 4),
        const Text(
          '지도를 드래그하면 중앙 핀 위치가 실시간으로 업데이트됩니다.',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            fontFamily: 'pretendard',
          ),
        ),
        const SizedBox(height: 8),

        // _PinMap 은 자체 State를 가지므로 부모 setState에 영향받지 않음
        _PinMap(
          key: _mapKey,
          isVehicle: _isVehicle,
          initLat: _lat ?? _kStations.first.lat,
          initLng: _lng ?? _kStations.first.lng,
          pinLat: _lat,
          pinLng: _lng,
          onPinChanged: (double lat, double lng) {
            setState(() {
              _lat = lat;
              _lng = lng;
              _latCtrl.text = lat.toStringAsFixed(6);
              _lngCtrl.text = lng.toStringAsFixed(6);
              if (_useStation) {
                _useStation = false;
                _selectedStation = null;
              }
              // 임시로 좌표 표시, 주소 조회 후 덮어쓰기
              _addrCtrl.text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
            });
            // 역지오코딩: 한국어 주소로 덮어쓰기
            DeviceRegistryRepository().requestReverseGeocode(lat, lng).then((String? addr) {
              if (addr != null && mounted) {
                setState(() => _addrCtrl.text = addr);
              }
            });
          },
        ),

        // 선택된 좌표 표시
        if (_lat != null && _lng != null) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.location_pin, size: 13, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 4),
              Text(
                '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'pretendard',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _lat = null;
                  _lng = null;
                }),
                child: const Text('핀 제거',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFDC2626),
                      fontFamily: 'pretendard',
                    )),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
        fontFamily: 'pretendard',
      ));

  InputDecoration _deco({String hint = ''}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF005FB8))),
        filled: true,
        fillColor: Colors.white,
      );
}

// ── 지도 핀 선택 위젯 (부모 setState에 영향받지 않도록 별도 StatefulWidget) ──────

class _PinMap extends StatefulWidget {
  const _PinMap({
    super.key,
    required this.isVehicle,
    required this.initLat,
    required this.initLng,
    required this.onPinChanged,
    this.pinLat,
    this.pinLng,
  });

  final bool isVehicle;
  final double initLat;
  final double initLng;
  final double? pinLat;
  final double? pinLng;
  final void Function(double lat, double lng) onPinChanged;

  @override
  State<_PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<_PinMap> {
  GoogleMapController? _ctrl;

  // 현재 카메라 중앙 좌표 (드래그 중 실시간 업데이트)
  double? _centerLat;
  double? _centerLng;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.pinLat ?? widget.initLat;
    _centerLng = widget.pinLng ?? widget.initLng;
  }

  @override
  void didUpdateWidget(_PinMap old) {
    super.didUpdateWidget(old);
    // 부모에서 좌표를 직접 변경한 경우(주소 검색 등) 동기화
    if (widget.pinLat != old.pinLat || widget.pinLng != old.pinLng) {
      _centerLat = widget.pinLat;
      _centerLng = widget.pinLng;
      if (_centerLat != null && _centerLng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => moveTo(_centerLat!, _centerLng!));
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  // 부모(_DeviceFormState)에서 직접 호출 가능
  void moveTo(double lat, double lng) {
    if (mounted) {
      setState(() {
        _centerLat = lat;
        _centerLng = lng;
      });
    }
    _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initPos = LatLng(widget.initLat, widget.initLng);
    final Color pinColor = widget.isVehicle ? const Color(0xFF005CB2) : const Color(0xFF00897B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: <Widget>[
                // ── 구글 맵: GestureDetector로 Flutter pan 제스처를 흡수해
                //    부모 SingleChildScrollView가 폼을 스크롤하지 못하게 막는다.
                //    브라우저 레벨 이벤트는 Google Maps JS가 직접 수신하므로
                //    지도 드래그는 정상 동작한다.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (_) {}, // Flutter 제스처 아레나에서 선점
                  onPanStart: (_) {},
                  onPanUpdate: (_) {},
                  onPanEnd: (_) {},
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: initPos, zoom: 14),
                    markers: const <Marker>{},
                    scrollGesturesEnabled: true, // 드래그 활성화
                    zoomControlsEnabled: true,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (GoogleMapController c) {
                      _ctrl = c;
                      if (_centerLat != null && _centerLng != null) {
                        c.animateCamera(
                            CameraUpdate.newLatLngZoom(LatLng(_centerLat!, _centerLng!), 15));
                      }
                    },
                    // 드래그 중: 카메라 중심 좌표로 핀 위치 실시간 갱신
                    onCameraMove: (CameraPosition pos) {
                      setState(() {
                        _isDragging = true;
                        _centerLat = pos.target.latitude;
                        _centerLng = pos.target.longitude;
                      });
                    },
                    // 드래그 완료: 좌표 확정 → 부모에 알림
                    onCameraIdle: () {
                      if (_isDragging && _centerLat != null && _centerLng != null) {
                        _isDragging = false;
                        widget.onPinChanged(_centerLat!, _centerLng!);
                      }
                    },
                  ),
                ), // GestureDetector

                // ── 화면 중앙 고정 핀 오버레이 ────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 핀 원형 헤드
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: pinColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: pinColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isVehicle
                              ? Icons.directions_car_rounded
                              : Icons.cell_tower_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      // 핀 꼬리 삼각형
                      CustomPaint(
                        size: const Size(12, 8),
                        painter: _PinTailPainter(pinColor),
                      ),
                      // 지면 그림자
                      Container(
                        width: 5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 현재 확정 위치로 카메라 복귀 버튼 ────────────────────────
                if (_centerLat != null)
                  Positioned(
                    right: 8,
                    bottom: 48,
                    child: GestureDetector(
                      onTap: () {
                        if (_centerLat != null && _centerLng != null) {
                          moveTo(_centerLat!, _centerLng!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x22000000), blurRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.center_focus_strong,
                            size: 18, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 핀 꼬리 삼각형
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter old) => old.color != color;
}
