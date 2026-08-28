import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/landmark.dart';
import '../models/lat_lng.dart';

/// assets/landmarks.json(표준노드링크에서 추출한 분기점/IC, 교량 이름)을 로드/캐싱합니다.
class LandmarkRepository {
  static List<Landmark>? _cache;

  Future<List<Landmark>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/landmarks.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    LatLng pos(Map<String, dynamic> e) =>
        LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble());

    final junctions = (json['junctions'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => Landmark(
              name: e['name'] as String,
              position: pos(e),
              type: LandmarkType.junction,
            ))
        .toList();
    final bridges = (json['bridges'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => Landmark(
              name: e['name'] as String,
              position: pos(e),
              type: LandmarkType.bridge,
            ))
        .toList();

    _cache = [...junctions, ...bridges];
    return _cache!;
  }
}
