import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../shared/utils/platform_check.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/firebase_services/auth_service.dart';
import '../../shared/firebase_services/firestore_service.dart';

/// Child enters 6-digit code from parent to link this device.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final firestore = context.read<FirestoreService>();
      final parentId = await firestore.claimPairingCode(code);
      if (parentId == null || !mounted) {
        setState(() {
          _error = 'Invalid or expired code';
          _loading = false;
        });
        return;
      }
      final deviceId = await _getOrCreateDeviceId();
      final auth = context.read<AuthService>();
      final childUid = auth.currentUser?.uid ?? '';
      await firestore.addDevice(
        deviceId: deviceId,
        parentId: parentId,
        childUid: childUid,
        deviceName: 'Child device',
        deviceModel: kIsWeb ? 'Web' : (isAndroid ? 'Android' : 'iOS'),
      );
      if (mounted) context.go('/child');
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'child_device_id';
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      final uid = context.read<AuthService>().currentUser?.uid ?? '';
      id = '${DateTime.now().millisecondsSinceEpoch}_${uid.hashCode.abs()}';
      await prefs.setString(key, id);
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link to parent')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter the 6-digit code from your parent\'s app.'),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(),
                  hintText: '000000',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _pair,
                child: _loading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Link device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
