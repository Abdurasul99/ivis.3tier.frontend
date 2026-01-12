import 'package:get/get.dart';

import '../../model/vehicle_model.dart';
import '../repository/vehicle_repository.dart';
import 'user_controller.dart';

class VehicleController extends GetxController {
  final VehicleRepository vehicleRepository = VehicleRepository();

  List<Vehicle> vehiclesInternal = <Vehicle>[];
  Vehicle? selectedInternalVehicle;

  List<Vehicle> get vehicles => vehiclesInternal;
  Vehicle? get selectedVehicle => selectedInternalVehicle;
  int? get selectedVehicleId => selectedInternalVehicle?.vehicleId;

  bool get hasToken {
    try {
      String? accessToken = Get.find<UserController>().accessToken;
      return accessToken != null && accessToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reqLoadVehicles() async {
    return requestVehicleList();
  }

  Future<bool> requestVehicleList() async {
    if (!hasToken) {
      vehiclesInternal = <Vehicle>[];
      selectedInternalVehicle = null;
      update();
      return false;
    }

    try {
      List<Vehicle> vehicleList = await vehicleRepository.requestVehicleList();
      vehiclesInternal = vehicleList;

      if (vehiclesInternal.isNotEmpty && selectedInternalVehicle == null) {
        selectedInternalVehicle = vehiclesInternal.first;
      }

      update();
      return true;
    } catch (_) {
      vehiclesInternal = <Vehicle>[];
      selectedInternalVehicle = null;
      update();
      return false;
    }
  }

  void selectVehicle(Vehicle vehicle) {
    selectedInternalVehicle = vehicle;
    update();
  }
}
