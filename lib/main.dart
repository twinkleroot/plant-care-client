import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:plant_care_app/firebase_options.dart';
import 'package:plant_care_app/screens/splash_screen.dart';
import 'package:plant_care_app/services/ad_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:plant_care_app/services/fcm_update_stream.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

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
  AdService.loadInterstitialAd();

  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']!);

  runApp(const MyApp());
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
        final prefs = await SharedPreferences.getInstance();
        final currentToRefresh = prefs.getStringList('plants_to_refresh')?.toSet() ?? {};
        currentToRefresh.add(plantId);
        await prefs.setStringList('plants_to_refresh', currentToRefresh.toList());
        logger.i('포그라운드 업데이트 플래그 설정: $currentToRefresh');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내 화초 시들기 전에: 물주기 알림',
      theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFFF5F5F3),
          fontFamily: 'Pretendard'
      ),
      home: const SplashScreen(),
    );
  }
}