import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/district.dart';
import '../models/lat_lng.dart';

/// 지역별 경계 데이터(southkorea/southkorea-maps, southkorea/seoul-maps 공개
/// 데이터, KOSTAT 출처)를 로드/캐싱합니다.
/// - 서울: assets/seoul_districts.json (25개 자치구 전체)
/// - 과천/성남/용인/하남: assets/gyeonggi_districts.json (해당 시/자치구만 필터링)
class DistrictRepository {
  static List<District>? _seoulCache;
  static List<District>? _gyeonggiCache;

  /// 자치구 이름이 이 접두어 목록 중 하나로 시작하면 해당 지역에 포함됩니다.
  /// (성남/용인은 자치구가 여럿이라 접두어로, 과천/하남은 시 이름 그대로 매칭)
  static const Map<String, List<String>> _gyeonggiNamePrefixes = {
    '과천': ['과천시'],
    '성남': ['성남시'],
    '용인': ['용인시'],
    '하남': ['하남시'],
  };

  Future<List<District>> loadForRegion(String regionName) async {
    if (regionName == '서울') {
      _seoulCache ??= await _loadFeatures('assets/seoul_districts.json');
      return _seoulCache!;
    }

    final prefixes = _gyeonggiNamePrefixes[regionName];
    if (prefixes == null) return [];

    _gyeonggiCache ??= await _loadFeatures('assets/gyeonggi_districts.json');
    return _gyeonggiCache!
        .where((d) => prefixes.any((p) => d.name.startsWith(p)))
        .toList();
  }

  Future<List<District>> _loadFeatures(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    return features.map((f) {
      final map = f as Map<String, dynamic>;
      final name = (map['properties'] as Map<String, dynamic>)['name'] as String;
      final ring = (map['geometry']['coordinates'] as List)[0] as List;
      final boundary = ring
          .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList();
      return District(name: name, boundary: boundary);
    }).toList();
  }
}
