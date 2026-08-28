import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/regions.dart';
import '../models/region.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';

/// 앱 시작 화면. 권역(서울/경기 4개 시)을 목록에서 고르면
/// 해당 지역 중심의 지도 화면으로 이동합니다.
/// 카드 하나하나가 고속도로 이정표(초록 명판 + 안내문)처럼 보이도록 구성했습니다.
class RegionListScreen extends StatelessWidget {
  const RegionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서울/경기 교통정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            '가고 싶은 방향을 고르세요',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.asphalt.withValues(alpha: 0.55),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          for (final region in regions) ...[
            _RegionCard(
              region: region,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => MapScreen(region: region)),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final Region region;
  final VoidCallback onTap;

  const _RegionCard({required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이정표 명판부: 초록 바탕에 흰 굵은 글씨로 지명을 보여줍니다.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                decoration: const BoxDecoration(
                  color: AppColors.highwayGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      region.name,
                      style: GoogleFonts.blackHanSans(
                        color: Colors.white,
                        fontSize: 25,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: region.symbolLabel,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(region.symbolEmoji, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 26),
                  ],
                ),
              ),
              // 안내문부: 이 방향에 포함된 도로 목록.
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Text(
                  region.description,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    color: AppColors.asphalt.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
