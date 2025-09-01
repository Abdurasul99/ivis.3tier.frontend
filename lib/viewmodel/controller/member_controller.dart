import 'package:fms/viewmodel/repository/member_repository.dart';
import 'package:get/get.dart';

import '../../model/user_model.dart';

class MemberController extends GetxController {
  List<Member> _unApprovedMembers = [];
  List<Member> _members = [];
  bool _isLoading = false;

  get unApprovedMembers => _unApprovedMembers;
  get members => _members;
  get isLoading => _isLoading;

  //////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////

  Future<void> reqLoadMembers() async {
    _isLoading = true;

    _unApprovedMembers = await MemberRepository().requestUnApprovedMemberList();
    _members = await MemberRepository().requestMemberList();

    _isLoading = false;
    update();
  }

  Future<bool> reqApproveMember(int id) async {
    return await MemberRepository().requestApproveMember(id);
  }

  Future<bool> reqRejectMember(int id) async {
    return await MemberRepository().requestRejectMember(id);
  }

  Future<bool> reqChangeRole(int id, String role) async {
    if (id == -1) {
      return false;
    }

    bool result = await MemberRepository().requestChangeRole(id, role);
    if (result) {
      for (int i = 0; i < _members.length; i++) {
        if (id == _members[i].id) {
          _members[i].role = (role == "관리자") ? "admin" : "user";
          break;
        }
      }
    }

    return result;
  }

  Future<bool> reqDeleteMember(int id) async {
    return await MemberRepository().requestDeleteMember(id);
  }
}
