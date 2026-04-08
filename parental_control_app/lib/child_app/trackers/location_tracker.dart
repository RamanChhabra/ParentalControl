import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../shared/firebase_services/firestore_service.dart';

/// Sends location updates to Firestore every 10 minutes when app is in foreground.
/// For production, use flutter_background_service for background updates.
class LocationTracker {
  static Timer? _timer;
  static bool get isRunning => _timer != null;

  static void startIfNeeded(BuildContext context, {required String deviceId}) {
    if (_timer != null) return;
    final firestore = context.read<FirestoreService>();
    _send(firestore, deviceId);
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _send(firestore, deviceId));
  }

  static Future<void> _send(FirestoreService firestore, String deviceId) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        return;
      }
      if (permission == LocationPermission.deniedForever) return;
      if (await Geolocator.isLocationServiceEnabled() == false) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      await firestore.addLocationLog(
        deviceId: deviceId,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {}
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
