import '../models/lat_lng.dart';
import '../models/region.dart';

/// 서울 주요 도로 + 경기 4개 시 권역 목록.
/// 좌표는 각 지역 시청(또는 대표 지점) 기준이며,
/// roadNames는 ITS 국가교통정보센터 API의 실제 도로명(roadName)과 일치합니다.
/// symbolEmoji는 각 시가 공식 지정한 시화/시목/시조 중 다른 권역과 겹치지 않는
/// 것을 골라 표현했습니다 (공식 CI 로고는 저작권 문제로 사용하지 않음).
const List<Region> regions = [
  Region(
    name: '서울',
    description: '올림픽대로, 강변북로 등 도심 도로',
    center: LatLng(37.5665, 126.9780), // 서울시청
    roadNames: ['올림픽대로', '강변북로', '내부순환도로', '동부간선도로', '서부간선도로', '북부간선도로'],
    symbolEmoji: '🌼',
    symbolLabel: '서울특별시 시화 개나리',
  ),
  Region(
    name: '과천',
    description: '봉담과천로, 과천의왕간고속도로',
    center: LatLng(37.4292, 126.9950), // 과천시청
    roadNames: ['봉담과천로', '과천의왕간고속도로'],
    symbolEmoji: '🕊️',
    symbolLabel: '과천시 시조 비둘기',
  ),
  Region(
    name: '성남',
    description: '분당수서로, 용인서울고속도로',
    center: LatLng(37.4200, 127.1265), // 성남시청
    roadNames: ['분당수서로', '용인서울고속도로'],
    symbolEmoji: '🐦',
    symbolLabel: '성남시 시조 까치',
  ),
  Region(
    name: '용인',
    description: '용인서울고속도로, 경부고속도로',
    center: LatLng(37.2411, 127.1776), // 용인시청
    roadNames: ['용인서울고속도로', '경부고속도로'],
    symbolEmoji: '🌲',
    symbolLabel: '용인시 시목 전나무',
  ),
  Region(
    name: '하남',
    description: '수도권제1순환고속도로, 서울양양고속도로',
    center: LatLng(37.5393, 127.2148), // 하남시청
    roadNames: ['수도권제1순환고속도로', '서울양양고속도로'],
    symbolEmoji: '🔔',
    symbolLabel: '하남시 시화 은방울꽃',
  ),
];
