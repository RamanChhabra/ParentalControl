import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/models/app_install_request_model.dart';

/// Child: request an app for parent to approve; view status of requests.
class AppRequestScreen extends StatefulWidget {
  const AppRequestScreen({super.key});

  @override
  State<AppRequestScreen> createState() => _AppRequestScreenState();
}

class _AppRequestScreenState extends State<AppRequestScreen> {
  final _appNameController = TextEditingController();
  final _packageController = TextEditingController();
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _deviceId = prefs.getString('child_device_id'));
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final name = _appNameController.text.trim();
    if (name.isEmpty) return;
    final deviceId = _deviceId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (deviceId == null || uid == null) return;
    await context.read<FirestoreService>().addAppInstallRequest(
      deviceId: deviceId,
      requestedByUid: uid,
      appName: name,
      packageName: _packageController.text.trim().isEmpty ? null : _packageController.text.trim(),
    );
    _appNameController.clear();
    _packageController.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to parent')));
  }

  @override
  Widget build(BuildContext context) {
    if (_deviceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request an app')),
        body: const Center(child: Text('Link this device first.')),
      );
    }
    final firestore = context.watch<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Request an app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ask your parent to allow an app. They will see your request and can approve or deny it.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _appNameController,
            decoration: const InputDecoration(
              labelText: 'App name',
              hintText: 'e.g. Minecraft',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _packageController,
            decoration: const InputDecoration(
              labelText: 'Package name (optional)',
              hintText: 'e.g. com.mojang.minecraftpe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitRequest,
            child: const Text('Send request'),
          ),
          const SizedBox(height: 24),
          const Text('My requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<AppInstallRequestModel>>(
            stream: firestore.watchAppInstallRequestsForDevice(_deviceId!),
            builder: (context, snapshot) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final list = (snapshot.data ?? [])
                  .where((r) => r.requestedByUid == uid)
                  .toList()
                ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
              if (list.isEmpty) {
                return const Card(child: ListTile(title: Text('No requests yet')));
              }
              return Column(
                children: list.map((r) {
                  final statusIcon = r.status == 'approved'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : r.status == 'denied'
                          ? const Icon(Icons.cancel, color: Colors.red)
                          : const Icon(Icons.schedule, color: Colors.orange);
                  return Card(
                    child: ListTile(
                      leading: statusIcon,
                      title: Text(r.appName),
                      subtitle: Text('${r.status} · ${_formatDate(r.requestedAt)}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}
