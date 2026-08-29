import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/district.dart';
import '../models/landmark.dart';
import '../models/lat_lng.dart';

/// 위/경도 좌표를 다이어그램 내부 평면 좌표로 변환하는 간단한 투영기.
/// 대상 지역이 좁아서(수도권 이내) 위선 보정만 한 등장방형 투영으로 충분합니다.
class DiagramProjection {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final double width;
  final double height;
  final double _lngScale;
  final double _latScale;

  DiagramProjection({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.width,
    required this.height,
  })  : _lngScale = math.cos((minLat + maxLat) / 2 * math.pi / 180),
        _latScale = 1;

  /// 좌표 목록을 모두 담는 경계 상자로부터, 지정한 여백을 두고 [width]x[height] 캔버스에
  /// 맞는 투영기를 만듭니다.
  factory DiagramProjection.fitBounds({
    required Iterable<LatLng> points,
    required double width,
    required double height,
    double paddingFraction = 0.08,
  }) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
      maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
      minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
      maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
    }
    minLat ??= 0;
    maxLat ??= 0;
    minLng ??= 0;
    maxLng ??= 0;

    final latPad = (maxLat - minLat) * paddingFraction;
    final lngPad = (maxLng - minLng) * paddingFraction;

    return DiagramProjection(
      minLat: minLat - latPad,
      maxLat: maxLat + latPad,
      minLng: minLng - lngPad,
      maxLng: maxLng + lngPad,
      width: width,
      height: height,
    );
  }

  Offset project(LatLng point) {
    final lngSpan = (maxLng - minLng) * _lngScale;
    final latSpan = (maxLat - minLat) * _latScale;
    if (lngSpan <= 0 || latSpan <= 0) return Offset(width / 2, height / 2);

    // 가로/세로 중 더 촘촘한 쪽 기준으로 스케일을 맞춰 종횡비를 유지합니다.
    final scale = math.min(width / lngSpan, height / latSpan);
    final contentWidth = lngSpan * scale;
    final contentHeight = latSpan * scale;
    final offsetX = (width - contentWidth) / 2;
    final offsetY = (height - contentHeight) / 2;

    final x = (point.longitude - minLng) * _lngScale * scale + offsetX;
    final y = (maxLat - point.latitude) * _latScale * scale + offsetY;
    return Offset(x, y);
  }
}

/// 그려질 도로 구간 하나 (좌표 + 색상).
class RoadSegment {
  final String roadName;
  final List<LatLng> points;
  final Color color;
  final bool congested;

  /// 이 구간의 실시간 속도(km/h). 조회 범위 밖이라 데이터가 없으면 null.
  final double? speedKmh;

  const RoadSegment({
    required this.roadName,
    required this.points,
    required this.color,
    this.congested = false,
    this.speedKmh,
  });
}

/// 클러스터에 포함된 도로 하나의 정체 정보.
class CongestedRoad {
  final String roadName;
  final double speedKmh;

  const CongestedRoad({required this.roadName, required this.speedKmh});
}

/// 화면에 가깝게 모여있는 정체 구간을 하나로 묶은 클러스터.
/// 경고 삼각형 하나가 이 클러스터 하나에 대응합니다.
class CongestionCluster {
  final Offset position;
  final List<CongestedRoad> roads;

  const CongestionCluster({required this.position, required this.roads});
}

/// [segments] 중 정체(congested) 구간들을, 서로 [clusterRadius] 이내에 있으면
/// 하나의 [CongestionCluster]로 묶어서 반환합니다. 지도가 지저분해지지 않도록
/// 경고 삼각형을 그리기 전에 항상 이 함수로 먼저 묶습니다.
/// (그리기와 탭 판정이 같은 클러스터 목록을 써야 위치가 어긋나지 않습니다.)
List<CongestionCluster> buildCongestionClusters({
  required List<RoadSegment> segments,
  required DiagramProjection projection,
  required Size size,
}) {
  final points = <(Offset, CongestedRoad)>[
    for (final segment in segments)
      if (segment.congested && segment.points.isNotEmpty && segment.speedKmh != null)
        (
          projection.project(segment.points[segment.points.length ~/ 2]),
          CongestedRoad(roadName: segment.roadName, speedKmh: segment.speedKmh!),
        ),
  ];

  final clusterRadius = math.min(size.width, size.height) * 0.035 + 12;
  final clusters = <CongestionCluster>[];

  for (final (point, road) in points) {
    final index = clusters.indexWhere((c) => (c.position - point).distance < clusterRadius);
    if (index == -1) {
      clusters.add(CongestionCluster(position: point, roads: [road]));
    } else if (!clusters[index].roads.any((r) => r.roadName == road.roadName)) {
      clusters[index] = CongestionCluster(
        position: clusters[index].position,
        roads: [...clusters[index].roads, road],
      );
    }
  }

  return clusters;
}

