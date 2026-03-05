// lib/features/auth/cubit/auth_cubit.dart
//
//  Handles:
//   • Email + Password sign-in
//   • Email + Password sign-up  ← also saves user doc to Firestore
//   • Google Sign-In            ← creates Firestore doc if first time
//   • Password reset email
//   • Firebase error → human-readable message mapping
//   • After AuthSuccess → emits AuthNeedsPinSetup or AuthNeedsPinLock
//     so the router knows where to send the user

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final _auth         = FirebaseAuth.instance;
  final _db           = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  final _storage      = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Shared: check PIN then emit correct success state ──────────
  Future<void> _emitSuccess(User user) async {
    final pinHash = await _storage.read(key: 'flowtrack_pin_hash');
    final pinSet  = pinHash != null;
    if (pinSet) {
      emit(AuthNeedsPinLock(user));   // returning user → go to /pin-lock
    } else {
      emit(AuthNeedsPinSetup(user));  // first time   → go to /pin-setup
    }
  }

  // ── Save user document to Firestore ───────────────────────────
  // Called after sign-up, and on first Google sign-in.
  // Uses set() with merge: true so it is safe to call multiple times.
  Future<void> _saveUserToFirestore(User user, {String? fullName}) async {
    final doc  = _db.collection('users').doc(user.uid);
    final snap = await doc.get();

    if (!snap.exists) {
      // First time — create the document
      await doc.set({
        'name':      fullName?.trim() ?? user.displayName ?? '',
        'email':     user.email ?? '',
        'currency':  'BDT',
        'timezone':  'Asia/Dhaka',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // Document already exists → returning user, do nothing
  }

  // ── Email / Password sign-in ───────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      await _emitSuccess(credential.user!);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Email / Password sign-up ───────────────────────────────────
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );

      // Save display name in Firebase Auth
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();

      final user = _auth.currentUser!;

      // Save profile to Firestore users/{uid} document
      await _saveUserToFirestore(user, fullName: fullName);

      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final googleUser = await _googleSignIn.signIn();

      // User cancelled the picker
      if (googleUser == null) {
        emit(AuthInitial());
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user     = userCred.user!;

      // Create Firestore doc only if this is a first-time Google login
      await _saveUserToFirestore(user);

      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  // ── Password reset ─────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    emit(AuthLoading());
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      emit(AuthPasswordResetSent());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Could not send reset email. Please try again.'));
    }
  }

  // ── Firebase error code → friendly message ─────────────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}