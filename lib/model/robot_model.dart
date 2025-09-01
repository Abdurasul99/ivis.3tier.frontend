class RobotType {
  int? id;
  String? typeDescription;
  String? imageUrl;

  RobotType({this.id, this.typeDescription, this.imageUrl});

  RobotType.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'] ?? "0");
    typeDescription = json['type_description'];
    imageUrl = json['image_url'];
  }

  @override
  String toString() {
    return 'RobotType{id: $id, typeDescription: $typeDescription, imageUrl: $imageUrl}';
  }
}

class Robot {
  int? id;
  int? objectTypeId;
  String? typeDescription;
  String? name;
  String? serial;
  String? description;
  String? typeImageUrl;
  String? imageUrl;
  String? createdTs;
  bool? isDeleted;

  Robot({
    this.id,
    this.objectTypeId,
    this.typeDescription,
    this.name,
    this.serial,
    this.description,
    this.typeImageUrl,
    this.imageUrl,
    this.createdTs,
    this.isDeleted,
  });

  Robot.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'] ?? "0");
    objectTypeId = int.tryParse(json['object_type_id'] ?? "0");
    typeDescription = json['type_description'];
    name = json['name'];
    serial = json['serial'];
    description = json['description'];
    typeImageUrl = json['type_image_url'];
    imageUrl = json['image_url'];
    createdTs = json['created_ts'];
    isDeleted = (json['is_deleted'] == 1);
  }

  @override
  String toString() {
    return 'Robot{id: $id, objectTypeId: $objectTypeId, typeDescription: $typeDescription, name: $name, serial: $serial, description: $description, typeImageUrl: $typeImageUrl, imageUrl: $imageUrl, createdTs: $createdTs, isDeleted: $isDeleted}';
  }
}

class RobotStatus {
  int? id;
  int? objectTypeId;
  String? name;
  String? serial;
  String? description;
  int? robotStatus;
  int? active;
  int? serviceMode;
  double? goalX;
  double? goalY;
  double? goalZ;
  double? goalW;
  double? posX;
  double? posY;
  double? posZ;
  double? posW;
  double? latitude;
  double? longitude;
  double? battery;
  int? linkRobot;
  double? timeManual;
  double? timeAuto;
  double? distanceManual;
  double? distanceAuto;
  double? accTimeManual;
  double? accTimeAuto;
  double? accDistanceManual;
  double? accDistanceAuto;
  double? wheelBattery;
  double? serviceBattery;
  double? remainDistance;
  double? remainTime;
  double? drivingSpeed;
  double? drivingRange;
  double? drivingDistance;
  double? totalDrivingDistance;
  String? address;
  String? connectTime;
  String? arrivalTime;
  String? stopTime;
  String? serviceTime;
  bool? onEmergencyStop;
  bool? onAutoPilot;
  bool? onHeadLight;
  bool? onReturning;
  bool? onInnerLight;
  bool? onOutsideDisplay;
  bool? onPromotionMode;
  bool? openRefrigDoor;
  bool? openBoxDoor;
  bool? openInnerDoor;
  bool? openDeliveryBox01;
  bool? openDeliveryBox02;
  bool? openDeliveryBox03;
  bool? openDeliveryBox04;
  int? bookInfoNum;
  String? createdTs;

  RobotStatus({
    this.id,
    this.objectTypeId,
    this.name,
    this.serial,
    this.description,
    this.robotStatus,
    this.active,
    this.serviceMode,
    this.goalX,
    this.goalY,
    this.goalZ,
    this.goalW,
    this.posX,
    this.posY,
    this.posZ,
    this.posW,
    this.latitude,
    this.longitude,
    this.battery,
    this.linkRobot,
    this.timeManual,
    this.timeAuto,
    this.distanceManual,
    this.distanceAuto,
    this.accTimeManual,
    this.accTimeAuto,
    this.accDistanceManual,
    this.accDistanceAuto,
    this.wheelBattery,
    this.serviceBattery,
    this.remainDistance,
    this.remainTime,
    this.drivingSpeed,
    this.drivingRange,
    this.drivingDistance,
    this.totalDrivingDistance,
    this.address,
    this.connectTime,
    this.arrivalTime,
    this.stopTime,
    this.serviceTime,
    this.onEmergencyStop,
    this.onAutoPilot,
    this.onHeadLight,
    this.onReturning,
    this.onInnerLight,
    this.onOutsideDisplay,
    this.onPromotionMode,
    this.openRefrigDoor,
    this.openBoxDoor,
    this.openInnerDoor,
    this.openDeliveryBox01,
    this.openDeliveryBox02,
    this.openDeliveryBox03,
    this.openDeliveryBox04,
    this.bookInfoNum,
    this.createdTs,
  });

