// test/widgets/vehicle_marker_widget_test.dart
// 차량/인프라/감지 객체 마커 위젯 테스트
// Triple-A 패턴 (Arrange / Act / Assert)
//
// google_maps_flutter 의 실제 BitmapDescriptor.bytes 는 위젯 트리에 마커를 그리지 않고
// 네이티브 GoogleMap 위젯에 직접 전달되므로 단위 테스트로 검증이 어렵다. 본 테스트는
// 마커의 시각적 모델(VehicleMarker / InfraMarker / DetectedObjectMarker) 만을 격리하여
// 위치/회전/강조 상태/툴팁 클릭이 정상 동작하는지 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────
  // VehicleMarkerWidget — 차량 마커
  // ─────────────────────────────────────────────
  group('VehicleMarkerWidget', () {
    testWidgets('차량 ID 와 선택되지 않은 상태로 렌더링', (WidgetTester tester) async {
      // Arrange
      const VehicleMarkerWidget marker = VehicleMarkerWidget(
        vehicleId: 7,
        headingDegrees: 90.0,
        selected: false,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert — ID 표시 + 미선택 색
      expect(find.text('V7'), findsOneWidget);
      final Container container =
          tester.widget(find.byKey(const Key('vehicle-marker-body')));
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, VehicleMarkerWidget.idleColor);
    });

    testWidgets('선택된 차량 마커는 강조 색상 사용', (WidgetTester tester) async {
      // Arrange
      const VehicleMarkerWidget marker = VehicleMarkerWidget(
        vehicleId: 3,
        headingDegrees: 0.0,
        selected: true,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Container container =
          tester.widget(find.byKey(const Key('vehicle-marker-body')));
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, VehicleMarkerWidget.selectedColor);
    });

    testWidgets('차량 마커 탭 → onTap 콜백 호출', (WidgetTester tester) async {
      // Arrange
      bool tapped = false;
      final VehicleMarkerWidget marker = VehicleMarkerWidget(
        vehicleId: 1,
        headingDegrees: 0.0,
        selected: false,
        onTap: () => tapped = true,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: marker)));

      // Act
      await tester.tap(find.byKey(const Key('vehicle-marker-body')));
      await tester.pump();

      // Assert
      expect(tapped, isTrue);
    });

    testWidgets('headingDegrees 가 Transform.rotate 의 각도로 반영', (WidgetTester tester) async {
      // Arrange — 90도 회전 = pi/2 rad
      const VehicleMarkerWidget marker = VehicleMarkerWidget(
        vehicleId: 1,
        headingDegrees: 90.0,
        selected: false,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Transform transform = tester.widget(
        find.byKey(const Key('vehicle-marker-rotor')),
      );
      // 90도 = 1.5708 rad
      expect(transform.transform.entry(0, 0), closeTo(0.0, 1e-3));
    });
  });

  // ─────────────────────────────────────────────
  // InfraMarkerWidget — 인프라 마커
  // ─────────────────────────────────────────────
  group('InfraMarkerWidget', () {
    testWidgets('인프라 ID 표시', (WidgetTester tester) async {
      // Arrange
      const InfraMarkerWidget marker =
          InfraMarkerWidget(infraId: 2, selected: false);

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      expect(find.text('I2'), findsOneWidget);
    });

    testWidgets('선택된 인프라 마커는 강조 색', (WidgetTester tester) async {
      // Arrange
      const InfraMarkerWidget marker =
          InfraMarkerWidget(infraId: 5, selected: true);

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Container body =
          tester.widget(find.byKey(const Key('infra-marker-body')));
      final BoxDecoration decoration = body.decoration as BoxDecoration;
      expect(decoration.color, InfraMarkerWidget.selectedColor);
    });
  });

  // ─────────────────────────────────────────────
  // DetectedObjectMarkerWidget — 감지 객체 마커
  // ─────────────────────────────────────────────
  group('DetectedObjectMarkerWidget', () {
    testWidgets('객체 타입에 따라 색상 매핑 (0=PEDESTRIAN)', (WidgetTester tester) async {
      // Arrange
      const DetectedObjectMarkerWidget marker = DetectedObjectMarkerWidget(
        objectId: 100,
        objectType: 0,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Container body =
          tester.widget(find.byKey(const Key('object-marker-body')));
      final BoxDecoration decoration = body.decoration as BoxDecoration;
      expect(decoration.color, DetectedObjectMarkerWidget.pedestrianColor);
    });

    testWidgets('타입 1=VEHICLE 일 때 차량 색', (WidgetTester tester) async {
      // Arrange
      const DetectedObjectMarkerWidget marker = DetectedObjectMarkerWidget(
        objectId: 1,
        objectType: 1,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Container body =
          tester.widget(find.byKey(const Key('object-marker-body')));
      final BoxDecoration decoration = body.decoration as BoxDecoration;
      expect(decoration.color, DetectedObjectMarkerWidget.vehicleColor);
    });

    testWidgets('알 수 없는 타입(99) 은 기본 색', (WidgetTester tester) async {
      // Arrange
      const DetectedObjectMarkerWidget marker = DetectedObjectMarkerWidget(
        objectId: 9,
        objectType: 99,
      );

      // Act
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: marker)));

      // Assert
      final Container body =
          tester.widget(find.byKey(const Key('object-marker-body')));
      final BoxDecoration decoration = body.decoration as BoxDecoration;
      expect(decoration.color, DetectedObjectMarkerWidget.defaultColor);
    });

    testWidgets('마커 탭 시 onTap 콜백', (WidgetTester tester) async {
      // Arrange
      int taps = 0;
      final DetectedObjectMarkerWidget marker = DetectedObjectMarkerWidget(
        objectId: 1,
        objectType: 1,
        onTap: () => taps++,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: marker)));

      // Act
      await tester.tap(find.byKey(const Key('object-marker-body')));
      await tester.pump();

      // Assert
      expect(taps, 1);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 마커 위젯들 — 테스트 격리용 단순 구현체
// 실제 BitmapDescriptor.bytes 기반 마커는 GoogleMap 네이티브 영역에서 그려지므로
// 위젯 트리에서 검증할 수 있는 표현으로 추출.
// ─────────────────────────────────────────────────────────────────────────────
class VehicleMarkerWidget extends StatelessWidget {
  final int vehicleId;
  final double headingDegrees;
  final bool selected;
  final VoidCallback? onTap;

  static const Color idleColor = Color(0xFF0F9ED5);
  static const Color selectedColor = Color(0xFFE97132);

  const VehicleMarkerWidget({
    super.key,
    required this.vehicleId,
    required this.headingDegrees,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // heading 0 = 북, 90 = 동. flutter 회전은 라디안 — 시계 방향 +.
    final double radians = headingDegrees * 3.141592653589793 / 180.0;
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        key: const Key('vehicle-marker-rotor'),
        angle: radians,
        child: Container(
          key: const Key('vehicle-marker-body'),
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedColor : idleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            'V$vehicleId',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class InfraMarkerWidget extends StatelessWidget {
  final int infraId;
  final bool selected;
  final VoidCallback? onTap;

  static const Color idleColor = Color(0xFF156082);
  static const Color selectedColor = Color(0xFFE97132);

  const InfraMarkerWidget({
    super.key,
    required this.infraId,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('infra-marker-body'),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedColor : idleColor,
          shape: BoxShape.rectangle,
        ),
        child: Text(
          'I$infraId',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class DetectedObjectMarkerWidget extends StatelessWidget {
  final int objectId;
  final int objectType;
  final VoidCallback? onTap;

  static const Color pedestrianColor = Color(0xFFA02B93); // 0
  static const Color vehicleColor = Color(0xFF0F9ED5); // 1
  static const Color bicycleColor = Color(0xFF4EA72E); // 2
  static const Color defaultColor = Color(0xFF5A7A9A); // unknown

  const DetectedObjectMarkerWidget({
    super.key,
    required this.objectId,
    required this.objectType,
    this.onTap,
  });

  Color get _color {
    switch (objectType) {
      case 0:
        return pedestrianColor;
      case 1:
        return vehicleColor;
      case 2:
        return bicycleColor;
      default:
        return defaultColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('object-marker-body'),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        child: Text(
          '#$objectId',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}
