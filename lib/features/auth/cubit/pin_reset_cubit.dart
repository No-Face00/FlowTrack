// lib/features/auth/cubit/pin_reset_cubit.dart
//
// PIN RESET — works for BOTH email and Google users.
// No email, no SMTP, no subscription needed.
//
// FLOW:
//   Email users:  enter account password → Firebase re-auth → set new PIN
//   Google users: Google sign-in popup   → Firebase re-auth → set new PIN
//
// Re-authentication proves the user owns the account before
// allowing them to set a new PIN.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'pin_reset_state.dart';

const _kPinKey = 'flowtrack_pin_hash';

class PinResetCubit extends Cubit<PinResetState> {
  PinResetCubit() : super(PinResetInitial());

  final _auth         = FirebaseAuth.instance;
  final _db           = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  final _storage      = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Detect sign-in provider ───────────────────────────────────
  // Returns 'google.com', 'facebook.com', or 'password'
  String get _provider {
    final user = _auth.currentUser;
    if (user == null) return 'password';
    for (final info in user.providerData) {
      if (info.providerId == 'google.com')   return 'google.com';
      if (info.providerId == 'facebook.com') return 'facebook.com';
    }
    return 'password';
  }

  bool get isGoogleUser   => _provider == 'google.com';
  bool get isEmailUser    => _provider == 'password';

  // ── Step 1a: Re-authenticate email user with password ─────────
  Future<void> reAuthWithPassword(String password) async {
    emit(PinResetLoading());
    try {
      final user  = _auth.currentUser;
      if (user == null || user.email == null) {
        emit(const PinResetError('No signed-in user found.'));
        return;
      }

      final credential = EmailAuthProvider.credential(
        email:    user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      emit(PinResetVerified());   // ← identity confirmed → show new PIN screen
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          emit(const PinResetError('Incorrect password. Please try again.'));
          break;
        case 'too-many-requests':
          emit(const PinResetError('Too many attempts. Please wait a moment.'));
          break;
        default:
          emit(PinResetError('Authentication failed: ${e.message}'));
      }
    } catch (e) {
      emit(const PinResetError('Something went wrong. Please try again.'));
    }
  }

  // ── Step 1b: Re-authenticate Google user ──────────────────────
  Future<void> reAuthWithGoogle() async {
    emit(PinResetLoading());
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        emit(PinResetInitial());  // user cancelled
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      await _auth.currentUser!.reauthenticateWithCredential(credential);
      emit(PinResetVerified());   // ← identity confirmed → show new PIN screen
    } on FirebaseAuthException catch (e) {
      emit(PinResetError('Google verification failed: ${e.message}'));
    } catch (e) {
      emit(const PinResetError('Google verification failed. Please try again.'));
    }
  }

  // ── Step 2: Set new PIN (after re-auth succeeds) ──────────────
  Future<void> setNewPin({
    required String pin,
    required String confirmPin,
  }) async {
    if (pin.length != 4) {
      emit(const PinResetError('PIN must be 4 digits.'));
      return;
    }
    if (pin != confirmPin) {
      emit(const PinResetError('PINs do not match. Please try again.'));
      return;
    }

    emit(PinResetLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(const PinResetError('Session expired. Please sign in again.'));
        return;
      }

      final hash = _hashPin(pin, user.uid);

      // Save locally
      await _storage.write(key: _kPinKey, value: hash);

      // Save to Firestore (survives reinstall)
      await _db.collection('users').doc(user.uid).set({
        'pinHash':      hash,
        'pinUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      emit(PinResetComplete());
    } catch (e) {
      emit(const PinResetError('Failed to save PIN. Please try again.'));
    }
  }

  // ── Hash helper ───────────────────────────────────────────────
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }
}