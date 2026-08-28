import 'lat_lng.dart';

enum LandmarkType { junction, bridge }

/// 도로 위의 분기점/IC 또는 교량 이름 표시용 지점.
class Landmark {
  final String name;
  final LatLng position;
  final LandmarkType type;

  const Landmark({required this.name, required this.position, required this.type});
}
