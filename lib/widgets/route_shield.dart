import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 이 앱의 시그니처 요소. 고속도로 노선 번호판(방패 마크)을 본뜬 배지로,
/// 도로 소통 상태를 표시하는 모든 곳(목록, 배너, 카드)에서 공통으로 사용합니다.
class RouteShield extends StatelessWidget {
  final Color color;
  final String? label;
  final double size;

  const RouteShield({
    super.key,
    required this.color,
    this.label,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: Colors.white, width: size * 0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: label == null
          ? null
          : Text(
              label!,
              style: GoogleFonts.notoSansKr(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                height: 1,
              ),
            ),
    );
  }
}
