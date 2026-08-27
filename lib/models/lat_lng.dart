/// 위도(latitude)/경도(longitude) 좌표. 카카오맵 SDK 없이 자체적으로 사용하는 좌표 타입입니다.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}
