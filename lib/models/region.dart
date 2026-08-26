import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// 사용자가 선택할 수 있는 교통정보 권역(서울 + 경기 6개 시).
class Region {
  final String name;
  final String description;
  final LatLng center;

  const Region({
    required this.name,
    required this.description,
    required this.center,
  });
}
