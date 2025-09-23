import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../repository/robot_repository.dart';

class RobotController extends GetxController {
  List<RobotType> _robotTypes = [];
  List<String> _robotTypeDescriptions = [];

  List<Robot> _allRobots = [];
  List<Robot> _filteredRobots = [];
  List<Robot> _unDeletedRobots = [];
  String _robotFilter = "3tier";
  String _normalizeSerial(String s) => s.replaceAll('controller_', '').trim();

  List<RobotStatus> _robotStatusList = [];
  bool _isLoading = false;

  List<RobotType> get robotTypes => _robotTypes;

  List<String> get robotTypeDescriptions => _robotTypeDescriptions;

  List<Robot> get robots => _filteredRobots;
  List<Robot> get unDeletedRobots => _unDeletedRobots;
  String get robotFilter => _robotFilter;

  List<RobotStatus> get robotStatusList => _robotStatusList;

  bool get isLoading => _isLoading;

  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////

  Future<void> reqRobotTypes() async {
    _robotTypes = await RobotRepository().requestRobotTypes();

    _robotTypeDescriptions = [];
    for (var robotType in _robotTypes) {
      _robotTypeDescriptions.add(robotType.typeDescription ?? "");
    }

    update();
  }

  void setRobotFilterStr(String filter) {
    if (_robotFilter != filter) {
      _robotFilter = filter;
      makeFilteredRobots();
      update();
    } else {
      _robotFilter = filter;
    }
  }

