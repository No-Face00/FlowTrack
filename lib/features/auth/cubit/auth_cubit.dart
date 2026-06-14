

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/email_validator.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  bool _busy = false;

  final _auth         = FirebaseAuth.instance;
  final _db           = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  final _storage      = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );


  Future<void> _emitSuccess(User user) async {
    try {
      await getIt<AppCubit>().load();
    } catch (_) {}

    final localPin = await _storage.read(key: 'flowtrack_pin_hash');
    if (localPin != null) {
      emit(AuthNeedsPinLock(user));
      return;
    }
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final hasPin = doc.data()?['pinHash'] != null;
      if (hasPin) {
        emit(AuthNeedsPinLock(user));
        return;
      }
    } catch (_) {}
    emit(AuthNeedsPinSetup(user));
  }

  // ── Save user doc (only on first sign-up) ─────────────────────
  Future<void> _saveUserToFirestore(User user, {String? fullName}) async {
    final doc  = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      final defaultCurrency = CurrencyHelper.detectDefault();
      await doc.set({
        'name':      fullName?.trim() ?? user.displayName ?? '',
        'email':     user.email ?? '',
        'currency':  defaultCurrency,
        'theme':     'light',
        'language':  'en',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Email sign-in ──────────────────────────────────────────────

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_busy) return;
    final emailErr = EmailValidator.validate(email);
    if (emailErr != null) {
      emit(AuthError(emailErr));
      return;
    }
    _busy = true;
    emit(AuthLoading());
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 25));

      final doc = await _db
          .collection('users')
          .doc(credential.user!.uid)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!doc.exists) {
        await _auth.signOut();
        emit(AuthError(
            'No account found with this email. Please sign up first.'));
        return;
      }

      await _emitSuccess(credential.user!);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } on TimeoutException {
      emit(AuthError('Request timed out. Check your connection.'));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    } finally {
      _busy = false;
    }
  }

  // ── Email sign-up ──────────────────────────────────────────────
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (_busy) return;
    final emailErr = EmailValidator.validate(email);
    if (emailErr != null) {
      emit(AuthError(emailErr));
      return;
    }
    if (password.length < 6) {
      emit(AuthError('Password must be at least 6 characters.'));
      return;
    }
    _busy = true;
    emit(AuthLoading());
    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 25));
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();
      final user = _auth.currentUser!;
      await _saveUserToFirestore(user, fullName: fullName);
      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } on TimeoutException {
      emit(AuthError('Request timed out. Check your connection.'));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    } finally {
      _busy = false;
    }
  }

  // ── Google sign-in ─────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    if (_busy) return;
    _busy = true;
    emit(AuthLoading());
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        emit(AuthInitial());
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 25));
      final user = userCred.user!;

      final doc = await _db
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!doc.exists) {
        // New Google user — create their profile doc
        await _saveUserToFirestore(user);
      }

      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } on TimeoutException {
      emit(AuthError('Google sign-in timed out. Try again.'));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    } finally {
      _busy = false;
    }
  }

  // ── Facebook sign-in ───────────────────────────────────────────
  Future<void> signInWithFacebook() async {
    if (_busy) return;
    _busy = true;
    emit(AuthLoading());
    try {
      final loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (loginResult.status == LoginStatus.cancelled) {
        emit(AuthInitial()); return;
      }
      if (loginResult.status != LoginStatus.success) {
        emit(AuthError('Facebook sign-in failed. Please try again.')); return;
      }

      final credential = FacebookAuthProvider.credential(
        loginResult.accessToken!.tokenString,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user     = userCred.user!;

      await _saveUserToFirestore(user);
      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } on TimeoutException {
      emit(AuthError('Facebook sign-in timed out. Try again.'));
    } catch (e) {
      emit(AuthError('Facebook sign-in failed. Please try again.'));
    } finally {
      _busy = false;
    }
  }

  // ── Password reset (for auth screen, NOT for PIN) ─────────────
  Future<void> sendPasswordReset(String email) async {
    if (_busy) return;
    final emailErr = EmailValidator.validate(email);
    if (emailErr != null) {
      emit(AuthError(emailErr));
      return;
    }
    _busy = true;
    emit(AuthLoading());
    try {
      await _auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 20));
      emit(AuthPasswordResetSent());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } on TimeoutException {
      emit(AuthError('Request timed out. Try again.'));
    } catch (e) {
      emit(AuthError('Could not send reset email. Please try again.'));
    } finally {
      _busy = false;
    }
  }

  // ── Error mapping ─────────────────────────────────────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
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