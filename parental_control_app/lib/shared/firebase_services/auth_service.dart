import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Handles login, register, and stores current user + role from Firestore.
class AuthService extends ChangeNotifier {
  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  UserRole? _userRole;
  String? _userDocId;

  User? get currentUser => _user;
  UserRole? get userRole => _userRole;
  String? get userDocId => _userDocId;
  bool get isLoggedIn => _user != null;

  void _onAuthStateChanged(User? user) {
    _user = user;
    if (user == null) {
      _userRole = null;
      _userDocId = null;
    } else {
      _loadUserRole();
    }
    notifyListeners();
  }

  Future<void> _loadUserRole() async {
    if (_user == null) return;
    try {
      final q = await _firestore
          .collection('users')
          .where('uid', isEqualTo: _user!.uid)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        _userDocId = q.docs.first.id;
        _userRole = UserRoleX.fromString(q.docs.first.data()['role'] as String?);
      } else {
        _userRole = null;
        _userDocId = null;
      }
    } catch (_) {
      _userRole = null;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _loadUserRole();
  }

  Future<void> register(String email, String password, UserRole role) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user == null) return;
    await _firestore.collection('users').add({
      'uid': cred.user!.uid,
      'email': email,
      'role': role.value,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _loadUserRole();
  }

  Future<void> setRole(UserRole role) async {
    if (_user == null) return;
    final q = await _firestore
        .collection('users')
        .where('uid', isEqualTo: _user!.uid)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      await _firestore.collection('users').add({
        'uid': _user!.uid,
        'email': _user!.email,
        'role': role.value,
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await q.docs.first.reference.update({'role': role.value});
    }
    await _loadUserRole();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
