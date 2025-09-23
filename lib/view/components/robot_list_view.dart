import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/constants.dart';
import '../../model/robot_model.dart';
import '../../viewmodel/controller/robot_controller.dart';
import '../../viewmodel/controller/user_controller.dart';
import 'gradient_button.dart';
import 'input_edit_dropdown_multi_select.dart';

class RobotListView extends StatefulWidget {
  const RobotListView({
    super.key,
    this.onChanged,
    this.showAddRobotButton = false,
    this.onRobotButtonTap,
  });

  final ValueChanged<Robot>? onChanged;
  final bool showAddRobotButton;
  final GestureTapCallback? onRobotButtonTap;

  @override
  State<RobotListView> createState() => _RobotListViewState();
}

class _RobotListViewState extends State<RobotListView> {
  List<String> _filters = [];
  int? _selectedObjectId;

  @override
  void initState() {
    super.initState();
    loadRobotFilters();
  }

  void loadRobotFilters() {
    if (Get.find<RobotController>().robotTypes.isNotEmpty) {
      _filters = [];
      for (int i = 0; i < Get.find<RobotController>().robotTypes.length; i++) {
        if (Get.find<RobotController>().robotTypes[i].typeDescription == null ||
            Get.find<RobotController>().robotTypes[i].typeDescription!.isEmpty) {
          continue;
        }
        _filters.add(Get.find<RobotController>().robotTypes[i].typeDescription ?? "");
      }
    }

    if (Get.find<UserController>().loginUser != null) {
      if (Get.find<UserController>().loginUser!.role == "admin") {
        _filters.add("삭제됨");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(3, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: GetBuilder<RobotController>(
              init: RobotController(),
              builder: (controller) {
                loadRobotFilters();

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: InputEditDropDownMultiSelect(
                          hintText: 'Robot Filter',
                          items: _filters,
                          selectedItems: Get.find<RobotController>().robotFilter,
                          onChanged: (selectedItems) {
                            if (selectedItems.isEmpty) return;
                            Get.find<RobotController>().setRobotFilterStr(selectedItems);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: controller.robots.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Robot robot = controller.robots[index];
                          final bool isSelected = (robot.id == _selectedObjectId);
                          final bool isDeleted = robot.isDeleted ?? false;

                          RobotStatus? status;
                          for (int i = 0; i < controller.robotStatusList.length; i++) {
                            if (controller.robotStatusList[i].id == robot.id) {
                              status = controller.robotStatusList[i];
                              break;
                            }
                          }
                          if (status == null) return const SizedBox.shrink();

                          String location = "";
                          String battery = '-%';

                          if (isDeleted) {
                            battery = "-";
                            location = "-";
                          } else {
                            if (status.battery != null) {
                              battery = '${status.battery!.round()}%';
                            }
                            location = status.address ?? "-";
                          }

                          String statusStr = "";
                          Color statusColor = Colors.transparent;
                          if (isDeleted) {
                            statusStr = "삭제됨";
                            statusColor = const Color(0xFF1E1F50);
                          } else {
                            statusStr = kStateStr[status.robotStatus ?? 0];
                            statusColor = kStateColor[status.robotStatus ?? 0];
                          }

                          return GestureDetector(
                            onTap: () {
                              _selectedObjectId = robot.id;
                              widget.onChanged?.call(robot);
                            },
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFFF8FDFF)
                                  : isDeleted
                                      ? const Color(0xFFF0F0F0)
                                      : Colors.transparent,
                              child: Column(
                                children: [
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${robot.typeDescription}_${robot.name}",
                                          style: TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 15,
                                            color: isSelected ? const Color(0xFF005CB2) : Colors.black,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            statusStr,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w400,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    color: const Color(0xFFDBDBDB),
                                  ),
                                  // фикс overflow: вместо height -> minHeight
                                  Container(
                                    constraints: const BoxConstraints(minHeight: 100),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFDADADA)),
                                                image: DecorationImage(
                                                  image: ExtendedNetworkImageProvider(
                                                    robot.imageUrl ?? robot.typeImageUrl ?? '',
                                                    cache: true,
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            if (isDeleted)
                                              Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFDADADA)),
                                                  color: const Color(0xFFD9D9D9).withOpacity(0.5),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Battery",
                                                style: TextStyle(
                                                  fontFamily: 'pretendard',
                                                  fontSize: 13,
                                                  color: Color(0xFF666565),
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                battery,
                                                style: const TextStyle(
                                                  fontFamily: 'pretendard',
                                                  fontSize: 18,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                "Location",
                                                style: TextStyle(
                                                  fontFamily: 'pretendard',
                                                  fontSize: 13,
                                                  color: Color(0xFF666565),
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                location,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'pretendard',
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (Get.find<UserController>().isAdminUser() && widget.showAddRobotButton)
            SizedBox(
              width: 158,
              child: Container(
                height: 72,
                alignment: Alignment.center,
                child: GradientButton(
                  buttonText: "로봇 추가",
                  icon: const Icon(Icons.add, color: Colors.black, size: 18),
                  onTap: widget.onRobotButtonTap,
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
