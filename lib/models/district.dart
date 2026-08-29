import 'lat_lng.dart';

/// 경계선을 얼마나 강조해서 그릴지.
/// - normal: 도로가 지나가는 주변 시/군/구, 혹은 해당 지역 안의 자치구 경계
/// - bold: "해당하는 시" 자체의 전체 외곽선 (더 두껍게 그려 한눈에 구분되도록)
enum DistrictEmphasis { normal, bold }

/// 행정구역 경계 (매우 간략화된 폴리곤 하나).
class District {
  final String name;
  final List<LatLng> boundary;
  final DistrictEmphasis emphasis;

  const District({
    required this.name,
    required this.boundary,
    this.emphasis = DistrictEmphasis.normal,
  });
}
