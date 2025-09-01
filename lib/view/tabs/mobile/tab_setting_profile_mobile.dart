import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fms/view/tabs/mobile/dialogs/photo_edit_dialog_mobile.dart';
import 'package:get/get.dart';

import '/utils/utils.dart';
import '/view/components/gradient_button.dart';
import '/view/components/input_edit_text_read_only.dart';
import '/view/dialogs/noti_dialog.dart';
import '/view/dialogs/password_change_dialog.dart';
import '/view/pages/login_page.dart';
import '/viewmodel/controller/user_controller.dart';
import '/view/tabs/mobile/components/input_edit_text_setting_mobile.dart' as mobile;

class TabSettingProfileMobile extends StatefulWidget {
  const TabSettingProfileMobile({super.key});

  @override
  State<TabSettingProfileMobile> createState() => _TabSettingProfileMobileState();
}

class _TabSettingProfileMobileState extends State<TabSettingProfileMobile> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final user = Get.find<UserController>().loginUser;
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _formatPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    String out;
    if (digits.length >= 8) {
      out = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length >= 4) {
      out = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      out = digits;
    }
    if (_phoneController.text != out) {
      _phoneController.value = TextEditingValue(
        text: out,
        selection: TextSelection.collapsed(offset: out.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<UserController>(
      builder: (userCtrl) {
        final user = userCtrl.loginUser;
        if (user == null) return const SizedBox.shrink();
        final String imageUrl = user.imageUrl ?? '';

        return SafeArea(
          child: ScrollConfiguration(
            behavior: const _NoBounceBehavior(),
            child: RepaintBoundary(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics().applyTo(const AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 37, vertical: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          RepaintBoundary(
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 104,
                                  height: 104,
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(52),
                                        child: imageUrl.isEmpty
                                            ? SvgPicture.asset(
                                                'assets/images/icons_profile.svg',
                                                width: 104,
                                                height: 104,
                                              )
                                            : ExtendedImage.network(
                                                imageUrl,
                                                width: 104,
                                                height: 104,
                                                fit: BoxFit.cover,
                                                cache: true,
                                              ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final bool changed = await Navigator.of(context).push<bool>(
                                                  MaterialPageRoute(
                                                    builder: (_) => const PhotoEditPageMobile(),
                                                  ),
                                                ) ??
                                                false;
                                            if (changed) {
                                              setState(() {});
                                            }
                                          },
                                          child: SvgPicture.asset(
                                            'assets/images/icons_small_edit.svg',
                                            width: 32,
                                            height: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          RepaintBoundary(
                            child: InputEditTextReadOnly(title: '이름', value: user.name),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: InputEditTextReadOnly(title: '메일', value: user.email),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: InputEditTextReadOnly(
                              title: '멤버 등급',
                              value: user.role == 'admin' ? '관리자' : '일반',
                            ),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            child: mobile.InputEditTextSetting(
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              title: '핸드폰',
                              hintText: '010-1234-5678',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              onChanged: _formatPhone,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RepaintBoundary(
                            child: GradientButton(buttonText: '연락처 변경', onTap: _changePhone),
                          ),
                          const SizedBox(height: 32),
                          RepaintBoundary(
                            child: GradientButton(
                              buttonText: '비밀번호 변경',
                              buttonColor: const Color(0xFF005FB8),
                              onTap: () async {
                                await showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => PasswordChangeDialog(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          RepaintBoundary(
                            child: GradientButton(
                              buttonText: '로그아웃',
                              onTap: () async {
                                await Get.find<UserController>().logout();
                                Get.offAllNamed(LoginPage.routeName);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePhone() async {
    final digits = _phoneController.text.replaceAll('-', '');
    if (digits.length != 11) {
      Utils.showSnackBar('11자리 숫자를 정확히 입력하세요.', isError: true);
      _phoneFocusNode.requestFocus();
      return;
    }
    final ok = await Get.find<UserController>().reqChangePhoneNumber({
      'id': Get.find<UserController>().loginUser!.id,
      'phoneNumber': digits,
    });
    if (ok) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NotiDialog(
          message: '개인 정보가 변경되었습니다.',
          addMessage: '연락처 정보가 변경되었습니다.',
        ),
      );
    }
  }
}

class _NoBounceBehavior extends ScrollBehavior {
  const _NoBounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
