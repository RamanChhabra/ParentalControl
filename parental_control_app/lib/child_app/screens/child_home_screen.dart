import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/utils/platform_check.dart';
import '../../child_app/trackers/location_tracker.dart';
import '../../child_app/trackers/app_usage_tracker.dart';
import '../../child_app/trackers/app_usage_tracker_ios.dart';
import '../../child_app/trackers/call_log_tracker.dart';
import '../../child_app/trackers/sms_tracker.dart';
import '../../shared/utils/ios_screen_time_helper.dart';
import '../../shared/models/rules_model.dart';
import '../../shared/utils/blocked_app_notification.dart';
import '../../shared/utils/device_owner_helper.dart';

const _prefBlockedPackages = 'blocked_packages_json';

/// Child device home: shows status and runs trackers (location, app usage).
class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> with WidgetsBindingObserver {
  bool _paired = false;
  bool _isLoading = true;
  bool _smsConsent = false;
  StreamSubscription<RulesModel>? _rulesSubscription;

  @override
  void initState() {
    super.initState();
    if (isIOS) {
      WidgetsBinding.instance.addObserver(this);
      AppUsageTrackerIos.iosAppBecameActive();
    }
    _loadDeviceId();
    if (isAndroid) Future.microtask(showBlockedAppNotificationIfNeeded);
  }

  @override
  void dispose() {
    if (isIOS) {
      AppUsageTrackerIos.iosAppBackgrounded();
      WidgetsBinding.instance.removeObserver(this);
    }
    _rulesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!isIOS) return;
    if (state == AppLifecycleState.resumed) {
      AppUsageTrackerIos.iosAppBecameActive();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AppUsageTrackerIos.iosAppBackgrounded();
    }
  }

  Future<void> _requestBackgroundLocationAndStartService() async {
    if (kIsWeb) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) await service.startService();
    } catch (_) {}
  }

  Future<void> _loadDeviceId() async {
    try {
      final firestore = context.read<FirestoreService>();
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('child_device_id');
      if (id == null || id.isEmpty) {
        if (mounted) setState(() {
          _paired = false;
          _isLoading = false;
        });
        return;
      }
      final device = await firestore.getDeviceByDeviceId(id);
      if (!mounted) return;
      final smsConsent = isAndroid ? await SmsTracker.hasConsent() : false;
      if (mounted) setState(() {
        _paired = device != null;
        _isLoading = false;
        _smsConsent = smsConsent;
      });
      if (_paired && mounted) {
        if (!kIsWeb) LocationTracker.startIfNeeded(context, deviceId: id);
        if (isAndroid) {
          AppUsageTracker.startIfNeeded(context, deviceId: id);
          CallLogTracker.syncIfNeeded(context, deviceId: id);
          if (smsConsent) SmsTracker.syncIfNeeded(context, deviceId: id);
          _rulesSubscription?.cancel();
          _rulesSubscription = firestore.watchRules(id).listen((rules) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefBlockedPackages, jsonEncode(rules.blockedPackages));
            await syncBlockedAppsWithDeviceOwner(rules.blockedPackages);
          });
          final rules = await firestore.getRules(id);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefBlockedPackages, jsonEncode(rules.blockedPackages));
          await syncBlockedAppsWithDeviceOwner(rules.blockedPackages);
        }
        if (isIOS) {
          AppUsageTrackerIos.startIfNeeded(context, deviceId: id);
        }
        if (!kIsWeb) _requestBackgroundLocationAndStartService();
      }
    } catch (_) {
      if (mounted) setState(() {
        _paired = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_paired) {
      return Scaffold(
        appBar: AppBar(title: const Text('Child device')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Link this device to a parent account.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/child/pair'),
                child: const Text('Enter pairing code'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Parental Control')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Device linked'),
              subtitle: Text('Location and app usage are shared with your parent.'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Location'),
            subtitle: const Text('Sent periodically to parent.'),
            trailing: LocationTracker.isRunning ? const Icon(Icons.sync) : null,
          ),
          if (isAndroid)
            const ListTile(
              leading: Icon(Icons.apps),
              title: Text('App usage'),
              subtitle: Text('Usage time is shared with parent. Grant Usage Access permission.'),
            ),
          if (isIOS)
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('App usage (Screen Time)'),
              subtitle: Text(AppUsageTrackerIos.isRunning
                  ? 'Screen Time data is shared with parent.'
                  : 'Tap to allow Screen Time access so usage can sync to your parent.'),
              trailing: AppUsageTrackerIos.isRunning ? const Icon(Icons.sync) : const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await IosScreenTimeHelper.requestScreenTimeAccess();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Screen Time access granted. The parent dashboard receives time this app stays open (about every 15 min). Full per-app device usage on iOS needs a native Device Activity Report extension; Apple does not expose that data to Flutter from the main app alone.'
                          : 'Screen Time access was not granted. In Settings → Screen Time, ensure this app can use Screen Time, and that the app is signed with the Family Controls capability.',
                    ),
                  ),
                );
              },
            ),
          if (isIOS)
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('Blocked apps (Screen Time)'),
              subtitle: const Text('Choose which apps to block, or remove all. Uses Apple Screen Time.'),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'select') {
                    final result = await IosScreenTimeHelper.selectAppsToBlock();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                  } else if (value == 'remove') {
                    final result = await IosScreenTimeHelper.removeAllAppRestrictions();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'select', child: Text('Choose apps to block')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove all restrictions')),
                ],
              ),
              onTap: () async {
                final result = await IosScreenTimeHelper.selectAppsToBlock();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
              },
            ),
          if (isAndroid)
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages (SMS)'),
              subtitle: Text(_smsConsent
                  ? 'Recent messages are shared with parent.'
                  : 'Tap to enable (requires your consent).'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (_smsConsent) {
                  final id = (await SharedPreferences.getInstance()).getString('child_device_id');
                  if (id != null && mounted) SmsTracker.syncIfNeeded(context, deviceId: id);
                } else {
                  await context.push('/child/sms-consent');
                  if (mounted) _loadDeviceId();
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Safe Browser'),
            subtitle: const Text('Browse the web with parent-defined filtering.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/child/safe-browser'),
          ),
          ListTile(
            leading: const Icon(Icons.get_app),
            title: const Text('Request an app'),
            subtitle: const Text('Ask your parent to approve an app.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/child/app-request'),
          ),
        ],
      ),
    );
  }
}
