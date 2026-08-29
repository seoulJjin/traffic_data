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

/// 고속국도/서울특별시도 노선표지: 모서리를 비스듬히 자른 팔각형 배지.
/// 흰 바탕 + 얇은 파랑 테두리 + 위쪽 빨강 사다리꼴 띠 + 파랑 굵은 번호.
/// (실제 참고 이미지와 동일한 팔각형 노선표지 모양.)
class _ExpresswayShield extends StatelessWidget {
  final int number;
  final double size;

  const _ExpresswayShield({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    final width = size * 1.3;
    final height = size * 0.98;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(width, height), painter: _OctagonSignPainter()),
          Padding(
            padding: EdgeInsets.only(top: height * 0.2),
            child: Text(
              '$number',
              style: GoogleFonts.notoSansKr(
                color: const Color(0xFF1B4F8C),
                fontWeight: FontWeight.w900,
                fontSize: height * 0.46,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OctagonSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cutX = w * 0.16;
    final cutY = h * 0.24;

    final octagon = Path()
      ..moveTo(cutX, 0)
      ..lineTo(w - cutX, 0)
      ..lineTo(w, cutY)
      ..lineTo(w, h - cutY)
      ..lineTo(w - cutX, h)
      ..lineTo(cutX, h)
      ..lineTo(0, h - cutY)
      ..lineTo(0, cutY)
      ..close();

    canvas.drawPath(octagon, Paint()..color = Colors.white);

    // 위쪽 빨강 사다리꼴 띠 (팔각형 안쪽으로만 잘라서 그립니다).
    canvas.save();
    canvas.clipPath(octagon);
    final redBand = Path()
      ..moveTo(cutX, 0)
      ..lineTo(w - cutX, 0)
      ..lineTo(w - cutX * 0.35, h * 0.22)
      ..lineTo(cutX * 0.35, h * 0.22)
      ..close();
    canvas.drawPath(redBand, Paint()..color = const Color(0xFFE0242C));
    canvas.restore();

    canvas.drawPath(
      octagon,
      Paint()
        ..color = const Color(0xFF1B4F8C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
