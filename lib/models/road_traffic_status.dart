import 'package:flutter/material.dart';

/// 도로 하나의 현재 소통 상태(구간 평균).
class RoadTrafficStatus {
  final String roadName;
  final double averageSpeedKmh;
  final int linkCount;

  const RoadTrafficStatus({
    required this.roadName,
    required this.averageSpeedKmh,
    required this.linkCount,
  });

  TrafficLevel get level {
    if (averageSpeedKmh < 20) return TrafficLevel.congested;
    if (averageSpeedKmh < 40) return TrafficLevel.slow;
    return TrafficLevel.smooth;
  }
}

/// 소통 상태 단계. 임계값은 일반적인 기준을 단순화한 근사치입니다.
enum TrafficLevel {
  smooth('원활', Colors.green),
  slow('서행', Colors.orange),
  congested('정체', Colors.red);

  final String label;
  final Color color;

  const TrafficLevel(this.label, this.color);
}
