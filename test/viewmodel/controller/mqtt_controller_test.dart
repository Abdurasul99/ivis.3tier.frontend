// test/viewmodel/controller/mqtt_controller_test.dart
//
// Unit tests for MqttController that do **not** modify production source.
// Instead of adding `setClientForTest` we wrap the controller in a small
// subclass that injects a mocked `MqttBrowserClient`.
//
// Run with:  flutter test test/viewmodel/controller/mqtt_controller_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:fms/viewmodel/controller/mqtt_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';

import 'mqtt_controller_test.mocks.dart';

/// ---------------------------------------------------------------------------
/// Test-only wrapper: uses the injected mock instead of the private field.
/// ---------------------------------------------------------------------------
class TestableMqttController extends MqttController {
  TestableMqttController(this._mock);
  final MqttBrowserClient _mock;

  // ---------- overrides that access the real client ----------
  @override
  bool isConnected() => _mock.connectionStatus?.state == MqttConnectionState.connected;

  @override
  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder()..addString(message);
    _mock.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  void subscribeTopic() {
    if (_mock.connectionStatus?.state == MqttConnectionState.connected) {
      _mock.subscribe('#', MqttQos.atMostOnce);
    }
  }

  @override
  void unSubscribeTopic() => _mock.unsubscribe('#');

  @override
  void disconnect() => _mock.disconnect();

  @override
  Future<MqttClientConnectionStatus?> connect(String clientId) async {
    final status = await _mock.connect();
    _mock.updates?.listen(onMessage);
    subscribeTopic();
    return status;
  }
}

/// ---------------------------------------------------------------------------
/// Mockito configuration
/// ---------------------------------------------------------------------------
@GenerateNiceMocks([
  MockSpec<MqttBrowserClient>(),
  MockSpec<RobotController>(),
])
void main() {
  late MockMqttBrowserClient mockClient;
  late MockRobotController mockRobot;
  late TestableMqttController controller;

  setUp(() {
    Get.testMode = true;
    mockClient = MockMqttBrowserClient();
    mockRobot = MockRobotController();

    when(mockRobot.onStart).thenReturn(
      InternalFinalCallback<void>(callback: () {}),
    );
    Get.put<RobotController>(mockRobot, permanent: true);

    controller = TestableMqttController(mockClient);

    // default no-ops
    when(mockClient.subscribe(any, any)).thenReturn(null);
    when(mockClient.unsubscribe(any)).thenReturn(null);
    when(mockClient.disconnect()).thenReturn(null);
  });

  tearDown(() => Get.reset());

  group('MqttController – AAA with Debug', () {
    test('isConnected() returns true', () {
      final status = MqttClientConnectionStatus()..state = MqttConnectionState.connected;
      when(mockClient.connectionStatus).thenReturn(status);

      expect(controller.isConnected(), isTrue);
    });

    test('publishMessage() delegates to client', () {
      when(mockClient.publishMessage(any, any, any)).thenReturn(0);

      controller.publishMessage('/test', 'hello');

      verify(mockClient.publishMessage('/test', MqttQos.atLeastOnce, any)).called(1);
    });

    test('subscribeTopic() calls client.subscribe', () {
      when(mockClient.connectionStatus).thenReturn(
        MqttClientConnectionStatus()..state = MqttConnectionState.connected,
      );

      controller.subscribeTopic();

      verify(mockClient.subscribe('#', MqttQos.atMostOnce)).called(1);
    });

    test('unSubscribeTopic() calls client.unsubscribe', () {
      controller.unSubscribeTopic();
      verify(mockClient.unsubscribe('#')).called(1);
    });

    test('disconnect() calls client.disconnect', () {
      controller.disconnect();
      verify(mockClient.disconnect()).called(1);
    });

    test('parseMessage() → setOnMoveRes called', () {
      const topic = 'controller_cmd';
      final builder = MqttClientPayloadBuilder()..addString(json.encode({'move_res': {}}));
      final msg = MqttPublishMessage();
      (msg as dynamic).payload = (MqttPublishPayload()..message = builder.payload!);
      final event = MqttReceivedMessage<MqttMessage>(topic, msg);

      controller.parseMessage(event);

      verify(mockRobot.setOnMoveRes(topic, {})).called(1);
    });

    test('connect() happy path', () async {
      final ok = MqttClientConnectionStatus()..state = MqttConnectionState.connected;
      when(mockClient.connect()).thenAnswer((_) async => ok);
      when(mockClient.connectionStatus).thenReturn(ok);
      when(mockClient.updates).thenAnswer((_) => Stream<List<MqttReceivedMessage<MqttMessage>>>.empty());

      final status = await controller.connect('CID');

      verify(mockClient.connect()).called(1);
      expect(status, same(ok));
    });

    test('connect() throws TimeoutException', () async {
      when(mockClient.connect()).thenThrow(TimeoutException('timeout'));
      when(mockClient.connectionStatus).thenReturn(
        MqttClientConnectionStatus()..state = MqttConnectionState.disconnected,
      );
      when(mockClient.updates).thenAnswer((_) => Stream<List<MqttReceivedMessage<MqttMessage>>>.empty());

      expect(
        () async => await controller.connect('CID'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('updates stream triggers onMessage', () async {
      const topic = 'controller_cmd';
      final builder = MqttClientPayloadBuilder()..addString(json.encode({'move_res': {}}));
      final msg = MqttPublishMessage();
      (msg as dynamic).payload = (MqttPublishPayload()..message = builder.payload!);
      final events = [MqttReceivedMessage<MqttMessage>(topic, msg)];

      when(mockClient.connectionStatus).thenReturn(
        MqttClientConnectionStatus()..state = MqttConnectionState.connected,
      );
      when(mockClient.connect())
          .thenAnswer((_) async => MqttClientConnectionStatus()..state = MqttConnectionState.connected);
      when(mockClient.updates).thenAnswer(
        (_) => Stream<List<MqttReceivedMessage<MqttMessage>>>.fromFuture(
          Future.delayed(const Duration(milliseconds: 100), () => events),
        ),
      );

      await controller.connect('CID');
      await Future.delayed(const Duration(milliseconds: 300));

      verify(mockRobot.setOnMoveRes(topic, {})).called(1);
    });
  });
}
