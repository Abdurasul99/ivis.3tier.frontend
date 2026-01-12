// lib/viewmodel/controller/mqtt_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../constants/constants.dart';

class MqttIncomingMessage {
  final String topic;
  final String raw;
  final Map<String, dynamic>? json;
  MqttIncomingMessage(this.topic, this.raw, this.json);
}

class MqttController extends GetxController {
  MqttBrowserClient? _client;
  final _incoming = StreamController<MqttIncomingMessage>.broadcast();
  Stream<MqttIncomingMessage> get incomingMessagesStream => _incoming.stream;

  final _connected = false.obs;
  bool get isConnected => _connected.value;

  Timer? _reconnectTimer;
  int _retry = 0;
  bool _manualDisconnect = false;

  final List<String> _defaultTopics;
  final MqttQos _defaultQos;

  MqttController({
    List<String> defaultTopics = const ['#'],
    MqttQos defaultQos = MqttQos.atMostOnce,
  })  : _defaultTopics = defaultTopics,
        _defaultQos = defaultQos;

  Future<MqttClientConnectionStatus?> connect(String clientId) async {
    _manualDisconnect = false;
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      return _client!.connectionStatus;
    }

    _disposeClient();

    final c = MqttBrowserClient.withPort(kMqttServer, clientId, 9001);
    c.keepAlivePeriod = 30;
    c.logging(on: false);
    c.websocketProtocols = MqttClientConstants.protocolsMultipleDefault;
    c.autoReconnect = false;
    c.onConnected = _onConnected;
    c.onDisconnected = _onDisconnected;
    c.onSubscribed = (t) {};
    c.onSubscribeFail = (t) {};
    c.pongCallback = () {};

    c.clientIdentifier = clientId;
    c.connectionMessage =
        MqttConnectMessage().withClientIdentifier(clientId).startClean().withWillQos(MqttQos.atLeastOnce);

    _client = c;

    try {
      final status = await _client!.connect();
      if (_client!.updates != null) {
        _client!.updates!.listen(_onUpdate, onError: (e, s) {});
      }
      _subscribeDefaults();
      _retry = 0;
      return status;
    } catch (e) {
      _scheduleReconnect();
      return null;
    }
  }

  void _onConnected() {
    _connected.value = true;
  }

  void _onDisconnected() {
    _connected.value = false;
    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _onUpdate(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final evt in events) {
      final topic = evt.topic;
      final msg = evt.payload;
      if (msg is! MqttPublishMessage) continue;

      final bytes = msg.payload.message;
      final raw = utf8.decode(bytes, allowMalformed: true).trim();

      Map<String, dynamic>? jsonMap;
      if (raw.isNotEmpty) {
        try {
          final parsed = json.decode(raw);
          if (parsed is Map<String, dynamic>) jsonMap = parsed;
        } catch (_) {}
      }

      _incoming.add(MqttIncomingMessage(topic, raw, jsonMap));
    }
  }

  void _subscribeDefaults() {
    if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    for (final t in _defaultTopics) {
      try {
        _client!.subscribe(t, _defaultQos);
      } catch (e) {}
    }
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atMostOnce}) {
    if (!isConnected) {
      return;
    }
    try {
      _client!.subscribe(topic, qos);
    } catch (e) {}
  }

  void unsubscribe(String topic) {
    try {
      _client?.unsubscribe(topic);
    } catch (e) {}
  }

  bool publishString(String topic, String message, {MqttQos qos = MqttQos.atLeastOnce, bool retain = false}) {
    if (!isConnected) return false;
    try {
      final b = MqttClientPayloadBuilder()..addString(message);
      _client!.publishMessage(topic, qos, b.payload!, retain: retain);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool publishJson(String topic, Map<String, dynamic> jsonBody,
      {MqttQos qos = MqttQos.atLeastOnce, bool retain = false}) {
    return publishString(topic, json.encode(jsonBody), qos: qos, retain: retain);
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _connected.value = false;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final seconds = _nextBackoffSeconds();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_manualDisconnect) return;
      final id = _client?.clientIdentifier ?? 'fms-web';
      connect(id);
    });
  }

  int _nextBackoffSeconds() {
    _retry = (_retry + 1).clamp(1, 10);
    final base = _retry <= 4 ? (1 << (_retry - 1)) : (_retry <= 5 ? 15 : 30);
    return base;
  }

  void _disposeClient() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  @override
  void onClose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _incoming.close();
    _disposeClient();
    super.onClose();
  }
}
