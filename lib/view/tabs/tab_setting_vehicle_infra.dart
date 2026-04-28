import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/utils.dart';
import '../../viewmodel/controller/activity_controller.dart';
import '../../viewmodel/controller/dashboard_controller.dart';
import '../../viewmodel/repository/device_registry_repository.dart';
import '../../viewmodel/repository/infra_repository.dart';
import '../../viewmodel/repository/vehicle_repository.dart';
import '../dialogs/ask_dialog.dart';

// ── 스테이션 정의 (시뮬레이터와 동일) ──────────────────────────────────────────
class _Station {
  final String name;
  final double lat;
  final double lng;
  const _Station(this.name, this.lat, this.lng);
}

const List<_Station> _vehicleStations = <_Station>[
  _Station('대구역',   35.875931, 128.596053),
  _Station('동대구역', 35.877992, 128.627778),
  _Station('수성구',   35.854300, 128.616000),
  _Station('범어역',   35.859167, 128.626111),
  _Station('칠성시장', 35.876110, 128.605000),
];

// ── 위젯 ──────────────────────────────────────────────────────────────────────

class TabSettingVehicleInfra extends StatefulWidget {
  const TabSettingVehicleInfra({super.key});

  @override
  State<TabSettingVehicleInfra> createState() => _TabSettingVehicleInfraState();
}

