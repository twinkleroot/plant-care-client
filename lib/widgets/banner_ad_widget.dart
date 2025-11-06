import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/logger.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = dotenv.env['GOOGLE_ADMOB_ID_ANDROID_BANNER'];
    if (adUnitId == null) {
      logger.i('배너 광고 ID가 .env 파일에 설정되지 않았습니다.');
      return;
    }

    // 이전 광고 인스턴스가 있다면 폐기합니다.
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          logger.i('배너 광고 로드 성공: $ad');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        // 광고 로드에 실패했을 때 호출됩니다. (네트워크 오류, 잘못된 광고 단위 ID, SVG 렌더링 오류 등)
        onAdFailedToLoad: (ad, err) {
          // 어떤 원인으로 실패했는지 상세하게 로그를 기록합니다.
          logger.e('배너 광고 로드 실패: $err');
          ad.dispose();

          // 반복적인 충돌을 방지하기 위해, 실패 시 1분 후에 재시도를 예약합니다.
          Future.delayed(const Duration(minutes: 1), () {
            if (mounted) {
              _loadAd();
            }
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 광고가 성공적으로 로드되었고, _bannerAd 객체가 null이 아닌지 다시 한번 확인합니다.
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      // 광고가 로드되지 않았거나 실패했을 때 빈 공간을 차지하도록 하여 레이아웃이 깨지는 것을 방지합니다.
      return SizedBox(height: AdSize.banner.height.toDouble());
    }
  }
}