  void makeFilteredRobots() {
    _filteredRobots = [];

    String robotFilter = _robotFilter.toLowerCase();

    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].isDeleted == true) {
        if (_robotFilter.contains("삭제됨")) {
          _filteredRobots.add(_allRobots[i]);
        }
        continue;
      }

      String robotType = _allRobots[i].typeDescription!.toLowerCase();
      if (robotFilter.contains(robotType)) {
        _filteredRobots.add(_allRobots[i]);
      }
    }

    _unDeletedRobots = [];
    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].isDeleted == true) {
        continue;
      }

      _unDeletedRobots.add(_allRobots[i]);
    }
  }

  Future<void> reqRobotList({int? typeId}) async {
    _allRobots = await RobotRepository().requestRobotList(typeId);

    _allRobots.sort((a, b) {
      int result = a.objectTypeId!.compareTo(b.objectTypeId!);

      if (result == 0) {
        result = a.id!.compareTo(b.id!);
      }

      return result;
    });

    makeFilteredRobots();
    update();
  }

  Future<bool> reqAddRobot(Map<String, dynamic> params) async {
    return await RobotRepository().requestAddRobot(params);
  }

  Future<bool> reqDeleteRobot(int objectId) async {
    return await RobotRepository().requestSoftDeleteRobot(objectId);
  }

  Future<void> reqRobotStatusList({int? objectId, int? objectTypeId}) async {
    _isLoading = true;

    _robotStatusList = await RobotRepository().requestRobotStatusList(
      objectId: objectId,
      objectTypeId: objectTypeId,
    );

    _isLoading = false;
    update();
  }

  String getRobotName(int objectId) {
    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].id == objectId) {
        return "${_allRobots[i].typeDescription}_${_allRobots[i].name}";
      }
    }

    return "";
  }

  Robot? getRobotBySerial(String serial) {
    final target = _normalizeSerial(serial);
    for (int i = 0; i < _allRobots.length; i++) {
      final r = _allRobots[i];
      final rs = _normalizeSerial(r.serial ?? '');
      if (rs == target) return r;
    }
    return null;
  }

  bool isDeletedRobot(int objectId) {
    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].id == objectId) {
        return (_allRobots[i].isDeleted == true);
      }
    }

    return false;
  }

  String getRobotNameByRobotId(int objectId) {
    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].id == objectId) {
        return _allRobots[i].name ?? "";
      }
    }

    return "";
  }

  void setOnMoveRes(String serial, Map<String, dynamic> moveRes) {
    debugPrint("setOnMoveRes()");
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].robotStatus = int.tryParse(moveRes['data']['status'].toString());
          _robotStatusList[i].drivingSpeed = double.tryParse(moveRes['data']['speed'].toString());

          List<dynamic> currentPosition = moveRes['data']['cur_coodi'];
          List<dynamic> toPosition = moveRes['data']['des_coodi'];

          _robotStatusList[i].posX = double.tryParse(currentPosition[0].toString());
          _robotStatusList[i].posY = double.tryParse(currentPosition[1].toString());

          _robotStatusList[i].latitude = _robotStatusList[i].posX;
          _robotStatusList[i].longitude = _robotStatusList[i].posY;

          debugPrint("setOnMoveRes() latitude: ${_robotStatusList[i].posX}, longitude: ${_robotStatusList[i].posY}");

          _robotStatusList[i].goalX = double.tryParse(toPosition[0].toString());
          _robotStatusList[i].goalY = double.tryParse(toPosition[1].toString());

          _robotStatusList[i].remainTime = double.tryParse(moveRes['data']['remain_time'].toString());
          _robotStatusList[i].remainDistance = double.tryParse(moveRes['data']['remain_dist'].toString());

          update();
          return;
        }
      }
    }
  }

  void setOnCarBatteryRes(String serial, Map<String, dynamic> carBatteryRes) {
    debugPrint("setOnCarBatteryRes()");
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].battery = double.tryParse(carBatteryRes['data']['soc'].toString());
          _robotStatusList[i].serviceBattery = double.tryParse(carBatteryRes['data']['soh'].toString());
          update();
          return;
        }
      }
    }
  }

  void setOnEmergencyStop(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onEmergencyStop = isOn;
          debugPrint("setOnEmergencyStop() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnAutoPilot(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onAutoPilot = isOn;
          debugPrint("setOnAutoPilot() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnHeadLight(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onHeadLight = isOn;
          debugPrint("setOnHeadLight() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnPromotionMode(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onPromotionMode = isOn;
          debugPrint("setOnPromotionMode() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnReturning(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onReturning = isOn;
          debugPrint("setOnReturning() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenRefrigDoor(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openRefrigDoor = isOn;
          debugPrint("openRefrigDoor() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenInnerDoor(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openInnerDoor = isOn;
          debugPrint("setOpenInnerDoor() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnInnerLight(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onInnerLight = isOn;
          debugPrint("setOnInnerLight() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOnOutsideDisplay(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].onOutsideDisplay = isOn;
          debugPrint("setOnOutsideDisplay() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenDeliveryBox01(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openDeliveryBox01 = isOn;
          debugPrint("setOpenDeliveryBox01() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenDeliveryBox02(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openDeliveryBox02 = isOn;
          debugPrint("setOpenDeliveryBox02() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenDeliveryBox03(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openDeliveryBox03 = isOn;
          debugPrint("setOpenDeliveryBox03() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenDeliveryBox04(String serial, bool isOn) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openDeliveryBox04 = isOn;
          debugPrint("setOpenDeliveryBox04() isOn $isOn");
          update();
          return;
        }
      }
    }
  }

  void setOpenDeliveryBox(String serial, String message) {
    Robot? robot = getRobotBySerial(serial);

    List<String> messages = message.split(",");

    bool openBox01 = (messages[0] == "ready");
    bool openBox02 = (messages[1] == "ready");
    bool openBox03 = (messages[2] == "ready");
    bool openBox04 = (messages[3] == "ready");

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].openDeliveryBox01 = openBox01;
          _robotStatusList[i].openDeliveryBox02 = openBox02;
          _robotStatusList[i].openDeliveryBox03 = openBox03;
          _robotStatusList[i].openDeliveryBox04 = openBox04;
          debugPrint("setOpenDeliveryBox() $openBox01, $openBox02, $openBox03, $openBox04");
          update();
          return;
        }
      }
    }
  }

  void setUpdateAddress(String serial, String address) {
    Robot? robot = getRobotBySerial(serial);

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          _robotStatusList[i].address = address;
          debugPrint("setOnUpdateAddress() address $address");
          update();
          return;
        }
      }
    }
  }
}
