import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/region.dart';
import '../models/road_traffic_status.dart';

/// 한 권역에 대한 실시간 교통정보 조회 결과.
class RegionTrafficData {
  /// 도로명 기준으로 집계한 평균 소통 상태 (하단 리스트 패널용).
  final List<RoadTrafficStatus> roadStatuses;

  /// 링크ID(구간) 기준 실시간 속도 (지도 위 구간별 색칠용).
  final Map<String, double> linkSpeeds;

  const RegionTrafficData({required this.roadStatuses, required this.linkSpeeds});
}

/// ITS 국가교통정보센터 실시간 교통소통정보 Open API 연동 서비스.
/// https://www.its.go.kr/opendata/opendataList?service=traffic
class ItsTrafficService {
  static const _baseUrl = 'https://openapi.its.go.kr:9443/trafficInfo';

  String get _apiKey {
    final key = dotenv.env['ITS_TRAFFIC_API_KEY'];
    if (key == null || key.isEmpty || key.contains('여기에')) {
      throw StateError('ITS_TRAFFIC_API_KEY가 .env 파일에 설정되어 있지 않습니다.');
    }
    return key;
  }

  /// [region]의 경계 상자 내 실시간 교통정보를 조회합니다.
  /// - roadStatuses: region.roadNames에 해당하는 도로의 평균 소통 상태
  /// - linkSpeeds: 조회된 모든 구간의 linkId -> 속도(km/h) (도로명 필터 없음)
  Future<RegionTrafficData> fetchRegionTrafficData(Region region) async {
    final bbox = region.boundingBox();
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'apiKey': _apiKey,
      'type': 'all',
      'minX': bbox.minX.toStringAsFixed(6),
      'maxX': bbox.maxX.toStringAsFixed(6),
      'minY': bbox.minY.toStringAsFixed(6),
      'maxY': bbox.maxY.toStringAsFixed(6),
      'getType': 'json',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('ITS API 호출 실패: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final header = json['header'] as Map<String, dynamic>;
    if (header['resultCode'] != 0) {
      throw Exception('ITS API 오류: ${header['resultMsg']}');
    }

    final items = (json['body']['items'] as List).cast<Map<String, dynamic>>();

    final targetNames = region.roadNames.toSet();
    final speedsByRoad = <String, List<double>>{};
    final linkSpeeds = <String, double>{};

    for (final item in items) {
      final speed = double.tryParse((item['speed'] as String?) ?? '');
      if (speed == null) continue;

      final linkId = item['linkId'] as String?;
      if (linkId != null) linkSpeeds[linkId] = speed;

      final roadName = item['roadName'] as String?;
      if (roadName == null || !targetNames.contains(roadName)) continue;
      speedsByRoad.putIfAbsent(roadName, () => []).add(speed);
    }

    final roadStatuses = [
      for (final roadName in region.roadNames)
        if (speedsByRoad.containsKey(roadName))
          RoadTrafficStatus(
            roadName: roadName,
            averageSpeedKmh:
                speedsByRoad[roadName]!.reduce((a, b) => a + b) /
                    speedsByRoad[roadName]!.length,
            linkCount: speedsByRoad[roadName]!.length,
          ),
    ];

    return RegionTrafficData(roadStatuses: roadStatuses, linkSpeeds: linkSpeeds);
  }
}
