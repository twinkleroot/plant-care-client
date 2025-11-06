import 'dart:async'; // Completer를 위해 import 추가
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/logger.dart';

// 앱 오픈 광고 로드 및 표시를 관리하는 서비스
class AppOpenAdService {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isAdLoaded = false;

  // 광고 로드 완료를 보장하기 위한 Completer 추가
  Completer<void> _appOpenAdCompleter = Completer<void>();

  String? get _adUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_APP_OPEN']!;
  }

  // 모든 광고를 미리 로드합니다. (스플래시 화면에서 호출)
  Future<void> preloadAd() async {
    if (_adUnitId == null) {
      logger.e('앱 오픈 광고 ID가 .env 파일에 설정되지 않았습니다.');
      return;
    }

    // Completer 초기화
    _appOpenAdCompleter = Completer<void>();

    // await 없이 로드 "시작"
    _loadAppOpenAd();

    // 로드가 완료될 때까지 기다립니다. (성공/실패 모두 포함)
    await _appOpenAdCompleter.future;
  }

  // --- 앱 오프닝 광고 (App Open) ---
  Future<void> _loadAppOpenAd() async {
    if (_adUnitId == null) {
      logger.e('앱 오픈 광고 ID가 없습니다.');
      if (!_appOpenAdCompleter.isCompleted) {
        _appOpenAdCompleter.complete();
      }
      return;
    }

    await AppOpenAd.load(
      adUnitId: _adUnitId!,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAdLoaded = true;
          logger.i('AppOpenAd loaded.');
          if (!_appOpenAdCompleter.isCompleted) {
            _appOpenAdCompleter.complete(); // 로드 성공 시 complete
          }
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          logger.e('AppOpenAd failed to load: $error');
          if (!_appOpenAdCompleter.isCompleted) {
            _appOpenAdCompleter.complete(); // 로드 실패 시에도 complete
          }
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable({required VoidCallback onAdDismissed}) {
    if (_isShowingAd || !_isAdLoaded || _appOpenAd == null) {
      logger.w('AppOpenAd not available or already showing.');
      onAdDismissed();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = true;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        onAdDismissed();
        // 다음 광고를 미리 로드
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        logger.e('AppOpenAd failed to show: $error');
        onAdDismissed();
      },
    );

    _appOpenAd!.show();
  }
}
