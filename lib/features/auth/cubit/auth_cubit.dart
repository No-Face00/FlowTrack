// lib/features/auth/cubit/auth_cubit.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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

  // ── After any sign-in: check PIN in local → Firestore → decide route ──
  // BUG 3 FIX: checks Firestore pinHash so cleared-data users go to
  // /pin-lock (not /pin-setup) when their PIN exists in cloud.
  Future<void> _emitSuccess(User user) async {
    final localPin = await _storage.read(key: 'flowtrack_pin_hash');
    if (localPin != null) {
      emit(AuthNeedsPinLock(user));
      return;
    }
    try {
      final doc    = await _db.collection('users').doc(user.uid).get();
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
      await doc.set({
        'name':      fullName?.trim() ?? user.displayName ?? '',
        'email':     user.email ?? '',
        'currency':  'BDT',
        'timezone':  'Asia/Dhaka',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Email sign-in ──────────────────────────────────────────────
  // BUG 1 FIX (email): checks Firestore doc exists after sign-in.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password,
      );

      final doc = await _db
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!doc.exists) {
        await _auth.signOut();
        emit(AuthError(
            'No account found with this email. Please sign up first.'));
        return;
      }

      await _emitSuccess(credential.user!);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Email sign-up ──────────────────────────────────────────────
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(AuthLoading());
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();
      final user = _auth.currentUser!;
      await _saveUserToFirestore(user, fullName: fullName);
      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Google sign-in ─────────────────────────────────────────────
  // BUG 2 FIX (Google): After sign-in with Google, check if a
  // Firestore user doc exists. If NOT, this is a brand-new Google
  // account — treat it as a NEW sign-up and create the doc.
  // BUT if the user was previously registered (doc existed) and
  // the admin deleted them from Firebase Console, the doc will also
  // be gone → show "No account found, please sign up" error.
  //
  // However: Google OAuth always succeeds even for "deleted" users
  // because Google re-creates the Firebase Auth entry on every login.
  // The ONLY reliable check is the Firestore doc.
  //
  // BEHAVIOUR:
  //   - Doc exists    → returning user → /pin-lock or /pin-setup
  //   - Doc NOT exist → new user       → create doc → /pin-setup
  //
  // If you want to BLOCK Google sign-up (only allow existing users),
  // swap the "doc not exist" block to emit AuthError instead.
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { emit(AuthInitial()); return; }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user     = userCred.user!;

      // Check if this Google account has a Firestore doc
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // New Google user — create their profile doc
        await _saveUserToFirestore(user);
      }

      await _emitSuccess(user);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  // ── Facebook sign-in ───────────────────────────────────────────
  Future<void> signInWithFacebook() async {
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
    } catch (e) {
      emit(AuthError('Facebook sign-in failed. Please try again.'));
    }
  }

  // ── Password reset (for auth screen, NOT for PIN) ─────────────
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