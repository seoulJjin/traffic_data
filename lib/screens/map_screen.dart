import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/region.dart';
import '../models/road_traffic_status.dart';
import '../services/its_traffic_service.dart';
import '../services/road_geometry_repository.dart';

/// 선택한 권역을 중심으로 카카오맵과 실시간 도로 소통 상태를 보여주는 화면.
/// 지도 위에는 실제 도로 모양을 따라 구간별 소통 상태 색상 선을 그립니다.
class MapScreen extends StatefulWidget {
  final Region region;

  const MapScreen({super.key, required this.region});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _trafficService = ItsTrafficService();
  final _geometryRepository = RoadGeometryRepository();

  late Future<RegionTrafficData> _trafficFuture;
  KakaoMapController? _mapController;
  ShapeController? _shapeController;

  @override
  void initState() {
    super.initState();
    _trafficFuture = _trafficService.fetchRegionTrafficData(widget.region);
  }

  void _refresh() {
    setState(() {
      _trafficFuture = _trafficService.fetchRegionTrafficData(widget.region);
    });
    _drawRoadLines();
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _mapController = controller;
    _shapeController = await controller.addShapeLayer('road_status_layer');
    await _drawRoadLines();
  }

  Future<void> _drawRoadLines() async {
    final mapController = _mapController;
    if (mapController == null) return;

    // 이전에 그린 구간이 남아있지 않도록 레이어를 새로 만듭니다.
    if (_shapeController != null) {
      await mapController.removeShapeLayer(_shapeController!);
    }
    final shapeController = await mapController.addShapeLayer(
      'road_status_layer_${DateTime.now().microsecondsSinceEpoch}',
    );
    _shapeController = shapeController;

    final links = await _geometryRepository.geometriesFor(widget.region.roadNames);
    final traffic = await _trafficFuture;

    for (final (roadName, link) in links) {
      final speed = traffic.linkSpeeds[link.linkId];
      final color = speed == null
          ? Colors.grey
          : TrafficLevel.fromSpeedKmh(speed).color;

      await shapeController.addPolylineShape(
        MapPoint(link.points),
        PolylineStyle(color, 6),
        PolylineCap.round,
        id: '${roadName}_${link.linkId}',
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
