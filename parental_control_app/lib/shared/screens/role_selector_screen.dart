import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../firebase_services/auth_service.dart';
import '../models/user_model.dart';

/// First screen: choose Parent or Child, then Login or Register.
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isLoggedIn = auth.isLoggedIn;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Parental Control',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isLoggedIn ? 'Choose your role' : 'I am a...',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => isLoggedIn ? _setRoleAndGo(context, auth, UserRole.parent) : _goToAuth(context, UserRole.parent),
                icon: const Icon(Icons.family_restroom),
                label: const Text('Parent'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => isLoggedIn ? _setRoleAndGo(context, auth, UserRole.child) : _goToAuth(context, UserRole.child),
                icon: const Icon(Icons.smartphone),
                label: const Text('Child device'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const Spacer(),
              if (isLoggedIn)
                TextButton(
                  onPressed: () => auth.signOut(),
                  child: const Text('Sign out'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToAuth(BuildContext context, UserRole role) {
    context.push<void>('/login', extra: role);
  }

  Future<void> _setRoleAndGo(BuildContext context, AuthService auth, UserRole role) async {
    await auth.setRole(role);
    if (!context.mounted) return;
    if (role == UserRole.parent) {
      context.go('/parent');
    } else {
      context.go('/child');
    }
  }
}