class RoadDiagramPainter extends CustomPainter {
  final DiagramProjection projection;
  final List<RoadSegment> segments;
  final List<CongestionCluster> congestionClusters;
  final List<Landmark> landmarks;
  final List<District> districts;
  final List<LatLng> riverPolygon;
  final LatLng? myLocation;
  final double? myHeading;

  RoadDiagramPainter({
    required this.projection,
    required this.segments,
    required this.congestionClusters,
    this.landmarks = const [],
    this.districts = const [],
    this.riverPolygon = const [],
    this.myLocation,
    this.myHeading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF5F2EA);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // 자치구 경계 (매우 간략한 회색 윤곽선) — 도로보다 먼저 그려 배경처럼 깔립니다.
    for (final district in districts) {
      if (district.boundary.length < 2) continue;
      final path = Path();
      final first = projection.project(district.boundary.first);
      path.moveTo(first.dx, first.dy);
      for (final point in district.boundary.skip(1)) {
        final offset = projection.project(point);
        path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      final bold = district.emphasis == DistrictEmphasis.bold;
      canvas.drawPath(
        path,
        Paint()
          ..color = bold ? const Color(0xFFA79A72) : const Color(0xFFCFC8B0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bold ? 2.4 : 1,
      );
    }

    // 한강 (강변북로/올림픽대로 두 도로 좌표 사이 영역을 옅은 파랑으로 채워
    // 아주 간략하게 표현합니다).
    if (riverPolygon.length >= 3) {
      final path = Path();
      final first = projection.project(riverPolygon.first);
      path.moveTo(first.dx, first.dy);
      for (final point in riverPolygon.skip(1)) {
        final offset = projection.project(point);
        path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFBFD8E8));
    }

    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final path = Path();
      final first = projection.project(segment.points.first);
      path.moveTo(first.dx, first.dy);
      for (final point in segment.points.skip(1)) {
        final offset = projection.project(point);
        path.lineTo(offset.dx, offset.dy);
      }

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }

    for (final landmark in landmarks) {
      _drawLandmark(canvas, projection.project(landmark.position), landmark);
    }

    for (final cluster in congestionClusters) {
      _drawWarningTriangle(canvas, cluster.position);
    }

    final location = myLocation;
    if (location != null) {
      _drawMyLocation(canvas, projection.project(location), myHeading);
    }
  }

  void _drawLandmark(Canvas canvas, Offset center, Landmark landmark) {
    final isJunction = landmark.type == LandmarkType.junction;
    final dotColor = isJunction
        ? const Color(0xFF1B4F8C) // 국도 표지판 파랑 — 분기점/IC
        : const Color(0xFF8A6B3E); // 다리 난간을 연상시키는 갈색 — 교량

    canvas.drawCircle(center, 3.5, Paint()..color = dotColor);
    canvas.drawCircle(
      center,
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: landmark.name,
        style: TextStyle(
          color: dotColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          backgroundColor: const Color(0xCCF3F1EA),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center.dx + 5, center.dy - textPainter.height / 2));
  }

  void _drawWarningTriangle(Canvas canvas, Offset center) {
    const size = 11.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx - size * 0.9, center.dy + size * 0.7)
      ..lineTo(center.dx + size * 0.9, center.dy + size * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFD64545));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2 + 1),
    );
  }

  void _drawMyLocation(Canvas canvas, Offset center, double? heading) {
    canvas.drawCircle(center, 12, Paint()..color = const Color(0xFF1B4F8C).withValues(alpha: 0.25));
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF1B4F8C));
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (heading != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(heading * math.pi / 180);
      final arrow = Path()
        ..moveTo(0, -16)
        ..lineTo(-5, -8)
        ..lineTo(5, -8)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0xFF0F3760));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RoadDiagramPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.congestionClusters != congestionClusters ||
        oldDelegate.landmarks != landmarks ||
        oldDelegate.districts != districts ||
        oldDelegate.riverPolygon != riverPolygon ||
        oldDelegate.myLocation != myLocation ||
        oldDelegate.myHeading != myHeading;
  }
}
