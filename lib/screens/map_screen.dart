import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/lat_lng.dart';
import '../models/region.dart';
import '../models/road_traffic_status.dart';
import '../services/its_traffic_service.dart';
import '../services/location_service.dart';
import '../services/road_geometry_repository.dart';
import '../widgets/road_diagram_painter.dart';

/// 선택한 권역의 실시간 도로 소통 상태를, 실제 지도 대신
/// 도로 모양만 강조한 심플한 다이어그램으로 보여주는 화면.
/// (교통방송 상황판 스타일: 두꺼운 색상 선 + 정체 구간 경고 삼각형)
class MapScreen extends StatefulWidget {
  final Region region;

  const MapScreen({super.key, required this.region});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _trafficService = ItsTrafficService();
  final _geometryRepository = RoadGeometryRepository();
  final _locationService = LocationService();
  final _transformController = TransformationController();

  late Future<RegionTrafficData> _trafficFuture;
  List<RoadSegment> _segments = [];
  Map<String, RoadTrafficStatus> _statusByRoad = {};

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _myLocation;
  double? _myHeading;
  String? _focusedRoadName;

  @override
  void initState() {
    super.initState();
    _trafficFuture = _load();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  Future<RegionTrafficData> _load() async {
    final links = await _geometryRepository.geometriesFor(widget.region.roadNames);

    // 실시간 조회 범위를 화면에 그려질 도로 구간 전체를 덮도록 잡습니다.
    // (권역 중심 반경만 쓰면 올림픽대로처럼 넓게 퍼진 도로의 먼 구간은 조회에서 빠짐)
    double? minLat, maxLat, minLng, maxLng;
    for (final (_, link) in links) {
      for (final point in link.points) {
        minLat = (minLat == null || point.latitude < minLat) ? point.latitude : minLat;
        maxLat = (maxLat == null || point.latitude > maxLat) ? point.latitude : maxLat;
        minLng = (minLng == null || point.longitude < minLng) ? point.longitude : minLng;
        maxLng = (maxLng == null || point.longitude > maxLng) ? point.longitude : maxLng;
      }
    }
    final bbox = minLat == null
        ? null
        : (minX: minLng!, maxX: maxLng!, minY: minLat, maxY: maxLat!);

    final traffic =
        await _trafficService.fetchRegionTrafficData(widget.region, bbox: bbox);
    final statusByRoad = {for (final s in traffic.roadStatuses) s.roadName: s};

    if (!mounted) return traffic;
    setState(() {
      _statusByRoad = statusByRoad;
      _segments = [
        for (final (roadName, link) in links)
          RoadSegment(
            roadName: roadName,
            points: link.points,
            color: traffic.linkSpeeds[link.linkId] == null
                ? Colors.grey
                : TrafficLevel.fromSpeedKmh(traffic.linkSpeeds[link.linkId]!).color,
            congested: traffic.linkSpeeds[link.linkId] != null &&
                TrafficLevel.fromSpeedKmh(traffic.linkSpeeds[link.linkId]!) ==
                    TrafficLevel.congested,
          ),
      ];
    });

    return traffic;
  }

  void _refresh() {
    setState(() {
      _trafficFuture = _load();
    });
  }

  void _selectRoad(String roadName) {
    setState(() {
      _focusedRoadName = _focusedRoadName == roadName ? null : roadName;
    });
    // 새로 확대/전체보기로 전환할 때마다 기존 확대/이동 상태를 초기화합니다.
    _transformController.value = Matrix4.identity();
  }

  Future<void> _startLocationTracking() async {
    final granted = await _locationService.ensurePermission();
    if (!granted || !mounted) return;

    _positionSubscription = _locationService.positionStream().listen(
      (position) {
        if (!mounted) return;
        final current = LatLng(position.latitude, position.longitude);
        setState(() {
          _myLocation = widget.region.contains(current) ? current : null;
          _myHeading = position.speed > 0.5 && !position.heading.isNaN
              ? position.heading
              : _myHeading;
        });
      },
      onError: (_) {}, // 위치 조회 실패는 조용히 무시 (핵심 기능이 아님).
    );
  }

  Future<void> _goToMyLocation() async {
    final granted = await _locationService.ensurePermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다. 설정에서 허용해주세요.')));
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      if (!widget.region.contains(current)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('현재 위치가 이 권역 범위 밖에 있습니다.')));
        return;
      }