class _TabSettingVehicleInfraState extends State<TabSettingVehicleInfra>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTab;

  // 텔레메트리 목록
  List<Map<String, dynamic>> _vehicles = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _infras   = <Map<String, dynamic>>[];
  bool _loadingVehicles = false;
  bool _loadingInfras   = false;

  // 레지스트리 맵: 'vehicle_1' → Map<String,dynamic>
  final Map<String, Map<String, dynamic>> _registry = <String, Map<String, dynamic>>{};
  bool _loadingRegistry = false;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(vsync: this, length: 2);
    _loadAll();
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait(<Future<void>>[
      _loadVehicles(),
      _loadInfras(),
      _loadRegistry(),
    ]);
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;
    setState(() => _loadingVehicles = true);
    _vehicles = await VehicleRepository().requestVehicleManageList();
    if (mounted) setState(() => _loadingVehicles = false);
  }

  Future<void> _loadInfras() async {
    if (!mounted) return;
    setState(() => _loadingInfras = true);
    _infras = await InfraRepository().requestInfraManageList();
    if (mounted) setState(() => _loadingInfras = false);
  }

  Future<void> _loadRegistry() async {
    if (!mounted) return;
    setState(() => _loadingRegistry = true);
    final List<Map<String, dynamic>> rows =
        await DeviceRegistryRepository().requestList();
    _registry.clear();
    for (final Map<String, dynamic> row in rows) {
      final String key =
          '${row['device_type']}_${row['device_id']}';
      _registry[key] = row;
    }
    if (mounted) setState(() => _loadingRegistry = false);
  }

  Map<String, dynamic>? _registryFor(String type, int id) =>
      _registry['${type}_$id'];

  // ── 삭제 ─────────────────────────────────────────────────────────────────────

  Future<void> _deleteVehicle(int vehicleId) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => AskDialog(
        message: '차량 $vehicleId 삭제',
        addMessage: '차량 $vehicleId 의 모든 데이터(이력 포함)가 영구 삭제됩니다.\n계속하시겠습니까?',
        leftText: '삭제',
        rightText: '취소',
      ),
    );
    if (result != 'LEFT') return;

    final bool ok =
        await VehicleRepository().requestVehicleManageDelete(vehicleId);
    if (ok) {
      Utils.showSnackBar('차량 $vehicleId 데이터가 삭제되었습니다.');
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().initialize();
      }
      if (Get.isRegistered<ActivityController>()) {
        unawaited(Get.find<ActivityController>().refreshCatalog());
      }
      await _loadVehicles();
    } else {
      Utils.showSnackBar('삭제에 실패했습니다.', isError: true);
    }
  }

  Future<void> _deleteInfra(int infraId) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => AskDialog(
        message: '인프라 $infraId 삭제',
        addMessage: '인프라 $infraId 의 모든 데이터(이력 포함)가 영구 삭제됩니다.\n계속하시겠습니까?',
        leftText: '삭제',
        rightText: '취소',
      ),
    );
    if (result != 'LEFT') return;

    final bool ok =
        await InfraRepository().requestInfraManageDelete(infraId);
    if (ok) {
      Utils.showSnackBar('인프라 $infraId 데이터가 삭제되었습니다.');
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().initialize();
      }
      if (Get.isRegistered<ActivityController>()) {
        unawaited(Get.find<ActivityController>().refreshCatalog());
      }
      await _loadInfras();
    } else {
      Utils.showSnackBar('삭제에 실패했습니다.', isError: true);
    }
  }

  // ── 편집 다이얼로그 ──────────────────────────────────────────────────────────

  Future<void> _openEditDialog(String deviceType, int deviceId) async {
    final Map<String, dynamic>? current =
        _registryFor(deviceType, deviceId);
    final bool saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _EditDialog(
            deviceType : deviceType,
            deviceId   : deviceId,
            initial    : current,
          ),
        ) ??
        false;
    if (saved) await _loadRegistry();
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 내부 탭 헤더
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F3),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _innerTab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1)),
                ],
              ),
              indicatorSize          : TabBarIndicatorSize.tab,
              dividerColor           : Colors.transparent,
              labelColor             : const Color(0xFF005FB8),
              unselectedLabelColor   : const Color(0xFF6B7280),
              labelStyle             : const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'pretendard'),
              unselectedLabelStyle   : const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'pretendard'),
              tabs: const <Tab>[
                Tab(text: '차량 관리'),
                Tab(text: '인프라 관리'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _innerTab,
              children: <Widget>[
                _buildSection(
                  entityLabel : '차량',
                  idKey       : 'vehicle_id',
                  deviceType  : 'vehicle',
                  rows        : _vehicles,
                  loading     : _loadingVehicles || _loadingRegistry,
                  onRefresh   : _loadAll,
                  onDelete    : _deleteVehicle,
                ),
                _buildSection(
                  entityLabel : '인프라',
                  idKey       : 'infra_id',
                  deviceType  : 'infra',
                  rows        : _infras,
                  loading     : _loadingInfras || _loadingRegistry,
                  onRefresh   : _loadAll,
                  onDelete    : _deleteInfra,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 ─────────────────────────────────────────────────────────────────────

  Widget _buildSection({
    required String entityLabel,
    required String idKey,
    required String deviceType,
    required List<Map<String, dynamic>> rows,
    required bool loading,
    required VoidCallback onRefresh,
    required Future<void> Function(int) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '$entityLabel 목록',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E), fontFamily: 'pretendard',
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF6B7280)),
              tooltip: '새로고침',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTableHeader(entityLabel),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: loading
              ? const Center(child: CupertinoActivityIndicator(radius: 16, color: Colors.grey))
              : rows.isEmpty
                  ? Center(
                      child: Text(
                        '등록된 $entityLabel 이(가) 없습니다.',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF9CA3AF), fontFamily: 'pretendard'),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (BuildContext ctx, int i) {
                        final Map<String, dynamic> row = rows[i];
                        final int id =
                            int.tryParse(row[idKey]?.toString() ?? '') ?? 0;
                        final String lastSeen =
                            row['last_seen']?.toString().substring(0, 19) ?? '-';
                        final String count =
                            row['record_count']?.toString() ?? '0';
                        final Map<String, dynamic>? reg =
                            _registryFor(deviceType, id);
                        return _buildTableRow(
                          entityLabel : entityLabel,
                          deviceType  : deviceType,
                          id          : id,
                          lastSeen    : lastSeen,
                          recordCount : count,
                          registry    : reg,
                          onDelete    : () => onDelete(id),
                          onEdit      : () => _openEditDialog(deviceType, id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── 테이블 헤더 ──────────────────────────────────────────────────────────────

  Widget _buildTableHeader(String entityLabel) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: <Widget>[
          _headerCell('$entityLabel ID', flex: 2),
          _headerCell('이름',           flex: 3),
          _headerCell('홈 위치',        flex: 4),
          _headerCell('마지막 수신',    flex: 4),
          _headerCell('레코드 수',      flex: 2),
          _headerCell('',              flex: 3),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280), fontFamily: 'pretendard',
        ),
      ),
    );
  }

  // ── 테이블 행 ────────────────────────────────────────────────────────────────

  Widget _buildTableRow({
    required String entityLabel,
    required String deviceType,
    required int id,
    required String lastSeen,
    required String recordCount,
    required Map<String, dynamic>? registry,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    final bool isVehicle = deviceType == 'vehicle';
    final String regName = registry?['name']?.toString() ?? '-';
    final String regLocation =
        registry?['location_address']?.toString() ??
        registry?['home_station']?.toString() ??
        '-';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: <Widget>[
          // ID
          Expanded(
            flex: 2,
            child: Row(
              children: <Widget>[
                Container(
                  width: 28, height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isVehicle
                        ? const Color(0xFFE8F0FE)
                        : const Color(0xFFE6F7F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVehicle
                        ? Icons.directions_car_rounded
                        : Icons.cell_tower_rounded,
                    size: 15,
                    color: isVehicle
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$id',
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF111827), fontFamily: 'pretendard',
                  ),
                ),
              ],
            ),
          ),
          // 이름
          Expanded(
            flex: 3,
            child: Text(
              regName,
              style: TextStyle(
                fontSize: 13,
                color: regName == '-'
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF374151),
                fontFamily: 'pretendard',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 홈 위치
          Expanded(
            flex: 4,
            child: Text(
              regLocation,
              style: TextStyle(
                fontSize: 13,
                color: regLocation == '-'
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF6B7280),
                fontFamily: 'pretendard',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 마지막 수신
          Expanded(
            flex: 4,
            child: Text(
              lastSeen,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), fontFamily: 'pretendard'),
            ),
          ),
          // 레코드 수
          Expanded(
            flex: 2,
            child: Text(
              recordCount,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151), fontFamily: 'pretendard'),
            ),
          ),
          // 액션 버튼
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                _actionButton(
                  label: registry != null ? '편집' : '등록',
                  bg   : registry != null
                      ? const Color(0xFFF0F9FF)
                      : const Color(0xFFEFF6FF),
                  border: registry != null
                      ? const Color(0xFFBAE6FD)
                      : const Color(0xFFBFDBFE),
                  fg   : registry != null
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF1D4ED8),
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                _actionButton(
                  label: '삭제',
                  bg   : const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  fg   : const Color(0xFFDC2626),
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color bg,
    required Color border,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: fg, fontFamily: 'pretendard',
          ),
        ),
      ),
    );
  }
}

