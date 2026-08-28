import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

  TrafficLevel get level => TrafficLevel.fromSpeedKmh(averageSpeedKmh);
}

/// 소통 상태 단계. 임계값은 일반적인 기준을 단순화한 근사치입니다.
enum TrafficLevel {
  smooth('원활', AppColors.signalSmooth),
  slow('서행', AppColors.signalSlow),
  congested('정체', AppColors.signalCongested);

  final String label;
  final Color color;

  const TrafficLevel(this.label, this.color);

  static TrafficLevel fromSpeedKmh(double speedKmh) {
    if (speedKmh < 20) return TrafficLevel.congested;
    if (speedKmh < 40) return TrafficLevel.slow;
    return TrafficLevel.smooth;
  }
}