  RobotStatus.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'] ?? "0");
    objectTypeId = int.tryParse(json['object_type_id'] ?? "0");
    name = json['name'];
    serial = json['serial'];
    description = json['description'];
    robotStatus = json['robot_status'];
    active = json['active'];
    serviceMode = json['service_mode'];
    goalX = json['goal_x'];
    goalY = json['goal_y'];
    goalZ = json['goal_z'];
    goalW = json['goal_w'];
    posX = json['pos_x'];
    posY = json['pos_y'];
    posZ = json['pos_z'];
    posW = json['pos_w'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    battery = json['battery'];
    linkRobot = json['link_robot'];
    timeManual = json['time_manual'];
    timeAuto = json['time_auto'];
    distanceManual = json['distance_manual'];
    distanceAuto = json['distance_auto'];
    accTimeManual = json['acc_time_manual'];
    accTimeAuto = json['acc_time_auto'];
    accDistanceManual = json['acc_distance_manual'];
    accDistanceAuto = json['acc_distance_auto'];
    wheelBattery = json['wheel_battery'];
    serviceBattery = json['service_battery'];
    remainDistance = json['remain_distance'];
    remainTime = json['remain_time'];
    drivingSpeed = json['driving_speed'];
    drivingRange = json['driving_range'];
    drivingDistance = json['driving_distance'];
    totalDrivingDistance = json['total_driving_distance'];
    address = json['address'];
    connectTime = json['connect_time'];
    arrivalTime = json['arrival_time'];
    stopTime = json['stop_time'];
    serviceTime = json['service_time'];
    onEmergencyStop = (json['on_emergency_stop'] == null) ? null : (json['on_emergency_stop'] == 1);
    onAutoPilot = (json['on_autopilot'] == null) ? null : (json['on_autopilot'] == 1);
    onHeadLight = (json['on_headlight'] == null) ? null : (json['on_headlight'] == 1);
    onReturning = (json['on_returning'] == null) ? null : (json['on_returning'] == 1);
    onInnerLight = (json['on_inner_light'] == null) ? null : (json['on_inner_light'] == 1);
    onOutsideDisplay = (json['on_outside_display'] == null) ? null : (json['on_outside_display'] == 1);
    onPromotionMode = (json['on_promotion_mode'] == null) ? null : (json['on_promotion_mode'] == 1);
    openRefrigDoor = (json['open_refrig_door'] == null) ? null : (json['open_refrig_door'] == 1);
    openBoxDoor = (json['open_box_door'] == null) ? null : (json['open_box_door'] == 1);
    openInnerDoor = (json['open_inner_door'] == null) ? null : (json['open_inner_door'] == 1);
    openDeliveryBox01 = (json['open_delivery_box_01'] == null) ? null : (json['open_delivery_box_01'] == 1);
    openDeliveryBox02 = (json['open_delivery_box_02'] == null) ? null : (json['open_delivery_box_02'] == 1);
    openDeliveryBox03 = (json['open_delivery_box_03'] == null) ? null : (json['open_delivery_box_03'] == 1);
    openDeliveryBox04 = (json['open_delivery_box_04'] == null) ? null : (json['open_delivery_box_04'] == 1);
    bookInfoNum = json['book_info_num'];
    createdTs = json['created_ts'];
  }

  @override
  String toString() {
    return 'RobotStatus{id: $id, objectTypeId: $objectTypeId, name: $name, serial: $serial, description: $description, robotStatus: $robotStatus, active: $active, serviceMode: $serviceMode, goalX: $goalX, goalY: $goalY, goalZ: $goalZ, goalW: $goalW, posX: $posX, posY: $posY, posZ: $posZ, posW: $posW, latitude: $latitude, longitude: $longitude, battery: $battery, linkRobot: $linkRobot, timeManual: $timeManual, timeAuto: $timeAuto, distanceManual: $distanceManual, distanceAuto: $distanceAuto, accTimeManual: $accTimeManual, accTimeAuto: $accTimeAuto, accDistanceManual: $accDistanceManual, accDistanceAuto: $accDistanceAuto, wheelBattery: $wheelBattery, serviceBattery: $serviceBattery, remainDistance: $remainDistance, remainTime: $remainTime, drivingSpeed: $drivingSpeed, drivingRange: $drivingRange, drivingDistance: $drivingDistance, totalDrivingDistance: $totalDrivingDistance, address: $address, connectTime: $connectTime, arrivalTime: $arrivalTime, stopTime: $stopTime, serviceTime: $serviceTime, onEmergencyStop: $onEmergencyStop, onAutoPilot: $onAutoPilot, onHeadLight: $onHeadLight, onReturning: $onReturning, onInnerLight: $onInnerLight, onOutsideDisplay: $onOutsideDisplay, onPromotionMode: $onPromotionMode, openRefrigDoor: $openRefrigDoor, openBoxDoor: $openBoxDoor, openInnerDoor: $openInnerDoor, openDeliveryBox01: $openDeliveryBox01, openDeliveryBox02: $openDeliveryBox02, openDeliveryBox03: $openDeliveryBox03, openDeliveryBox04: $openDeliveryBox04, bookInfoNum: $bookInfoNum, createdTs: $createdTs}';
  }
}

