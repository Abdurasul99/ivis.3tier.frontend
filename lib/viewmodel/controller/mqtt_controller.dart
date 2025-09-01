import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';

class MqttController extends GetxController {
  MqttBrowserClient? _client;

  get client => _client;

  ///////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  bool isConnected() {
    return _client != null && _client!.connectionStatus!.state == MqttConnectionState.connected;
  }

  Future<MqttClientConnectionStatus?> connect(String clientId) async {
    try {
      _client = MqttBrowserClient.withPort(kMqttServer, clientId, 9001)
        ..keepAlivePeriod = 30
        ..onDisconnected = () {
          debugPrint("[MQTT] onDisconnected");
        }
        ..onConnected = () {
          debugPrint("[MQTT] onConnected");
        }
        ..onSubscribed = (String data) {
          debugPrint("[MQTT] data : $data");
        }
        ..pongCallback = () {
          debugPrint("[MQTT] pongCallback");
        };

      MqttClientConnectionStatus? status = await _client!.connect();
      debugPrint("[MQTT] connect() status $status");

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> event) {
        onMessage(event);
      });

      subscribeTopic();

      return status;
    } on Exception catch (e) {
      debugPrint('[MQTT] connect() client exception - $e');
      return null;
    }
  }

  Future<void> onMessage(List<MqttReceivedMessage<MqttMessage>> event) async {
    for (int i = 0; i < event.length; i++) {
      parseMessage(event[i]);
    }
  }

  void parseMessage(MqttReceivedMessage<MqttMessage> event) {
    String topic = event.topic.toString();
    debugPrint("parseMessage() topic : $topic");

    MqttPublishMessage msg = event.payload as MqttPublishMessage;
    String receivedValue = utf8.decode(msg.payload.message);
    debugPrint("parseMessage() receivedValue : $receivedValue");

    Map<String, dynamic> payload;
    try {
      payload = json.decode(receivedValue);
    } catch (e) {
      debugPrint("parseMessage() JSON 파싱 오류: $e");
      return;
    }

    if (topic.contains("controller_")) {
      if (payload['move_res'] != null) {
        Get.find<RobotController>().setOnMoveRes(topic, payload['move_res']);
      } else if (payload['car_battery_res'] != null) {
        Get.find<RobotController>().setOnCarBatteryRes(topic, payload['car_battery_res']);
      } else {
        String tag = payload['tag'];
        switch (tag) {
          case "on_emergency_stop":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnEmergencyStop(topic, isOn);
            break;

          case "on_auto_pilot":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnAutoPilot(topic, isOn);
            break;

          case "on_head_light":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnHeadLight(topic, isOn);
            break;

          case "on_returning":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnReturning(topic, isOn);
            break;

          case "open_refrig_door":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenRefrigDoor(topic, isOn);
            break;

          case "interior_door":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenInnerDoor(topic, isOn);
            break;

          case "interior_lamp":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnInnerLight(topic, isOn);
            break;

          case "interior_display":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOnOutsideDisplay(topic, isOn);
            break;

          case "open_delivery_box_01":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenDeliveryBox01(topic, isOn);
            break;

          case "open_delivery_box_02":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenDeliveryBox02(topic, isOn);
            break;

          case "open_delivery_box_03":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenDeliveryBox03(topic, isOn);
            break;

          case "open_delivery_box_04":
            bool isOn = (payload['data']['message'] == "ready");
            Get.find<RobotController>().setOpenDeliveryBox04(topic, isOn);
            break;

          case "open_delivery_box":
            String message = (payload['data']['message']).toString();
            Get.find<RobotController>().setOpenDeliveryBox(topic, message);
            break;

          case "address_update":
            String address = (payload['data']['address']).toString();
            Get.find<RobotController>().setUpdateAddress(topic, address);
            break;

          default:
            break;
        }
      }
    } else {
      if (topic.startsWith("UserApp_Pub")) {
        onTaroMessageUserApp(payload);
      } else if (topic == "Info_Display_Pub") {
        onTaroMessageDisplayApp(payload);
      } else if (topic.startsWith("MainPage_Pub/")) {
        onTaroMessageMainPagePub(payload);
      } else if (topic == "MainPage_Sub") {
        Get.find<RobotController>().onTaroMessageMainPageSub(payload);
      }
    }
  }

  void publishMessage(String topic, String message) {
    try {
      final builder1 = MqttClientPayloadBuilder();

      builder1.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder1.payload!);
    } on Exception catch (e) {
      debugPrint('[MQTT] publishMessage() client exception - $e');
    }
  }

  void subscribeTopic() {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.subscribe("#", MqttQos.atMostOnce);
    } else {
      debugPrint("[MQTT] subscribeTopic() fail, client is null or state ${_client!.connectionStatus!.state}");
    }
  }

  void unSubscribeTopic() {
    if (_client != null) {
      _client!.unsubscribe("#");
    } else {
      debugPrint("[MQTT] subscribeTopic() fail, client is null");
    }
  }

  void disconnect() {
    if (_client != null) {
      debugPrint("[MQTT] disconnect()");
      _client!.disconnect();
    } else {
      debugPrint("[MQTT] subscribeTopic() fail, client is null");
    }
  }

  void onTaroMessageUserApp(Map<String, dynamic> params) {
    int? statusCode = int.tryParse(params['Data']['Status'].toString());
    int? robotNumber = int.tryParse(params['Data']['Robot_Num'].toString());

    if (statusCode == null || robotNumber == null) {
      debugPrint("[Broker -> UserApp] statusCode $statusCode, robotNumber $robotNumber, null");
      return;
    }

    debugPrint("[Broker -> UserApp] statusCode ${getEventName(statusCode)}, robotNumber $robotNumber");

    Get.find<RobotController>().updateTaroState(robotNumber, statusCode);

    switch (statusCode) {
      case RobotState.requestMove: // 출발
        // Utils.showSnackBar("Taro_Robot$robotNumber이 출발하였습니다.");
        break;

      case RobotState.requestArrive: // 도착
        // Utils.showSnackBar("Taro_Robot$robotNumber이 도착하였습니다.");
        break;

      case RobotState.cancelAnswer: // 배차취소 응답 : 로봇 배정 전
      case RobotState.cancelAnswerAfter: // 배차취소(15) 응답 : 로봇 배정 후
        // Utils.showSnackBar("Taro_Robot$robotNumber의 호출이 취소되었습니다.");
        break;

      case RobotState.arrival: // 도착
        List<Robot> robotList = Get.find<RobotController>().robots;
        int robotId = robotList.where((element) => element.serial == robotNumber.toString()).first.id!;
        Get.find<GraphController>().reqRemoveChartItems(robotId);
        break;

      default:
        break;
    }
  }

  void onTaroMessageDisplayApp(Map<String, dynamic> params) {
    int? statusCode = int.tryParse(params['Status'].toString());
    int? robotNumber = int.tryParse(params['Robot_Num'].toString());

    if (statusCode == null || robotNumber == null) {
      debugPrint("[Broker -> InfoApp] statusCode $statusCode, robotNumber $robotNumber, null");
      return;
    }

    debugPrint("[Broker -> InfoApp] statusCode ${getEventName(statusCode)}, robotNumber $robotNumber");

    Get.find<RobotController>().updateTaroState(robotNumber, statusCode);
  }

  void onTaroMessageMainPagePub(Map<String, dynamic> params) {
    int? statusCode = int.tryParse(params['Data']['RobotStatus'].toString());
    int? robotNumber = int.tryParse(params['Data']['Robot_Num'].toString());

    if (statusCode == null || robotNumber == null) {
      debugPrint("[Broker -> Taro] statusCode $statusCode, robotNumber $robotNumber, null");
      return;
    }

    debugPrint("[Broker -> Taro] statusCode ${getEventName(statusCode)}, robotNumber $robotNumber");

    switch (statusCode) {
      case RobotState.headLightOn:
        Get.find<RobotController>().setOnHeadLight(robotNumber.toString(), true);
        update();
        break;

      case RobotState.headLightOff:
        Get.find<RobotController>().setOnHeadLight(robotNumber.toString(), false);
        update();
        break;

      case RobotState.promotionModeOn:
        Get.find<RobotController>().setOnPromotionMode(robotNumber.toString(), true);
        break;

      case RobotState.promotionModeOff:
        Get.find<RobotController>().setOnPromotionMode(robotNumber.toString(), false);
        break;

      default:
        break;
    }
  }
}
