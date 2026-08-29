import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/road_signage.dart';

/// 도로명 앞에 붙는 실제 교통 표지 마크.
/// 노선번호가 있는 고속도로는 방패 모양 노선표지(미국 인터스테이트 방패에서
/// 유래한 실제 한국 고속도로 표지 디자인)로, 번호가 없는 도시고속화도로/
/// 자동차전용도로는 자동차전용도로 픽토그램 표지로 표현합니다.
class RoadSignBadge extends StatelessWidget {
  final String roadName;
  final double size;

  const RoadSignBadge({super.key, required this.roadName, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final signage = roadSignageByName[roadName];
    switch (signage?.type) {
      case RoadSignType.expresswayNumbered:
      case RoadSignType.cityRoute:
        // 내비게이션 앱들이 서울특별시도 번호도 고속도로와 같은 방패 마크로
        // 표시하므로 동일한 디자인을 사용합니다.
        return _ExpresswayShield(number: signage!.routeNumber!, size: size);
      case RoadSignType.regionalRoute:
        return _RegionalRouteBadge(number: signage!.routeNumber!, size: size);
      case RoadSignType.motorway:
      case null:
        return _MotorwayBadge(size: size);
    }
  }
}

/// 고속국도/서울특별시도 노선표지: 흰 바탕 + 파란 테두리(둥근 사각형) + 위쪽
/// 빨간 캡 + 파란 번호. (실제 노선표지판/내비게이션 앱 아이콘과 동일한 모양.)
class _ExpresswayShield extends StatelessWidget {
  final int number;
  final double size;

  const _ExpresswayShield({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1B4F8C);
    const red = Color(0xFFC23B3B);
    final borderWidth = size * 0.09;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: blue, width: borderWidth),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -borderWidth * 0.6,
            left: size * 0.2,
            right: size * 0.2,
            child: Container(
              height: size * 0.18,
              decoration: BoxDecoration(
                color: red,
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.08),
            child: Text(
              '$number',
              style: GoogleFonts.notoSansKr(
                color: blue,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지방도 노선표지: 노란 바탕 + 파란 테두리 + 파란 번호 (실제 도로표지규칙 색상 규정).
class _RegionalRouteBadge extends StatelessWidget {
  final int number;
  final double size;

  const _RegionalRouteBadge({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.86,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF6C846),
        borderRadius: BorderRadius.circular(size * 0.1),
        border: Border.all(color: const Color(0xFF1B4F8C), width: size * 0.08),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: GoogleFonts.notoSansKr(
          color: const Color(0xFF1B4F8C),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          height: 1,
        ),
      ),
    );
  }
}

/// 자동차전용도로 표지: 파란 사각 배경에 흰 차량 픽토그램.
class _MotorwayBadge extends StatelessWidget {
  final double size;

  const _MotorwayBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.86,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1B4F8C),
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: Colors.white, width: size * 0.07),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_car_filled_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
