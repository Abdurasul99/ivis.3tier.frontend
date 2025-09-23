import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../constants/constants.dart';

class MqttController extends GetxController {
  MqttBrowserClient? _client;

  get client => _client;

  bool isConnected() {
    return _client != null &&
        _client!.connectionStatus != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected;
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
          debugPrint("[MQTT] subscribed : $data");
        }
        ..pongCallback = () {
          debugPrint("[MQTT] pongCallback");
        };

      final status = await _client!.connect();
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
    final topic = event.topic.toString();
    final msg = event.payload as MqttPublishMessage;
    final receivedValue = utf8.decode(msg.payload.message);

    Map<String, dynamic> payload;
    try {
      payload = json.decode(receivedValue);
    } catch (e) {
      return;
    }

    if (topic.contains("controller_")) {
      if (payload['move_res'] != null) {
        Get.find<RobotController>().setOnMoveRes(topic, payload['move_res']);
      } else if (payload['car_battery_res'] != null) {
        Get.find<RobotController>().setOnCarBatteryRes(topic, payload['car_battery_res']);
      } else {
        final tag = payload['tag'];
        switch (tag) {
          case "on_emergency_stop":
            Get.find<RobotController>().setOnEmergencyStop(topic, payload['data']['message'] == "ready");
            break;
          case "on_auto_pilot":
            Get.find<RobotController>().setOnAutoPilot(topic, payload['data']['message'] == "ready");
            break;
          case "on_head_light":
            Get.find<RobotController>().setOnHeadLight(topic, payload['data']['message'] == "ready");
            break;
          case "on_returning":
            Get.find<RobotController>().setOnReturning(topic, payload['data']['message'] == "ready");
            break;
          case "open_refrig_door":
            Get.find<RobotController>().setOpenRefrigDoor(topic, payload['data']['message'] == "ready");
            break;
          case "interior_door":
            Get.find<RobotController>().setOpenInnerDoor(topic, payload['data']['message'] == "ready");
            break;
          case "interior_lamp":
            Get.find<RobotController>().setOnInnerLight(topic, payload['data']['message'] == "ready");
            break;
          case "interior_display":
            Get.find<RobotController>().setOnOutsideDisplay(topic, payload['data']['message'] == "ready");
            break;
          case "open_delivery_box_01":
            Get.find<RobotController>().setOpenDeliveryBox01(topic, payload['data']['message'] == "ready");
            break;
          case "open_delivery_box_02":
            Get.find<RobotController>().setOpenDeliveryBox02(topic, payload['data']['message'] == "ready");
            break;
          case "open_delivery_box_03":
            Get.find<RobotController>().setOpenDeliveryBox03(topic, payload['data']['message'] == "ready");
            break;
          case "open_delivery_box_04":
            Get.find<RobotController>().setOpenDeliveryBox04(topic, payload['data']['message'] == "ready");
            break;
          case "open_delivery_box":
            Get.find<RobotController>().setOpenDeliveryBox(topic, (payload['data']['message']).toString());
            break;
          case "address_update":
            Get.find<RobotController>().setUpdateAddress(topic, (payload['data']['address']).toString());
            break;
          default:
            break;
        }
      }
    }
  }

  void publishMessage(String topic, String message) {
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } on Exception catch (e) {
      debugPrint('[MQTT] publishMessage() client exception - $e');
    }
  }

  void subscribeTopic() {
    if (_client != null &&
        _client!.connectionStatus != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.subscribe("#", MqttQos.atMostOnce);
    } else {
      debugPrint("[MQTT] subscribeTopic() fail: client is null or not connected");
    }
  }

  void unSubscribeTopic() {
    if (_client != null) {
      _client!.unsubscribe("#");
    }
  }

  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
    }
  }
}
