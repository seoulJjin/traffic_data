import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/region.dart';
import '../models/road_traffic_status.dart';

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

  /// [region]의 경계 상자 내 실시간 교통정보를 조회하고,
  /// region.roadNames에 해당하는 도로만 도로명 기준으로 집계해서 반환합니다.
  Future<List<RoadTrafficStatus>> fetchRegionRoadStatuses(
    Region region,
  ) async {
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

    for (final item in items) {
      final roadName = item['roadName'] as String?;
      if (roadName == null || !targetNames.contains(roadName)) continue;

      final speed = double.tryParse((item['speed'] as String?) ?? '');
      if (speed == null) continue;

      speedsByRoad.putIfAbsent(roadName, () => []).add(speed);
    }

    return [
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
  }
}
