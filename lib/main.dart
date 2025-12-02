import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../screens/splash_screen.dart';
import '../services/ad_service.dart';
import '../services/app_open_ad_service.dart';
import '../services/fcm_update_stream.dart';
import '../utils/logger.dart';
import '../utils/navigator_service.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logger.i("백그라운드에서 메시지 처리: ${message.data}");

  if (message.data['type'] == 'IMAGE_PROCESSED') {
    final plantId = message.data['plantId'];
    if (plantId != null) {
      // SharedPreferences에 업데이트가 필요한 plantId를 '플래그'로 남깁니다.
      final prefs = await SharedPreferences.getInstance();
      // '업데이트 할 목록'에 plantId를 추가합니다. (여러 개가 될 수 있으므로 Set 사용)
      final currentToRefresh = prefs.getStringList('plants_to_refresh')?.toSet() ?? {};
      currentToRefresh.add(plantId);
      await prefs.setStringList('plants_to_refresh', currentToRefresh.toList());
      logger.i('백그라운드 업데이트 플래그 설정: $currentToRefresh');
    }
  }
}

void main() async {
  // main 함수에서 비동기 작업을 수행하기 위해 필요
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 로드. 앱 시작 시 딱 한 번만 호출하면 됩니다.
  const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  await dotenv.load(fileName: ".env.$env");
  // Firebase 앱 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 푸시 알림 관련 전체 설정
  await _setupFirebaseMessaging();

  MobileAds.instance.initialize();
  // 광고 서비스를 미리 생성합니다.
  final adService = AppOpenAdService();

  AdService.loadInterstitialAd();

  // 카카오톡 앱 간 인증에 사용되는 customScheme을 추가합니다.
  KakaoSdk.init(
      nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'],
      javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY']
  );

  // Provider를 통해 AdService를 앱에 주입합니다.
  runApp(
    MultiProvider(
      providers: [
        Provider<AppOpenAdService>(
          create: (_) => adService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isAppInitialized = false;
  final _storage = const FlutterSecureStorage(); // 토큰 확인용

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // 앱이 처음 시작될 때(Splash)가 아니라,
      // 백그라운드에서 포그라운드로 돌아왔을 때(Warm Start)만 로직을 수행합니다.
      if (_isAppInitialized) {
        // 로그인 여부 확인 (토큰이 있어야만 광고 노출)
        String? token = await _storage.read(key: 'appToken');
        if (token == null) {
          logger.i("비로그인 사용자입니다. 앱 오픈 광고를 건너뜁니다.");
          return;
        }

        // 전면 광고 쿨다운 확인 (5초 이내에 전면 광고를 닫았다면 건너뜀)
        if (AdService.recentlyShowedInterstitial) {
          logger.i("방금 전면 광고를 보았습니다. Warm Start 광고를 건너뜁니다.");
          return;
        }

        if (Random().nextBool()) {  // 50% 확률로 광고 표시
          logger.i("앱이 포그라운드로 돌아왔습니다. (50% 당첨) 앱 오픈 광고를 시도합니다.");
          if (!mounted) return;
          // Provider를 통해 인스턴스를 가져와서 메서드 호출
          // listen: false는 이 메서드 내에서 UI를 다시 빌드할 필요가 없기 때문입니다.
          context.read<AppOpenAdService>().showAdIfAvailable(onAdDismissed: () {});
        } else {
          logger.i("앱이 포그라운드로 돌아왔습니다. (50% 미당첨) 광고를 건너뜁니다.");
        }
      } else {
        // 앱이 처음 시작될 때는, SplashScreen이 광고를 처리하도록 플래그만 변경합니다.
        _isAppInitialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigatorService.navigatorKey,
      title: '내 화초 관리: 물주기 알림',
      theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFFF5F5F3),
          fontFamily: 'Pretendard'
      ),
      home: const SplashScreen(),
    );
  }
}

// Firebase Messaging 설정을 담당하는 함수
Future<void> _setupFirebaseMessaging() async {
  final fcm = FirebaseMessaging.instance;
  // 1. (가장 중요) Android 13 이상에서 알림 권한 요청
  await fcm.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // 2. 포그라운드 알림 처리 설정
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // AndroidManifest.xml에 설정한 채널 ID
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // onMessage 리스너도 SharedPreferences에 플래그를 남기도록 통합
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data['type'] == 'IMAGE_PROCESSED') {
      final plantId = message.data['plantId'];
      if (plantId != null) {
        // 1. 안전장치: SharedPreferences에 저장
        final prefs = await SharedPreferences.getInstance();
        final currentToRefresh = prefs.getStringList('plants_to_refresh')?.toSet() ?? {};
        currentToRefresh.add(plantId);
        await prefs.setStringList('plants_to_refresh', currentToRefresh.toList());
        logger.i('포그라운드 업데이트 플래그 설정: $currentToRefresh');

        // 2. 핵심: 실시간으로 리스트 화면에 알림 (이것이 즉시 갱신을 트리거합니다)
        FcmUpdateStream().notifyUpdate(plantId);
      }
      return;
    }

    // 2. 기존 알림 메시지 처리 로직
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: 'notification_icon', // AndroidManifest.xml에 설정한 아이콘
          ),
        ),
      );
    }
  });

  // 3. 백그라운드/종료 상태 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}
