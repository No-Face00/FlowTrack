// lib/features/auth/cubit/auth_cubit.dart
//
//  Handles:
//   • Email + Password sign-in
//   • Email + Password sign-up
//   • Google Sign-In
//   • Password reset email
//   • Firebase error → human-readable message mapping

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final _auth        = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  // ── Email / Password sign-in ───────────────────────────────
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
      emit(AuthSuccess(credential.user!));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Email / Password sign-up ───────────────────────────────
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
      // Save display name
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();
      emit(AuthSuccess(_auth.currentUser!));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Something went wrong. Please try again.'));
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      // Show Google account picker
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
      emit(AuthSuccess(userCred.user!));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('Google sign-in failed. Please try again.'));
    }
  }

  // ── Password reset ─────────────────────────────────────────
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

  // ── Firebase error code → friendly message ─────────────────
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