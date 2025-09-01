import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/notification_model.dart';
import '../../view/components/page_nation_view.dart';
import '../repository/notification_repository.dart';

class NotificationController extends GetxController {
  bool _isLoading = false;
  int _settingTabIndex = 0;
  List<NotificationItem> _notifications = [];
  int _totalCount = 0;
  int _viewPage = 0;
  int _maxPage = 0;
  String? _startDate = "";
  String? _endDate = "";

  List<NotificationItem> _unreadNotifications = [];
  int _unreadCount = 0;

  bool _notificationDialogOpen = false;

  bool get isLoading => _isLoading;
  int get settingTabIndex => _settingTabIndex;
  List<NotificationItem> get notifications => _notifications;
  int get totalCount => _totalCount;
  int get viewPage => _viewPage;
  int get maxPage => _maxPage;
  String? get startDate => _startDate;
  String? get endDate => _endDate;

  List<NotificationItem> get unreadNotifications => _unreadNotifications;
  int get unreadCount => _unreadCount;

  bool get notificationDialogOpen => _notificationDialogOpen;

  /////////////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////////

  void setSettingTabIndex(int index) {
    _settingTabIndex = index;
  }

  Future<void> reqNotifications(String? startDate, String? endDate) async {
    NotificationResult? notificationResult;
    _isLoading = true;
    _totalCount = 0;
    _notifications.clear();
    _startDate = startDate;
    _endDate = endDate;

    int offset = (_viewPage * kNotificationListLimit);
    notificationResult = await NotificationRepository().requestNotifications(startDate, endDate, offset);
    // debugPrint("reqNotifications() notificationResult $notificationResult");

    if (notificationResult == null) {
      _isLoading = false;
      update();
      return;
    }

    _totalCount = notificationResult.totalCount ?? 0;
    if (_totalCount % kLogListLimit == 0) {
      _maxPage = (_totalCount / kNotificationListLimit).floor();
    } else {
      _maxPage = (_totalCount / kNotificationListLimit).floor() + 1;
    }

    if (_maxPage <= 0) {
      _maxPage = 1;
    }

    _notifications = notificationResult.notifications;

    _isLoading = false;
    update();
  }

  Future<void> reqReadNotification(int notificationId) async {
    if (notificationId == -1) {
      debugPrint("reqReadNotification() notificationId: $notificationId");
      return;
    }

    bool result = await NotificationRepository().requestReadNotification(notificationId);

    if (result == true) {
      for (int i = 0; i < _notifications.length; i++) {
        if (_notifications[i].id == notificationId) {
          if (_notifications[i].isRead == false) {
            _unreadCount--;
          }

          _notifications[i].isRead = true;
          break;
        }
      }

      update();
    }
  }

  Future<void> reqUnreadNotifications() async {
    _unreadNotifications = await NotificationRepository().requestUnreadNotifications();
    _unreadCount = _unreadNotifications.length;
    update();
  }

  Future<int> reqUnreadNotificationCount() async {
    _unreadCount = await NotificationRepository().requestUnreadNotificationCount() ?? 0;
    return _unreadCount;
  }

  Widget getPageNationView() {
    return PageNationView(
      viewPage: _viewPage,
      maxPage: _maxPage,
      onViewPageChanged: (index) async {
        _viewPage = index;
        reqNotifications(_startDate, _endDate);
      },
    );
  }

  void setNotificationDialogOpen(bool set) {
    _notificationDialogOpen = set;
  }
}
