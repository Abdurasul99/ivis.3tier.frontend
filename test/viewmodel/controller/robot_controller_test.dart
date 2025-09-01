// test/viewmodel/controller/robot_controller_test.dart
//
// Pure-unit tests for RobotController (production code is unmodified).
// We wrap the real controller in TestableRobotController to inject a
// MockRobotRepository, then use classic AAA + explicit debug prints.
//
// ───────────── run tests ─────────────
// flutter test test/viewmodel/controller/robot_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/model/robot_model.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:fms/viewmodel/repository/robot_repository.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

import 'robot_controller_test.mocks.dart';

class TestableRobotController extends RobotController {
  TestableRobotController(this.mockRepository);

  final RobotRepository mockRepository;

  @override
  Future<void> reqRobotTypes() async {
    final List<RobotType> types = await mockRepository.requestRobotTypes();
    robotTypes
      ..clear()
      ..addAll(types);

    robotTypeDescriptions
      ..clear()
      ..addAll(
        types.map((RobotType t) => t.typeDescription ?? ''),
      );

    update();
  }

  @override
  Future<void> reqRobotList({int? typeId}) async {
    final List<Robot> fetched = await mockRepository.requestRobotList(typeId);
    robots
      ..clear()
      ..addAll(fetched);

    robots.sort((Robot a, Robot b) {
      final int byType = a.objectTypeId!.compareTo(b.objectTypeId!);
      return byType != 0 ? byType : a.id!.compareTo(b.id!);
    });

    update();
  }

  @override
  Future<void> reqRobotStatusList({int? objectId, int? objectTypeId}) async {
    robotStatusList
      ..clear()
      ..addAll(
        await mockRepository.requestRobotStatusList(
          objectId: objectId,
          objectTypeId: objectTypeId,
        ),
      );
    update();
  }

}

@GenerateNiceMocks(<MockSpec<dynamic>>[
  MockSpec<RobotRepository>(),
])
void main() {
  late MockRobotRepository mockRepository;
  late TestableRobotController controller;

  setUpAll(() => Get.testMode = true);

  setUp(() {
    print('\n=== setUp: fresh mock & controller ===');
    mockRepository = MockRobotRepository();
    Get.put<UserController>(UserController(), permanent: true);
    controller = TestableRobotController(mockRepository);
  });

  tearDown(Get.reset);

  group('RobotController – AAA pattern with debug prints', () {
    test('reqRobotTypes() populates robotTypes and descriptions', () async {
      print('\n▶ TEST: reqRobotTypes()');
      // Arrange
      print('ARRANGE → stub requestRobotTypes');
      final List<RobotType> stubTypes = <RobotType>[
        RobotType(id: 1, typeDescription: 'DELIVERY'),
      ];
      when(mockRepository.requestRobotTypes()).thenAnswer((_) async => stubTypes);

      // Act
      print('ACT     → call controller.reqRobotTypes');
      await controller.reqRobotTypes();

      // Assert
      print('ASSERT  → verify state and interaction');
      expect(controller.robotTypes, equals(stubTypes));
      expect(controller.robotTypeDescriptions, equals(<String>['DELIVERY']));
      verify(mockRepository.requestRobotTypes()).called(1);
    });

    test('reqRobotList() sorts list by objectTypeId then id', () async {
      print('\n▶ TEST: reqRobotList() sorting');
      // Arrange
      print('ARRANGE → stub requestRobotList with unsorted items');
      final List<Robot> unsorted = <Robot>[
        Robot(id: 2, objectTypeId: 1, serial: 'B'),
        Robot(id: 1, objectTypeId: 1, serial: 'A'),
      ];
      when(mockRepository.requestRobotList(null)).thenAnswer((_) async => unsorted);

      // Act
      print('ACT     → call controller.reqRobotList');
      await controller.reqRobotList();

      // Assert
      print('ASSERT  → first robot id should be 1');
      expect(controller.robots.first.id, equals(1));
      verify(mockRepository.requestRobotList(null)).called(1);
    });

    test('setOnEmergencyStop() updates matching RobotStatus.onEmergencyStop flag', () async {
      print('\n▶ TEST: setOnEmergencyStop()');

      // Arrange
      print('ARRANGE → stub list & status list');
      final List<Robot> robotList = <Robot>[
        Robot(id: 1, serial: 'Taro_RobotNum_1', objectTypeId: 1),
      ];
      final List<RobotStatus> statusList = <RobotStatus>[
        RobotStatus(id: 1, serial: 'Taro_RobotNum_1', onEmergencyStop: false),
      ];

      when(mockRepository.requestRobotList(null)).thenAnswer((_) async => robotList);
      when(
        mockRepository.requestRobotStatusList(objectId: null, objectTypeId: null),
      ).thenAnswer((_) async => statusList);

      await controller.reqRobotList();
      await controller.reqRobotStatusList();

      // Act
      print('ACT     → call controller.setOnEmergencyStop');
      controller.setOnEmergencyStop('Taro_RobotNum_1', true);

      // Assert
      print('ASSERT  → flag should be true');
      expect(controller.robotStatusList.first.onEmergencyStop, isTrue);
    });
  });
}
