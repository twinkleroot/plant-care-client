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
import 'package:plant_care_app/services/plant_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase를 초기화해야 shared_preferences 등을 사용할 수 있습니다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logger.i("백그라운드에서 메시지 처리: ${message.messageId}");

  // 이미지 처리 완료 메시지인 경우
  if (message.data['type'] == 'IMAGE_PROCESSED') {
    final plantId = message.data['plantId'];
    if (plantId != null) {
      // SharedPreferences에 업데이트가 필요한 plantId를 '플래그'로 남깁니다.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plant_id_to_refresh', plantId);
      logger.i('백그라운드 업데이트 플래그 설정: plantId $plantId');
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

// ❗️ [추가] Firebase Messaging 설정을 담당하는 함수
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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 앱이 포그라운드 상태일 때 메시지를 수신하면 이 리스너가 호출됨
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // 1. 데이터 메시지인지 확인
    if (message.data['type'] == 'IMAGE_PROCESSED') {
      final plantId = int.tryParse(message.data['plantId'] ?? '');
      if (plantId != null) {
        // PlantUpdateService를 통해 업데이트 알림
        PlantUpdateService().notifyUpdate(plantId);
      }
      return; // 데이터 메시지는 화면에 표시하지 않음
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