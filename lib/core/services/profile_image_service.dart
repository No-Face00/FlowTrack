// lib/core/services/profile_image_service.dart
//
// Manages the current user's profile image entirely in memory.
// The source of truth is the `photoBase64` field in the Firestore
// `users/{uid}` document — no Firebase Storage or external host required.
//
// Usage:
//   // After a successful photo save in EditProfileScreen:
//   ProfileImageService.instance.notifyUpdatedBytes(compressedBytes);
//
//   // In any widget that shows the avatar:
//   ValueListenableBuilder<Uint8List?>(
//     valueListenable: ProfileImageService.instance.bytesNotifier,
//     builder: (_, bytes, __) => Image(
//       image: bytes != null ? MemoryImage(bytes) : fallbackProvider,
//     ),
//   );

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProfileImageService {
  ProfileImageService._();
  static final ProfileImageService instance = ProfileImageService._();

  // ── Public notifiers ──────────────────────────────────────────────────────

  /// Emits the latest decoded image bytes whenever the photo is updated or
  /// loaded from Firestore. Widgets subscribe to this for zero-latency updates.
  final ValueNotifier<Uint8List?> bytesNotifier = ValueNotifier(null);

  // ── State ─────────────────────────────────────────────────────────────────

  String? _lastUid;
  bool    _loading = false;

  // ── Write path ────────────────────────────────────────────────────────────

  /// Called immediately after EditProfileScreen writes the new `photoBase64`
  /// field to Firestore. Updates the in-memory cache so every listening widget
  /// refreshes without waiting for a Firestore snapshot.
  void notifyUpdatedBytes(Uint8List bytes) {
    bytesNotifier.value = bytes;
    debugPrint('[ProfileImageService] In-memory cache updated '
        '(${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)');
  }

  // ── Read path ─────────────────────────────────────────────────────────────

  /// Fetches `photoBase64` from Firestore for [uid] and decodes it into
  /// [bytesNotifier]. No-ops if the cache already has bytes for this uid
  /// (avoids redundant reads on every AccountScreen build).
  ///
  /// Pass [force] = true to bypass the uid-equality guard (e.g. after sign-in).
  Future<void> reloadFromFirestore(String? uid, {bool force = false}) async {
    if (uid == null) return;
    if (!force && _lastUid == uid && bytesNotifier.value != null) return;
    if (_loading) return;

    _loading  = true;
    _lastUid  = uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final base64Str = doc.data()?['photoBase64'] as String?;
      if (base64Str != null && base64Str.isNotEmpty) {
        final bytes = base64Decode(base64Str);
        bytesNotifier.value = bytes;
        debugPrint('[ProfileImageService] Loaded from Firestore '
            '(${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)');
      } else {
        // No photo stored yet — clear stale bytes from a previous account.
        bytesNotifier.value = null;
      }
    } catch (e) {
      debugPrint('[ProfileImageService] Firestore load error: $e');
    } finally {
      _loading = false;
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Call on sign-out to clear the cached bytes so a subsequent login starts
  /// fresh and doesn't briefly flash the previous user's avatar.
  void clear() {
    bytesNotifier.value = null;
    _lastUid            = null;
    debugPrint('[ProfileImageService] Cache cleared (sign-out)');
  }
}