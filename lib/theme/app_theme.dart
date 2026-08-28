import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 전체 비주얼 아이덴티티.
/// 고속도로 이정표(초록 바탕/흰 글씨)와 국도 표지판(파랑)에서 색과 구조를 가져왔습니다.
class AppColors {
  /// 종이/이정표 배경 — 도로 다이어그램과 통일된 크림색.
  static const paper = Color(0xFFF5F2EA);

  /// 아스팔트 — 본문 텍스트, 고대비 표면.
  static const asphalt = Color(0xFF1E2422);

  /// 고속도로 이정표 초록 — 브랜드 주색.
  static const highwayGreen = Color(0xFF0B6B45);
  static const highwayGreenDark = Color(0xFF084F33);

  /// 국도 표지판 파랑 — 보조색. 소통 상태 색(초록/주황/빨강)과 겹치지 않도록
  /// 구조적인 요소(헤더, 보조 배지)에만 사용합니다.
  static const routeBlue = Color(0xFF1B4F8C);

  /// 소통 상태 색상 (기존 다이어그램과 동일하게 유지).
  static const signalSmooth = Color(0xFF2E9E5B);
  static const signalSlow = Color(0xFFE8A33D);
  static const signalCongested = Color(0xFFD64545);

  static const hairline = Color(0xFFDAD4C4);
}

class AppTheme {
  static ThemeData build() {
    final displayFont = GoogleFonts.blackHanSansTextTheme();
    final bodyFont = GoogleFonts.notoSansKrTextTheme();

    final textTheme = bodyFont.copyWith(
      headlineLarge: displayFont.headlineLarge?.copyWith(
        color: AppColors.asphalt,
        letterSpacing: -0.5,
      ),
      headlineMedium: displayFont.headlineMedium?.copyWith(
        color: AppColors.asphalt,
      ),
      titleLarge: displayFont.titleLarge?.copyWith(
        color: AppColors.asphalt,
        fontSize: 22,
      ),
      titleMedium: bodyFont.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.asphalt,
      ),
      bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.asphalt),
      bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.asphalt),
      labelLarge: bodyFont.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.highwayGreen,
        primary: AppColors.highwayGreen,
        secondary: AppColors.routeBlue,
        surface: AppColors.paper,
        error: AppColors.signalCongested,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.highwayGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.blackHanSans(
          fontSize: 22,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.highwayGreen,
        foregroundColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.highwayGreen,
      ),
    );
  }
}
