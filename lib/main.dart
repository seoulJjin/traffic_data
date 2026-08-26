import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final kakaoNativeAppKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
  if (kakaoNativeAppKey == null || kakaoNativeAppKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY가 .env 파일에 설정되어 있지 않습니다.');
  }
  await KakaoMapSdk.instance.initialize(kakaoNativeAppKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서울/경기 교통정보',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  // 서울시청 좌표를 기본 중심으로 사용합니다.
  static const _seoulCityHall = LatLng(37.5665, 126.9780);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서울/경기 교통정보')),
      body: KakaoMap(
        option: const KakaoMapOption(
          position: _seoulCityHall,
          zoomLevel: 14,
          mapType: MapType.normal,
        ),
        onMapReady: (KakaoMapController controller) {
          debugPrint('카카오 지도가 정상적으로 불러와졌습니다.');
        },
      ),
    );
  }
}
