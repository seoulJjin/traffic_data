import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// 도로 한 구간(링크)의 실제 좌표 목록.
/// linkId는 ITS 국가교통정보센터 표준노드링크의 LINK_ID이며,
/// trafficInfo API 응답의 linkId와 동일한 값입니다.
class RoadLinkGeometry {
  final String linkId;
  final List<LatLng> points;

  const RoadLinkGeometry({required this.linkId, required this.points});
}
