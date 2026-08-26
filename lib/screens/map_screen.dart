import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/region.dart';
import '../models/road_link_geometry.dart';
import '../models/road_traffic_status.dart';
import '../services/its_traffic_service.dart';
import '../services/location_service.dart';
import '../services/road_geometry_repository.dart';

/// 선택한 권역을 중심으로 카카오맵과 실시간 도로 소통 상태를 보여주는 화면.
/// 지도 위에는 실제 도로 모양을 따라 구간별 소통 상태 색상 선을 그리고,
/// 폴리라인은 탭 이벤트를 지원하지 않는 SDK 제약 때문에 도로마다 탭 가능한 마커를 함께 놓습니다.
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

  // 소통 상태 색상별 마커 아이콘 캐시 (매번 위젯을 이미지로 다시 그리지 않도록).
  static final Map<Color, Future<KImage>> _markerIconCache = {};
  static Future<KImage>? _myLocationIconCache;

  late Future<RegionTrafficData> _trafficFuture;
  KakaoMapController? _mapController;
  ShapeController? _shapeController;
  LabelController? _labelController;
  LabelController? _myLocationLayer;
  Poi? _myLocationPoi;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _trafficFuture = _trafficService.fetchRegionTrafficData(widget.region);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _trafficFuture = _trafficService.fetchRegionTrafficData(widget.region);
    });
    _drawRoadOverlays();
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _mapController = controller;
    _shapeController = await controller.addShapeLayer('road_status_layer');
    _labelController = await controller.addLabelLayer('road_marker_layer');
    _myLocationLayer = await controller.addLabelLayer('my_location_layer');
    await _drawRoadOverlays();
    await _startLocationTracking();
  }

  Future<KImage> _myLocationIcon() {
    return _myLocationIconCache ??= KImage.fromWidget(
      Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.navigation, color: Colors.white, size: 18),
      ),
      const Size(32, 32),
    );
  }

  Future<void> _startLocationTracking() async {
    final granted = await _locationService.ensurePermission();
    if (!granted || !mounted) return;

    _positionSubscription = _locationService.positionStream().listen(
      _onPositionUpdate,
      onError: (_) {}, // 위치 조회 실패는 조용히 무시 (핵심 기능이 아님).
    );
  }

  Future<void> _onPositionUpdate(Position position) async {
    final mapController = _mapController;
    final myLocationLayer = _myLocationLayer;
    if (mapController == null || myLocationLayer == null) return;

    final current = LatLng(position.latitude, position.longitude);
    final inRegion = widget.region.contains(current);

    if (!inRegion) {
      if (_isTracking) {
        _isTracking = false;
        await mapController.tracking.stop();
        await _myLocationPoi?.hide();
      }
      return;
    }

    if (_myLocationPoi == null) {
      final icon = await _myLocationIcon();
      _myLocationPoi = await myLocationLayer.addPoi(
        current,
        style: PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5)),
        id: 'my_location',
      );
    } else {
      await _myLocationPoi!.show();
      await _myLocationPoi!.move(current, 500);
    }

    // 이동 중(속도가 유의미할 때)에만 방향을 갱신합니다. 정지 시 GPS heading은 노이즈가 큽니다.
    if (position.speed > 0.5 && !position.heading.isNaN) {
      await _myLocationPoi!.rotate(position.heading, 300);
    }

    if (!_isTracking) {
      _isTracking = true;
      mapController.tracking.poi = _myLocationPoi;
      await mapController.tracking.start();
      await mapController.tracking.setTrackingRotate(true);
    }
  }

  Future<KImage> _markerIcon(Color color) {
    return _markerIconCache.putIfAbsent(
      color,
      () => KImage.fromWidget(
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const Size(22, 22),
      ),
    );
  }

  Future<void> _showRoadInfo(String roadName, RoadTrafficStatus? status) async {
    if (!mounted) return;
    final message = status == null
        ? '$roadName - 현재 소통정보 없음'
        : '$roadName - ${status.level.label} (${status.averageSpeedKmh.toStringAsFixed(0)}km/h)';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _drawRoadOverlays() async {
    final mapController = _mapController;
    if (mapController == null) return;

    // 이전에 그린 선/마커가 남아있지 않도록 레이어를 새로 만듭니다.
    if (_shapeController != null) {
      await mapController.removeShapeLayer(_shapeController!);
    }
    if (_labelController != null) {
      await mapController.removeLabelLayer(_labelController!);
    }
    final uniqueSuffix = DateTime.now().microsecondsSinceEpoch;
    final shapeController =
        await mapController.addShapeLayer('road_status_layer_$uniqueSuffix');
    final labelController =
        await mapController.addLabelLayer('road_marker_layer_$uniqueSuffix');
    _shapeController = shapeController;
    _labelController = labelController;

    final links = await _geometryRepository.geometriesFor(widget.region.roadNames);
    final traffic = await _trafficFuture;
    final statusByRoad = {for (final s in traffic.roadStatuses) s.roadName: s};

    // 도로명별로 가장 긴 구간을 찾아 마커 위치(중간 지점)로 사용합니다.
    final longestLinkByRoad = <String, RoadLinkGeometryWithRoad>{};

    for (final (roadName, link) in links) {
      final speed = traffic.linkSpeeds[link.linkId];
      final color = speed == null ? Colors.grey : TrafficLevel.fromSpeedKmh(speed).color;

      await shapeController.addPolylineShape(
        MapPoint(link.points),
        PolylineStyle(color, 6),
        PolylineCap.round,
        id: '${roadName}_${link.linkId}',
      );

      final current = longestLinkByRoad[roadName];
      if (current == null || link.points.length > current.link.points.length) {
        longestLinkByRoad[roadName] = (roadName: roadName, link: link);
      }
    }

    for (final entry in longestLinkByRoad.values) {
      final status = statusByRoad[entry.roadName];
      final midpoint = entry.link.points[entry.link.points.length ~/ 2];
      final icon = await _markerIcon(status?.level.color ?? Colors.grey);

      await labelController.addPoi(
        midpoint,
        style: PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5)),
        id: 'marker_${entry.roadName}',
        onClick: () => _showRoadInfo(entry.roadName, status),
      );
    }
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
            child: KakaoMap(
              option: KakaoMapOption(
                position: widget.region.center,
                zoomLevel: 14,
                mapType: MapType.normal,
              ),
              onMapReady: _onMapReady,
            ),
          ),
          SizedBox(
            height: 220,
            child: _RoadStatusPanel(
              trafficFuture: _trafficFuture,
              onRetry: _refresh,
            ),
          ),
        ],
      ),
    );
  }
}

typedef RoadLinkGeometryWithRoad = ({String roadName, RoadLinkGeometry link});

class _RoadStatusPanel extends StatelessWidget {
  final Future<RegionTrafficData> trafficFuture;
  final VoidCallback onRetry;

  const _RoadStatusPanel({required this.trafficFuture, required this.onRetry});

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
              return ListTile(
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
