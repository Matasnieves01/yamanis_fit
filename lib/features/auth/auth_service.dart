import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum UserRole { admin, user }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _lastSignInError;

  String? get lastSignInError => _lastSignInError;

  Future<User?> signIn(String email, String password) async {
    _lastSignInError = null;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        _lastSignInError = 'Login failed. Please try again.';
        return null;
      }

      return user;
    } catch (e) {
      _lastSignInError = 'Login failed. Check your credentials.';
      if (kDebugMode) {
        print('Error signing in: $e');
      }
      return null;
    }
  }

  Future<bool> isUserAccessActive(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final role = (data['role'] as String?)?.toLowerCase() ?? 'user';
      if (role == 'admin') return true;

      final isActive = data['isActive'] == true;
      final activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();
      return isActive && activeUntil != null && activeUntil.isAfter(DateTime.now());
    } catch (e) {
      if (kDebugMode) {
        print('Error checking access: $e');
      }
      return false;
    }
  }

  Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] as String?)?.toLowerCase();
      if (role == 'admin') {
        return UserRole.admin;
      }
      return UserRole.user;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading role: $e');
      }
      return UserRole.user;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }
}
