import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/models/device_model.dart';
import '../../shared/models/rules_model.dart';
import '../../shared/models/app_usage_model.dart';
import '../widgets/section_header.dart';

/// Parent: set screen time limit, per-app limits, and blocked apps for a device.
class EditRulesScreen extends StatefulWidget {
  const EditRulesScreen({super.key, required this.device, required this.rules});

  final DeviceModel device;
  final RulesModel rules;

  @override
  State<EditRulesScreen> createState() => _EditRulesScreenState();
}

class _EditRulesScreenState extends State<EditRulesScreen> {
  late int? _screenTimeMinutes;
  late List<String> _blockedPackages;
  late Map<String, int> _appTimeLimits;
  late List<String> _blockedDomains;
  late List<String> _allowedDomains;
  final _screenTimeController = TextEditingController();
  final _blockPackageController = TextEditingController();
  final _blockDomainController = TextEditingController();
  final _allowDomainController = TextEditingController();
  String? _newAppLimitPackage;
  final _newAppLimitMinutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _screenTimeMinutes = widget.rules.screenTimeLimitMinutes;
    _blockedPackages = List.from(widget.rules.blockedPackages);
    _appTimeLimits = Map.from(widget.rules.appTimeLimitMinutes);
    _blockedDomains = List.from(widget.rules.blockedDomains);
    _allowedDomains = List.from(widget.rules.allowedDomains);
    _screenTimeController.text = _screenTimeMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _screenTimeController.dispose();
    _blockPackageController.dispose();
    _blockDomainController.dispose();
    _allowDomainController.dispose();
    _newAppLimitMinutesController.dispose();
    super.dispose();
  }

  Future<void> _openStoreSearch(BuildContext context, {required bool isAndroid}) async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAndroid ? 'Search Play Store' : 'Search App Store'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isAndroid ? 'e.g. YouTube, TikTok' : 'e.g. Instagram, TikTok',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;
    final uri = isAndroid
        ? Uri.parse('https://play.google.com/store/search?q=${Uri.encodeComponent(query)}')
        : Uri.parse('https://apps.apple.com/search?term=${Uri.encodeComponent(query)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open store')));
      }
    }
  }

  Future<void> _save() async {
    final v = int.tryParse(_screenTimeController.text.trim());
    setState(() {
      _screenTimeMinutes = (v != null && v > 0) ? v : null;
    });
    final updated = RulesModel(
      deviceId: widget.device.deviceId,
      blockedPackages: _blockedPackages,
      screenTimeLimitMinutes: _screenTimeMinutes,
      appTimeLimitMinutes: _appTimeLimits,
      bedtimeStart: widget.rules.bedtimeStart,
      bedtimeEnd: widget.rules.bedtimeEnd,
      blockedDomains: _blockedDomains,
      allowedDomains: _allowedDomains,
      updatedAt: widget.rules.updatedAt,
    );
    await context.read<FirestoreService>().setRules(widget.device.deviceId, updated);
    if (mounted) Navigator.of(context).pop();
  }

  bool get _isAndroidDevice =>
      widget.device.deviceModel?.toLowerCase().contains('android') ?? false;
  bool get _isIosDevice =>
      widget.device.deviceModel?.toLowerCase().contains('ios') ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceId = widget.device.deviceId;
    final firestore = context.watch<FirestoreService>();

    final inputDecoration = InputDecoration(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Screen time & blocking'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SectionHeader(
            icon: Icons.timer_rounded,
            title: 'Daily screen time limit',
            subtitle: 'Total minutes per day (leave empty for no limit)',
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _screenTimeController,
                keyboardType: TextInputType.number,
                decoration: inputDecoration.copyWith(
                  hintText: 'e.g. 120',
                  prefixIcon: const Icon(Icons.schedule_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            icon: Icons.block_rounded,
            title: 'Blocked apps',
            subtitle: _isIosDevice
                ? 'On iOS, blocks are set on the child\'s device (Blocked apps → Screen Time). You can still add bundle IDs here for reference.'
                : 'Select from apps on your child\'s device (from Play Store) or add by package name below.',
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select from apps on child\'s device',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isAndroidDevice
                        ? 'Apps the child has used (from Play Store). Tap Block to add.'
                        : 'Apps from child\'s Screen Time usage. On iOS, blocking is done on the child device.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<AppUsageModel>>(
                    stream: firestore.watchAppUsageForDevice(deviceId, limit: 100),
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      final byPackage = <String, AppUsageModel>{};
                      for (final u in list) {
                        if (!byPackage.containsKey(u.packageName)) {
                          byPackage[u.packageName] = u;
                        }
                      }
                      final apps = byPackage.values.toList();
                      if (apps.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _isAndroidDevice
                                ? 'No app usage yet. Once the child uses apps, they will appear here. Or add by package name below.'
                                : 'No Screen Time data yet. Ask the child to open the app and allow Screen Time. Or add by bundle ID below.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final u in apps) ...[
                            _BlockAppTile(
                              usage: u,
                              isBlocked: _blockedPackages.contains(u.packageName),
                              onBlock: () => setState(() {
                                if (!_blockedPackages.contains(u.packageName)) {
                                  _blockedPackages = [..._blockedPackages, u.packageName];
                                }
                              }),
                              onUnblock: () => setState(() {
                                _blockedPackages = _blockedPackages.where((x) => x != u.packageName).toList();
                              }),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  if (_blockedPackages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Blocked (${_blockedPackages.length})',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _blockedPackages.map((p) {
                        return Chip(
                          label: Text(p, style: theme.textTheme.bodySmall),
                          onDeleted: () => setState(() => _blockedPackages = _blockedPackages.where((x) => x != p).toList()),
                          deleteIcon: const Icon(Icons.close_rounded, size: 18),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      title: Row(
                        children: [
                          Icon(Icons.code_rounded, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _isAndroidDevice
                                ? 'Add by package name (advanced)'
                                : 'Add by bundle ID (advanced)',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isAndroidDevice) ...[
                                Text(
                                  'To block an app not in the list: open Play Store, search for the app, open its page. In the browser URL you\'ll see id=com.example.app — that\'s the package name.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _openStoreSearch(context, isAndroid: true),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: const Text('Open Play Store search'),
                                ),
                              ] else if (_isIosDevice) ...[
                                Text(
                                  'On iOS, blocking is best done on the child\'s device (Blocked apps → Screen Time). You can add a bundle ID here for your records (e.g. com.apple.mobilesafari).',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _openStoreSearch(context, isAndroid: false),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: const Text('Open App Store search'),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _blockPackageController,
                                      decoration: inputDecoration.copyWith(
                                        hintText: _isAndroidDevice ? 'e.g. com.google.android.youtube' : 'e.g. com.example.app',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () {
                                      final p = _blockPackageController.text.trim();
                                      if (p.isEmpty) return;
                                      setState(() {
                                        _blockedPackages = [..._blockedPackages, p];
                                        _blockedPackages = _blockedPackages.toSet().toList();
                                        _blockPackageController.clear();
                                      });
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isAndroidDevice) ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        title: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Device owner (hide apps from launcher)',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'By default, blocked apps are only brought to background when the child opens them. '
                              'To fully hide blocked apps from the launcher (child cannot open them), set this app as device owner on the child device.\n\n'
                              'Requirements: child device must have no Google/user accounts (or use a dedicated kid device after factory reset).\n\n'
                              'On a computer with adb connected to the child device, run:\n'
                              'adb shell dpm set-device-owner com.parentalcontrol.app/.DeviceAdminReceiver\n\n'
                              'Then open the Parental Control app on the child device and the blocked apps will be hidden from the launcher. '
                              'To remove device owner later: Settings → Apps → Parental Control → Uninstall (or adb shell dpm remove-active-admin).',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            icon: Icons.language_rounded,
            title: 'Web filtering (Safe Browser)',
            subtitle: 'Block or allow domains when child uses in-app browser',
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blocked domains',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _blockDomainController,
                          decoration: inputDecoration.copyWith(
                            hintText: 'domain.com',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final d = _blockDomainController.text.trim();
                          if (d.isEmpty) return;
                          setState(() {
                            _blockedDomains = [..._blockedDomains, d];
                            _blockedDomains = _blockedDomains.toSet().toList();
                            _blockDomainController.clear();
                          });
                        },
                        child: const Text('Block'),
                      ),
                    ],
                  ),
                  if (_blockedDomains.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _blockedDomains.map((d) => Chip(
                        label: Text(d, style: theme.textTheme.bodySmall),
                        onDeleted: () => setState(() => _blockedDomains = _blockedDomains.where((x) => x != d).toList()),
                        deleteIcon: const Icon(Icons.close_rounded, size: 18),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Allowed only (whitelist; leave empty to use block list only)',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _allowDomainController,
                          decoration: inputDecoration.copyWith(
                            hintText: 'domain.com',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final d = _allowDomainController.text.trim();
                          if (d.isEmpty) return;
                          setState(() {
                            _allowedDomains = [..._allowedDomains, d];
                            _allowedDomains = _allowedDomains.toSet().toList();
                            _allowDomainController.clear();
                          });
                        },
                        child: const Text('Allow'),
                      ),
                    ],
                  ),
                  if (_allowedDomains.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allowedDomains.map((d) => Chip(
                        label: Text(d, style: theme.textTheme.bodySmall),
                        onDeleted: () => setState(() => _allowedDomains = _allowedDomains.where((x) => x != d).toList()),
                        deleteIcon: const Icon(Icons.close_rounded, size: 18),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            icon: Icons.apps_rounded,
            title: 'Per-app daily time limit',
            subtitle: 'Set a daily cap (minutes) for specific apps',
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_appTimeLimits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No per-app limits set. Use recent apps below to add one.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ..._appTimeLimits.entries.map((e) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.timer_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        title: Text(e.key, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${e.value} min/day', style: theme.textTheme.labelMedium),
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline_rounded, color: theme.colorScheme.error),
                              onPressed: () => setState(() => _appTimeLimits.remove(e.key)),
                              tooltip: 'Remove limit',
                            ),
                          ],
                        ),
                      );
                    }),
                  if (_appTimeLimits.isNotEmpty) Divider(height: 1, color: theme.dividerColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Recent apps — tap Set limit to add',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  StreamBuilder<List<AppUsageModel>>(
                    stream: firestore.watchAppUsageForDevice(deviceId, limit: 20),
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'No recent app usage. Usage from the child device will appear here.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (int i = 0; i < list.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: theme.dividerColor),
                            _AppLimitTile(
                              usage: list[i],
                              currentMinutes: _appTimeLimits[list[i].packageName],
                              onSetLimit: () => _showSetAppLimit(context, list[i].packageName, list[i].appName),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetAppLimit(BuildContext context, String package, String? appName) {
    _newAppLimitPackage = package;
    _newAppLimitMinutesController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Daily limit: ${appName ?? package}'),
        content: TextField(
          controller: _newAppLimitMinutesController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Minutes per day',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final m = int.tryParse(_newAppLimitMinutesController.text.trim());
              if (m != null && m > 0 && _newAppLimitPackage != null) {
                setState(() => _appTimeLimits[_newAppLimitPackage!] = m);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class _BlockAppTile extends StatelessWidget {
  const _BlockAppTile({
    required this.usage,
    required this.isBlocked,
    required this.onBlock,
    required this.onUnblock,
  });

  final AppUsageModel usage;
  final bool isBlocked;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = usage.appName ?? usage.packageName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      dense: true,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.apps_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(
        usage.packageName,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isBlocked
          ? FilledButton.tonal(
              onPressed: onUnblock,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Unblock'),
            )
          : FilledButton(
              onPressed: onBlock,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Block'),
            ),
    );
  }
}

class _AppLimitTile extends StatelessWidget {
  const _AppLimitTile({
    required this.usage,
    required this.currentMinutes,
    required this.onSetLimit,
  });

  final AppUsageModel usage;
  final int? currentMinutes;
  final VoidCallback onSetLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.apps_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(usage.appName ?? usage.packageName, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        usage.packageName,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: currentMinutes != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$currentMinutes min', style: theme.textTheme.labelMedium),
            )
          : FilledButton.tonal(
              onPressed: onSetLimit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Set limit'),
            ),
    );
  }
}
