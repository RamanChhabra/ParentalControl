// iOS background: one-shot location when system triggers background fetch (~15 min).
// Must be top-level for flutter_background_service. No app usage on iOS in background.
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/firebase_options_ios.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackgroundFetch(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: iosFirebaseOptions);

  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString('child_device_id');
  if (deviceId == null || deviceId.isEmpty) return true;

  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return true;
    if (!await Geolocator.isLocationServiceEnabled()) return true;
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );
    await FirebaseFirestore.instance.collection('location_logs').add({
      'device_id': deviceId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
  return true;
}