      setState(() => _myLocation = current);
      // 화면 확대 없이, 현재 위치가 표시된 것을 사용자가 바로 알아볼 수 있도록
      // 변환(확대/이동) 상태를 기본값으로 되돌립니다.
      _transformController.value = Matrix4.identity();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('현재 위치를 가져오지 못했습니다.')));
    }
  }

  void _onDiagramTap(Offset localPosition, DiagramProjection projection, Size size) {
    RoadSegment? closest;
    double closestDistance = double.infinity;

    for (final segment in _segments) {
      for (var i = 0; i < segment.points.length - 1; i++) {
        final a = projection.project(segment.points[i]);
        final b = projection.project(segment.points[i + 1]);
        final distance = _distanceToSegment(localPosition, a, b);
        if (distance < closestDistance) {
          closestDistance = distance;
          closest = segment;
        }
      }
    }

    // 화면 크기 대비 일정 거리 이내일 때만 탭으로 인정합니다.
    final threshold = math.min(size.width, size.height) * 0.03 + 10;
    if (closest == null || closestDistance > threshold) return;

    final status = _statusByRoad[closest.roadName];
    final message = status == null
        ? '${closest.roadName} - 현재 소통정보 없음'
        : '${closest.roadName} - ${status.level.label} (${status.averageSpeedKmh.toStringAsFixed(0)}km/h)';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared == 0) return (p - a).distance;

    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / abLengthSquared;
    t = t.clamp(0.0, 1.0);
    final projected = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projected).distance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.region.name),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      final focused = _focusedRoadName;
                      final boundsSegments = focused == null
                          ? _segments
                          : _segments.where((s) => s.roadName == focused);
                      final allPoints = boundsSegments.expand((s) => s.points);
                      final projection = DiagramProjection.fitBounds(
                        points: allPoints.isEmpty ? [widget.region.center] : allPoints,
                        width: size.width,
                        height: size.height,
                      );
                      final paintSegments = focused == null
                          ? _segments
                          : [
                              for (final s in _segments)
                                RoadSegment(
                                  roadName: s.roadName,
                                  points: s.points,
                                  color: s.roadName == focused
                                      ? s.color
                                      : s.color.withValues(alpha: 0.2),
                                  congested: s.congested,
                                ),
                            ];

                      return InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1,
                        maxScale: 6,
                        child: GestureDetector(
                          onTapUp: (details) =>
                              _onDiagramTap(details.localPosition, projection, size),
                          child: CustomPaint(
                            size: size,
                            painter: RoadDiagramPainter(
                              projection: projection,
                              segments: paintSegments,
                              myLocation: _myLocation,
                              myHeading: _myHeading,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_focusedRoadName != null)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: ActionChip(
                      avatar: const Icon(Icons.zoom_out_map, size: 18),
                      label: Text('${_focusedRoadName!} · 전체보기'),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onPressed: () => _selectRoad(_focusedRoadName!),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'my_location_button',
                    onPressed: _goToMyLocation,
                    tooltip: '현재 위치로 이동',
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: _RoadStatusPanel(
              trafficFuture: _trafficFuture,
              onRetry: _refresh,
              focusedRoadName: _focusedRoadName,
              onSelectRoad: _selectRoad,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadStatusPanel extends StatelessWidget {
  final Future<RegionTrafficData> trafficFuture;
  final VoidCallback onRetry;
  final String? focusedRoadName;
  final ValueChanged<String> onSelectRoad;

  const _RoadStatusPanel({
    required this.trafficFuture,
    required this.onRetry,
    required this.focusedRoadName,
    required this.onSelectRoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: FutureBuilder<RegionTrafficData>(
        future: trafficFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('교통정보를 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
                ],
              ),
            );
          }

          final statuses = snapshot.data?.roadStatuses ?? [];
          if (statuses.isEmpty) {
            return const Center(child: Text('현재 조회된 도로 소통정보가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: statuses.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final status = statuses[index];
              final selected = status.roadName == focusedRoadName;
              return ListTile(
                selected: selected,
                selectedTileColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                onTap: () => onSelectRoad(status.roadName),
                leading: CircleAvatar(
                  backgroundColor: status.level.color,
                  radius: 8,
                  child: const SizedBox.shrink(),
                ),
                title: Text(status.roadName),
                subtitle: Text('구간 ${status.linkCount}곳 평균'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status.level.label,
                      style: TextStyle(
                        color: status.level.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${status.averageSpeedKmh.toStringAsFixed(0)}km/h'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
