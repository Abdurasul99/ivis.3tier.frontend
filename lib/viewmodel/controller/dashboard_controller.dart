import 'package:get/get.dart';

import '../../model/dashboard_model.dart';
import '../../viewmodel/repository/dashboard_repository.dart';

class DashboardController extends GetxController {
  bool _isLoading = false;
  String _mapViewId = '';
  List<RobotSuccessData> _robotSuccessData = [];
  DeviceStatusData? _deviceStatusData;
  List<LayoutSet> _layoutSets = [];

  bool get isLoading => _isLoading;
  String get mapViewId => _mapViewId;
  List<RobotSuccessData> get robotSuccessData => _robotSuccessData;
  DeviceStatusData? get deviceStatusData => _deviceStatusData;
  List<LayoutSet> get layoutSets => _layoutSets;

  //////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////

  void setMapViewId(String mapViewId) {
    _mapViewId = mapViewId;
  }

  Future<void> reqDashboardLayoutSetting() async {
    _isLoading = true;

    _layoutSets = await DashboardRepository().requestDashboardLayoutSetting();

    _isLoading = false;
    update();
  }

  Future<bool> reqInsertDashboardLayoutSetting(
      String title, int row, int column, String period, String displayMethod) async {
    Map<String, dynamic> params = {};
    params['title'] = title;
    params['rowIndex'] = row.toString();
    params['columnIndex'] = column.toString();
    if (period.isNotEmpty) {
      params['period'] = period;
    }
    if (displayMethod.isNotEmpty) {
      params['displayMethod'] = displayMethod;
    }

    return await DashboardRepository().requestInsertDashboardLayoutSetting(params);
  }

  void clearLayouts() {
    _layoutSets.clear();
  }

  bool isEmptyLayouts() {
    for (int i = 0; i < _layoutSets.length; i++) {
      if (_layoutSets[i].title != null && _layoutSets[i].title!.isNotEmpty) {
        return false;
      }
    }

    return true;
  }

  Future<bool> saveLayouts() async {
    await DashboardRepository().requestDeleteDashboardLayoutSetting();

    int rowIndex = 0;
    int colIndex = 0;

    bool saveSuccess = true;

    for (int i = 0; i < _layoutSets.length; i++) {
      LayoutSet layoutSet = _layoutSets[i];
      if (layoutSet.title == null || layoutSet.title!.isEmpty) {
        continue;
      }

      if (layoutSet.rowIndex == null || layoutSet.columnIndex == null) {
        continue;
      }

      if (rowIndex != layoutSets[i].rowIndex) {
        colIndex = 0;
      }

      rowIndex = _layoutSets[i].rowIndex ?? 0;
      _layoutSets[i].columnIndex = colIndex;

      bool result = await reqInsertDashboardLayoutSetting(
        layoutSet.title ?? "",
        rowIndex,
        colIndex,
        layoutSet.period ?? "",
        layoutSet.displayMethod ?? "",
      );

      colIndex++;

      if (result == false) {
        saveSuccess = false;
      }
    }

    return saveSuccess;
  }

  void addLayout(LayoutSet layout) {
    for (int i = 0; i < _layoutSets.length; i++) {
      if (_layoutSets[i].rowIndex == layout.rowIndex && _layoutSets[i].columnIndex == layout.columnIndex) {
        _layoutSets.removeAt(i);
        break;
      }
    }

    _layoutSets.add(layout);
    update();
  }

  void deleteLayout(int row, int column) {
    for (int i = 0; i < _layoutSets.length; i++) {
      if (_layoutSets[i].rowIndex == row && _layoutSets[i].columnIndex == column) {
        _layoutSets.removeAt(i);
        break;
      }
    }

    update();
  }

  void deleteLayoutByRow(int row) {
    for (LayoutSet set in _layoutSets) {
      if (set.rowIndex == row) {
        _layoutSets.remove(set);
        break;
      }
    }

    update();
  }

  Future<bool> reqDeleteDashboardLayoutSetting() async {
    return await DashboardRepository().requestDeleteDashboardLayoutSetting();
  }

  Future<void> fetchRobotSuccess() async {
    _isLoading = true;

    _robotSuccessData = await DashboardRepository().fetchRobotSuccess();

    _isLoading = false;
    update();
  }

  Future<void> fetchDeviceStatus() async {
    _isLoading = true;

    _deviceStatusData = await DashboardRepository().fetchDeviceStatus();

    _isLoading = false;
    update();
  }
}
