import 'package:geolocator/geolocator.dart';

/// 위치 권한 확인/요청과 실시간 위치 스트림을 감싸는 서비스.
class LocationService {
  /// 위치 서비스 사용 가능 여부를 확인하고, 필요하면 권한을 요청합니다.
  /// 사용할 수 없으면 false를 반환합니다 (호출부에서 UI 처리).
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// 위치(및 이동 방향) 실시간 스트림.
  /// heading은 이동 중일 때의 진행 방향(도, 0=북쪽 기준)입니다.
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5m 이상 이동 시에만 갱신
      ),
    );
  }
}