class StatusHistoryList {
  int? listCount;
  List<RobotStatus> logList = [];

  StatusHistoryList.fromJson(Map<String, dynamic> json) {
    listCount = json['logListCount'] ?? 0;
    if (json['logList'] != null) {
      logList = (json['logList'] as List).map((i) => RobotStatus.fromJson(i)).toList();
    }
  }

  @override
  String toString() {
    return 'StatusHistoryList{listCount: $listCount, logList: $logList}';
  }
}

class RobotLogList {
  int? listCount;
  List<RobotLog> logList = [];

  RobotLogList.fromJson(Map<String, dynamic> json) {
    listCount = int.tryParse(json['logListCount'] ?? "0");
    if (json['logList'] != null && json['logList'].isNotEmpty) {
      logList = (json['logList'] as List).map((i) => RobotLog.fromJson(i)).toList();
    }
  }

  @override
  String toString() {
    return 'RobotLogList{listCount: $listCount, logList: $logList}';
  }
}

class RobotLog {
  int? id;
  String? createdTs;
  String? level;
  String? message;

  RobotLog({this.id, this.createdTs, this.level, this.message});

  RobotLog.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id']);
    createdTs = json['created_ts'] ?? "";
    level = (json['level'] == 0)
        ? "INFO"
        : (json['level'] == 1)
            ? "WARNING"
            : "ERROR";
    message = json['message'];
  }

  @override
  String toString() {
    return 'RobotLog{id: $id, createdTs: $createdTs, level: $level, message: $message}';
  }
}

class RobotState {
  static const int nonOperatingHour = -11; // 운영시간 아님
  static const int error = -1; // 오류

  static const int none = 0; // NONE
  static const int waiting = 1; // 사용가능상태

  static const int request = 11; // 호출요청
  static const int requestAnswer = 12; // 호출요청 응답

  static const int requestMove = 13; // 출발지로 이동중
  static const int requestArrive = 14; // 출발지 도착

  static const int requestCancel = 15; // 배차취소
  static const int cancelAnswer = 16; // 배차취소 응답 : 로봇 배정 전
  static const int cancelAnswerAfter = 17; // 배차취소 응답 : 로봇 배정 전

  static const int boarding = 31; // 탑승
  static const int boardingAnswer = 32; // 탑승 응답

  static const int destination = 33; // 이동요청
  static const int destinationAnswer = 34; // 이동

  static const int stop = 35; // 정지
  static const int stopAnswer = 36; // 정지응답

  static const int arrival = 37; // 도착

  static const int manualMode = 38; // 수동운전

  static const int returnRequest = 39; // 반납
  static const int returnAnswer = 40; // 반납중

  static const int promotionModeOn = 71; // 홍보모드 ON
  static const int promotionModeOff = 72; // 홍보모드 OFF

  static const int headLightOn = 91; // 라이트 ON
  static const int headLightOff = 92; // 라이트 OFF

  static const int onAutomotiveOff = 115; // 자율주행 OFF
  static const int onEmergencyStop = 117; // 비상정지

  static const int unknown = 999;
}

String getEventName(int state) {
  switch (state) {
    case RobotState.nonOperatingHour:
      return "nonOperatingHour[$state]";

    case RobotState.error:
      return "error[$state]";

    case RobotState.none:
      return "none[$state]";

    case RobotState.waiting:
      return "waiting[$state]";

    case RobotState.request:
      return "request[$state]";

    case RobotState.requestAnswer:
      return "requestAnswer[$state]";

    case RobotState.requestMove:
      return "requestMove[$state]";

    case RobotState.requestArrive:
      return "requestArrive[$state]";

    case RobotState.boarding:
      return "boarding[$state]";

    case RobotState.boardingAnswer:
      return "boardingAnswer[$state]";

    case RobotState.destination:
      return "destination[$state]";

    case RobotState.destinationAnswer:
      return "destinationAnswer[$state]";

    case RobotState.stop:
      return "stop[$state]";

    case RobotState.stopAnswer:
      return "stopAnswer[$state]";

    case RobotState.arrival:
      return "arrival[$state]";

    case RobotState.manualMode:
      return "manualMode[$state]";

    case RobotState.returnRequest:
      return "returnRequest[$state]";

    case RobotState.returnAnswer:
      return "returnAnswer[$state]";

    case RobotState.promotionModeOn:
      return "promotionModeOn[$state]";

    case RobotState.promotionModeOff:
      return "promotionModeOff[$state]";

    case RobotState.headLightOn:
      return "headLightOn[$state]";

    case RobotState.headLightOff:
      return "headLightOff[$state]";

    case RobotState.onAutomotiveOff:
      return "onAutomotiveOff[$state]";

    case RobotState.onEmergencyStop:
      return "onEmergencyStop[$state]";

    default:
      return "Unknown event[$state]";
  }
}
