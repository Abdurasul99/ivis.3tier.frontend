class NotificationItem {
  int? id;
  String? alarmType;
  String? comment;
  String? createTs;
  bool? isRead;

  NotificationItem({this.id, this.alarmType, this.comment, this.createTs, this.isRead});

  NotificationItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    alarmType = json['alarm_type'] ?? "";
    comment = json['comment'] ?? "";
    createTs = json['created_ts'] ?? "";
    isRead = (json['is_unread'] == 0);
  }

  @override
  String toString() {
    return 'NotificationItem{id: $id, alarmType: $alarmType, comment: $comment, createTs: $createTs, isRead: $isRead}';
  }
}

class NotificationResult {
  int? totalCount;
  List<NotificationItem> notifications = [];

  NotificationResult.fromJson(Map<String, dynamic> json) {
    totalCount = json['notificationListCount'] ?? 0;
    if (json['notificationList'] != null) {
      notifications = (json['notificationList'] as List).map((i) => NotificationItem.fromJson(i)).toList();
    }
  }

  @override
  String toString() {
    return 'NotificationResult{totalCount: $totalCount, notifications: $notifications}';
  }
}
