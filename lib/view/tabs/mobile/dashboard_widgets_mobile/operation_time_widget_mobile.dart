import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';

class OperationTimeWidgetMobile extends StatefulWidget {
  const OperationTimeWidgetMobile({super.key});

  @override
  State<OperationTimeWidgetMobile> createState() => _OperationTimeWidgetMobileState();
}

class _OperationTimeWidgetMobileState extends State<OperationTimeWidgetMobile> {
  @override
  void initState() {
    super.initState();
    Get.find<GraphController>().makeTotalValues();
  }

  Future<void> _refresh() async {
    await Get.find<GraphController>().makeTotalValues();
  }

  @override
  Widget build(BuildContext context) {
    final robots = Get.find<RobotController>().robots;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '전체 로봇의 누적 운영시간',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF666565)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GetBuilder<GraphController>(
              init: GraphController(),
              builder: (controller) {
                if (controller.isLoadingTotal) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final totalTime = controller.totalTime;
                if (robots.isEmpty || totalTime.isEmpty) {
                  return Center(
                    child: Text(
                      '운영시간 정보가 없습니다 😑',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kHintColor),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: (robots.length / 2).ceil(),
                    itemBuilder: (_, idx) {
                      final firstIndex = idx * 2;
                      final secondIndex = firstIndex + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildRobotItem(
                                robots[firstIndex],
                                totalTime[robots[firstIndex].id] ?? 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: secondIndex < robots.length
                                  ? _buildRobotItem(
                                      robots[secondIndex],
                                      totalTime[robots[secondIndex].id] ?? 0,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRobotItem(Robot robot, double time) {
    final t = time.round();
    final h = t ~/ 3600;
    final m = (t % 3600) ~/ 60;
    final s = t % 60;
    final formatted = '${h > 0 ? '$h시간 ' : ''}${m.toString().padLeft(2, '0')}분 ${s.toString().padLeft(2, '0')}초';

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ExtendedImage.network(
                robot.imageUrl ?? robot.typeImageUrl ?? '',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${robot.typeDescription}_${robot.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                formatted,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
