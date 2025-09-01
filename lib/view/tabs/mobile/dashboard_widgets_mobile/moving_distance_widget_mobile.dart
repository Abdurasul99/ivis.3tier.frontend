import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fms/constants/constants.dart';
import 'package:fms/model/robot_model.dart';
import 'package:fms/utils/utils.dart';
import 'package:fms/viewmodel/controller/graph_controller.dart';
import 'package:fms/viewmodel/controller/robot_controller.dart';
import 'package:get/get.dart';

class MovingDistanceWidgetMobile extends StatefulWidget {
  const MovingDistanceWidgetMobile({super.key});

  @override
  State<MovingDistanceWidgetMobile> createState() => _MovingDistanceWidgetMobileState();
}

class _MovingDistanceWidgetMobileState extends State<MovingDistanceWidgetMobile> {
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
    final robots = Get.find<RobotController>().unDeletedRobots;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '전체 로봇의 누적 주행거리',
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
                final totalDist = controller.totalDistance;
                if (robots.isEmpty || totalDist.isEmpty) {
                  return Center(
                    child: Text(
                      '주행 정보가 없습니다 😑',
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
                      final first = idx * 2;
                      final second = first + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildRobotItem(
                                robots[first],
                                totalDist[robots[first].id] ?? 0.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: second < robots.length
                                  ? _buildRobotItem(
                                      robots[second],
                                      totalDist[robots[second].id] ?? 0.0,
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

  Widget _buildRobotItem(Robot robot, double dist) {
    final val = (robot.typeDescription?.toLowerCase() == 'untact')
        ? ((dist / 10000 * 100).roundToDouble() / 100)
        : (dist * 100).roundToDouble() / 100;
    final suffix = robot.typeDescription?.toLowerCase() == 'untact' ? 'km' : 'm';
    final text = '${Utils.doubleWithComma(val)}$suffix';

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
                text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
