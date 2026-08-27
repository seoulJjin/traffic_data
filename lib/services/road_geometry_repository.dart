import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/lat_lng.dart';
import '../models/road_link_geometry.dart';

/// assets/road_geometry.json(표준노드링크에서 추출한 대상 도로 좌표)을 로드/캐싱합니다.
class RoadGeometryRepository {
  static Map<String, List<RoadLinkGeometry>>? _cache;

  Future<Map<String, List<RoadLinkGeometry>>> _load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/road_geometry.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final result = <String, List<RoadLinkGeometry>>{};
    json.forEach((roadName, links) {
      result[roadName] = (links as List)
          .map((link) {
            final map = link as Map<String, dynamic>;
            final points = (map['points'] as List)
                .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
                .toList();
            return RoadLinkGeometry(linkId: map['linkId'] as String, points: points);
          })
          .toList();
    });

    _cache = result;
    return result;
  }

  /// [roadNames]에 해당하는 모든 구간(링크) 지오메트리를 도로명과 함께 반환합니다.
  Future<List<(String roadName, RoadLinkGeometry link)>> geometriesFor(
    List<String> roadNames,
  ) async {
    final all = await _load();
    return [
      for (final roadName in roadNames)
        if (all.containsKey(roadName))
          for (final link in all[roadName]!) (roadName, link),
    ];
  }
}
