import 'lat_lng.dart';

/// 서울 자치구 경계 (매우 간략화된 폴리곤 하나).
class District {
  final String name;
  final List<LatLng> boundary;

  const District({required this.name, required this.boundary});
}
