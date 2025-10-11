import java.util.Properties
import java.io.FileInputStream
// .env 파일을 읽기 위한 Properties 객체 생성
val kakaoProperties = Properties()
// 프로젝트 루트에 있는 .env 파일 경로 지정 (현재 파일 위치 기준)
val kakaoPropertiesFile = rootProject.file("../.env")
// .env 파일 로드
if (kakaoPropertiesFile.exists()) {
    kakaoProperties.load(kakaoPropertiesFile.inputStream())
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.heeblings.plant_care_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.heeblings.plant_care_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // manifestPlaceholders를 사용하여 AndroidManifest.xml에 변수를 주입
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = kakaoProperties.getProperty("KAKAO_NATIVE_APP_KEY")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
