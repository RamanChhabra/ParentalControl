import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/firebase_services/auth_service.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/models/device_model.dart';
import '../widgets/device_card.dart';
import '../widgets/section_header.dart';
import 'add_device_screen.dart';

/// Parent dashboard: linked devices, add device, navigate to child details.
class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final parentId = auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Parental Control'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: parentId.isEmpty
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<DeviceModel>>(
              stream: context.read<FirestoreService>().watchDevicesForParent(parentId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Something went wrong', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final devices = snapshot.data!;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              devices.isEmpty
                                  ? 'Link a child device to get started'
                                  : '${devices.length} device${devices.length == 1 ? '' : 's'} linked',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: SectionHeader(
                          icon: Icons.smartphone_rounded,
                          title: 'Linked devices',
                          subtitle: 'Tap a device to view activity and set rules',
                        ),
                      ),
                    ),
                    if (devices.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.phone_android_rounded, size: 56, color: theme.colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No devices linked yet',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add a device using the pairing code from the child\'s app.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => DeviceCard(device: devices[index]),
                            childCount: devices.length,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AddDeviceScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add device'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
