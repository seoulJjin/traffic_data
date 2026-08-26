import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/region.dart';

/// 선택한 권역을 중심으로 카카오맵을 보여주는 화면.
class MapScreen extends StatelessWidget {
  final Region region;

  const MapScreen({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(region.name)),
      body: KakaoMap(
        option: KakaoMapOption(
          position: region.center,
          zoomLevel: 14,
          mapType: MapType.normal,
        ),
        onMapReady: (KakaoMapController controller) {
          debugPrint('${region.name} 지도가 정상적으로 불러와졌습니다.');
        },
      ),
    );
  }
}
