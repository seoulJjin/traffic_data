import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  const RoadSegment({
    required this.roadName,
    required this.points,
    required this.color,
    this.congested = false,
  });
}

class RoadDiagramPainter extends CustomPainter {
  final DiagramProjection projection;
  final List<RoadSegment> segments;
  final LatLng? myLocation;
  final double? myHeading;

  RoadDiagramPainter({
    required this.projection,
    required this.segments,
    this.myLocation,
    this.myHeading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF3F1EA);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

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

    // 가까운 정체 구간끼리는 삼각형 하나로 묶어서(클러스터링) 화면이 지저분해지지 않게 합니다.
    final congestedPoints = <Offset>[
      for (final segment in segments)
        if (segment.congested && segment.points.isNotEmpty)
          projection.project(segment.points[segment.points.length ~/ 2]),
    ];
    final clusterRadius = math.min(size.width, size.height) * 0.035 + 12;
    final clusters = <Offset>[];
    for (final point in congestedPoints) {
      final hasNearbyCluster =
          clusters.any((c) => (c - point).distance < clusterRadius);
      if (!hasNearbyCluster) clusters.add(point);
    }
    for (final cluster in clusters) {
      _drawWarningTriangle(canvas, cluster);
    }

    final location = myLocation;
    if (location != null) {
      _drawMyLocation(canvas, projection.project(location), myHeading);
    }
  }

  void _drawWarningTriangle(Canvas canvas, Offset center) {
    const size = 11.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx - size * 0.9, center.dy + size * 0.7)
      ..lineTo(center.dx + size * 0.9, center.dy + size * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.red.shade700);
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
    canvas.drawCircle(center, 12, Paint()..color = Colors.blue.withValues(alpha: 0.25));
    canvas.drawCircle(center, 8, Paint()..color = Colors.blue.shade700);
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
      canvas.drawPath(arrow, Paint()..color = Colors.blue.shade900);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant RoadDiagramPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.myLocation != myLocation ||
        oldDelegate.myHeading != myHeading;
  }
}
