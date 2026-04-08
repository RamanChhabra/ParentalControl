import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/models/device_model.dart';
import '../../shared/models/location_model.dart';
import '../../shared/models/app_usage_model.dart';
import '../../shared/models/rules_model.dart';
import '../../shared/models/call_log_model.dart';
import '../../shared/models/sms_log_model.dart';
import '../../shared/models/app_install_request_model.dart';
import '../widgets/section_header.dart';
import 'edit_rules_screen.dart';

String _formatDate(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day}/${d.month}/${d.year}';
}

/// Parent view: location, app usage, call history, and rules (screen time, block apps).
class DeviceControlsScreen extends StatefulWidget {
  const DeviceControlsScreen({super.key, required this.device});

  final DeviceModel device;

  @override
  State<DeviceControlsScreen> createState() => _DeviceControlsScreenState();
}

class _DeviceControlsScreenState extends State<DeviceControlsScreen> {
  String? _childNameOverride;

  String get _displayName => _childNameOverride ?? widget.device.childName ?? 'Device';

  Future<void> _setChildName() async {
    final controller = TextEditingController(text: _displayName == 'Device' ? '' : _displayName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set child name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Child name',
            hintText: 'e.g. Alex',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await context.read<FirestoreService>().updateDeviceChildName(widget.device.deviceId, name);
    if (mounted) setState(() => _childNameOverride = name);
  }

  bool get _isIosDevice =>
      widget.device.deviceModel?.toLowerCase().contains('ios') == true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = context.read<FirestoreService>();
    final deviceId = widget.device.deviceId;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Device details'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _setChildName,
            tooltip: 'Set child name',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _ProfileHeader(displayName: _displayName, theme: theme),
          const SizedBox(height: 24),
          SectionHeader(icon: Icons.location_on_rounded, title: 'Location', subtitle: 'Last reported position'),
          _LocationCard(firestore: firestore, deviceId: deviceId),
          const SizedBox(height: 24),
          SectionHeader(
            icon: Icons.apps_rounded,
            title: 'App usage',
            subtitle: _isIosDevice ? 'Screen Time data from child device (iOS)' : 'Recent usage on this device',
          ),
          _AppUsageCard(firestore: firestore, deviceId: deviceId, isIosDevice: _isIosDevice),
          const SizedBox(height: 24),
          SectionHeader(icon: Icons.timer_rounded, title: 'Rules', subtitle: 'Screen time and blocked apps'),
          _RulesCard(firestore: firestore, deviceId: deviceId, device: widget.device),
          const SizedBox(height: 24),
          SectionHeader(icon: Icons.sms_rounded, title: 'Messages (SMS)', subtitle: 'With child consent'),
          if (!_isIosDevice) _SmsNotice(theme: theme),
          if (!_isIosDevice) const SizedBox(height: 8),
          _SmsCard(firestore: firestore, deviceId: deviceId, isIosDevice: _isIosDevice),
          const SizedBox(height: 24),
          SectionHeader(icon: Icons.get_app_rounded, title: 'App requests', subtitle: 'Install approval requests'),
          _AppRequestsCard(firestore: firestore, deviceId: deviceId),
          const SizedBox(height: 24),
          SectionHeader(icon: Icons.call_rounded, title: 'Call history', subtitle: 'Recent calls from child device'),
          _CallHistoryCard(firestore: firestore, deviceId: deviceId, isIosDevice: _isIosDevice),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.theme});

  final String displayName;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Child device',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.firestore, required this.deviceId});

  final FirestoreService firestore;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<LocationModel>>(
      stream: firestore.watchLocationForDevice(deviceId, limit: 1),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load location',
            subtitle: '${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _InfoCard(icon: Icons.hourglass_empty_rounded, title: 'Loading...', subtitle: null);
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _InfoCard(
            icon: Icons.location_off_rounded,
            title: 'No location yet',
            subtitle: 'On the child device: open this app, tap "Device linked", and allow location. '
                'Location is sent every few minutes while the app is open.',
          );
        }
        final loc = list.first;
        final mapsUri = Uri.parse('https://www.google.com/maps?q=${loc.latitude},${loc.longitude}');
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last location', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open Maps')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Maps'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppUsageCard extends StatelessWidget {
  const _AppUsageCard({required this.firestore, required this.deviceId, this.isIosDevice = false});

  final FirestoreService firestore;
  final String deviceId;
  final bool isIosDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AppUsageModel>>(
      stream: firestore.watchAppUsageForDevice(deviceId, limit: 10),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load app usage',
            subtitle: '${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _InfoCard(icon: Icons.hourglass_empty_rounded, title: 'Loading...', subtitle: null);
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _InfoCard(
            icon: Icons.apps_rounded,
            title: 'No usage data yet',
            subtitle: isIosDevice
                ? 'Screen Time data from the child device will appear here once authorized.'
                : 'App usage from the child device will appear here.',
          );
        }
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                for (int i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _AppUsageTile(usage: list[i], firestore: firestore, deviceId: deviceId, canBlock: !isIosDevice),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppUsageTile extends StatelessWidget {
  const _AppUsageTile({required this.usage, required this.firestore, required this.deviceId, this.canBlock = true});

  final AppUsageModel usage;
  final FirestoreService firestore;
  final String deviceId;
  final bool canBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pkg = usage.packageName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.apps_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(usage.appName ?? pkg, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(
        pkg,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${usage.usageMinutes} min', style: theme.textTheme.labelMedium),
          ),
          if (canBlock) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.block_rounded, size: 20, color: theme.colorScheme.error),
              tooltip: 'Block this app on child device',
              onPressed: () async {
                final rules = await firestore.getRules(deviceId);
                if (rules.blockedPackages.contains(pkg)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already blocked')));
                  }
                  return;
                }
                final updated = rules.copyWith(blockedPackages: [...rules.blockedPackages, pkg]);
                await firestore.setRules(deviceId, updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocked: $pkg')));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.firestore, required this.deviceId, required this.device});

  final FirestoreService firestore;
  final String deviceId;
  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RulesModel>(
      stream: firestore.watchRules(deviceId),
      builder: (context, snapshot) {
        final rules = snapshot.data ?? RulesModel(deviceId: deviceId);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RuleRow(
                  icon: Icons.timer_outlined,
                  label: 'Screen time limit',
                  value: rules.screenTimeLimitMinutes != null
                      ? '${rules.screenTimeLimitMinutes} min/day'
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _RuleRow(
                  icon: Icons.block_rounded,
                  label: 'Blocked apps',
                  value: rules.blockedPackages.isEmpty
                      ? 'None'
                      : '${rules.blockedPackages.length} app(s)',
                ),
                if (rules.appTimeLimitMinutes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RuleRow(
                    icon: Icons.schedule_rounded,
                    label: 'Per-app limits',
                    value: rules.appTimeLimitMinutes.entries
                        .map((e) => '${e.key}: ${e.value} min')
                        .take(3)
                        .join('; '),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditRulesScreen(device: device, rules: rules),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: const Text('Edit rules'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmsNotice extends StatelessWidget {
  const _SmsNotice({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SMS content is sensitive. Only recent messages from the child device are shown, and only after the child has given consent in the app.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsCard extends StatelessWidget {
  const _SmsCard({required this.firestore, required this.deviceId, this.isIosDevice = false});

  final FirestoreService firestore;
  final String deviceId;
  final bool isIosDevice;

  @override
  Widget build(BuildContext context) {
    if (isIosDevice) {
      return _InfoCard(
        icon: Icons.sms_rounded,
        title: 'Not available on iOS',
        subtitle: 'SMS/Messages cannot be read by third-party apps on iOS. This feature is Android-only.',
      );
    }
    return StreamBuilder<List<SmsLogModel>>(
      stream: firestore.watchSmsForDevice(deviceId, limit: 50),
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        if (snapshot.hasError) {
          return _InfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load messages',
            subtitle: '${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _InfoCard(icon: Icons.hourglass_empty_rounded, title: 'Loading...', subtitle: null);
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _InfoCard(
            icon: Icons.sms_rounded,
            title: 'No messages yet',
            subtitle: 'On the child device: enable Messages (SMS) and grant permission.',
          );
        }
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                for (int i = 0; i < list.take(30).length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _SmsTile(sms: list[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmsTile extends StatelessWidget {
  const _SmsTile({required this.sms});

  final SmsLogModel sms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = sms.type == 'sent' ? 'Sent' : 'Inbox';
    final body = sms.body.length > 80 ? '${sms.body.substring(0, 80)}...' : sms.body;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          sms.type == 'sent' ? Icons.send_rounded : Icons.inbox_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(sms.address, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '$typeLabel · $body',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AppRequestsCard extends StatelessWidget {
  const _AppRequestsCard({required this.firestore, required this.deviceId});

  final FirestoreService firestore;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppInstallRequestModel>>(
      stream: firestore.watchAppInstallRequestsForDevice(deviceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load requests',
            subtitle: '${snapshot.error}',
          );
        }
        final list = snapshot.data ?? [];
        final pending = list.where((r) => r.status == 'pending').toList();
        if (pending.isEmpty && list.isEmpty) {
          return _InfoCard(icon: Icons.get_app_rounded, title: 'No app requests yet', subtitle: null);
        }
        if (pending.isEmpty) {
          return _InfoCard(icon: Icons.check_circle_outline_rounded, title: 'No pending requests', subtitle: null);
        }
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: pending
                  .map(
                    (r) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.apps_rounded, size: 22),
                      ),
                      title: Text(r.appName),
                      subtitle: Text('Requested ${_formatDate(r.requestedAt)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: () async {
                              await firestore.setAppInstallRequestStatus(r.id, 'approved');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
                              }
                            },
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              await firestore.setAppInstallRequestStatus(r.id, 'denied');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Denied')));
                              }
                            },
                            child: const Text('Deny'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class _CallHistoryCard extends StatelessWidget {
  const _CallHistoryCard({required this.firestore, required this.deviceId, this.isIosDevice = false});

  final FirestoreService firestore;
  final String deviceId;
  final bool isIosDevice;

  @override
  Widget build(BuildContext context) {
    if (isIosDevice) {
      return _InfoCard(
        icon: Icons.call_rounded,
        title: 'Not available on iOS',
        subtitle: 'Call history is not exposed to third-party apps on iOS. This feature is Android-only.',
      );
    }
    return StreamBuilder<List<CallLogModel>>(
      stream: firestore.watchCallLogsForDevice(deviceId, limit: 50),
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        if (snapshot.hasError) {
          return _InfoCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load call history',
            subtitle: '${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _InfoCard(icon: Icons.hourglass_empty_rounded, title: 'Loading...', subtitle: null);
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _InfoCard(
            icon: Icons.call_rounded,
            title: 'No call history',
            subtitle: 'Call logs from the child device (Android) will appear here.',
          );
        }
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                for (int i = 0; i < list.take(20).length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _CallLogTile(call: list[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallLogTile extends StatelessWidget {
  const _CallLogTile({required this.call});

  final CallLogModel call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeIcon = call.type == 'incoming'
        ? Icons.call_received_rounded
        : call.type == 'outgoing'
            ? Icons.call_made_rounded
            : Icons.call_missed_rounded;
    final title = (call.name?.isNotEmpty == true) ? call.name! : (call.number.isNotEmpty ? call.number : 'Unknown number');
    final subtitle = (call.number.isNotEmpty && call.name != null && call.name!.isNotEmpty)
        ? '${call.number} · ${call.type} · ${call.durationSeconds}s · ${_formatDate(call.timestamp)}'
        : '${call.type} · ${call.durationSeconds}s · ${_formatDate(call.timestamp)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(typeIcon, size: 20, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
