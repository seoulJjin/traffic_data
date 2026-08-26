import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// 사용자가 선택할 수 있는 교통정보 권역(서울 + 경기 4개 시).
class Region {
  final String name;
  final String description;
  final LatLng center;

  /// ITS 국가교통정보센터 API의 roadName과 정확히 일치해야 하는 도로명 목록.
  final List<String> roadNames;

  const Region({
    required this.name,
    required this.description,
    required this.center,
    required this.roadNames,
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
}
