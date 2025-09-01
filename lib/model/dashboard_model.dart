class DashboardWidget {
  String? displayInfo;
  String? displayMethod;
  String? period;
  DashboardWidget({this.displayInfo = "", this.displayMethod = "", this.period = ""});

  Map<String, dynamic> toJson() {
    return {
      "displayInfo": displayInfo,
      "displayMethod": displayMethod,
      "period": period,
    };
  }

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      displayInfo: json["displayInfo"] ?? "",
      displayMethod: json["displayMethod"] ?? "",
      period: json["period"] ?? "",
    );
  }
}

class DashboardLayout {
  int? numColumns;
  List<DashboardWidget>? widgets;

  DashboardLayout({
    this.numColumns,
    this.widgets,
  });

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    List<DashboardWidget>? widgetList = [];
    widgetList = (json['widgets'] as List).map((i) => DashboardWidget.fromJson(i)).toList();

    return DashboardLayout(
      numColumns: json["numColumns"] ?? "",
      widgets: widgetList,
    );
  }
}

class RobotSuccessData {
  int objectId;
  String robotName;
  double successRate;
  RobotSuccessData({this.objectId = 0, this.robotName = '', this.successRate = 0.0});

  factory RobotSuccessData.fromJson(Map<String, dynamic> json) {
    double rate;
    if (json['successRate'] is String) {
      rate = double.tryParse(json['successRate']) ?? 0.0;
    } else if (json['successRate'] is num) {
      rate = (json['successRate'] as num).toDouble();
    } else {
      rate = 0.0;
    }
    return RobotSuccessData(
      objectId: json["objectId"] ?? 0,
      robotName: json["robotName"] ?? "",
      successRate: rate,
    );
  }
}

class DeviceStatusData {
  int? runningCount;
  int? chargingCount;
  int? errorCount;
  DeviceStatusData({this.runningCount = 0, this.chargingCount = 0, this.errorCount = 0});

  factory DeviceStatusData.fromJson(Map<String, dynamic> json) {
    return DeviceStatusData(
      runningCount: json["runningCount"] ?? 0,
      chargingCount: json["chargingCount"] ?? 0,
      errorCount: json["errorCount"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "runningCount": runningCount,
      "chargingCount": chargingCount,
      "errorCount": errorCount,
    };
  }
}

class LayoutSet {
  int? id;
  int? userId;
  String? title;
  int? rowIndex;
  int? columnIndex;
  String? period;
  String? displayMethod;

  LayoutSet({
    this.id,
    this.userId,
    this.title,
    this.rowIndex,
    this.columnIndex,
    this.period,
    this.displayMethod,
  });

  LayoutSet.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    title = json['title'] ?? "";
    rowIndex = json['row_index'];
    columnIndex = json['column_index'];
    period = json['period'] ?? "";
    displayMethod = json['display_method'] ?? "";
  }

  @override
  String toString() {
    return 'LayoutSet{id: $id, userId: $userId, title: $title, rowIndex: $rowIndex, columnIndex: $columnIndex, period: $period, displayMethod: $displayMethod}';
  }
}
