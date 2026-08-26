import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/region.dart';

/// 서울 주요 도로 + 경기 6개 시 권역 목록.
/// 좌표는 각 지역 시청(또는 대표 지점) 기준입니다.
const List<Region> regions = [
  Region(
    name: '서울',
    description: '올림픽대로, 강변북로 등 도심 도로',
    center: LatLng(37.5665, 126.9780), // 서울시청
  ),
  Region(
    name: '과천',
    description: '과천봉담도시고속화도로',
    center: LatLng(37.4292, 126.9950), // 과천시청
  ),
  Region(
    name: '성남',
    description: '분당수서간도시고속화도로, 용인서울고속도로',
    center: LatLng(37.4200, 127.1265), // 성남시청
  ),
  Region(
    name: '용인',
    description: '용인서울고속도로, 경부고속도로',
    center: LatLng(37.2411, 127.1776), // 용인시청
  ),
  Region(
    name: '하남',
    description: '수도권제1순환고속도로, 서울양양고속도로',
    center: LatLng(37.5393, 127.2148), // 하남시청
  ),
  Region(
    name: '구리',
    description: '수도권제1순환고속도로, 구리포천고속도로',
    center: LatLng(37.5943, 127.1296), // 구리시청
  ),
  Region(
    name: '남양주',
    description: '수도권제1순환고속도로, 구리포천고속도로',
    center: LatLng(37.6360, 127.2165), // 남양주시청
  ),
];
