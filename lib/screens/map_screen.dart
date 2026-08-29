import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_fonts/google_fonts.dart';

import '../models/district.dart';
import '../models/landmark.dart';
import '../models/lat_lng.dart';
import '../models/region.dart';
import '../models/road_link_geometry.dart';
import '../models/road_traffic_status.dart';
import '../services/district_repository.dart';
import '../services/its_traffic_service.dart';
import '../services/landmark_repository.dart';
import '../services/location_service.dart';
import '../services/road_geometry_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/road_diagram_painter.dart';
import '../widgets/road_sign_badge.dart';

/// 지도에서 도로 선 또는 정체 경고 삼각형을 탭했을 때 하단에 보여줄 정보.
class _SelectionInfo {
  final String title;
  final List<String> lines;

  const _SelectionInfo({required this.title, required this.lines});
}

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
  final _landmarkRepository = LandmarkRepository();
  final _districtRepository = DistrictRepository();
  final _locationService = LocationService();
  final _transformController = TransformationController();

  late Future<RegionTrafficData> _trafficFuture;
  List<RoadSegment> _segments = [];
  List<Landmark> _landmarks = [];
  List<District> _districts = [];
  List<LatLng> _riverPolygon = [];
  Map<String, RoadTrafficStatus> _statusByRoad = {};

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _myLocation;
  double? _myHeading;
  String? _focusedRoadName;
  _SelectionInfo? _selection;

  @override
  void initState() {
    super.initState();
    _trafficFuture = _load();
    _loadLandmarks();
    _loadDistricts();
    _startLocationTracking();
  }

  Future<void> _loadLandmarks() async {
    final landmarks = await _landmarkRepository.load();
    if (!mounted) return;
    setState(() => _landmarks = landmarks);
  }

  Future<void> _loadDistricts() async {
    final districts = await _districtRepository.loadForRegion(widget.region.name);
    if (!mounted) return;
    setState(() => _districts = districts);
  }

  /// 강변북로(북단)/올림픽대로(남단) 도로 좌표 사이 영역을 한강 모양으로
  /// 아주 간략하게 근사합니다. 두 도로가 모두 있을 때(서울 권역)만 값이 나옵니다.
  ///
  /// 원본 링크는 조각조각 나뉘어 있고 순서도 뒤섞여 있어, 단순히 경도 순으로만
  /// 정렬하면 위/경도가 들쭉날쭉해서 리본 폴리곤이 스스로 꼬입니다(자기교차).
  /// 그래서 경도 구간을 일정 폭으로 나눠(버킷) 구간별 평균 위도만 남기는 방식으로
  /// 각 강변을 "경도 하나당 위도 하나"인 매끄러운 곡선으로 만든 뒤 리본을 만듭니다.
  List<LatLng> _buildRiverPolygon(List<(String, RoadLinkGeometry)> links) {
    final northBank = <LatLng>[];
    final southBank = <LatLng>[];
    for (final (roadName, link) in links) {
      if (roadName == '강변북로') northBank.addAll(link.points);
      if (roadName == '올림픽대로') southBank.addAll(link.points);
    }
    if (northBank.isEmpty || southBank.isEmpty) return [];

    final northCurve = _smoothByLongitude(northBank);
    final southCurve = _smoothByLongitude(southBank);
    if (northCurve.isEmpty || southCurve.isEmpty) return [];

    return [...northCurve, ...southCurve.reversed];
  }

  /// [points]를 경도 기준 [bucketCount]개 구간으로 나눠 구간별 평균 좌표만 남긴,
  /// 경도 오름차순의 매끄러운 곡선을 반환합니다.
  List<LatLng> _smoothByLongitude(List<LatLng> points, {int bucketCount = 60}) {
    if (points.isEmpty) return [];
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final span = maxLng - minLng;
    if (span <= 0) return [];

    final sumLat = List<double>.filled(bucketCount, 0);
    final sumLng = List<double>.filled(bucketCount, 0);
    final count = List<int>.filled(bucketCount, 0);
    for (final p in points) {
      var bucket = ((p.longitude - minLng) / span * bucketCount).floor();
      if (bucket < 0) bucket = 0;
      if (bucket >= bucketCount) bucket = bucketCount - 1;
      sumLat[bucket] += p.latitude;
      sumLng[bucket] += p.longitude;
      count[bucket]++;
    }

    return [
      for (var i = 0; i < bucketCount; i++)
        if (count[i] > 0) LatLng(sumLat[i] / count[i], sumLng[i] / count[i]),
    ];
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
      _riverPolygon = _buildRiverPolygon(links);
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
            speedKmh: traffic.linkSpeeds[link.linkId],
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

  void _onDiagramTap(
    Offset localPosition,
    DiagramProjection projection,
    Size size,
    List<CongestionCluster> clusters,
  ) {
    // 경고 삼각형이 도로 선 위에 그려져 있으므로, 삼각형을 먼저 확인합니다.
    final triangleRadius = math.min(size.width, size.height) * 0.03 + 14;
    CongestionCluster? tappedCluster;
    double closestClusterDistance = double.infinity;
    for (final cluster in clusters) {
      final distance = (cluster.position - localPosition).distance;
      if (distance < triangleRadius && distance < closestClusterDistance) {
        closestClusterDistance = distance;
        tappedCluster = cluster;
      }
    }

    if (tappedCluster != null) {
      setState(() {
        _selection = _SelectionInfo(
          title: '정체 구간',
          lines: [
            for (final road in tappedCluster!.roads)
              '${road.roadName} - ${TrafficLevel.fromSpeedKmh(road.speedKmh).label} '
                  '(${road.speedKmh.toStringAsFixed(0)}km/h)',
          ],
        );
      });
      return;
    }

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

    setState(() {
      _selection = _SelectionInfo(
        title: closest!.roadName,
        lines: [_roadLine(closest.roadName)],
      );
    });
  }

  String _roadLine(String roadName) {
    final status = _statusByRoad[roadName];
    return status == null
        ? '$roadName - 현재 소통정보 없음'
        : '$roadName - ${status.level.label} (${status.averageSpeedKmh.toStringAsFixed(0)}km/h)';
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
                      // 도로를 선택해 확대했을 때는 다른 도로의 소통 정보가 섞여 보이지
                      // 않도록 선택한 도로만 그립니다.
                      final paintSegments = focused == null
                          ? _segments
                          : _segments.where((s) => s.roadName == focused).toList();
                      final clusters = buildCongestionClusters(
                        segments: paintSegments,
                        projection: projection,
                        size: size,
                      );
                      // 분기점/교량 이름은 도로를 하나 선택해 확대했을 때만 보여줍니다.
                      // 전체보기 상태에서 다 표시하면 글자가 너무 빽빽해집니다.
                      final visibleLandmarks = focused == null
                          ? const <Landmark>[]
                          : _landmarks
                              .where((l) =>
                                  l.position.latitude >= projection.minLat &&
                                  l.position.latitude <= projection.maxLat &&
                                  l.position.longitude >= projection.minLng &&
                                  l.position.longitude <= projection.maxLng)
                              .toList();

                      return InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1,
                        maxScale: 6,
                        child: GestureDetector(
                          onTapUp: (details) => _onDiagramTap(
                            details.localPosition,
                            projection,
                            size,
                            clusters,
                          ),
                          child: CustomPaint(
                            size: size,
                            painter: RoadDiagramPainter(
                              projection: projection,
                              segments: paintSegments,
                              congestionClusters: clusters,
                              landmarks: visibleLandmarks,
                              districts: _districts,
                              riverPolygon: _riverPolygon,
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
                      avatar: const Icon(Icons.zoom_out_map, size: 18, color: Colors.white),
                      label: Text(
                        '${_focusedRoadName!} · 전체보기',
                        style: GoogleFonts.notoSansKr(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.highwayGreen,
                      side: BorderSide.none,
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
          if (_selection != null) _SelectionBanner(
            selection: _selection!,
            onClose: () => setState(() => _selection = null),
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

/// 도로 선/정체 경고 삼각형을 탭했을 때, 목록 위에 고정으로 보여주는 설명 배너.
class _SelectionBanner extends StatelessWidget {
  final _SelectionInfo selection;
  final VoidCallback onClose;

  const _SelectionBanner({required this.selection, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFEFE9D8),
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selection.title,
                  style: GoogleFonts.blackHanSans(
                    fontSize: 17,
                    color: AppColors.asphalt,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in selection.lines)
                  Text(
                    line,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13.5,
                      color: AppColors.asphalt.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20, color: AppColors.asphalt),
            tooltip: '닫기',
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
                selectedTileColor: AppColors.highwayGreen.withValues(alpha: 0.08),
                onTap: () => onSelectRoad(status.roadName),
                leading: RoadSignBadge(roadName: status.roadName),
                title: Text(
                  status.roadName,
                  style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '구간 ${status.linkCount}곳 평균',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12.5,
                    color: AppColors.asphalt.withValues(alpha: 0.6),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status.level.label,
                      style: GoogleFonts.notoSansKr(
                        color: status.level.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${status.averageSpeedKmh.toStringAsFixed(0)}km/h',
                      style: GoogleFonts.notoSansKr(
                        color: AppColors.asphalt.withValues(alpha: 0.75),
                      ),
                    ),
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
