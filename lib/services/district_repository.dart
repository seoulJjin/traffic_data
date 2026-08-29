import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/district.dart';
import '../models/lat_lng.dart';

/// assets/seoul_districts.json(서울 자치구 경계, southkorea/seoul-maps 공개 데이터,
/// Apache-2.0)를 로드/캐싱합니다.
class DistrictRepository {
  static List<District>? _cache;

  Future<List<District>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/seoul_districts.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    _cache = features.map((f) {
      final map = f as Map<String, dynamic>;
      final name = (map['properties'] as Map<String, dynamic>)['name'] as String;
      final ring = (map['geometry']['coordinates'] as List)[0] as List;
      final boundary = ring
          .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList();
      return District(name: name, boundary: boundary);
    }).toList();

    return _cache!;
  }
}
