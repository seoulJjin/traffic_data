/// 도로별 실제 교통 표지 유형.
/// - expresswayNumbered: 고속국도 노선표지(파랑/빨강 방패 마크)가 있는 도로.
/// - regionalRoute: 지방도 노선표지(노란 바탕 사각 마크)가 있는 도로.
/// - cityRoute: "서울특별시도" 노선번호가 있는 도로. 내비게이션 앱들이 실제로
///   고속도로와 같은 방패 마크로 표시하므로 동일한 디자인을 사용합니다.
/// - motorway: 확인된 번호가 없는 도시고속화도로/자동차전용도로.
enum RoadSignType { expresswayNumbered, regionalRoute, cityRoute, motorway }

class RoadSignage {
  final RoadSignType type;
  final int? routeNumber;

  const RoadSignage.expressway(this.routeNumber) : type = RoadSignType.expresswayNumbered;
  const RoadSignage.regional(this.routeNumber) : type = RoadSignType.regionalRoute;
  const RoadSignage.cityRoute(this.routeNumber) : type = RoadSignType.cityRoute;
  const RoadSignage.motorway()
      : type = RoadSignType.motorway,
        routeNumber = null;
}

/// 실제 고속국도/지방도/서울특별시도 노선번호 기준
/// (도로표지규칙, 한국도로공사·경기도 노선 안내, 서울특별시도 노선 목록).
const Map<String, RoadSignage> roadSignageByName = {
  '경부고속도로': RoadSignage.expressway(1),
  '서울양양고속도로': RoadSignage.expressway(60),
  '수도권제1순환고속도로': RoadSignage.expressway(100),
  '용인서울고속도로': RoadSignage.expressway(171),
  '봉담과천로': RoadSignage.regional(309),
  '서부간선도로': RoadSignage.cityRoute(1),
  '내부순환도로': RoadSignage.cityRoute(30),
  '동부간선도로': RoadSignage.cityRoute(61),
  '강변북로': RoadSignage.cityRoute(70),
  '올림픽대로': RoadSignage.cityRoute(88),
  // 북부간선도로는 서울특별시도 노선번호가 없어 번호 없이 표현합니다.
  '북부간선도로': RoadSignage.motorway(),
  '과천의왕간고속도로': RoadSignage.motorway(),
  '분당수서로': RoadSignage.motorway(),
};