// ── 편집 / 등록 다이얼로그 ────────────────────────────────────────────────────

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.deviceType,
    required this.deviceId,
    this.initial,
  });

  final String deviceType;
  final int    deviceId;
  final Map<String, dynamic>? initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final TextEditingController _nameCtrl    = TextEditingController();
  final TextEditingController _memoCtrl    = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  String? _selectedStation;
  double? _lat;
  double? _lng;
  bool _geocoding = false;
  bool _saving    = false;
  bool _useStationLocation = true;

  bool get _isVehicle => widget.deviceType == 'vehicle';
  String get _entityLabel => _isVehicle ? '차량' : '인프라';

  String? get _stationValue {
    final String value = _selectedStation?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _addressValue {
    final String value = _addressCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get _resolvedLocationAddress => _useStationLocation ? _stationValue : _addressValue;
  String? get _resolvedHomeStation => _isVehicle && _useStationLocation ? _stationValue : null;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? ini = widget.initial;
    _useStationLocation = _isVehicle;
    if (ini != null) {
      _nameCtrl.text    = ini['name']         ?.toString() ?? '';
      _memoCtrl.text    = ini['memo']         ?.toString() ?? '';
      _addressCtrl.text = ini['location_address'] ?.toString() ?? '';
      _lat = _toDouble(ini['location_lat']);
      _lng = _toDouble(ini['location_lng']);
      _selectedStation =
          _matchStationName(ini['home_station']?.toString()) ??
          _matchStationName(ini['location_address']?.toString());
      if (_selectedStation != null) {
        _useStationLocation = true;
        _applySelectedStation(_selectedStation, preserveCoordinates: true);
      } else if (_addressCtrl.text.trim().isNotEmpty) {
        _useStationLocation = false;
      }
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _matchStationName(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    for (final _Station station in _vehicleStations) {
      if (station.name == normalized) {
        return station.name;
      }
    }
    return null;
  }

  void _applySelectedStation(String? stationName, {bool preserveCoordinates = false}) {
    final String? normalized = _matchStationName(stationName);
    _selectedStation = normalized;

    if (normalized == null) {
      if (!preserveCoordinates) {
        _lat = null;
        _lng = null;
      }
      return;
    }

    final _Station? station = _vehicleStations.cast<_Station?>().firstWhere(
          (_Station? item) => item?.name == normalized,
          orElse: () => null,
        );

    if (station != null) {
      _lat = station.lat;
      _lng = station.lng;
    } else if (!preserveCoordinates) {
      _lat = null;
      _lng = null;
    }
  }

  void _setLocationMode(bool useStation) {
    if (_useStationLocation == useStation) return;
    setState(() {
      _useStationLocation = useStation;
      if (useStation) {
        if (_stationValue != null) {
          _applySelectedStation(_stationValue);
        } else {
          _lat = null;
          _lng = null;
        }
      } else if (_addressValue == null) {
        _lat = null;
        _lng = null;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── 주소 검색 ──────────────────────────────────────────────────────────────

  Future<void> _geocode() async {
    final String addr = _addressCtrl.text.trim();
    if (addr.isEmpty) return;
    setState(() => _geocoding = true);
    final Map<String, dynamic>? result =
        await DeviceRegistryRepository().requestGeocode(addr);
    if (!mounted) return;
    setState(() => _geocoding = false);
    if (result == null) {
      Utils.showSnackBar('주소를 찾을 수 없습니다.', isError: true);
      return;
    }
    setState(() {
      _useStationLocation = false;
      _addressCtrl.text = result['address']?.toString() ?? addr;
      _lat = _toDouble(result['lat']);
      _lng = _toDouble(result['lng']);
    });
  }

  // ── 저장 ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    final Map<String, dynamic>? row =
        await DeviceRegistryRepository().requestUpsert(
      deviceType  : widget.deviceType,
      deviceId    : widget.deviceId,
      name        : _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      locationLat     : _lat,
      locationLng     : _lng,
      locationAddress : _resolvedLocationAddress,
      homeStation : _resolvedHomeStation,
      memo        : _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (row != null) {
      Utils.showSnackBar('저장되었습니다.');
      Navigator.of(context).pop(true);
    } else {
      Utils.showSnackBar('저장에 실패했습니다.', isError: true);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String title =
        '${_isVehicle ? '차량' : '인프라'} ${widget.deviceId} 등록 정보';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 제목
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E), fontFamily: 'pretendard',
                ),
              ),
              const SizedBox(height: 24),

              // 이름
              _label('이름'),
              const SizedBox(height: 6),
              _field(_nameCtrl, hint: '예) 차량 001'),
              const SizedBox(height: 18),

              // 홈 위치 (차량: 스테이션 드롭다운 / 인프라: 주소 입력)
              if (_isVehicle) ...<Widget>[
                _label('홈 스테이션'),
                const SizedBox(height: 6),
                _stationDropdown(),
              ] else ...<Widget>[
                _label('고정 주소'),
                const SizedBox(height: 6),
                _addressField(),
                if (_lat != null && _lng != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '위도 ${_lat!.toStringAsFixed(6)}  경도 ${_lng!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280), fontFamily: 'pretendard',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),

              // 메모
              _label('메모 (선택)'),
              const SizedBox(height: 6),
              _field(_memoCtrl, hint: '메모를 입력하세요', maxLines: 2),
              const SizedBox(height: 28),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 14, color: Color(0xFF6B7280), fontFamily: 'pretendard',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005FB8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              fontFamily: 'pretendard',
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: Color(0xFF374151), fontFamily: 'pretendard',
        ),
      );

  Widget _field(
    TextEditingController ctrl, {
    String hint = '',
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines   : maxLines,
      style      : const TextStyle(fontSize: 14, fontFamily: 'pretendard'),
      decoration : InputDecoration(
        hintText     : hint,
        hintStyle    : const TextStyle(
            fontSize: 14, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide  : const BorderSide(color: Color(0xFF005FB8)),
        ),
      ),
    );
  }

  Widget _locationModeToggle() => Row(
        children: <Widget>[
          _locationModeButton(
            label: '스테이션',
            icon: Icons.train_rounded,
            selected: _useStationLocation,
            onTap: () => _setLocationMode(true),
          ),
          const SizedBox(width: 8),
          _locationModeButton(
            label: '주소',
            icon: Icons.location_on_outlined,
            selected: !_useStationLocation,
            onTap: () => _setLocationMode(false),
          ),
        ],
      );

  Widget _locationModeButton({
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                Icon(
                  icon,
                  size: 15,
                  color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
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

  Widget _locationSummary() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.place_rounded, size: 14, color: Color(0xFF475569)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _resolvedLocationAddress ?? '-',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  fontFamily: 'pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  // 차량 스테이션 드롭다운
  Widget _stationDropdown() {
    final ThemeData selectorBaseTheme = Theme.of(context);
    final ThemeData selectorTheme = selectorBaseTheme.copyWith(
      canvasColor: Colors.white,
      cardColor: Colors.white,
      colorScheme: selectorBaseTheme.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Colors.white,
      ),
    );

    final Widget selectorField = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: selectorTheme,
        child: DropdownButton<String>(
          value: _stationValue,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          hint: const Text(
            '스테이션을 선택하세요',
            style: TextStyle(fontSize: 14, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
          ),
          items: _vehicleStations
              .map((s) => DropdownMenuItem<String>(
                    value: s.name,
                    child: Text(
                      s.name,
                      style: const TextStyle(fontSize: 14, fontFamily: 'pretendard'),
                    ),
                  ))
              .toList(),
          onChanged: (String? value) {
            setState(() {
              _useStationLocation = true;
              _applySelectedStation(value);
            });
          },
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _locationModeToggle(),
        const SizedBox(height: 10),
        _useStationLocation ? selectorField : _addressInputField(),
        if (_resolvedLocationAddress != null) ...<Widget>[
          const SizedBox(height: 8),
          _locationSummary(),
        ],
      ],
    );
    /*

    final ThemeData baseTheme = Theme.of(context);
    final ThemeData dropdownTheme = baseTheme.copyWith(
      canvasColor: Colors.white,
      cardColor: Colors.white,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Colors.white,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: dropdownTheme,
        child: DropdownButton<String>(
        value       : _selectedStation,
        isExpanded  : true,
        underline   : const SizedBox.shrink(),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        hint: const Text(
          '스테이션 선택',
          style: TextStyle(
              fontSize: 14, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
        ),
        items: _vehicleStations
            .map((s) => DropdownMenuItem<String>(
                  value: s.name,
                  child: Text(
                    s.name,
                    style: const TextStyle(fontSize: 14, fontFamily: 'pretendard'),
                  ),
                ))
            .toList(),
        onChanged: (String? v) {
          if (v == null) return;
          final _Station? st = _vehicleStations.cast<_Station?>().firstWhere(
                (s) => s?.name == v,
                orElse: () => null,
              );
          setState(() {
            _selectedStation = v;
            _lat = st?.lat;
            _lng = st?.lng;
          });
        },
        ),
      ),
    );
    */
  }

  // 인프라 주소 입력 + 검색 버튼
  Widget _addressInputField() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _addressCtrl,
            style      : const TextStyle(fontSize: 14, fontFamily: 'pretendard'),
            onSubmitted: (_) => _geocode(),
            decoration : InputDecoration(
              hintText     : '예) 대구광역시 중구 태평로 141',
              hintStyle    : const TextStyle(
                  fontSize: 14, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFF005FB8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: ElevatedButton(
            onPressed: _geocoding ? null : _geocode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005FB8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: _geocoding
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    '주소 검색',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      fontFamily: 'pretendard',
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _addressField() {
    if (_useStationLocation) {
      return _stationDropdown();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _locationModeToggle(),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
        Expanded(
          child: TextField(
            controller: _addressCtrl,
            style      : const TextStyle(fontSize: 14, fontFamily: 'pretendard'),
            onSubmitted: (_) => _geocode(),
            decoration : InputDecoration(
              hintText     : '예) 대구광역시 중구 태평로 141',
              hintStyle    : const TextStyle(
                  fontSize: 14, color: Color(0xFFD1D5DB), fontFamily: 'pretendard'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: Color(0xFF005FB8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: ElevatedButton(
            onPressed: _geocoding ? null : _geocode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005FB8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: _geocoding
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    '검색',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      fontFamily: 'pretendard',
                    ),
                  ),
          ),
        ),
          ],
        ),
        if (_resolvedLocationAddress != null) ...<Widget>[
          const SizedBox(height: 8),
          _locationSummary(),
        ],
      ],
    );
  }
}
