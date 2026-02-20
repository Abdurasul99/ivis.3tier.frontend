import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_data.dart';

import '../../constants/constants.dart';

class MqttIncomingMessage {
  final String topic;
  final Uint8List? binaryPayload;
  final String? textPayload;

  MqttIncomingMessage({
    required this.topic,
    required this.binaryPayload,
    required this.textPayload,
  });
}

class WebSocketTarget {
  final String scheme;
  final String host;
  final int port;
  final String path;

  WebSocketTarget({
    required this.scheme,
    required this.host,
    required this.port,
    required this.path,
  });

  WebSocketTarget copyWith({
    String? scheme,
    String? host,
    int? port,
    String? path,
  }) {
    return WebSocketTarget(
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      port: port ?? this.port,
      path: path ?? this.path,
    );
  }

  String normalizedPath() {
    String value = path.trim();
    if (value.isEmpty) {
      return '/';
    }
    if (!value.startsWith('/')) {
      value = '/$value';
    }
    return value;
  }

  String normalizedScheme() {
    String value = scheme.trim().toLowerCase();
    if (value == 'ws' || value == 'wss') {
      return value;
    }
    return 'ws';
  }

  String buildServerUrlWithoutPort() {
    String finalScheme = normalizedScheme();
    String finalHost = host.trim().isEmpty ? 'localhost' : host.trim();
    String finalPath = normalizedPath();
    return '$finalScheme://$finalHost$finalPath';
  }
}

class MqttController extends GetxController {
  MqttBrowserClient? mqttClient;

  final RxString connectionState = 'disconnected'.obs;
  final RxString lastEvent = ''.obs;
  final RxInt receivedCount = 0.obs;

  final RxBool simulatorActive = false.obs;
  final RxInt simulatorRefreshIndex = 0.obs;

  StreamController<MqttIncomingMessage> incomingMessagesStreamController =
      StreamController<MqttIncomingMessage>.broadcast();

  Stream<MqttIncomingMessage> get incomingMessagesStream {
    return incomingMessagesStreamController.stream;
  }

  DateTime? lastMessageReceivedAt;
  Timer? simulatorActiveTimer;

  Future<void>? connectInFlight;
  bool subscribedAfterConnect = false;

  bool get isConnected {
    MqttBrowserClient? clientValue = mqttClient;
    if (clientValue == null) {
      return false;
    }
    MqttClientConnectionStatus? statusValue = clientValue.connectionStatus;
    if (statusValue == null) {
      return false;
    }
    return statusValue.state == MqttConnectionState.connected;
  }

  WebSocketTarget parseWebSocketTargetFromInput({
    required String inputValue,
    required int defaultPort,
    required String defaultPath,
  }) {
    String trimmedValue = inputValue.trim();

    if (trimmedValue.isEmpty) {
      return WebSocketTarget(
        scheme: 'ws',
        host: 'localhost',
        port: defaultPort,
        path: defaultPath,
      );
    }

    String schemeValue = 'ws';
    String remainder = trimmedValue;

    if (remainder.startsWith('ws://')) {
      schemeValue = 'ws';
      remainder = remainder.substring(5);
    } else if (remainder.startsWith('wss://')) {
      schemeValue = 'wss';
      remainder = remainder.substring(6);
    } else if (remainder.startsWith('http://')) {
      schemeValue = 'ws';
      remainder = remainder.substring(7);
    } else if (remainder.startsWith('https://')) {
      schemeValue = 'wss';
      remainder = remainder.substring(8);
    }

    String hostPart = remainder;
    String pathPart = '';

    int slashIndex = remainder.indexOf('/');
    if (slashIndex >= 0) {
      hostPart = remainder.substring(0, slashIndex);
      pathPart = remainder.substring(slashIndex);
    }

    String hostOnly = hostPart;
    int portValue = defaultPort;

    int lastColonIndex = hostPart.lastIndexOf(':');
    if (lastColonIndex >= 0) {
      String possiblePort = hostPart.substring(lastColonIndex + 1);
      int? parsedPortValue = int.tryParse(possiblePort);
      if (parsedPortValue != null) {
        hostOnly = hostPart.substring(0, lastColonIndex);
        portValue = parsedPortValue;
      }
    }

    if (hostOnly.trim().isEmpty) {
      hostOnly = 'localhost';
    }

    String finalPath = pathPart.trim();
    if (finalPath.isEmpty) {
      finalPath = defaultPath;
    }

    return WebSocketTarget(
      scheme: schemeValue,
      host: hostOnly,
      port: portValue,
      path: finalPath,
    );
  }

