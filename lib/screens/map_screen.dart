import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/region.dart';
import '../models/road_traffic_status.dart';
import '../services/its_traffic_service.dart';

/// 선택한 권역을 중심으로 카카오맵과 실시간 도로 소통 상태를 보여주는 화면.
class MapScreen extends StatefulWidget {
  final Region region;

  const MapScreen({super.key, required this.region});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _trafficService = ItsTrafficService();
  late Future<List<RoadTrafficStatus>> _statusesFuture;

  @override
  void initState() {
    super.initState();
    _statusesFuture = _trafficService.fetchRegionRoadStatuses(widget.region);
  }

  void _refresh() {
    setState(() {
      _statusesFuture = _trafficService.fetchRegionRoadStatuses(widget.region);
    });
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
              onMapReady: (KakaoMapController controller) {
                debugPrint('${widget.region.name} 지도가 정상적으로 불러와졌습니다.');
              },
            ),
          ),
          SizedBox(
            height: 220,
            child: _RoadStatusPanel(
              statusesFuture: _statusesFuture,
              onRetry: _refresh,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadStatusPanel extends StatelessWidget {
  final Future<List<RoadTrafficStatus>> statusesFuture;
  final VoidCallback onRetry;

  const _RoadStatusPanel({required this.statusesFuture, required this.onRetry});

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
      child: FutureBuilder<List<RoadTrafficStatus>>(
        future: statusesFuture,
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

          final statuses = snapshot.data ?? [];
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
