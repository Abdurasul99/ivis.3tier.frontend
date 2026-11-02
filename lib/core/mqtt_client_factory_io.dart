// 비웹(Dart VM) 환경용 MQTT 클라이언트 팩토리
// 테스트(Dart VM)에서 mqtt_controller.dart가 컴파일되도록 MqttServerClient 사용
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// WebSocket 기반 MQTT 클라이언트 생성 (VM: MqttServerClient + useWebSocket)
MqttClient createWebSocketMqttClient(
  String serverUrl,
  String clientIdentifier,
  int port,
) {
  final MqttServerClient client =
      MqttServerClient.withPort(serverUrl, clientIdentifier, port);
  client.useWebSocket = true;
  return client;
}
