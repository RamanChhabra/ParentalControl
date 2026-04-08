// Parental Control App - Entry point.
// Setup: Add google-services.json (Android) and GoogleService-Info.plist (iOS) from Firebase Console.
// Run: flutter pub get, then flutter run.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'shared/firebase_services/auth_service.dart';
import 'shared/firebase_services/firestore_service.dart';
import 'shared/firebase_options_android.dart';
import 'app_router.dart';
import 'child_app/trackers/location_background_service.dart';
import 'child_app/trackers/location_background_service_ios.dart';
import 'shared/utils/blocked_app_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDHCKAY5WHOUCUyjRsqwIuRRQmV8-sm5q0',
        authDomain: 'parental-controll-app-9a0d6.firebaseapp.com',
        projectId: 'parental-controll-app-9a0d6',
        storageBucket: 'parental-controll-app-9a0d6.firebasestorage.app',
        messagingSenderId: '862206635333',
        appId: '1:862206635333:web:6594b9e798c7761583222c',
        measurementId: 'G-XF2HX4C2JS',
      ),
    );
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(options: androidFirebaseOptions);
    await _configureBackgroundTrackingService();
    await initBlockedAppNotification();
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp();
    await _configureBackgroundTrackingService();
  } else {
    await Firebase.initializeApp();
  }
  runApp(const ParentalControlApp());
}

Future<void> _configureBackgroundTrackingService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: (_) {},
      onBackground: onIosBackgroundFetch,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onLocationServiceStart,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.location],
      initialNotificationTitle: 'Parental Control',
      initialNotificationContent: 'Location & app usage shared with parent',
    ),
  );
}

class ParentalControlApp extends StatefulWidget {
  const ParentalControlApp({super.key});

  @override
  State<ParentalControlApp> createState() => _ParentalControlAppState();
}

class _ParentalControlAppState extends State<ParentalControlApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(showBlockedAppNotificationIfNeeded);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      showBlockedAppNotificationIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp.router(
            title: 'Parental Control',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            routerConfig: createAppRouter(auth),
          );
        },
      ),
    );
  }
}
