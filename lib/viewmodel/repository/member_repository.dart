import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ivis/viewmodel/repository/base_repository.dart';
import 'package:http/http.dart' as http;

import '../../model/user_model.dart';

class MemberRepository extends BaseRepository {
  final String unApprovedMemberListPath = "/api/member/unApprovedMember";
  final String memberListPath = "/api/member/Member";

  final String approvePath = "/api/member/approveMember";
  final String rejectPath = "/api/member/rejectMember";

  final String changeRolePath = "/api/member/changeRole";
  final String deleteMemberPath = "/api/member/deleteMember";

  Future<List<Member>> requestUnApprovedMemberList() async {
    final Uri url = buildApiUri(unApprovedMemberListPath);

    try {
      final http.Response response =
          await http.get(url, headers: getHeader()).timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestUnApprovedMemberList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
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
    final Uri url = buildApiUri(memberListPath);

    try {
      final http.Response response =
          await http.get(url, headers: getHeader()).timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestMemberList() statusCode ${response.statusCode}');
        return [];
      }

      return handleResponse(response, (jsonResponse) {
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

    final Uri url = buildApiUri(approvePath);

    try {
      final http.Response response = await http
          .post(url, body: body, headers: getHeader())
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestApproveMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // 성공 판정: 백엔드 buildResponse code '0000' (pg 결과엔 affectedRows 없음 — MySQL 잔재 버그 수정)
        return jsonResponse is Map && jsonResponse['code'] == '0000';
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
    final Uri url = buildApiUri(rejectPath);

    try {
      final http.Response response = await http
          .post(url, body: body, headers: getHeader())
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestRejectMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // 성공 판정: 백엔드 buildResponse code '0000' (pg 결과엔 affectedRows 없음 — MySQL 잔재 버그 수정)
        return jsonResponse is Map && jsonResponse['code'] == '0000';
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
    final Uri url = buildApiUri(changeRolePath);

    try {
      final http.Response response = await http
          .patch(url, body: body, headers: getHeader())
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestChangeRole() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // 성공 판정: 백엔드 buildResponse code '0000' (pg 결과엔 affectedRows 없음 — MySQL 잔재 버그 수정)
        return jsonResponse is Map && jsonResponse['code'] == '0000';
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
    final Uri url = buildApiUri(deleteMemberPath);

    try {
      final http.Response response = await http
          .delete(url, body: body, headers: getHeader())
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint('[Error] requestDeleteMember() statusCode ${response.statusCode}');
        return false;
      }

      return handleResponse(response, (jsonResponse) {
        // 성공 판정: 백엔드 buildResponse code '0000' (pg 결과엔 affectedRows 없음 — MySQL 잔재 버그 수정)
        return jsonResponse is Map && jsonResponse['code'] == '0000';
      });
    } catch (e) {
      debugPrint("[Exception] requestDeleteMember => $e");
      return false;
    }
  }
}
