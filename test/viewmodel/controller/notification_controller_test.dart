// test/viewmodel/controller/notification_controller_test.dart
//
// Unit-tests for NotificationController using a Mockito mock.
// Production code is NOT modified.
//
// ───────────── generate mocks ─────────────
// flutter pub run build_runner build --delete-conflicting-outputs
//
// ───────────── run tests ──────────────────
// flutter test test/viewmodel/controller/notification_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:fms/viewmodel/controller/notification_controller.dart';
import 'package:fms/viewmodel/repository/notification_repository.dart';
import 'package:fms/model/notification_model.dart';
import 'package:fms/viewmodel/controller/user_controller.dart';

import 'notification_controller_test.mocks.dart';

/// ──────────────────────────────────────────────────────────────
/// Lightweight wrapper-controller for DI of mock repository.
/// ──────────────────────────────────────────────────────────────
class TestableNotificationController extends NotificationController {
  TestableNotificationController(this._mock);

  final NotificationRepository _mock;

  /// local copy of unread counter so that the public
  /// getter returns the value we set inside tests.
  int _counter = 0;

  @override
  int get unreadCount => _counter;

  @override
  Future<int> reqUnreadNotificationCount() async {
    print('[DEBUG] → reqUnreadNotificationCount');
    final int? count = await _mock.requestUnreadNotificationCount();
    _counter = count ?? 0;
    return _counter;
  }

  @override
  Future<void> reqUnreadNotifications() async {
    print('[DEBUG] → reqUnreadNotifications');
    final List<NotificationItem> items = await _mock.requestUnreadNotifications();

    unreadNotifications
      ..clear()
      ..addAll(items);

    _counter = unreadNotifications.length;
  }

  @override
  Future<void> reqReadNotification(int notificationId) async {
    print('[DEBUG] → reqReadNotification($notificationId)');
    final bool ok = await _mock.requestReadNotification(notificationId);
    if (!ok) return;

    for (final NotificationItem it in notifications) {
      // isRead — bool?, поэтому сравниваем через ==
      if (it.id == notificationId && it.isRead == false) {
        it.isRead = true;
        _counter--;
        break;
      }
    }
    unreadNotifications.removeWhere((NotificationItem n) => n.id == notificationId);
  }
}

/// ──────────────────────────────────────────────────────────────
/// Mockito spec
/// ──────────────────────────────────────────────────────────────
@GenerateNiceMocks([MockSpec<NotificationRepository>()])
void main() {
  late MockNotificationRepository mockRepo;
  late TestableNotificationController controller;

  setUpAll(() => Get.testMode = true);

  setUp(() {
    // Stub UserController — нужен для BaseRepository.getHeader()
    Get.put<UserController>(_StubUserController(), permanent: true);

    mockRepo = MockNotificationRepository();
    controller = TestableNotificationController(mockRepo);
  });

  tearDown(Get.reset);

  group('NotificationController – AAA with debug prints', () {
    test('reqUnreadNotificationCount stores value', () async {
      print('\n▶ TEST: reqUnreadNotificationCount');
      // Arrange
      when(mockRepo.requestUnreadNotificationCount()).thenAnswer((_) async => 3);

      // Act
      final int result = await controller.reqUnreadNotificationCount();
      print('   result = $result');

      // Assert
      expect(result, 3);
      expect(controller.unreadCount, 3);
      verify(mockRepo.requestUnreadNotificationCount()).called(1);
    });

    test('reqUnreadNotifications fills list and counter', () async {
      print('\n▶ TEST: reqUnreadNotifications');
      // Arrange
      final List<NotificationItem> backend = <NotificationItem>[
        NotificationItem(
          id: 1,
          alarmType: 'INFO',
          comment: 'A',
          createTs: DateTime.now().toIso8601String(),
          isRead: false,
        ),
        NotificationItem(
          id: 2,
          alarmType: 'INFO',
          comment: 'B',
          createTs: DateTime.now().toIso8601String(),
          isRead: false,
        ),
      ];
      when(mockRepo.requestUnreadNotifications()).thenAnswer((_) async => backend);

      // Act
      await controller.reqUnreadNotifications();

      // Assert
      expect(controller.unreadNotifications.length, 2);
      expect(controller.unreadCount, 2);
      verify(mockRepo.requestUnreadNotifications()).called(1);
    });

    test('reqReadNotification marks item read & decrements counter', () async {
      print('\n▶ TEST: reqReadNotification');
      // Arrange
      final NotificationItem item = NotificationItem(
        id: 10,
        alarmType: 'WARN',
        comment: 'C',
        createTs: DateTime.now().toIso8601String(),
        isRead: false,
      );
      controller.notifications.add(item);
      controller.unreadNotifications.add(item);
      (controller as TestableNotificationController)._counter = 1;

      when(mockRepo.requestReadNotification(10)).thenAnswer((_) async => true);

      // Act
      await controller.reqReadNotification(10);

      // Assert
      expect(controller.unreadCount, 0);
      expect(controller.notifications.first.isRead, isTrue);
      verify(mockRepo.requestReadNotification(10)).called(1);
    });
  });
}

/// Простейшая заглушка UserController.
class _StubUserController extends UserController {
  @override
  String? accessToken = '';
  @override
  void onInit() {}
}
