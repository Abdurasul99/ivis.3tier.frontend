import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ivis/view/components/gradient_button.dart';
import 'package:ivis/view/components/layout.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/user_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/member_controller.dart';
import '../components/input_edit_dropdown_member.dart';
import '../dialogs/ask_dialog.dart';

class TabSettingMember extends StatefulWidget {
  const TabSettingMember({super.key});

  @override
  State<TabSettingMember> createState() => _TabSettingMemberState();
}

class _TabSettingMemberState extends State<TabSettingMember> {
  final List<String> _cellTitles = [
    '이름',
    '아이디',
    '멤버등급',
    '메일',
    '연락처',
    '승인요청일자',
    '승인여부선택',
  ];
  final List<int> _cellWidths = [14, 14, 14, 28, 15, 15, 28];

  final List<String> _roles = ["관리자", "일반"];

  @override
  void initState() {
    super.initState();

    Get.find<MemberController>().reqLoadMembers();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile()) {
      return const TabSettingMember();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60.0, vertical: 34),
      child: SingleChildScrollView(
        child: GetBuilder<MemberController>(
          init: MemberController(),
          builder: (controller) {
            if (controller.isLoading) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 20, color: Colors.grey),
              );
            }

            return Column(
              children: [
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  child: const Text(
                    '승인 대기 멤버',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 40,
                  color: const Color(0xFFFAFAFA),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: _cellTitles.map((title) {
                      int index = _cellTitles.indexOf(title);
                      return Flexible(
                        flex: _cellWidths[index],
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Color(0xFF666565),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                (controller.unApprovedMembers.isEmpty)
                    ? Column(
                        children: [
                          Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: const Text(
                              '승인 대기 멤버가 없습니다. 😎',
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 15,
                                color: Color(0xFF666565),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            width: MediaQuery.of(context).size.width,
                            color: kLineColor,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: controller.unApprovedMembers.length,
                        itemBuilder: (BuildContext context, int index) {
                          Member member = controller.unApprovedMembers[index];

                          return buildMemberItem(member, false);
                        },
                      ),
                const SizedBox(height: 56),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  child: const Text(
                    '멤버 관리',
                    style: TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 15,
                      color: Color(0xFF666565),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 40,
                  color: const Color(0xFFFAFAFA),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: _cellTitles.map((title) {
                      int index = _cellTitles.indexOf(title);
                      return Flexible(
                        flex: _cellWidths[index],
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'pretendard',
                              fontSize: 15,
                              color: Color(0xFF666565),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                (controller.members.isEmpty)
                    ? Column(
                        children: [
                          Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: const Text(
                              '멤버가 없습니다. 😎',
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 15,
                                color: Color(0xFF666565),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            width: MediaQuery.of(context).size.width,
                            color: kLineColor,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: controller.members.length,
                        itemBuilder: (BuildContext context, int index) {
                          Member member = controller.members[index];
                          return buildMemberItem(member, true);
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildMemberItem(Member member, bool isApproved) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Flexible(
            flex: _cellWidths[0],
            child: Container(
              alignment: Alignment.center,
              child: Text(
                member.name ?? "",
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[1],
            child: Container(
              alignment: Alignment.center,
              child: Text(
                (member.userId ?? "").toString(),
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[2],
            child: Container(
              alignment: Alignment.center,
              child: isApproved
                  ? InputEditDropDownMember(
                      items: _roles,
                      hintText: "",
                      onChanged: (value) async {
                        if (value == null || value.isEmpty) {
                          return;
                        }

                        if (value == "관리자" && member.role == "admin") {
                          return;
                        }

                        if (value == "일반" && member.role == "user") {
                          return;
                        }

                        bool result = await Get.find<MemberController>().reqChangeRole(member.id ?? -1, value);

                        if (result) {
                          Utils.showSnackBar("변경되었습니다.");
                        }

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      selectedText: (member.role == "admin") ? "관리자" : "일반",
                      // buttonPadding: EdgeInsets.all(0),
                    )
                  : Text(
                      (member.role == "admin") ? "관리자" : "일반",
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
          Flexible(
            flex: _cellWidths[3],
            child: Container(
              alignment: Alignment.center,
              child: Text(
                member.email ?? "",
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[4],
            child: Container(
              alignment: Alignment.center,
              child: Text(
                member.phoneNumber ?? "-",
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[5],
            child: Container(
              alignment: Alignment.center,
              child: Text(
                member.createdTs!.substring(0, 10),
                style: const TextStyle(
                  fontFamily: 'pretendard',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[6],
            child: Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  isApproved
                      ? const SizedBox(width: 102)
                      : SizedBox(
                          width: 102,
                          child: GradientButton(
                            buttonText: "승인",
                            buttonColor: const Color(0xFF005FB8),
                            onTap: () async {
                              bool isSuccess = await Get.find<MemberController>().reqApproveMember(member.id!);

                              if (isSuccess) {
                                Utils.showSnackBar("승인되었습니다.");
                                await Get.find<MemberController>().reqLoadMembers();
                              }
                            },
                          ),
                        ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 102,
                    child: GradientButton(
                      buttonText: isApproved ? "삭제" : "거절",
                      onTap: () async {
                        bool isSuccess = false;
                        if (isApproved) {
                          final result = await showDialog(
                            context: Get.context!,
                            builder: (BuildContext context) {
                              return AskDialog(
                                message: '"${member.name}"님을 멤버에서 삭제할까요?',
                                addMessage:
                                    "멤버를 삭제하면 해당 멤버는 로그인 및 시스템을 사용할 수 없습니다.\n다시 이용하려면 신규 가입 후 승인 절차를 다시 진행해야 합니다.",
                                leftText: "삭제",
                                rightText: "취소",
                              );
                            },
                            barrierDismissible: false,
                          );

                          if (result != "LEFT") {
                            return;
                          }

                          isSuccess = await Get.find<MemberController>().reqDeleteMember(member.id!);
                          Get.find<MemberController>().reqLoadMembers();
                          Utils.showSnackBar("삭제되었습니다.");
                        } else {
                          final result = await showDialog(
                            context: Get.context!,
                            builder: (BuildContext context) {
                              return AskDialog(
                                message: '"${member.name}"님을 거절할까요?',
                                addMessage: "거절된 멤버는 시스템을 사용할 수 없습니다.\n다시 이용하려면 신규 가입 후 승인 절차를 다시 진행해야 합니다.",
                                leftText: "거절",
                                rightText: "취소",
                              );
                            },
                            barrierDismissible: false,
                          );

                          if (result != "LEFT") {
                            return;
                          }

                          isSuccess = await Get.find<MemberController>().reqRejectMember(member.id!);
                          Get.find<MemberController>().reqLoadMembers();
                          Utils.showSnackBar("거절되었습니다.");
                        }

                        if (isSuccess) {
                          await Get.find<MemberController>().reqLoadMembers();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
