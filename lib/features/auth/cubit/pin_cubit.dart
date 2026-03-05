// ============================================================
// FILE 2: lib/features/pin/cubit/pin_cubit.dart
// ============================================================
// HOW THE PIN IS STORED — SECURE STORAGE
//
// We use flutter_secure_storage which on Android uses the
// Android Keystore, and on iOS uses the iOS Keychain.
// This means the PIN hash is NEVER stored in plaintext.
//
// We store a SHA-256 hash of the PIN, not the PIN itself.
// Even if someone extracts the storage, they cannot reverse it.
//
// Storage key: 'flowtrack_pin_hash'
// Value: SHA-256( pin + salt )   where salt = user's Firebase UID
//
// Add to pubspec.yaml:
//   flutter_secure_storage: ^9.2.2
//   crypto: ^3.0.5
// ============================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

part 'pin_state.dart';

const _kPinKey      = 'flowtrack_pin_hash';
const _kBioEnabledKey = 'flowtrack_bio_enabled';
const _maxAttempts  = 5;

class PinCubit extends Cubit<PinState> {
  PinCubit() : super(PinInitial());

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  // ── Hash helper ──────────────────────────────────────────────
  String _hash(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  // ── Save PIN (called from PinSetupScreen) ────────────────────
  Future<void> savePin({
    required String pin,
    required String userId,      // Firebase UID as salt
    bool enableBiometrics = false,
  }) async {
    emit(PinLoading());
    try {
      final hash = _hash(pin, userId);
      await _storage.write(key: _kPinKey, value: hash);
      await _storage.write(
        key: _kBioEnabledKey,
        value: enableBiometrics.toString(),
      );
      emit(PinSetSuccess());
    } catch (e) {
      emit(const PinError('Failed to save PIN. Please try again.'));
    }
  }

  // ── Verify PIN (called from lock screen on re-open) ──────────
  int _attempts = 0;

  Future<void> verifyPin({
    required String pin,
    required String userId,
  }) async {
    emit(PinLoading());
    try {
      final stored = await _storage.read(key: _kPinKey);
      if (stored == null) {
        emit(const PinError('No PIN set. Please set a new PIN.'));
        return;
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

  // ── Biometric auth ────────────────────────────────────────────
  Future<void> authenticateWithBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canAuth || !isDeviceSupported) {
        emit(const PinError('Biometrics not available on this device.'));
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock FlowTrack',
        options: const AuthenticationOptions(
          biometricOnly: false,   // allows device PIN as fallback
          stickyAuth: true,
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

  // ── Check if PIN is set ────────────────────────────────────────
  Future<bool> isPinSet() async {
    final val = await _storage.read(key: _kPinKey);
    return val != null;
  }

  // ── Check if biometrics enabled ───────────────────────────────
  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _kBioEnabledKey);
    return val == 'true';
  }

  // ── Delete PIN (for account delete / sign out) ─────────────────
  Future<void> clearPin() async {
    await _storage.delete(key: _kPinKey);
    await _storage.delete(key: _kBioEnabledKey);
  }
}
