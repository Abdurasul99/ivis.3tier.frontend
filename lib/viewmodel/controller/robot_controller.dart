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

    // debugPrint("makeFilteredRobots() _filteredRobots : $_filteredRobots");
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
    for (int i = 0; i < _allRobots.length; i++) {
      if (_allRobots[i].serial == serial) {
        return _allRobots[i];
      }
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

  void updateTaroState(int robotNumber, int state) {
    Robot? robot = getRobotBySerial(robotNumber.toString());

    if (robot != null) {
      for (int i = 0; i < _robotStatusList.length; i++) {
        if (_robotStatusList[i].id == robot.id) {
          if (_robotStatusList[i].robotStatus == state) {
            return;
          }

          _robotStatusList[i].robotStatus = state;
          debugPrint("updateTaroState() robotNumber $robotNumber, state $state");
          update();
          return;
        }
      }
    }
  }

  void onTaroMessageMainPageSub(Map<String, dynamic> payload) {
    String taroSerial = (payload['Data']['Robot_Num'] ?? "").toString();

    if (taroSerial.isEmpty) {
      return;
    }

    double currentX = payload['Data']['Current_X'] ?? 0.0;
    double currentY = payload['Data']['Current_Y'] ?? 0.0;
    double goalX = payload['Data']['Target_X'] ?? 0.0;
    double goalY = payload['Data']['Target_Y'] ?? 0.0;

    if (currentX == 0.0 && currentY == 0.0) {
      return;
    }

    double timeAuto = payload['Data']['TimeAuto'] ?? 0.0;
    double distanceAuto = payload['Data']['DistanceAuto'] ?? 0.0;
    double wheelBattery = payload['Data']['WheelBattery'] ?? 0.0;
    double accTimeAuto = payload['Data']['Acc_TimeAuto'] ?? 0.0;
    double accDistanceAuto = payload['Data']['Acc_DistanceAuto'] ?? 0.0;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == taroSerial) {
        _robotStatusList[i].posX = currentX;
        _robotStatusList[i].posY = currentY;
        _robotStatusList[i].latitude = currentX;
        _robotStatusList[i].longitude = currentY;
        _robotStatusList[i].goalX = goalX;
        _robotStatusList[i].goalY = goalY;
        _robotStatusList[i].wheelBattery = wheelBattery;

        double drivingSpeed = 0;
        if (goalX != 0.0 && goalY != 0.0) {
          if (timeAuto != 0.0) {
            drivingSpeed = distanceAuto / timeAuto;
          }
        }

        debugPrint("distanceAuto: $distanceAuto, timeAuto: $timeAuto, drivingSpeed: $drivingSpeed");

        _robotStatusList[i].drivingSpeed = drivingSpeed;

        _robotStatusList[i].timeAuto = timeAuto;
        _robotStatusList[i].distanceAuto = distanceAuto;

        _robotStatusList[i].accTimeAuto = accTimeAuto;
        _robotStatusList[i].accDistanceAuto = accDistanceAuto;

        update();
        return;
      }
    }
  }

  String getTaroStateLabel(String serial) {
    int? state;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == serial) {
        state = _robotStatusList[i].robotStatus;
        break;
      }
    }

    if (state == null) {
      return "";
    }

    switch (state) {
      case RobotState.nonOperatingHour: // 운영시간 아님
        return "운영종료";

      case RobotState.error: // 오류
        return "오류";

      case RobotState.none: // NONE
        return "";

      case RobotState.waiting: // 사용가능상태
        return "대기중";

      case RobotState.request: // 호출요청
      case RobotState.requestAnswer: // 호출요청 응답
        return "호출됨";

      case RobotState.requestMove: // 출발지로 이동중
        return "이동중";

      case RobotState.requestArrive: // 출발지 도착
        return "출발대기";

      case RobotState.requestCancel: // 배차취소
      case RobotState.cancelAnswer: // 배차취소 응답 : 로봇 배정 전
      case RobotState.cancelAnswerAfter: // 배차취소 응답 : 로봇 배정 전
        return "배차취소";

      case RobotState.boarding: // 탑승
      case RobotState.boardingAnswer: // 탑승 응답
        return "탑승";

      case RobotState.destination: // 이동요청
      case RobotState.destinationAnswer: // 이동
        return "이동중";

      case RobotState.stop: // 정지
      case RobotState.stopAnswer: // 정지응답
        return "일시정지";

      case RobotState.arrival: // 도착
        return "목적지 도착";

      case RobotState.manualMode: // 수동운전
        return "수동운전중";

      case RobotState.returnRequest: // 반납
      case RobotState.returnAnswer: // 반납중
        return "반납중";
    }
    return "";
  }

  Color getTaroStatedColor(String serial) {
    int? state;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == serial) {
        state = _robotStatusList[i].robotStatus;
        break;
      }
    }

    if (state == null) {
      return Colors.transparent;
    }

    switch (state) {
      case RobotState.nonOperatingHour: // 운영시간 아님
        return const Color(0xFF666565);

      case RobotState.error: // 오류
        return const Color(0xFFC42B1C);

      case RobotState.none: // NONE
        return Colors.transparent;

      case RobotState.waiting: // 사용가능상태
        return const Color(0xFF60CDFF);

      case RobotState.request: // 호출요청
      case RobotState.requestAnswer: // 호출요청 응답
        return const Color(0xFF005FB8);

      case RobotState.requestMove: // 출발지로 이동중
        return Colors.blue;

      case RobotState.requestArrive: // 출발지 도착
        return const Color(0xFF60CDFF);

      case RobotState.requestCancel: // 배차취소
      case RobotState.cancelAnswer: // 배차취소 응답 : 로봇 배정 전
      case RobotState.cancelAnswerAfter: // 배차취소 응답 : 로봇 배정 전
        return const Color(0xFFFFAE00);

      case RobotState.boarding: // 탑승
      case RobotState.boardingAnswer: // 탑승 응답
        return const Color(0xFF005FB8);

      case RobotState.destination: // 이동요청
      case RobotState.destinationAnswer: // 이동
        return const Color(0xFF005FB8);

      case RobotState.stop: // 정지
      case RobotState.stopAnswer: // 정지응답
        return const Color(0xFFFFAE00);

      case RobotState.arrival: // 도착
        return const Color(0xFF005FB8);

      case RobotState.manualMode: // 수동운전
        return const Color(0xFF666565);

      case RobotState.returnRequest: // 반납
      case RobotState.returnAnswer: // 반납중
        return const Color(0xFF666565);
    }
    return Colors.transparent;
  }

  bool getTaroIsSeated(String serial) {
    int? state;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == serial) {
        state = _robotStatusList[i].robotStatus;
        break;
      }
    }

    if (state == null) {
      return false;
    }

    switch (state) {
      case RobotState.nonOperatingHour: // 운영시간 아님
      case RobotState.error: // 오류
      case RobotState.none: // NONE
      case RobotState.waiting: // 사용가능상태
      case RobotState.request: // 호출요청
      case RobotState.requestAnswer: // 호출요청 응답
      case RobotState.requestMove: // 출발지로 이동중
      case RobotState.requestArrive: // 출발지 도착
      case RobotState.requestCancel: // 배차취소
      case RobotState.cancelAnswer: // 배차취소 응답 : 로봇 배정 전
      case RobotState.cancelAnswerAfter: // 배차취소 응답 : 로봇 배정 전
        return false;

      case RobotState.boarding: // 탑승
      case RobotState.boardingAnswer: // 탑승 응답
      case RobotState.destination: // 이동요청
      case RobotState.destinationAnswer: // 이동
      case RobotState.stop: // 정지
      case RobotState.stopAnswer: // 정지응답
      case RobotState.arrival: // 도착
      case RobotState.manualMode: // 수동운전
        return true;

      case RobotState.returnRequest: // 반납
      case RobotState.returnAnswer: // 반납중
        return false;
    }
    return false;
  }

  String getTaroLocation(String serial) {
    RobotStatus? status;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == serial) {
        status = _robotStatusList[i];
        break;
      }
    }

    if (status == null) {
      debugPrint("getTaroLocation() status is null, serial $serial");
      return "";
    }

    //debugPrint("serial : $serial, posX = ${status.posX}, posY = ${status.posY}");

    if (status.posX != 0.0 && status.posY != 0.0) {
      for (int i = 0; i < kTaroMakers.length; i++) {
        //debugPrint("[i]: $i, posX = ${kTaroMakers[i]['X']}, posY = ${kTaroMakers[i]['Y']}");

        if (status.posX == kTaroMakers[i]['X'] && status.posY == kTaroMakers[i]['Y']) {
          return kTaroMakers[i]['title'] as String;
        }
      }
    }

    String goal = "";
    for (int i = 0; i < kTaroMakers.length; i++) {
      if (status.goalX == kTaroMakers[i]['X'] && status.goalY == kTaroMakers[i]['Y']) {
        goal = kTaroMakers[i]['title'] as String;
        break;
      }
    }

    switch (status.robotStatus) {
      case RobotState.request: // 호출요청
      case RobotState.requestAnswer: // 호출요청 응답
      case RobotState.requestMove: // 출발지로 이동중
      case RobotState.destination: // 이동요청
      case RobotState.destinationAnswer: // 이동
      case RobotState.returnRequest: // 반납
      case RobotState.returnAnswer: // 반납중
        return "$goal(으)로 이동중";

      case RobotState.stop: // 정지
      case RobotState.stopAnswer: // 정지응답
        return "일시정지";

      case RobotState.manualMode: // 수동운전
        return "수동운전중";
    }

    debugPrint("getTaroLocation() return empty, serial $serial");
    return "";
  }

  bool getIsTaroAutoPilotMode(String serial) {
    RobotStatus? status;

    for (int i = 0; i < _robotStatusList.length; i++) {
      if (_robotStatusList[i].serial == serial) {
        status = _robotStatusList[i];
        break;
      }
    }

    if (status == null) {
      return true;
    }

    switch (status.robotStatus) {
      case RobotState.manualMode: // 수동운전
        return false;
    }

    return true;
  }
}
