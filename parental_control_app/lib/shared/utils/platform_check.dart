import 'package:flutter/foundation.dart';

/// Use this instead of dart:io Platform so the app compiles and runs on web.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get isIOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