  List<WebSocketTarget> buildFallbackTargets(WebSocketTarget primaryTarget) {
    List<WebSocketTarget> targets = <WebSocketTarget>[primaryTarget];

    String normalizedPathValue = primaryTarget.normalizedPath();

    if (normalizedPathValue == '/mqtt') {
      targets.add(primaryTarget.copyWith(path: '/'));
    } else if (normalizedPathValue == '/') {
      targets.add(primaryTarget.copyWith(path: '/mqtt'));
    }

    return targets;
  }

  String chooseSchemeForBrowser(WebSocketTarget target) {
    String schemeValue = target.normalizedScheme();

    if (!kIsWeb) {
      return schemeValue;
    }

    if (Uri.base.scheme == 'https') {
      return 'wss';
    }

    return schemeValue;
  }

  void ensureSimulatorActiveTimer() {
    if (simulatorActiveTimer != null) {
      return;
    }

    simulatorActiveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        DateTime? lastTimeValue = lastMessageReceivedAt;
        if (lastTimeValue == null) {
          simulatorActive.value = false;
          return;
        }

        Duration gapValue = DateTime.now().difference(lastTimeValue);
        if (gapValue.inSeconds >= 3) {
          simulatorActive.value = false;
        }
      },
    );
  }

  void ensureStreamIsOpen() {
    if (!incomingMessagesStreamController.isClosed) {
      return;
    }
    incomingMessagesStreamController = StreamController<MqttIncomingMessage>.broadcast();
  }

  Future<MqttClientConnectionStatus?> connect(String clientIdentifier) async {
    if (connectInFlight != null) {
      await connectInFlight;
      return mqttClient?.connectionStatus;
    }

    Completer<void> completer = Completer<void>();
    connectInFlight = completer.future;

    try {
      ensureStreamIsOpen();
      subscribedAfterConnect = false;

      WebSocketTarget baseTarget = parseWebSocketTargetFromInput(
        inputValue: kMqttServer,
        defaultPort: 9001,
        defaultPath: '/mqtt',
      );

      List<WebSocketTarget> targetsToTry = buildFallbackTargets(baseTarget);

      for (int index = 0; index < targetsToTry.length; index += 1) {
        WebSocketTarget currentTarget = targetsToTry[index];

        try {
          disconnectInternal(resetStream: false);

          WebSocketTarget schemeAdjustedTarget = currentTarget.copyWith(
            scheme: chooseSchemeForBrowser(currentTarget),
          );

          String serverUrl = schemeAdjustedTarget.buildServerUrlWithoutPort();
          int portValue = schemeAdjustedTarget.port;

          MqttBrowserClient newClient = MqttBrowserClient.withPort(
            serverUrl,
            clientIdentifier,
            portValue,
          );

          newClient.logging(on: false);
          newClient.keepAlivePeriod = 30;
          newClient.autoReconnect = true;
          newClient.resubscribeOnAutoReconnect = true;

          newClient.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

          newClient.onConnected = () {
            connectionState.value = 'connected';
            lastEvent.value = 'onConnected';
            subscribedAfterConnect = false;
            subscribeToDefaultTopics();
          };

          newClient.onDisconnected = () {
            connectionState.value = 'disconnected';
            MqttClientConnectionStatus? statusValue = newClient.connectionStatus;
            lastEvent.value = 'onDisconnected state=${statusValue?.state} returnCode=${statusValue?.returnCode}';
          };

          newClient.onAutoReconnect = () {
            lastEvent.value = 'onAutoReconnect';
          };

          newClient.onAutoReconnected = () {
            lastEvent.value = 'onAutoReconnected';
            subscribedAfterConnect = false;
            subscribeToDefaultTopics();
          };

          newClient.onSubscribed = (String topicName) {
            lastEvent.value = 'onSubscribed topic=$topicName';
          };

          newClient.onSubscribeFail = (String topicName) {
            lastEvent.value = 'onSubscribeFail topic=$topicName';
          };

          newClient.onFailedConnectionAttempt = (int attemptNumber) {
            lastEvent.value = 'onFailedConnectionAttempt attempt=$attemptNumber';
          };

          newClient.pongCallback = () {};

          MqttConnectMessage connectMessage =
              MqttConnectMessage().withClientIdentifier(clientIdentifier).startClean().keepAliveFor(30);

          newClient.connectionMessage = connectMessage;

          mqttClient = newClient;

          MqttClientConnectionStatus? statusValue = await newClient.connect();

          connectionState.value = statusValue?.state.toString() ?? 'unknown';
          lastEvent.value = 'connect_result state=${statusValue?.state} returnCode=${statusValue?.returnCode}';

          if (isConnected) {
            ensureSimulatorActiveTimer();

            Stream<List<MqttReceivedMessage<MqttMessage>>>? updateStream = mqttClient?.updates;
            if (updateStream != null) {
              updateStream.listen(
                (List<MqttReceivedMessage<MqttMessage>> eventList) {
                  handleIncomingMessages(eventList);
                },
                onError: (Object errorValue) {
                  lastEvent.value = 'updates_error error=$errorValue';
                },
                cancelOnError: false,
              );
            }

            subscribeToDefaultTopics();

            completer.complete();
            return statusValue;
          }
        } catch (errorValue) {
          connectionState.value = 'error';
          lastEvent.value = 'connect_error error=$errorValue';
        }
      }

      completer.complete();
      return null;
    } finally {
      connectInFlight = null;
    }
  }

  void subscribeToDefaultTopics() {
    if (!isConnected) {
      return;
    }
    if (subscribedAfterConnect) {
      return;
    }
    subscribedAfterConnect = true;
    subscribe('#', qos: MqttQos.atMostOnce);
  }

  void subscribe(String topicFilter, {MqttQos qos = MqttQos.atMostOnce}) {
    if (!isConnected) {
      lastEvent.value = 'subscribe skipped not_connected topic=$topicFilter';
      return;
    }
    try {
      mqttClient?.subscribe(topicFilter, qos);
    } catch (errorValue) {
      lastEvent.value = 'subscribe error=$errorValue topic=$topicFilter';
    }
  }

  void unsubscribe(String topicFilter) {
    try {
      mqttClient?.unsubscribe(topicFilter);
    } catch (_) {}
  }

  String? tryDecodeUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  void handleIncomingMessages(List<MqttReceivedMessage<MqttMessage>> eventList) {
    ensureStreamIsOpen();

    for (int indexValue = 0; indexValue < eventList.length; indexValue += 1) {
      MqttReceivedMessage<MqttMessage> receivedMessage = eventList[indexValue];
      String topicName = receivedMessage.topic;

      MqttPublishMessage publishMessage = receivedMessage.payload as MqttPublishMessage;
      Uint8Buffer payloadBuffer = publishMessage.payload.message;
      Uint8List payloadBytes = Uint8List.fromList(payloadBuffer);

      receivedCount.value = receivedCount.value + 1;

      lastMessageReceivedAt = DateTime.now();
      simulatorActive.value = true;
      simulatorRefreshIndex.value = simulatorRefreshIndex.value + 1;

      String? decodedTextPayload = tryDecodeUtf8(payloadBytes);

      if (!incomingMessagesStreamController.isClosed) {
        incomingMessagesStreamController.add(
          MqttIncomingMessage(
            topic: topicName,
            binaryPayload: payloadBytes,
            textPayload: decodedTextPayload,
          ),
        );
      }
    }
  }

  bool publishBinary(
    String topicName,
    Uint8List payloadBytes, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) {
    if (!isConnected) {
      lastEvent.value = 'publishBinary skipped not_connected topic=$topicName';
      return false;
    }

    try {
      MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      Uint8Buffer bufferValue = Uint8Buffer();
      bufferValue.addAll(payloadBytes);
      builder.addBuffer(bufferValue);
      mqttClient?.publishMessage(topicName, qos, builder.payload!, retain: retain);
      return true;
    } catch (errorValue) {
      lastEvent.value = 'publishBinary error=$errorValue';
      return false;
    }
  }

  bool publishText(
    String topicName,
    String payloadText, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) {
    if (!isConnected) {
      lastEvent.value = 'publishText skipped not_connected topic=$topicName';
      return false;
    }

    try {
      MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      builder.addString(payloadText);
      mqttClient?.publishMessage(topicName, qos, builder.payload!, retain: retain);
      return true;
    } catch (errorValue) {
      lastEvent.value = 'publishText error=$errorValue';
      return false;
    }
  }

  void disconnectInternal({required bool resetStream}) {
    try {
      MqttBrowserClient? clientValue = mqttClient;
      if (clientValue != null) {
        clientValue.autoReconnect = false;
        clientValue.disconnect();
      }
    } catch (_) {}

    mqttClient = null;
    simulatorActive.value = false;
    connectionState.value = 'disconnected';
    subscribedAfterConnect = false;

    if (resetStream) {
      if (!incomingMessagesStreamController.isClosed) {
        incomingMessagesStreamController.close();
      }
      incomingMessagesStreamController = StreamController<MqttIncomingMessage>.broadcast();
    }
  }

  void disconnect() {
    disconnectInternal(resetStream: false);
  }

  @override
  void onClose() {
    simulatorActiveTimer?.cancel();
    simulatorActiveTimer = null;

    disconnectInternal(resetStream: true);

    super.onClose();
  }
}
