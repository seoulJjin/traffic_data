import 'lat_lng.dart';

/// 사용자가 선택할 수 있는 교통정보 권역(서울 + 경기 4개 시).
class Region {
  final String name;
  final String description;
  final LatLng center;

  /// ITS 국가교통정보센터 API의 roadName과 정확히 일치해야 하는 도로명 목록.
  final List<String> roadNames;

  /// 해당 시가 공식 지정한 상징(시화/시목/시조 등)을 나타내는 이모지.
  /// 실제 CI 로고는 저작권/상표 문제가 있어, 공적으로 지정된 자연 상징으로 대신합니다.
  final String symbolEmoji;

  /// [symbolEmoji]가 어떤 상징인지 설명하는 텍스트 (접근성/툴팁용).
  final String symbolLabel;

  const Region({
    required this.name,
    required this.description,
    required this.center,
    required this.roadNames,
    required this.symbolEmoji,
    required this.symbolLabel,
  });

  /// 이 권역의 중심 좌표를 기준으로 한 조회용 경계 상자(bounding box).
  /// deltaDegree만큼 상하좌우로 확장합니다 (약 0.06도 ≈ 6~7km).
  ({double minX, double maxX, double minY, double maxY}) boundingBox({
    double deltaDegree = 0.06,
  }) {
    return (
      minX: center.longitude - deltaDegree,
      maxX: center.longitude + deltaDegree,
      minY: center.latitude - deltaDegree,
      maxY: center.latitude + deltaDegree,
    );
  }

  /// [point]가 이 권역의 경계 상자 안에 있는지 확인합니다.
  bool contains(LatLng point, {double deltaDegree = 0.06}) {
    final bbox = boundingBox(deltaDegree: deltaDegree);
    return point.longitude >= bbox.minX &&
        point.longitude <= bbox.maxX &&
        point.latitude >= bbox.minY &&
        point.latitude <= bbox.maxY;
  }
}
