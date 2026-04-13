import 'package:flutter/material.dart';
import '../../shared/utils/android_parental_control_channel.dart';
import '../../shared/utils/mdm_ca_certificate.dart';

const androidChildSetupWizardDoneKey = 'android_child_setup_wizard_done_v1';

/// In-app onboarding styled like Qustodio: education screens + [android_parental_control_channel]
/// to open the real system Settings / dialogs. System Settings UIs themselves cannot be embedded.
class AndroidChildSetupScreen extends StatefulWidget {
  const AndroidChildSetupScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<AndroidChildSetupScreen> createState() => _AndroidChildSetupScreenState();
}

class _SetupBrand {
  static const indigo = Color(0xFF6366F1);
  static const indigoDark = Color(0xFF4F46E5);
  static const successGreen = Color(0xFF4CAF50);
  static const settingsGreyBg = Color(0xFFF2F2F7);
  static const cardWhite = Colors.white;
  static const appName = 'Parental Control';
}

class _AndroidChildSetupScreenState extends State<AndroidChildSetupScreen>
    with WidgetsBindingObserver {
  int _step = 0;
  static const int _pageCount = 9;

  bool _usageOk = false;
  bool _batteryOk = false;
  bool _a11yOk = false;
  bool _adminOk = false;
  bool _notifOk = false;
  bool _overlayOk = false;
  bool _vpnOk = false;

  static const _a11yServiceFlattened =
      'com.parentalcontrol.app/com.parentalcontrol.app.ParentalControlAccessibilityService';

  int _usageTab = 0; // 0 All, 1 Allowed, 2 Not allowed — decorative
  int _notifTab = 0;
  bool _caDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final usage = await androidHasUsageStatsPermission();
    final battery = await androidIsIgnoringBatteryOptimizations();
    final a11y = await androidIsAccessibilityServiceEnabled(_a11yServiceFlattened);
    final admin = await androidIsDeviceAdminActive();
    final notif = await androidIsNotificationListenerEnabledForPackage();
    final overlay = await androidCanDrawOverlays();
    final vpn = !await androidIsVpnPrepareNeeded();
    if (mounted) {
      setState(() {
        _usageOk = usage;
        _batteryOk = battery;
        _a11yOk = a11y;
        _adminOk = admin;
        _notifOk = notif;
        _overlayOk = overlay;
        _vpnOk = vpn;
      });
    }
  }

  void _next() {
    if (_step < _pageCount - 1) {
      setState(() => _step++);
    } else {
      widget.onFinished();
    }
  }

  void _finish() {
    widget.onFinished();
  }

  Future<void> _confirmOptOut() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip monitoring?'),
        content: const Text(
          'Your parent may not see full activity on this device until setup is completed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit setup')),
        ],
      ),
    );
    if (go == true && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _stepBackground(),
      appBar: AppBar(
        backgroundColor: _step == 0 || _step == 3 || _step == 5 ? _SetupBrand.settingsGreyBg : null,
        surfaceTintColor: Colors.transparent,
        title: Text(_appBarTitle()),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: List.generate(_pageCount, (i) {
                final done = i < _step;
                final active = i == _step;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: done || active ? 1 : 0.12,
                        minHeight: 3,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: active ? _SetupBrand.indigo : cs.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(child: _buildPage()),
          _buildBottomActions(cs),
        ],
      ),
    );
  }

  Color _stepBackground() {
    switch (_step) {
      case 0:
      case 3:
      case 5:
        return _SetupBrand.settingsGreyBg;
      default:
        return _SetupBrand.cardWhite;
    }
  }

  String _appBarTitle() {
    switch (_step) {
      case 0:
        return 'Usage access';
      case 1:
        return 'Background activity';
      case 2:
        return 'Allow accessibility';
      case 3:
        return 'Accessibility';
      case 4:
        return 'Activate device admin';
      case 5:
        return 'Device & app notifications';
      case 6:
        return 'Display over other apps';
      case 7:
        return 'Enhance protection';
      case 8:
        return 'Install certificate';
      default:
        return 'Set up this device';
    }
  }

  Widget _buildPage() {
    switch (_step) {
      case 0:
        return _pageUsageAccessReplica();
      case 1:
        return _pageBatteryIntro();
      case 2:
        return _pageAccessibilityEducation();
      case 3:
        return _pageAccessibilitySettingsMock();
      case 4:
        return _pageDeviceAdminIntro();
      case 5:
        return _pageNotificationAccessReplica();
      case 6:
        return _pageDisplayOverOtherApps();
      case 7:
        return _pageEnhanceVpn();
      case 8:
        return _pageInstallCaCertificate();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Screenshot: Usage access — description, segmented All / Allowed / Not allowed, app list.
  Widget _pageUsageAccessReplica() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'This permission allows an app to track what other apps you\'re using and how often, '
              'as well as your operator, language settings and other details.',
              style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF666666)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _pillSegmented(
              labels: const ['All', 'Allowed', 'Not allowed'],
              selected: _usageTab,
              onChanged: (i) => setState(() => _usageTab = i),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                _settingsListRow(
                  leading: Icons.android_rounded,
                  title: 'Android System',
                  status: 'Allowed',
                ),
                const Divider(height: 1),
                _settingsListRow(
                  leading: Icons.shield_outlined,
                  title: _SetupBrand.appName,
                  status: _usageOk ? 'Allowed' : 'Not allowed',
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (_usageOk)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _SetupBrand.successGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Usage access is on', style: TextStyle(color: _SetupBrand.successGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Screenshot: battery / allow in background — illustration + copy.
  Widget _pageBatteryIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.smartphone_rounded, size: 88, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 28),
          const Text(
            'Let app always run in background?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          Text(
            'Allowing ${_SetupBrand.appName} to always run in the background may reduce battery life. '
            'You can change this later from Settings → Apps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: Colors.grey.shade700),
          ),
          if (_batteryOk) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Unrestricted background is allowed',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Screenshot: Allow accessibility — green row, hand, primary + opt out.
  Widget _pageAccessibilityEducation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _fakeSettingsRow(active: false, label: '········'),
                    const SizedBox(height: 10),
                    _fakeSettingsRow(active: false, label: '········'),
                    const SizedBox(height: 10),
                    _fakeSettingsRow(active: true, label: _SetupBrand.appName),
                  ],
                ),
                Positioned(
                  right: 8,
                  bottom: 18,
                  child: Icon(Icons.touch_app_rounded, size: 56, color: _SetupBrand.indigo.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Allow accessibility',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Switch on accessibility to let ${_SetupBrand.appName} report this device\'s activity to your parent.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'This helps supervise screen time and online interactions when your parent enables those features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: Colors.grey.shade600),
          ),
          if (_a11yOk) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Accessibility is on for ${_SetupBrand.appName}',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Screenshot: Accessibility root — tabs + Convenience + Downloaded apps.
  Widget _pageAccessibilitySettingsMock() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _tabChip('General', selected: true),
                _tabChip('Vision', selected: false),
                _tabChip('Hearing', selected: false),
                _tabChip('Interaction', selected: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Convenience', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _miniTile(title: 'Press Power button to end calls', subtitle: 'This works only when the screen is on.', trailing: Switch(value: false, onChanged: (_) {})),
                const Divider(height: 1),
                _miniTile(title: 'Accessibility Menu', subtitle: 'Show frequently used functions in a large menu.', chevron: true),
                const Divider(height: 1),
                _miniTile(title: 'Accessibility button', chevron: true),
                const Divider(height: 1),
                _miniTile(
                  title: 'Shortcut from Lock screen',
                  subtitle: 'Allow accessibility function shortcuts from the Lock screen.',
                  chevron: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('More', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              title: const Text('Downloaded apps', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tap Downloaded apps, then find ${_SetupBrand.appName} and turn it on. '
              'Android will show a safety dialog — read it and allow if you agree.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  /// Screenshot: Activate device admin — illustration + Activate now.
  Widget _pageDeviceAdminIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 24,
                  top: 0,
                  child: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red.shade400),
                ),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _SetupBrand.indigo,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: _SetupBrand.indigo.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 52),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 8,
                  child: Icon(Icons.pan_tool_alt_rounded, size: 48, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Activate device admin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          Text(
            'This ensures your child can\'t remove ${_SetupBrand.appName} without a parent. '
            'The next screen is Android\'s system confirmation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
          if (_adminOk) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                Text('Device admin is active', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Screenshot: Device & app notifications — description + segmented + list.
  Widget _pageNotificationAccessReplica() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'This permission allows an app to read all notifications (including personal information such as contact names '
              'and notification content), dismiss notifications, trigger actions from notifications, '
              'turn Do Not Disturb on or off and change notification settings.',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF555555)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _pillSegmented(
              labels: const ['All', 'Allowed', 'Not allowed'],
              selected: _notifTab,
              onChanged: (i) => setState(() => _notifTab = i),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                _settingsListRow(leading: Icons.directions_car_outlined, title: 'Android Auto', status: 'Allowed'),
                const Divider(height: 1),
                _settingsListRow(
                  leading: Icons.shield_outlined,
                  title: _SetupBrand.appName,
                  status: _notifOk ? 'Allowed' : 'Not allowed',
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (_notifOk)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: _SetupBrand.successGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Notification access is on', style: TextStyle(color: _SetupBrand.successGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Display over other apps — needed for block/warning overlays on some setups.
  Widget _pageDisplayOverOtherApps() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.smartphone_rounded, size: 88, color: Colors.grey.shade500),
                Positioned(
                  top: 8,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _SetupBrand.indigo.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Display over other apps',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Allow ${_SetupBrand.appName} to draw on top of other apps when your parent enables full-screen '
            'warnings or blocking. Android will show a system screen to turn this on.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
          if (_overlayOk) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Overlay permission granted',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Screenshot: Enhance protection — VPN step (CA is the next screen).
  Widget _pageEnhanceVpn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _doodleTile(Icons.check_rounded, _SetupBrand.successGreen),
              const SizedBox(width: 12),
              _doodleTile(Icons.priority_high_rounded, const Color(0xFF64B5F6)),
              const SizedBox(width: 12),
              _doodleTile(Icons.close_rounded, Colors.red.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Icon(Icons.person_outline_rounded, size: 72, color: Colors.grey.shade700),
          const SizedBox(height: 20),
          const Text(
            'Enhance protection',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Allowing the VPN connection can improve web filtering and reporting on some devices. '
            'The next screen after this helps with a security certificate if your parent uses one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
              children: const [
                TextSpan(text: 'Select '),
                TextSpan(text: 'OK', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' on the system dialog to allow the VPN connection.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_vpnOk) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'VPN permission addressed',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Install CA / user certificate — opens Security settings (OEM-specific path inside).
  Widget _pageInstallCaCertificate() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _SetupBrand.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.verified_user_outlined, size: 72, color: _SetupBrand.indigo),
          ),
          const SizedBox(height: 28),
          const Text(
            'Install a certificate (optional)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Healthkart MDM hosts the filtering CA at the URL below. Tap the main button to download it '
            'and open Android’s installer. Your parent may ask you to trust this CA for safer browsing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          SelectableText(
            kParentalCaCertUrl,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.35, color: _SetupBrand.indigoDark, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            'If automatic install does not open, use Open security settings and install from storage.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ColorScheme cs) {
    final isLast = _step == _pageCount - 1;

    Future<void> primary() async {
      switch (_step) {
        case 0:
          await androidOpenUsageAccessSettings();
          break;
        case 1:
          await androidRequestIgnoreBatteryOptimizations();
          break;
        case 2:
          await androidOpenAccessibilitySettings();
          break;
        case 3:
          await androidOpenAccessibilitySettings();
          break;
        case 4:
          await androidRequestDeviceAdmin(
            explanation:
                '${_SetupBrand.appName} needs device admin so it can’t be removed without your parent’s permission.',
          );
          break;
        case 5:
          await androidOpenNotificationListenerSettings();
          break;
        case 6:
          await androidOpenManageOverlaySettings();
          break;
        case 7:
          final vpnShown = await androidLaunchVpnPrepare();
          if (mounted && !vpnShown) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'VPN permission was already granted, or your device blocked the prompt. You can tap Continue.',
                ),
              ),
            );
          }
          break;
        case 8:
          setState(() => _caDownloading = true);
          try {
            final outcome = await downloadAndInstallParentalCaFromMdm();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(mdmCaInstallOutcomeMessage(outcome))),
            );
            if (outcome == MdmCaInstallOutcome.installUiFailed) {
              await androidOpenSecuritySettings();
            }
          } finally {
            if (mounted) setState(() => _caDownloading = false);
          }
          break;
        default:
          break;
      }
      await _refreshStatuses();
    }

    String primaryLabel() {
      switch (_step) {
        case 0:
          return 'Allow now';
        case 1:
          return 'Allow now';
        case 2:
          return 'Allow now';
        case 3:
          return 'Open system Accessibility';
        case 4:
          return 'Activate now';
        case 5:
          return 'Allow now';
        case 6:
          return 'Allow display over other apps';
        case 7:
          return 'Allow VPN';
        case 8:
          return 'Download & install from MDM';
        default:
          return 'Allow VPN';
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _stepBackground(),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: (_caDownloading && _step == 8) ? null : primary,
            style: FilledButton.styleFrom(
              backgroundColor: _SetupBrand.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _caDownloading && _step == 8
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(primaryLabel(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (_step == 8) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _caDownloading ? null : () => androidOpenSecuritySettings(),
              child: Text(
                'Open security settings only',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              if (isLast) {
                widget.onFinished();
              } else {
                _next();
              }
            },
            child: Text(
              isLast ? 'Done — go to home' : 'Continue',
              style: TextStyle(color: _SetupBrand.indigoDark, fontWeight: FontWeight.w600),
            ),
          ),
          if (_step == 2)
            TextButton(
              onPressed: _confirmOptOut,
              child: Text(
                'I don\'t want to monitor this device',
                style: TextStyle(color: cs.secondary),
              ),
            )
          else if (!isLast)
            TextButton(
              onPressed: _next,
              child: Text('Set up later', style: TextStyle(color: cs.outline)),
            ),
        ],
      ),
    );
  }

  // —— UI building blocks ——

  Widget _pillSegmented({
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                    color: sel ? Colors.black87 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _settingsListRow({
    required IconData leading,
    required String title,
    required String status,
    bool emphasize = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: emphasize ? _SetupBrand.indigo.withValues(alpha: 0.12) : Colors.grey.shade200,
        child: Icon(leading, color: emphasize ? _SetupBrand.indigo : Colors.grey.shade700, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500, fontSize: 15),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
        ],
      ),
    );
  }

  Widget _fakeSettingsRow({required bool active, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active ? _SetupBrand.successGreen : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                letterSpacing: active ? 0.2 : 2,
              ),
            ),
          ),
          Container(
            width: 44,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: active ? Colors.white.withValues(alpha: 0.95) : Colors.grey.shade400,
            ),
            child: active
                ? Icon(Icons.check, color: _SetupBrand.successGreen, size: 18)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? Colors.black : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: 56,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTile({
    required String title,
    String? subtitle,
    bool chevron = false,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
      trailing: trailing ?? (chevron ? const Icon(Icons.chevron_right, color: Colors.grey) : null),
    );
  }

  Widget _doodleTile(IconData icon, Color bg) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
