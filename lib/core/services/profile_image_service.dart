// lib/core/services/profile_image_service.dart
//
// A lightweight singleton ValueNotifier that broadcasts the latest profile
// photo URL to every widget that listens.  When EditProfileScreen finishes
// uploading, it calls `ProfileImageService.instance.notifyUpdated(url)`.
// Any avatar widget wrapped in a ValueListenableBuilder rebuilds immediately.
//
// Usage
// ─────
//   // After successful upload:
//   ProfileImageService.instance.notifyUpdated(newUrl);
//
//   // In any avatar widget:
//   ValueListenableBuilder<String?>(
//     valueListenable: ProfileImageService.instance,
//     builder: (ctx, url, _) => MyAvatar(url: url),
//   );

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileImageService extends ValueNotifier<String?> {
  ProfileImageService._() : super(_currentUrl());

  static final ProfileImageService instance = ProfileImageService._();

  static String? _currentUrl() =>
      FirebaseAuth.instance.currentUser?.photoURL;

  /// Call this after a successful upload to broadcast the new URL.
  void notifyUpdated(String? url) {
    value = url;
    // Also stamp the time so a NetworkImage with the same URL but a new
    // cache-buster query param will reload (handled in the URL itself).
  }

  /// Reload from the current Auth user (e.g. on app start / sign-in).
  void reloadFromAuth() {
    value = _currentUrl();
  }
}