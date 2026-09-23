import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, user }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _lastSignInError;

  String? get lastSignInError => _lastSignInError;

  Future<User?> signIn(String email, String password, {bool stayLoggedIn = true}) async {
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

      // Save the stayLoggedIn preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stayLoggedIn', stayLoggedIn);

      return user;
    } catch (e) {
      _lastSignInError = 'Login failed. Check your credentials.';
      if (kDebugMode) {
        print('Error signing in: $e');
      }
      return null;
    }
  }

  Future<bool> shouldStayLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('stayLoggedIn') ?? true;
  }

  Future<bool> isUserAccessActive(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final role = (data['role'] as String?)?.toLowerCase() ?? 'user';
      if (role == 'admin') return true;

      final isActive = data['isActive'] == true;
      if (!isActive) return false;

      final now = DateTime.now();
      final activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();
      if (activeUntil != null && activeUntil.isAfter(now)) {
        return true;
      }

      // Semana adicional de gracia ligada al plan del usuario
      final planStart = (data['planStartDate'] as Timestamp?)?.toDate();
      final planWeeks = (data['planDurationWeeks'] as num?)?.toInt();
      if (planStart != null && planWeeks != null && planWeeks > 0) {
        final graceEnd = planStart.add(Duration(days: (planWeeks + 1) * 7));
        if (now.isBefore(graceEnd)) {
          return true;
        }
      }

      return false;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stayLoggedIn');
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending password reset email: $e');
      }
      rethrow;
    }
  }
}
