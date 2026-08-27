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
  bool _hasFittedCameraToRoads = false;

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

  /// 카카오맵 SDK는 onMapReady 직후 잠깐 동안 레이어 생성(addShapeLayer 등)이
  /// 네이티브 쪽 초기화 타이밍 문제로 실패(getLayer(...) must not be null)할 수 있어,
  /// 짧은 간격으로 재시도합니다.
  Future<T> _retryOnFailure<T>(
    Future<T> Function() action, {
    int retries = 6,
    Duration delay = const Duration(milliseconds: 250),
  }) async {
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future.delayed(delay);
      }
    }
    throw StateError('unreachable');
  }

  void _refresh() {
    setState(() {
      _trafficFuture = _trafficService.fetchRegionTrafficData(widget.region);
    });
    _drawRoadOverlays();
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _mapController = controller;
    _shapeController = await _retryOnFailure(
      () => controller.addShapeLayer('road_status_layer'),
    );
    _labelController = await _retryOnFailure(
      () => controller.addLabelLayer('road_marker_layer'),
    );
    _myLocationLayer = await _retryOnFailure(
      () => controller.addLabelLayer('my_location_layer'),
    );
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

  Future<void> _goToMyLocation() async {
    final granted = await _locationService.ensurePermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다. 설정에서 허용해주세요.')));
      return;
    }

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('현재 위치를 가져오지 못했습니다.')));
      return;
    }

    await _onPositionUpdate(position);

    final mapController = _mapController;
    if (mapController == null) return;
    await mapController.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(position.latitude, position.longitude),
        zoomLevel: 16,
      ),
      animation: const CameraAnimation(300),
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
    final shapeController = await _retryOnFailure(
      () => mapController.addShapeLayer('road_status_layer_$uniqueSuffix'),
    );
    final labelController = await _retryOnFailure(
      () => mapController.addLabelLayer('road_marker_layer_$uniqueSuffix'),
    );
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

    // 첫 진입 시에는 그려진 도로가 실제로 화면에 보이도록, 전체 도로 구간의 경계 상자에
    // 카메라를 맞춥니다. (권역 중심 좌표만으로는 도로가 화면 밖에 있을 수 있음 - 예:
    // 올림픽대로/강변북로는 한강변이라 서울시청 근처 기본 화면에는 안 보임)
    if (!_hasFittedCameraToRoads && links.isNotEmpty) {
      _hasFittedCameraToRoads = true;
      double? minLat, maxLat, minLng, maxLng;
      for (final (_, link) in links) {
        for (final point in link.points) {
          minLat = (minLat == null || point.latitude < minLat) ? point.latitude : minLat;
          maxLat = (maxLat == null || point.latitude > maxLat) ? point.latitude : maxLat;
          minLng = (minLng == null || point.longitude < minLng) ? point.longitude : minLng;
          maxLng = (maxLng == null || point.longitude > maxLng) ? point.longitude : maxLng;
        }
      }
      if (minLat != null) {
        await mapController.moveCamera(
          CameraUpdate.fitMapPoints(
            [
              LatLng(minLat, minLng!),
              LatLng(maxLat!, maxLng!),
            ],
            padding: 80,
          ),
        );
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
            child: Stack(
              children: [
                KakaoMap(
                  option: KakaoMapOption(
                    position: widget.region.center,
                    zoomLevel: 14,
                    mapType: MapType.normal,
                  ),
                  onMapReady: _onMapReady,
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
