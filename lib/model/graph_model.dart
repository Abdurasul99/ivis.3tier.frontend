import 'package:fl_chart/fl_chart.dart';

class GraphPoint {
  final String label;

  final double value;

  GraphPoint({
    required this.label,
    required this.value,
  });

  /// Creates a [GraphPoint] from JSON.
  factory GraphPoint.fromJson(Map<String, dynamic> json) {
    return GraphPoint(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'GraphPoint(label: $label, value: $value)';
  }
}

class GraphModel {
  final List<GraphPoint> points;

  final double total;

  final String unit;

  GraphModel({
    this.points = const [],
    this.total = 0.0,
    this.unit = '',
  });

  /// Creates a [GraphModel] from JSON.
  factory GraphModel.fromJson(Map<String, dynamic> json) {
    return GraphModel(
      points: (json['points'] as List).map((e) => GraphPoint.fromJson(e)).toList(),
      total: (json['total'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  @override
  String toString() {
    return 'GraphModel{points: $points, total: $total, unit: $unit}';
  }
}

class ChartItem {
  String? date;
  double? distance;
  double? time;
  double? battery;

  ChartItem({this.date, this.distance, this.time, this.battery});

  ChartItem.fromJson(Map<String, dynamic> json) {
    date = (json['date'] ?? "").toString();
    distance = json['distance'] ?? 0;
    time = json['time'] ?? 0;
    battery = json['battery'] ?? 0;
  }

  @override
  String toString() {
    return 'ChartItem{date: $date, distance: $distance, time: $time, battery: $battery}';
  }
}

class BarChartBase {
  double? maxY;
  double? sumOfValue;
  List<String>? titles;
  List<BarChartGroupData>? barChartItems;

  BarChartBase({this.maxY, this.sumOfValue, this.titles, this.barChartItems});

  @override
  String toString() {
    return 'BarChartBase{maxY: $maxY, sumOfValue: $sumOfValue, titles: $titles, barChartItems: $barChartItems}';
  }
}
