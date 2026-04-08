import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../trackers/sms_tracker.dart';

/// Child must accept disclosure before SMS can be shared with parent. Android only.
class SmsConsentScreen extends StatelessWidget {
  const SmsConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages (SMS) sharing')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.sms, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Share messages with your parent?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Card(
            color: Color(0xFFFFF8E1),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'If you turn this on, your parent will be able to see your recent text messages (sender, content, and time) in the parent app. '
                'This is sensitive information. Only enable this if your parent has asked you to and you agree.\n\n'
                'You can turn this off later in settings.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await SmsTracker.setConsent(true);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('I agree, share messages with my parent'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No thanks'),
          ),
        ],
      ),
    );
  }

  static Future<String?> _getDeviceId(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('child_device_id');
  }
}
