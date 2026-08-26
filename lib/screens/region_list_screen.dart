import 'package:flutter/material.dart';

import '../data/regions.dart';
import 'map_screen.dart';

/// 앱 시작 화면. 권역(서울/경기 6개 시)을 목록에서 고르면
/// 해당 지역 중심의 지도 화면으로 이동합니다.
class RegionListScreen extends StatelessWidget {
  const RegionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서울/경기 교통정보')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: regions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final region = regions[index];
          return ListTile(
            leading: const Icon(Icons.location_city),
            title: Text(region.name),
            subtitle: Text(region.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MapScreen(region: region),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
