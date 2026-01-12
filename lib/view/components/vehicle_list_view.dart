import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ivis/viewmodel/controller/vehicle_controller.dart';
import 'package:ivis/model/vehicle_model.dart';

class VehicleListView extends StatefulWidget {
  const VehicleListView({super.key, this.initialCollapsed = false});

  final bool initialCollapsed;

  @override
  State<VehicleListView> createState() => _VehicleListViewState();
}

class _VehicleListViewState extends State<VehicleListView> {
  static const Color primaryBlue = Color(0xFF0A84FF);
  static const Color backgroundWhite = Colors.white;
  static const Color borderColor = Color(0xFFDCE3EC);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color subtitleGray = Color(0xFF6E6E73);

  final TextEditingController searchTextEditingController = TextEditingController();

  double panelWidth = 300;
  bool collapsed = false;

  @override
  void initState() {
    super.initState();
    collapsed = widget.initialCollapsed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final VehicleController controller = Get.find<VehicleController>();
        if (controller.vehicles.isEmpty) {
          controller.requestVehicleList();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    searchTextEditingController.dispose();
    super.dispose();
  }

  String _displayName(Vehicle vehicle) {
    final String make = (vehicle.make ?? '').trim();
    final String modelName = (vehicle.modelName ?? '').trim();
    if (make.isNotEmpty || modelName.isNotEmpty) {
      return <String>[make, modelName].where((String element) => element.isNotEmpty).join(' ');
    }
    return 'Vehicle ${vehicle.vehicleId ?? ''}';
  }

  String _subtitle(Vehicle vehicle) {
    final String vehicleType = (vehicle.vehicleType ?? 'unknown');
    final String state = (vehicle.state ?? '').trim();
    final String idText = (vehicle.vehicleId?.toString() ?? '-');
    final String stateTail = state.isEmpty ? '' : ' • $state';
    return '$vehicleType • id=$idText$stateTail';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: collapsed ? 64 : panelWidth,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(collapsed ? 6 : 12, 12, collapsed ? 6 : 12, 8),
              decoration: const BoxDecoration(
                color: backgroundWhite,
                border: Border(
                  right: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: GetBuilder<VehicleController>(
                builder: (VehicleController controller) {
                  final String queryText = searchTextEditingController.text.trim().toLowerCase();

                  final List<Vehicle> filteredVehicles = controller.vehicles.where((Vehicle vehicle) {
                    if (queryText.isEmpty) {
                      return true;
                    }
                    final String vehicleIdText = (vehicle.vehicleId?.toString() ?? '').toLowerCase();
                    final String displayNameText = _displayName(vehicle).toLowerCase();
                    final String vehicleTypeText = (vehicle.vehicleType ?? '').toLowerCase();
                    final String stateText = (vehicle.state ?? '').toLowerCase();
                    final String makeText = (vehicle.make ?? '').toLowerCase();
                    final String modelNameText = (vehicle.modelName ?? '').toLowerCase();

                    return vehicleIdText.contains(queryText) ||
                        displayNameText.contains(queryText) ||
                        vehicleTypeText.contains(queryText) ||
                        stateText.contains(queryText) ||
                        makeText.contains(queryText) ||
                        modelNameText.contains(queryText);
                  }).toList();

                  final Vehicle? selectedVehicle = controller.selectedVehicle;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (!collapsed)
                            const Text(
                              'Vehicles',
                              style: TextStyle(
                                fontFamily: 'pretendard',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            )
                          else
                            const Icon(
                              Icons.router,
                              size: 20,
                              color: primaryBlue,
                            ),
                          const Spacer(),
                          if (!collapsed)
                            IconButton(
                              tooltip: 'Refresh',
                              onPressed: controller.requestVehicleList,
                              icon: const Icon(
                                Icons.refresh,
                                size: 20,
                                color: primaryBlue,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                            ),
                          IconButton(
                            tooltip: collapsed ? 'Expand' : 'Collapse',
                            onPressed: () {
                              setState(() {
                                collapsed = !collapsed;
                              });
                            },
                            icon: Icon(
                              collapsed ? Icons.chevron_right : Icons.chevron_left,
                              size: 20,
                              color: primaryBlue,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!collapsed)
                        TextField(
                          controller: searchTextEditingController,
                          onChanged: (_) {
                            setState(() {});
                          },
                          cursorColor: textDark,
                          style: const TextStyle(
                            fontFamily: 'pretendard',
                            fontSize: 14,
                            color: textDark,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search id, make, model, type, state',
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: subtitleGray,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: primaryBlue),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      if (!collapsed) const SizedBox(height: 8),
                      if (!collapsed)
                        Row(
                          children: <Widget>[
                            _statChip('Total', controller.vehicles.length.toString()),
                            const SizedBox(width: 8),
                            _statChip('Shown', filteredVehicles.length.toString()),
                          ],
                        ),
                      if (!collapsed) const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: backgroundWhite,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: ListView.separated(
                            itemCount: filteredVehicles.length,
                            separatorBuilder: (_, int index) => const Divider(
                              height: 1,
                              color: borderColor,
                            ),
                            itemBuilder: (_, int index) {
                              final Vehicle vehicle = filteredVehicles[index];
                              final bool isSelectedVehicle = vehicle.vehicleId == selectedVehicle?.vehicleId;

                              return Material(
                                color: isSelectedVehicle ? primaryBlue.withOpacity(0.08) : backgroundWhite,
                                child: ListTile(
                                  dense: true,
                                  minLeadingWidth: 0,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: collapsed ? 8 : 12,
                                    vertical: 6,
                                  ),
                                  leading: Icon(
                                    isSelectedVehicle ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: isSelectedVehicle ? primaryBlue : subtitleGray,
                                  ),
                                  title: Text(
                                    collapsed ? '#${vehicle.vehicleId ?? ''}' : _displayName(vehicle),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'pretendard',
                                      fontSize: 15,
                                      fontWeight: isSelectedVehicle ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelectedVehicle ? primaryBlue : textDark,
                                    ),
                                  ),
                                  subtitle: collapsed
                                      ? null
                                      : Text(
                                          _subtitle(vehicle),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'pretendard',
                                            fontSize: 12,
                                            color: subtitleGray,
                                          ),
                                        ),
                                  onTap: () {
                                    controller.selectVehicle(vehicle);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                final double nextPanelWidth = (panelWidth + details.delta.dx).clamp(220, 520);
                setState(() {
                  panelWidth = nextPanelWidth;
                  collapsed = false;
                });
              },
              child: const SizedBox(width: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String labelText, String valueText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            labelText,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 13,
              color: subtitleGray,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            valueText,
            style: const TextStyle(
              fontFamily: 'pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }
}
