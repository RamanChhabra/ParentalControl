import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/firebase_services/auth_service.dart';
import '../../shared/firebase_services/firestore_service.dart';

/// Parent generates a 6-digit code; child enters it on their app to link.
class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  String? _code;
  bool _loading = false;
  String? _error;

  Future<void> _generateCode() async {
    final auth = context.read<AuthService>();
    final parentId = auth.currentUser?.uid;
    if (parentId == null) {
      setState(() => _error = 'Not logged in');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await context.read<FirestoreService>().createPairingCode(parentId);
      if (mounted) setState(() {
        _code = code;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add child device')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'On your child\'s phone, open this app, sign in as Child, and enter the code below.',
              ),
              const SizedBox(height: 24),
              if (_code != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _code!,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Code expires in 10 minutes. Enter it on the child device.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _loading ? null : _generateCode,
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate code'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
