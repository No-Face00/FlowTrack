// lib/features/auth/cubit/pin_cubit.dart
//
// PIN is stored in TWO places:
//   1. flutter_secure_storage (local) — fast unlock, works offline
//   2. Firestore users/{uid}/pinHash  — survives reinstall/clear data
//
// PIN RESET FLOW (BUG 2 FIX):
//   "Forgot PIN?" → signs user out + clears local PIN
//   → router sends to /login
//   → after login, Firestore has no pinHash (we deleted it) → /pin-setup
//   → user sets new PIN
//   NO password reset email needed. PIN is separate from password.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

part 'pin_state.dart';

const _kPinKey        = 'flowtrack_pin_hash';
const _kBioEnabledKey = 'flowtrack_bio_enabled';
const _maxAttempts    = 5;

class PinCubit extends Cubit<PinState> {
  PinCubit() : super(PinInitial());

  final _storage   = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();
  final _db        = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  // ── Hash helper ───────────────────────────────────────────────
  String _hash(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  // ── Save PIN → local + Firestore ──────────────────────────────
  Future<void> savePin({
    required String pin,
    required String userId,
    bool enableBiometrics = false,
  }) async {
    emit(PinLoading());
    try {
      final hash = _hash(pin, userId);

      // 1. Save locally
      await _storage.write(key: _kPinKey, value: hash);
      await _storage.write(
        key: _kBioEnabledKey,
        value: enableBiometrics.toString(),
      );

      // 2. Save to Firestore so it survives reinstall / clear data
      await _db.collection('users').doc(userId).set({
        'pinHash':      hash,
        'pinUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      emit(PinSetSuccess());
    } catch (e) {
      emit(const PinError('Failed to save PIN. Please try again.'));
    }
  }

  // ── Restore PIN from Firestore to local storage ───────────────
  Future<bool> _restorePinFromFirestore(String userId) async {
    try {
      final doc  = await _db.collection('users').doc(userId).get();
      final hash = doc.data()?['pinHash'] as String?;
      if (hash != null) {
        await _storage.write(key: _kPinKey, value: hash);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Verify PIN ────────────────────────────────────────────────
  int _attempts = 0;

  Future<void> verifyPin({
    required String pin,
    required String userId,
  }) async {
    emit(PinLoading());
    try {
      String? stored = await _storage.read(key: _kPinKey);

      // If local PIN missing (reinstall/clear data) → restore from Firestore
      if (stored == null) {
        final restored = await _restorePinFromFirestore(userId);
        if (!restored) {
          emit(const PinError('No PIN found. Please set a new PIN.'));
          return;
        }
        stored = await _storage.read(key: _kPinKey);
      }

      final hash = _hash(pin, userId);
      if (hash == stored) {
        _attempts = 0;
        emit(PinVerifySuccess());
      } else {
        _attempts++;
        final left = _maxAttempts - _attempts;
        if (left <= 0) {
          _attempts = 0;
          emit(const PinError('Too many attempts. Please log in again.'));
        } else {
          emit(PinWrongAttempt(left));
        }
      }
    } catch (e) {
      emit(const PinError('Verification failed.'));
    }
  }

  // ── Reset PIN (Forgot PIN flow) ────────────────────────────────
  // BUG 2 FIX: Does NOT use password reset email.
  // Instead: deletes PIN from Firestore + local, then signs user out.
  // After sign-in again, _emitSuccess() sees no pinHash → /pin-setup.
  Future<void> resetPin() async {
    emit(PinLoading());
    try {
      final userId = _auth.currentUser?.uid;

      // 1. Delete PIN from Firestore
      if (userId != null) {
        await _db.collection('users').doc(userId).update({
          'pinHash':      FieldValue.delete(),
          'pinUpdatedAt': FieldValue.delete(),
        });
      }

      // 2. Delete PIN from local storage
      await _storage.delete(key: _kPinKey);
      await _storage.delete(key: _kBioEnabledKey);

      // 3. Sign out → router sends to /login
      await _auth.signOut();

      emit(PinResetSuccess());
    } catch (e) {
      emit(const PinError('Could not reset PIN. Please try again.'));
    }
  }

  // ── Check if PIN exists (local OR Firestore) ──────────────────
  Future<bool> isPinSet(String userId) async {
    final local = await _storage.read(key: _kPinKey);
    if (local != null) return true;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data()?['pinHash'] != null;
    } catch (_) {
      return false;
    }
  }

  // ── Clear PIN (sign out / account delete) ─────────────────────
  Future<void> clearPin() async {
    await _storage.delete(key: _kPinKey);
    await _storage.delete(key: _kBioEnabledKey);
  }

  // ── Biometric auth ────────────────────────────────────────────
  Future<void> authenticateWithBiometrics() async {
    try {
      final canAuth           = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canAuth || !isDeviceSupported) {
        emit(const PinError('Biometrics not available on this device.'));
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock FlowTrack',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth:    true,
        ),
      );
      if (authenticated) {
        emit(PinVerifySuccess());
      } else {
        emit(const PinError('Biometric authentication failed.'));
      }
    } catch (e) {
      emit(PinError(e.toString()));
    }
  }

  // ── Check if biometrics enabled ───────────────────────────────
  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _kBioEnabledKey);
    return val == 'true';
  }
}