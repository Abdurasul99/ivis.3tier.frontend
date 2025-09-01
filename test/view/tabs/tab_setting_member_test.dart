// File: test/view/tabs/tab_setting_member_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fms/view/tabs/tab_setting_member.dart';
import 'package:fms/model/user_model.dart';
import 'package:fms/viewmodel/controller/member_controller.dart';
import 'package:fms/view/dialogs/ask_dialog.dart';
import 'package:fms/view/components/gradient_button.dart';
import 'package:fms/constants/constants.dart';

// 1) Fake controller with no members
class EmptyMemberController extends MemberController {
  @override
  Future<void> reqLoadMembers() async {
    debugPrint('EmptyMemberController.reqLoadMembers() called');
    unApprovedMembers.clear();
    members.clear();
    update();
  }
}

// 2) Fake controller with one unapproved and one approved member
class PopulatedMemberController extends MemberController {
  int? lastApprovedId;
  int? lastDeletedId;
  int? lastRejectedId;

  @override
  Future<void> reqLoadMembers() async {
    debugPrint('PopulatedMemberController.reqLoadMembers() called');
    unApprovedMembers
      ..clear()
      ..add(Member(
        id: 11,
        name: 'Alice',
        userId: 'alice01',
        role: 'user',
        email: 'alice@example.com',
        phoneNumber: '010-0000-0000',
        createdTs: '2025-06-29T12:34:56',
      ));
    members
      ..clear()
      ..add(Member(
        id: 22,
        name: 'Bob',
        userId: 'bob02',
        role: 'admin',
        email: 'bob@example.com',
        phoneNumber: '010-1111-1111',
        createdTs: '2025-06-28T11:22:33',
      ));
    update();
  }

  @override
  Future<bool> reqApproveMember(int id) async {
    debugPrint('reqApproveMember($id) called');
    lastApprovedId = id;
    return true;
  }

  @override
  Future<bool> reqDeleteMember(int id) async {
    debugPrint('reqDeleteMember($id) called');
    lastDeletedId = id;
    return true;
  }

  @override
  Future<bool> reqRejectMember(int id) async {
    debugPrint('reqRejectMember($id) called');
    lastRejectedId = id;
    return true;
  }
}

void main() {
  Future<void> pumpMemberTab(WidgetTester tester, MemberController ctrl) async {
    // Give wide surface so the 7-column row fits
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    Get.reset();
    Get.put<MemberController>(ctrl);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: TabSettingMember()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no members', (tester) async {
    final ctrl = EmptyMemberController();
    await pumpMemberTab(tester, ctrl);

    debugPrint('Testing empty state UI');
    expect(find.text('승인 대기 멤버가 없습니다. 😎'), findsOneWidget);
    expect(find.text('멤버가 없습니다. 😎'), findsOneWidget);
  });

  testWidgets('shows lists and handles approve/delete', (tester) async {
    final ctrl = PopulatedMemberController();
    await pumpMemberTab(tester, ctrl);

    debugPrint('Tapping Approve for Alice');
    final approveBtn = find.widgetWithText(GradientButton, '승인');
    expect(approveBtn, findsOneWidget);
    await tester.tap(approveBtn, warnIfMissed: false);
    await tester.pumpAndSettle();
    debugPrint('lastApprovedId = ${ctrl.lastApprovedId}');
    expect(ctrl.lastApprovedId, 11);

    debugPrint('Tapping Delete for Bob');
    final deleteBtn = find
        .ancestor(
          of: find.text('삭제'),
          matching: find.byType(GradientButton),
        )
        .last;
    await tester.ensureVisible(deleteBtn);
    await tester.tap(deleteBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    debugPrint('Verifying AskDialog appears');
    expect(find.byType(AskDialog), findsOneWidget);

    debugPrint('Confirming Delete in dialog');
    final dialogDelete = find.descendant(
      of: find.byType(AskDialog),
      matching: find.text('삭제'),
    );
    await tester.tap(dialogDelete, warnIfMissed: false);
    await tester.pumpAndSettle();
    debugPrint('lastDeletedId = ${ctrl.lastDeletedId}');
    expect(ctrl.lastDeletedId, 22);
  });

  testWidgets('rejects unapproved member', (tester) async {
    final ctrl = PopulatedMemberController();
    await pumpMemberTab(tester, ctrl);

    debugPrint('Tapping Reject for Alice');
    final rejectBtn = find
        .ancestor(
          of: find.text('거절'),
          matching: find.byType(GradientButton),
        )
        .first;
    await tester.ensureVisible(rejectBtn);
    await tester.tap(rejectBtn, warnIfMissed: false);
    await tester.pumpAndSettle();

    debugPrint('Verifying AskDialog appears for Reject');
    expect(find.byType(AskDialog), findsOneWidget);

    debugPrint('Confirming Reject in dialog');
    final dialogReject = find.descendant(
      of: find.byType(AskDialog),
      matching: find.text('거절'),
    );
    await tester.tap(dialogReject, warnIfMissed: false);
    await tester.pumpAndSettle();
    debugPrint('lastRejectedId = ${ctrl.lastRejectedId}');
    expect(ctrl.lastRejectedId, 11);
  });
}
