import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fms/viewmodel/repository/base_repository.dart';
import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../model/user_model.dart';

class MemberRepository extends BaseRepository {
  final String unApprovedMemberListPath = "/api/member/unApprovedMember";
  final String memberListPath = "/api/member/Member";

  final String approvePath = "/api/member/approveMember";
  final String rejectPath = "/api/member/rejectMember";

  final String changeRolePath = "/api/member/changeRole";
  final String deleteMemberPath = "/api/member/deleteMember";

  Future<List<Member>> requestUnApprovedMemberList() async {
    var url = Uri.http(kApiServer, unApprovedMemberListPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestUnApprovedMemberList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestUnApprovedMemberList() ${jsonResp.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<Member> result = items.map((e) => Member.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestUnApprovedMemberList => $e");
      return [];
    }
  }

  Future<List<Member>> requestMemberList() async {
    var url = Uri.http(kApiServer, memberListPath);

    try {
      final response = await http.get(url, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestMemberList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestMemberList() ${jsonResponse.toString()}");
        List<dynamic> items = jsonResponse['body'];
        List<Member> result = items.map((e) => Member.fromJson(e)).toList();

        return result;
      });
    } catch (e) {
      debugPrint("[Exception] requestMemberList => $e");
      return [];
    }
  }

  Future<bool> requestApproveMember(int id) async {
    Map<String, dynamic> params = {};
    params['id'] = id;

    String body = jsonEncode(params);

    var url = Uri.http(kApiServer, approvePath);

    try {
      final response = await http.post(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestApproveMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestApproveMember() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestApproveMember => $e");
      return false;
    }
  }

  Future<bool> requestRejectMember(int id) async {
    Map<String, dynamic> params = {};
    params['id'] = id;

    String body = jsonEncode(params);
    var url = Uri.http(kApiServer, rejectPath);

    try {
      final response = await http.post(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestRejectMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestRejectMember() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestRejectMember => $e");
      return false;
    }
  }

  Future<bool> requestChangeRole(int id, String role) async {
    Map<String, dynamic> params = {};
    params['id'] = id;
    params['role'] = (role == "관리자") ? "admin" : "user";

    String body = jsonEncode(params);
    var url = Uri.http(kApiServer, changeRolePath);

    try {
      final response = await http.patch(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestChangeRole() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestChangeRole() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestChangeRole => $e");
      return false;
    }
  }

  Future<bool> requestDeleteMember(int id) async {
    Map<String, dynamic> params = {};
    params['id'] = id;

    String body = jsonEncode(params);
    var url = Uri.http(kApiServer, deleteMemberPath);

    try {
      final response = await http.delete(url, body: body, headers: getHeader());
      if (response.statusCode != 200) {
        debugPrint('[Error] requestDeleteMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // debugPrint("requestDeleteMember() ${jsonResp.toString()}");
        return (jsonResponse['body']['affectedRows'] != null);
      });
    } catch (e) {
      debugPrint("[Exception] requestDeleteMember => $e");
      return false;
    }
  }
}
