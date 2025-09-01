import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/notification_model.dart';
import 'base_repository.dart';

class NotificationRepository extends BaseRepository {
  final String notificationListPath = '/api/notification/list';
  final String readNotificationPath = '/api/notification/read';
  final String unreadNotificationPath = '/api/notification/unread/list';
  final String unreadNotificationCountPath = '/api/notification/unread/count';

  Future<NotificationResult?> requestNotifications(String? startDate, String? endDate, int offset) async {
    Map<String, dynamic> params = {};

    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
    }

    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
    }

    params['limit'] = kNotificationListLimit.toString();
    params['offset'] = offset.toString();

    var url = Uri.http(kApiServer, notificationListPath, params);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] notificationList() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("notificationList() ${jsonResponse.toString()}");
        return NotificationResult.fromJson(jsonResponse['body']);
      });
    } catch (e) {
      debugPrint("[Exception] notificationList $e");
      return null;
    }
  }

  Future<bool> requestReadNotification(int notificationId) async {
    Map<String, dynamic> params = {};
    params['notificationId'] = notificationId.toString();

    String body = jsonEncode(params);

    var url = Uri.http(kApiServer, readNotificationPath);

    try {
      final response = await http.post(url, headers: getHeader(), body: body);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestReadNotification() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestReadNotification() ${jsonResponse.toString()}");
        return (jsonResponse != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestReadNotification $e");
      return false;
    }
  }

  Future<List<NotificationItem>> requestUnreadNotifications() async {
    var url = Uri.http(kApiServer, unreadNotificationPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestUnreadNotifications() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestUnreadNotifications() ${jsonResponse.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<NotificationItem> result = items.map((e) => NotificationItem.fromJson(e)).toList();
        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestUnreadNotifications $e");
      return [];
    }
  }

  Future<int?> requestUnreadNotificationCount() async {
    var url = Uri.http(kApiServer, unreadNotificationCountPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestUnreadNotificationCount() statusCode ${response.statusCode}');
        return null;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestUnreadNotificationCount() ${jsonResponse.toString()}");
        return int.tryParse(jsonResponse['body'].toString());
      });
    } catch (e) {
      debugPrint("[Exception] requestUnreadNotificationCount $e");
      return null;
    }
  }
}
