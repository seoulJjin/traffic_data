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
        return _ExpresswayShield(number: signage!.routeNumber!, size: size);
      case RoadSignType.regionalRoute:
        return _RegionalRouteBadge(number: signage!.routeNumber!, size: size);
      case RoadSignType.motorway:
      case null:
        return _MotorwayBadge(size: size);
    }
  }
}

/// 고속국도 노선표지: 흰 테두리 방패 + 상단 빨간 띠 + 파란 바탕 + 흰 번호.
class _ExpresswayShield extends StatelessWidget {
  final int number;
  final double size;

  const _ExpresswayShield({required this.number, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.86,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size * 0.86, size),
            painter: _ShieldPainter(),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.14),
            child: Text(
              '$number',
              style: GoogleFonts.notoSansKr(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0.16 * h)
      ..lineTo(0, 0.58 * h)
      ..quadraticBezierTo(0, 0.82 * h, 0.22 * w, 0.94 * h)
      ..lineTo(0.5 * w, h)
      ..lineTo(0.78 * w, 0.94 * h)
      ..quadraticBezierTo(w, 0.82 * h, w, 0.58 * h)
      ..lineTo(w, 0.16 * h)
      ..quadraticBezierTo(w, 0, 0.86 * w, 0)
      ..lineTo(0.14 * w, 0)
      ..quadraticBezierTo(0, 0, 0, 0.16 * h)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF1B4F8C));

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.26),
      Paint()..color = const Color(0xFFC23B3B),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07,
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
