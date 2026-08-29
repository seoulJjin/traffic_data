import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/district.dart';
import '../models/lat_lng.dart';

/// 경계 데이터 3종을 로드/캐싱합니다. (southkorea/southkorea-maps,
/// southkorea/seoul-maps 공개 데이터, KOSTAT 출처)
/// - 해당 지역 안의 자치구: assets/seoul_districts.json / assets/gyeonggi_districts.json
/// - 해당 지역의 전체 외곽선(굵게): assets/city_outlines.json
/// - 도로가 지나가는 주변 시/군/구(가늘게): assets/nationwide_districts.json
class DistrictRepository {
  static List<District>? _seoulCache;
  static List<District>? _gyeonggiCache;
  static List<District>? _outlineCache;
  static List<District>? _nationwideCache;

  /// 자치구 이름이 이 접두어 목록 중 하나로 시작하면 해당 지역에 포함됩니다.
  /// (성남/용인은 자치구가 여럿이라 접두어로, 과천/하남은 시 이름 그대로 매칭)
  static const Map<String, List<String>> _gyeonggiNamePrefixes = {
    '과천': ['과천시'],
    '성남': ['성남시'],
    '용인': ['용인시'],
    '하남': ['하남시'],
  };

  /// 해당 지역 안의 자치구 경계 (일반 두께).
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

  /// 해당 지역의 전체 외곽선 하나 (굵게). 서울/성남/용인은 자치구 여러 개를
  /// 하나로 합친 모양을 미리 계산해 assets/city_outlines.json에 저장해 두었습니다.
  Future<List<District>> loadCityOutline(String regionName) async {
    _outlineCache ??= await _loadFeatures(
      'assets/city_outlines.json',
      emphasis: DistrictEmphasis.bold,
    );
    return _outlineCache!.where((d) => d.name == regionName).toList();
  }

  /// [minLat]~[maxLng] 범위(도로가 그려지는 화면 범위)와 겹치는 전국 시/군/구
  /// 경계를 모두 반환합니다 (일반 두께). 도로가 해당 지역 밖으로 뻗어나가는
  /// 구간에서도 어느 시/군/구를 지나는지 알아볼 수 있도록 배경으로 깔립니다.
  Future<List<District>> loadContext({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    _nationwideCache ??= await _loadFeatures('assets/nationwide_districts.json');

    return [
      for (final d in _nationwideCache!)
        if (d.boundary.isNotEmpty && _intersects(d.boundary, minLat, maxLat, minLng, maxLng))
          d,
    ];
  }

  bool _intersects(
    List<LatLng> boundary,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    var dMinLat = boundary.first.latitude;
    var dMaxLat = boundary.first.latitude;
    var dMinLng = boundary.first.longitude;
    var dMaxLng = boundary.first.longitude;
    for (final p in boundary) {
      if (p.latitude < dMinLat) dMinLat = p.latitude;
      if (p.latitude > dMaxLat) dMaxLat = p.latitude;
      if (p.longitude < dMinLng) dMinLng = p.longitude;
      if (p.longitude > dMaxLng) dMaxLng = p.longitude;
    }
    return dMinLat <= maxLat && dMaxLat >= minLat && dMinLng <= maxLng && dMaxLng >= minLng;
  }

  Future<List<District>> _loadFeatures(
    String assetPath, {
    DistrictEmphasis emphasis = DistrictEmphasis.normal,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    return features.map((f) {
      final map = f as Map<String, dynamic>;
      final name = (map['properties'] as Map<String, dynamic>)['name'] as String;
      final boundary = _extractBoundary(map['geometry'] as Map<String, dynamic>);
      return District(name: name, boundary: boundary, emphasis: emphasis);
    }).toList();
  }

  /// Polygon은 바깥쪽 고리(첫 번째 ring) 그대로, MultiPolygon(섬 등으로 나뉜
  /// 경우)은 그중 면적이 가장 넓은 조각 하나만 사용합니다 (매우 간략한 표현이라
  /// 작은 섬까지 표현할 필요는 없습니다).
  List<LatLng> _extractBoundary(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String;
    if (type == 'Polygon') {
      final ring = (geometry['coordinates'] as List)[0] as List;
      return _ringToLatLng(ring);
    }
    if (type == 'MultiPolygon') {
      List<LatLng>? largest;
      var largestArea = -1.0;
      for (final polygon in geometry['coordinates'] as List) {
        final ring = (polygon as List)[0] as List;
        final points = _ringToLatLng(ring);
        final area = _ringArea(points);
        if (area > largestArea) {
          largestArea = area;
          largest = points;
        }
      }
      return largest ?? [];
    }
    return [];
  }

  List<LatLng> _ringToLatLng(List ring) {
    return ring
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
  }

  double _ringArea(List<LatLng> points) {
    var area = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      area += a.longitude * b.latitude - b.longitude * a.latitude;
    }
    return area.abs() / 2;
  }
}
