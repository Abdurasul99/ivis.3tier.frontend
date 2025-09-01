// lib/view/tabs/mobile/tab_setting_member_mobile.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/model/user_model.dart';
import '/utils/utils.dart';
import '/view/tabs/mobile/dialogs/ask_dialog_mobile.dart';
import '/viewmodel/controller/member_controller.dart';

class TabSettingMemberMobile extends StatefulWidget {
  const TabSettingMemberMobile({super.key});

  @override
  State<TabSettingMemberMobile> createState() => _TabSettingMemberMobileState();
}

class _TabSettingMemberMobileState extends State<TabSettingMemberMobile> {
  final List<String> _memberRoleLabels = const <String>[
    '소유자',
    '관리자',
    '일반',
  ];

  @override
  void initState() {
    super.initState();
    Get.find<MemberController>().reqLoadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: GetBuilder<MemberController>(
        init: MemberController(),
        builder: (MemberController controller) {
          if (controller.isLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('확인 대기 멤버'),
                if (controller.unApprovedMembers.isEmpty)
                  const _EmptyLabel('확인 대기 멤버가 없습니다. 😎')
                else
                  ...controller.unApprovedMembers
                      .map(
                        (Member member) => _WaitingCard(
                          member: member,
                          onDone: _reloadMembers,
                        ),
                      )
                      .toList(),
                const SizedBox(height: 24),
                const _SectionTitle('멤버 관리'),
                if (controller.members.isEmpty)
                  const _EmptyLabel('멤버가 없습니다. 😎')
                else
                  ...controller.members
                      .map(
                        (Member member) => _MemberCard(
                          member: member,
                          roles: _memberRoleLabels,
                          onDone: _reloadMembers,
                        ),
                      )
                      .toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _reloadMembers() async {
    await Get.find<MemberController>().reqLoadMembers();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'pretendard',
          ),
        ),
      );
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF666565),
            fontFamily: 'pretendard',
          ),
        ),
      );
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.member,
    required this.onDone,
    super.key,
  });

  final Member member;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 450;
    final double buttonHeight = isMobile ? 32 : 36;

    return _BaseCard(
      header: '${member.name ?? "-"} (${member.userId})',
      children: <Widget>[
        const _InfoRow('멤버 등급', '일반'),
        _InfoRow('메일', member.email ?? '-'),
        _InfoRow('연락처', member.phoneNumber ?? '-'),
        _InfoRow('승인요청일', member.createdTs!.substring(0, 10)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: Color(0xFFE5E5E5)),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005FB8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () async {
                    final bool isOk = await Get.find<MemberController>().reqApproveMember(
                      member.id!,
                    );
                    if (isOk) {
                      Utils.showSnackBar('확인 되었습니다.');
                      onDone();
                    }
                  },
                  child: const Text('확인'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () async {
                    final dynamic result = await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const AskDialog(
                        message: '요청을 거절할까요?',
                        addMessage: '거절된 멤버는 시스템을 사용할 수 없습니다.',
                        leftText: '거절',
                        rightText: '취소',
                      ),
                    );
                    if (result != 'LEFT') return;

                    final bool isOk = await Get.find<MemberController>().reqRejectMember(
                      member.id!,
                    );
                    if (isOk) {
                      Utils.showSnackBar('거절되었습니다.');
                      onDone();
                    }
                  },
                  child: const Text('취소'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemberCard extends StatefulWidget {
  const _MemberCard({
    required this.member,
    required this.roles,
    required this.onDone,
    super.key,
  });

  final Member member;
  final List<String> roles;
  final VoidCallback onDone;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  late String _currentRoleLabel;

  @override
  void initState() {
    super.initState();
    _currentRoleLabel = widget.member.role == 'admin'
        ? '관리자'
        : widget.member.role == 'owner'
            ? '소유자'
            : '일반';
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      header: '${widget.member.name ?? "-"} (${widget.member.userId})',
      headerTrailing: GestureDetector(
        onTap: () async {
          final dynamic result = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AskDialog(
              message: '"${widget.member.name}"님을 멤버에서 삭제할까요?',
              addMessage: '멤버를 삭제하면 해당 멤버는 로그인 및 시스템을 사용할 수 없습니다.',
              leftText: '삭제',
              rightText: '취소',
            ),
          );
          if (result != 'LEFT') return;

          final bool isOk = await Get.find<MemberController>().reqDeleteMember(
            widget.member.id!,
          );
          if (isOk) {
            Utils.showSnackBar('삭제되었습니다.');
            widget.onDone();
          }
        },
        child: const Text(
          '삭제하기',
          style: TextStyle(fontSize: 13, color: Color(0xFFFF3B30)),
        ),
      ),
      children: <Widget>[
        _DropRow(
          label: '멤버 등급',
          value: _currentRoleLabel,
          items: widget.roles,
          onChanged: (String? newValue) {
            if (newValue == null) return;
            setState(() => _currentRoleLabel = newValue);
            Utils.showSnackBar('화면상 등급이 "$newValue"로 변경되었습니다.');
          },
        ),
        _InfoRow('메일', widget.member.email ?? '-'),
        _InfoRow('연락처', widget.member.phoneNumber ?? '-'),
        _InfoRow(
          '승인요청일',
          widget.member.createdTs!.substring(0, 10),
        ),
      ],
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({
    required this.header,
    this.headerTrailing,
    required this.children,
    super.key,
  });

  final String header;
  final Widget? headerTrailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'pretendard',
                      ),
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666565),
                  fontFamily: 'pretendard',
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'pretendard',
                ),
              ),
            ),
          ],
        ),
      );
}

class _DropRow extends StatelessWidget {
  const _DropRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666565),
                  fontFamily: 'pretendard',
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCCCCCC)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: value,
                    dropdownColor: Colors.white,
                    items: items
                        .map(
                          (String roleLabel) => DropdownMenuItem<String>(
                            value: roleLabel,
                            child: Text(
                              roleLabel,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
