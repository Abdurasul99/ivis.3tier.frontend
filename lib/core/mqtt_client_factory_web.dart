// 웹(브라우저) 환경용 MQTT 클라이언트 팩토리
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// WebSocket 기반 MQTT 클라이언트 생성 (웹: MqttBrowserClient)
MqttClient createWebSocketMqttClient(
  String serverUrl,
  String clientIdentifier,
  int port,
) {
  return MqttBrowserClient.withPort(serverUrl, clientIdentifier, port);
}
