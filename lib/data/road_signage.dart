/// 도로별 실제 교통 표지 유형.
/// - expresswayNumbered: 고속국도 노선표지(파랑 방패 마크)가 있는 도로.
/// - regionalRoute: 지방도 노선표지(노란 바탕 사각 마크)가 있는 도로.
/// - motorway: 실제 표지판에 번호가 표기되지 않는 도시고속화도로/자동차전용도로.
///   (서울시 도로 중 일부는 "서울특별시도" 내부 번호가 있지만, 서울시는 이 번호를
///   실제 표지판에 표기하지 않으므로 번호 없이 자동차전용도로 표지로 표현합니다.)
enum RoadSignType { expresswayNumbered, regionalRoute, motorway }

class RoadSignage {
  final RoadSignType type;
  final int? routeNumber;

  const RoadSignage.expressway(this.routeNumber) : type = RoadSignType.expresswayNumbered;
  const RoadSignage.regional(this.routeNumber) : type = RoadSignType.regionalRoute;
  const RoadSignage.motorway()
      : type = RoadSignType.motorway,
        routeNumber = null;
}

/// 실제 고속국도/지방도 노선번호 기준 (도로표지규칙/한국도로공사·경기도 노선 안내).
const Map<String, RoadSignage> roadSignageByName = {
  '경부고속도로': RoadSignage.expressway(1),
  '서울양양고속도로': RoadSignage.expressway(60),
  '수도권제1순환고속도로': RoadSignage.expressway(100),
  '용인서울고속도로': RoadSignage.expressway(171),
  '봉담과천로': RoadSignage.regional(309),
  // 아래는 실제 표지판에 노선번호가 표기되지 않는 도시고속화도로/자동차전용도로.
  '올림픽대로': RoadSignage.motorway(),
  '강변북로': RoadSignage.motorway(),
  '내부순환도로': RoadSignage.motorway(),
  '동부간선도로': RoadSignage.motorway(),
  '서부간선도로': RoadSignage.motorway(),
  '북부간선도로': RoadSignage.motorway(),
  '과천의왕간고속도로': RoadSignage.motorway(),
  '분당수서로': RoadSignage.motorway(),
};
