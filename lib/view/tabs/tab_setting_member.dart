import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ivis/view/components/layout.dart';

import '../../constants/constants.dart';
import '../../i18n/app_locale.dart';
import '../../model/user_model.dart';
import '../../utils/utils.dart';
import '../../viewmodel/controller/locale_controller.dart';
import '../../viewmodel/controller/member_controller.dart';
import '../components/gradient_button.dart';
import '../components/input_edit_dropdown_member.dart';
import '../dialogs/ask_dialog.dart';

class TabSettingMember extends StatefulWidget {
  const TabSettingMember({super.key});

  @override
  State<TabSettingMember> createState() => _TabSettingMemberState();
}

class _TabSettingMemberState extends State<TabSettingMember> {
  final List<int> _cellWidths = <int>[14, 14, 14, 28, 15, 15, 28];

  List<String> get _cellTitles => <String>[
        t('이름'),
        t('아이디'),
        t('멤버등급'),
        t('메일'),
        t('연락처'),
        t('승인요청일자'),
        t('승인여부선택'),
      ];

  List<String> get _roles => <String>[t('관리자'), t('일반')];

  String _roleLabel(String? role) => role == 'admin' ? t('관리자') : t('일반');

  String _roleRequestValue(String value) => value == t('관리자') ? '관리자' : '일반';

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

    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 34),
        child: SingleChildScrollView(
          child: GetBuilder<MemberController>(
            init: Get.find<MemberController>(),
            builder: (MemberController controller) {
              if (controller.isLoading) {
                return const Center(
                  child: CupertinoActivityIndicator(radius: 20, color: Colors.grey),
                );
              }

              return Column(
                children: <Widget>[
                  _sectionTitle(t('승인 대기 멤버')),
                  const SizedBox(height: 14),
                  _tableHeader(),
                  controller.unApprovedMembers.isEmpty
                      ? _emptyRow(t('승인 대기 멤버가 없습니다. 😎'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: controller.unApprovedMembers.length,
                          itemBuilder: (_, int index) => _buildMemberItem(controller.unApprovedMembers[index], false),
                        ),
                  const SizedBox(height: 56),
                  _sectionTitle(t('멤버 관리')),
                  const SizedBox(height: 14),
                  _tableHeader(),
                  controller.members.isEmpty
                      ? _emptyRow(t('멤버가 없습니다. 😎'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: controller.members.length,
                          itemBuilder: (_, int index) => _buildMemberItem(controller.members[index], true),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 23),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'pretendard',
          fontSize: 15,
          color: Color(0xFF666565),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 40,
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _cellTitles.map((String title) {
          final int index = _cellTitles.indexOf(title);
          return Flexible(
            flex: _cellWidths[index],
            child: Center(
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
    );
  }

  Widget _emptyRow(String label) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 50,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'pretendard',
                fontSize: 15,
                color: Color(0xFF666565),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        Container(
          height: 1,
          width: double.infinity,
          color: kLineColor,
        ),
      ],
    );
  }

  Widget _memberAvatar(Member member, double size) {
    final String? url = member.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          Utils.proxyImageUrl(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialAvatar(member, size),
        ),
      );
    }
    return _initialAvatar(member, size);
  }

  Widget _initialAvatar(Member member, double size) {
    final String initial = (member.name?.isNotEmpty == true ? member.name![0] : '?').toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1565C0),
        ),
      ),
    );
  }

  Widget _buildMemberItem(Member member, bool isApproved) {
    final String selectedRole = _roleLabel(member.role);

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          Flexible(
            flex: _cellWidths[0],
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _memberAvatar(member, 30),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      member.name ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'pretendard',
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            flex: _cellWidths[1],
            child: Center(
              child: Text(
                (member.userId ?? '').toString(),
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
            child: Center(
              child: isApproved
                  ? InputEditDropDownMember(
                      items: _roles,
                      hintText: '',
                      selectedText: selectedRole,
                      onChanged: (String? value) async {
                        if (value == null || value.isEmpty || value == selectedRole) {
                          return;
                        }

                        final bool result = await Get.find<MemberController>().reqChangeRole(
                          member.id ?? -1,
                          _roleRequestValue(value),
                        );

                        if (result) {
                          Utils.showSnackBar(t('변경되었습니다.'));
                        }

                        if (mounted) {
                          setState(() {});
                        }
                      },
                    )
                  : Text(
                      selectedRole,
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
            child: Center(
              child: Text(
                member.email ?? '',
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
            child: Center(
              child: Text(
                member.phoneNumber ?? '-',
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
            child: Center(
              child: Text(
                member.createdTs?.substring(0, 10) ?? '-',
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
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  isApproved
                      ? const SizedBox(width: 102)
                      : SizedBox(
                          width: 102,
                          child: GradientButton(
                            buttonText: t('승인'),
                            buttonColor: const Color(0xFF005FB8),
                            onTap: () async {
                              final bool isSuccess =
                                  await Get.find<MemberController>().reqApproveMember(member.id!);

                              if (isSuccess) {
                                Utils.showSnackBar(t('승인되었습니다.'));
                                await Get.find<MemberController>().reqLoadMembers();
                              }
                            },
                          ),
                        ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 102,
                    child: GradientButton(
                      buttonText: isApproved ? t('삭제') : t('거절'),
                      onTap: () async {
                        bool isSuccess = false;
                        if (isApproved) {
                          final String? result = await showDialog<String>(
                            context: Get.context!,
                            barrierDismissible: false,
                            builder: (_) => AskDialog(
                              message: l10n('"${member.name}"님을 멤버에서 삭제할까요?', 'Delete "${member.name}" from members?'),
                              addMessage: l10n(
                                '멤버를 삭제하면 해당 멤버는 로그인 및 시스템을 사용할 수 없습니다.\n다시 이용하려면 신규 가입 후 승인 절차를 다시 진행해야 합니다.',
                                'If deleted, this member will no longer be able to log in or use the system.\nThey must sign up again and be approved to regain access.',
                              ),
                              leftText: t('삭제'),
                              rightText: t('취소'),
                            ),
                          );

                          if (result != 'LEFT') return;

                          isSuccess = await Get.find<MemberController>().reqDeleteMember(member.id!);
                          Utils.showSnackBar(t('삭제되었습니다.'));
                        } else {
                          final String? result = await showDialog<String>(
                            context: Get.context!,
                            barrierDismissible: false,
                            builder: (_) => AskDialog(
                              message: l10n('"${member.name}"님을 거절할까요?', 'Reject "${member.name}"?'),
                              addMessage: l10n(
                                '거절된 멤버는 시스템을 사용할 수 없습니다.\n다시 이용하려면 신규 가입 후 승인 절차를 다시 진행해야 합니다.',
                                'A rejected member cannot use the system.\nThey must sign up again and be approved to regain access.',
                              ),
                              leftText: t('거절'),
                              rightText: t('취소'),
                            ),
                          );

                          if (result != 'LEFT') return;

                          isSuccess = await Get.find<MemberController>().reqRejectMember(member.id!);
                          Utils.showSnackBar(t('거절되었습니다.'));
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
