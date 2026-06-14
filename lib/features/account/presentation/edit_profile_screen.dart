// Edit Profile — glass UI, Firebase Auth + Firestore photo (base64 stored directly in Firestore).
// No Firebase Storage or external image hosting required.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_themes.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/services/profile_image_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  // ── Image state ──────────────────────────────────────────────
  /// Compressed bytes ready for upload.
  Uint8List? _pickedBytes;
  /// Local file path for the preview (avoids holding full-res in memory).
  String?    _pickedPath;

  bool _loadingDoc  = true;
  bool _saving      = false;
  bool _compressing = false;
  String _initial   = '?';

  // Fade-in animation for avatar after picking.
  late final AnimationController _avatarFadeCtrl;
  late final Animation<double>   _avatarFade;

  // ── Cached translations (set in build, safe to use in async handlers) ───
  String _msgNameRequired  = '';
  String _msgProfileUpdated = '';
  String _msgProfileUpdatedSub = '';
  String _msgProfileError  = '';

  // ── Limits ───────────────────────────────────────────────────
  static const int _maxFileSizeBytes = 8 * 1024 * 1024; // 8 MB guard

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(
            () => setState(() => _scrollOffset = _scrollCtrl.offset));
    _avatarFadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _avatarFade = CurvedAnimation(
        parent: _avatarFadeCtrl, curve: Curves.easeOut);
    _avatarFadeCtrl.forward();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingDoc = false);
      return;
    }
    // Reload to get latest photoURL (prevents stale cached user object).
    try { await user.reload(); } catch (_) {}

    String name =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    if (name.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        name = (doc.data()?['name'] as String?)?.trim() ?? '';
      } catch (_) {}
    }
    if (name.isEmpty && user.email != null) {
      name = user.email!.split('@').first;
    }
    _nameCtrl.text = name;
    _initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (mounted) setState(() => _loadingDoc = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scrollCtrl.dispose();
    _avatarFadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // PERMISSION HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Returns true when we have permission to open the gallery.
  /// Uses permission_handler which handles Android SDK version
  /// differences internally (READ_MEDIA_IMAGES on 33+, storage on older).
  Future<bool> _ensureGalleryPermission() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      // permission_handler maps Permission.photos to READ_MEDIA_IMAGES
      // on Android 13+ (SDK 33) and READ_EXTERNAL_STORAGE on older versions.
      status = await Permission.photos.request();

      // On some Android 12 devices Permission.photos isn't the right one;
      // fall back to storage if denied.
      if (status.isDenied || status.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;
      }
    } else {
      // iOS
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && mounted) {
      _showPermissionDeniedDialog();
      return false;
    }

    if (mounted) {
      showPremiumSnackBar(
        context,
        message: 'Gallery permission denied',
        subtitle: 'Please allow photo access to change your profile picture.',
        icon: Icons.photo_library_outlined,
        isError: true,
      );
    }
    return false;
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Photo Access Required'),
        content: const Text(
            'To change your profile picture, please allow photo access in '
                'Settings → App → Permissions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────────────

  Future<void> _showPickerOptions() async {
    HapticFeedback.selectionClick();
    final rs = Rs.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(rs: rs, onPick: _pickFrom),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    // On Android 13+ (API 33+) ImagePicker requests READ_MEDIA_IMAGES itself,
    // so manual permission checks are redundant and can block the picker.
    // We only show our custom dialog if ImagePicker throws a permission error.
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source:              source,
        maxWidth:            1080,
        maxHeight:           1080,
        imageQuality:        92,
        requestFullMetadata: false, // prevents crash on some Samsung/Xiaomi
      );
    } on PlatformException catch (e) {
      debugPrint('[EditProfile] ImagePicker PlatformException: $e');
      if (!mounted) return;
      // photo_access_denied / camera_access_denied are thrown by ImagePicker
      // when the user permanently denies permission on iOS or Android.
      if (e.code == 'photo_access_denied' ||
          e.code == 'camera_access_denied' ||
          (e.message?.toLowerCase().contains('permission') ?? false)) {
        _showPermissionDeniedDialog();
      } else {
        showPremiumSnackBar(
          context,
          message: 'Could not open image picker',
          subtitle: e.message ?? e.code,
          icon: Icons.broken_image_outlined,
          isError: true,
        );
      }
      return;
    } catch (e) {
      debugPrint('[EditProfile] ImagePicker error: $e');
      if (mounted) {
        showPremiumSnackBar(
          context,
          message: 'Image picker failed',
          subtitle: e.toString(),
          icon: Icons.broken_image_outlined,
          isError: true,
        );
      }
      return;
    }

    if (file == null || !mounted) return;

    // ── Basic validation ──────────────────────────────────────
    final rawSize = await file.length();
    if (rawSize > _maxFileSizeBytes) {
      if (mounted) {
        showPremiumSnackBar(
          context,
          message: 'Image too large',
          subtitle: 'Please choose an image smaller than 8 MB.',
          icon: Icons.photo_size_select_large_outlined,
          isError: true,
        );
      }
      return;
    }

    final ext = p.extension(file.path).toLowerCase();
    const supported = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', ''];
    if (!supported.contains(ext)) {
      if (mounted) {
        showPremiumSnackBar(
          context,
          message: 'Unsupported format',
          subtitle: 'Please choose a JPG, PNG, or WebP image.',
          icon: Icons.image_not_supported_outlined,
          isError: true,
        );
      }
      return;
    }

    // Show preview immediately while compressing in the background.
    if (mounted) {
      setState(() {
        _pickedPath  = file!.path;
        _compressing = true;
      });
    }

    // ── Compress ──────────────────────────────────────────────
    Uint8List? compressed;
    try {
      compressed = await _compressImage(file);
    } catch (e) {
      debugPrint('[EditProfile] Compression error: $e');
      try { compressed = await file.readAsBytes(); } catch (_) {}
    }

    if (!mounted) return;

    if (compressed == null || compressed.isEmpty) {
      setState(() => _compressing = false);
      showPremiumSnackBar(
        context,
        message: 'Could not process image',
        subtitle: 'The image may be corrupted. Please try another.',
        icon: Icons.broken_image_outlined,
        isError: true,
      );
      return;
    }

    setState(() {
      _pickedBytes = compressed;
      _compressing = false;
    });
    _avatarFadeCtrl
      ..reset()
      ..forward();
    HapticFeedback.lightImpact();
  }

  /// Resizes and compresses [file] to PNG using dart:ui — no native plugin needed.
  /// Target: 300×300 px so base64-encoded size stays well within Firestore's 1 MB doc limit.
  Future<Uint8List?> _compressImage(XFile file) async {
    try {
      final rawBytes = await file.readAsBytes();

      // Decode and resize to 300×300 (2× the max rendered avatar size for HiDPI).
      final codec    = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth:  300,
        targetHeight: 300,
      );
      final frame    = await codec.getNextFrame();
      final image    = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[EditProfile] Compression error: $e');
      // Fallback: return original bytes uncompressed.
      try { return await file.readAsBytes(); } catch (_) { return null; }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE / UPLOAD
  // ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPremiumSnackBar(
        context,
        message: _msgNameRequired,
        icon: Icons.info_outline_rounded,
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    // Use pre-cached translations — context.tr / context.watch must NEVER
    // be called inside async methods or tap handlers (only safe in build()).
    final rootCtx = Navigator.of(context).context;

    try {
      await user.updateDisplayName(name);

      final uid   = user.uid;
      final batch = <String, dynamic>{'name': name};

      if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
        // Save photo bytes directly to Firestore and notify the image service
        // with the decoded bytes so the avatar updates immediately in-memory.
        await _savePhotoToFirestore(uid, _pickedBytes!);
        batch['photoBase64'] = base64Encode(_pickedBytes!);
        // Clear any stale HTTP URL from Auth so we always read from Firestore.
        await user.updatePhotoURL(null);
        ProfileImageService.instance.notifyUpdatedBytes(_pickedBytes!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(batch, SetOptions(merge: true));

      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;
      setState(() => _saving = false);

      context.pop();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (rootCtx.mounted) {
          showPremiumSnackBar(
            rootCtx,
            message: _msgProfileUpdated,
            subtitle: _msgProfileUpdatedSub,
            icon: Icons.check_circle_rounded,
          );
        }
      });
    } on FirebaseException catch (e) {
      debugPrint('[EditProfile] Firebase error: ${e.code} ${e.message}');
      if (mounted) {
        setState(() => _saving = false);
        showPremiumSnackBar(
          context,
          message: _friendlyFirebaseError(e),
          subtitle: e.message,
          icon: Icons.cloud_off_rounded,
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[EditProfile] Save error: $e');
      if (mounted) {
        setState(() => _saving = false);
        showPremiumSnackBar(
          context,
          message: _msgProfileError,
          subtitle: e.toString(),
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BASE64 → FIRESTORE PHOTO SAVE
  // ─────────────────────────────────────────────────────────────

  /// Encodes [bytes] as base64 and writes them to the user's Firestore document
  /// under the key `photoBase64`. This is a direct Firestore write — no external
  /// service, no HTTP round-trip to a third-party host. Typical latency: < 1 s.
  ///
  /// Size note: a 300×300 PNG is ~40–80 KB raw, ~55–110 KB as base64.
  /// Firestore's 1 MB document limit gives ample headroom for a profile image.
  Future<void> _savePhotoToFirestore(String uid, Uint8List bytes) async {
    final base64Str = base64Encode(bytes);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'photoBase64': base64Str}, SetOptions(merge: true));
    debugPrint('[EditProfile] Firestore base64 photo saved '
        '(${(base64Str.length / 1024).toStringAsFixed(1)} KB)');
  }

  // NOTE: This method must NOT use context.tr() / context.watch because it is
  // called after async gaps where the widget may no longer be building.
  String _friendlyFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return 'Profile update failed (${e.code})';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rs     = Rs.of(context);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cache translations here — build() is the ONLY safe place to call
    // context.tr / context.watch. These fields are then used safely in
    // async handlers like _save() where context.watch would crash.
    _msgNameRequired     = context.tr(S.nameEnterRequired);
    _msgProfileUpdated   = context.tr(S.profileUpdated);
    _msgProfileUpdatedSub = context.tr(S.profileUpdatedSub);
    _msgProfileError     = context.tr(S.profileError);

    final user     = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    ImageProvider<Object>? avatarImage;
    if (_pickedBytes != null) {
      avatarImage = MemoryImage(_pickedBytes!);
    } else if (_pickedPath != null) {
      avatarImage = FileImage(File(_pickedPath!));
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImage = NetworkImage(photoUrl);
    }

    final headerFade =
    (1.0 - ((_scrollOffset - 40) / 120).clamp(0.0, 1.0));
    final surfaceGlass = isDark
        ? DarkColors.surface.withOpacity(0.92)
        : Colors.white.withOpacity(0.94);
    final borderGlass = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.75);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // ── Background gradient ──────────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: headerFade,
                child: const DecoratedBox(
                  decoration:
                  BoxDecoration(gradient: AppColors.heroGradient),
                ),
              ),
            ),

            // ── Scrollable content ───────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        height: MediaQuery.of(context).padding.top +
                            rs.sp(8)),

                    // ── App bar row ────────────────────────────
                    Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: rs.sp(16)),
                      child: Row(
                        children: [
                          _GlassIconButton(
                            rs:     rs,
                            isDark: isDark,
                            icon:   Icons.arrow_back_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.pop();
                            },
                          ),
                          SizedBox(width: rs.sp(10)),
                          Text(
                            context.tr(S.editProfile),
                            style: TextStyle(
                              fontFamily:    'Sora',
                              fontSize:      rs.sp(22),
                              fontWeight:    FontWeight.w800,
                              color:         Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: rs.sp(28)),

                    // ── Glass card ─────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(20)),
                      child: ClipRRect(
                        borderRadius:
                        BorderRadius.circular(rs.sp(28)),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                              sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: EdgeInsets.all(rs.sp(22)),
                            decoration: BoxDecoration(
                              color: surfaceGlass,
                              borderRadius:
                              BorderRadius.circular(rs.sp(28)),
                              border: Border.all(
                                  color: borderGlass, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                      isDark ? 0.35 : 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: AppColors.royalBlue
                                      .withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _loadingDoc
                                ? Center(
                              child: Padding(
                                padding:
                                EdgeInsets.all(rs.sp(24)),
                                child: CircularProgressIndicator(
                                  color:       AppColors.royalBlue,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                                : Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                              children: [
                                // ── Avatar ──────────────
                                Center(
                                  child: GestureDetector(
                                    onTap: (_compressing ||
                                        _saving)
                                        ? null
                                        : _showPickerOptions,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding:
                                          const EdgeInsets
                                              .all(3),
                                          decoration:
                                          BoxDecoration(
                                            gradient:
                                            const LinearGradient(
                                              colors: [
                                                Colors.white,
                                                AppColors.violet,
                                              ],
                                            ),
                                            shape:
                                            BoxShape.circle,
                                          ),
                                          child: FadeTransition(
                                            opacity: _avatarFade,
                                            child: CircleAvatar(
                                              radius: rs.sp(52),
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              backgroundImage:
                                              (_compressing ||
                                                  avatarImage ==
                                                      null)
                                                  ? null
                                                  : avatarImage,
                                              child: _compressing
                                                  ? CircularProgressIndicator(
                                                color: AppColors
                                                    .royalBlue,
                                                strokeWidth:
                                                2,
                                              )
                                                  : (avatarImage ==
                                                  null
                                                  ? Text(
                                                _initial,
                                                style:
                                                TextStyle(
                                                  fontSize:
                                                  rs.sp(36),
                                                  fontWeight:
                                                  FontWeight.w800,
                                                  color: AppColors
                                                      .royalBlue,
                                                  fontFamily:
                                                  'Sora',
                                                ),
                                              )
                                                  : null),
                                            ),
                                          ),
                                        ),
                                        // Camera badge
                                        Positioned(
                                          right:  4,
                                          bottom: 4,
                                          child: AnimatedOpacity(
                                            opacity: _compressing
                                                ? 0.4
                                                : 1.0,
                                            duration: const Duration(
                                                milliseconds: 200),
                                            child: Container(
                                              padding:
                                              EdgeInsets.all(
                                                  rs.sp(8)),
                                              decoration:
                                              BoxDecoration(
                                                gradient: AppColors
                                                    .buttonGradient,
                                                shape:
                                                BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors
                                                      .white
                                                      .withOpacity(
                                                      0.9),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .royalBlue
                                                        .withOpacity(
                                                        0.45),
                                                    blurRadius:
                                                    12,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons
                                                    .photo_camera_rounded,
                                                color: Colors
                                                    .white,
                                                size: rs.sp(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: rs.sp(10)),
                                Center(
                                  child: Text(
                                    _compressing
                                        ? 'Processing image…'
                                        : context.tr(
                                        S.tapToChangePhoto),
                                    style: TextStyle(
                                      fontSize: rs.sp(12),
                                      color: theme.colorScheme
                                          .onSurface
                                          .withOpacity(0.5),
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: rs.sp(28)),

                                // ── Name field ───────────
                                Text(
                                  context.tr(S.displayName),
                                  style: TextStyle(
                                    fontSize: rs.sp(12),
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme
                                        .onSurface
                                        .withOpacity(0.55),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: rs.sp(8)),
                                TextField(
                                  controller: _nameCtrl,
                                  textCapitalization:
                                  TextCapitalization.words,
                                  style: TextStyle(
                                    fontSize:   rs.sp(16),
                                    fontWeight: FontWeight.w600,
                                    color: theme
                                        .colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context
                                        .tr(S.yourNameHint),
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      color: AppColors.royalBlue
                                          .withOpacity(0.85),
                                      size: rs.sp(22),
                                    ),
                                  ),
                                ),
                                SizedBox(height: rs.sp(28)),

                                // ── Save button ──────────
                                SizedBox(
                                  height: rs.sp(52),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors
                                          .buttonGradient,
                                      borderRadius:
                                      BorderRadius.circular(
                                          rs.sp(16)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors
                                              .royalBlue
                                              .withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(
                                              0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                        BorderRadius.circular(
                                            rs.sp(16)),
                                        onTap: (_saving ||
                                            _compressing)
                                            ? null
                                            : _save,
                                        child: Center(
                                          child: (_saving ||
                                              _compressing)
                                              ? SizedBox(
                                            width:
                                            rs.sp(22),
                                            height:
                                            rs.sp(22),
                                            child:
                                            const CircularProgressIndicator(
                                              color: Colors
                                                  .white,
                                              strokeWidth:
                                              2.2,
                                            ),
                                          )
                                              : Text(
                                            context.tr(
                                                S.saveChanges),
                                            style:
                                            TextStyle(
                                              color: Colors
                                                  .white,
                                              fontSize:
                                              rs.sp(16),
                                              fontWeight:
                                              FontWeight
                                                  .w800,
                                              fontFamily:
                                              'Sora',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom +
                            rs.sp(32)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SOURCE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({required this.rs, required this.onPick});
  final Rs                        rs;
  final void Function(ImageSource) onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.fromLTRB(
        rs.sp(12), 0, rs.sp(12),
        rs.sp(12) + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(rs.sp(28)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.18),
            blurRadius: 40,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width:  rs.sp(36),
              height: rs.sp(4),
              margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
              decoration: BoxDecoration(
                gradient:     AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(6)),
            child: Text(
              'Change Profile Photo',
              style: TextStyle(
                fontSize:   rs.sp(17),
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                color:      Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _SourceTile(
            rs:    rs,
            icon:  Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            onTap: () {
              Navigator.pop(context);
              onPick(ImageSource.gallery);
            },
          ),
          _SourceTile(
            rs:    rs,
            icon:  Icons.camera_alt_rounded,
            label: 'Take a Photo',
            onTap: () {
              Navigator.pop(context);
              onPick(ImageSource.camera);
            },
          ),
          SizedBox(height: rs.sp(8)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.sp(22)),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: rs.sp(48),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.06),
                  borderRadius: BorderRadius.circular(rs.sp(14)),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize:   rs.sp(15),
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: rs.sp(8)),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.rs,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Rs           rs;
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
          horizontal: rs.sp(22), vertical: rs.sp(2)),
      leading: Container(
        width:  rs.sp(42),
        height: rs.sp(42),
        decoration: BoxDecoration(
          gradient:     AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(rs.sp(13)),
        ),
        child: Icon(icon, color: Colors.white, size: rs.sp(20)),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize:   rs.sp(15),
          fontWeight: FontWeight.w600,
          color:      Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.rs,
    required this.isDark,
    required this.icon,
    required this.onTap,
  });
  final Rs           rs;
  final bool         isDark;
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(14)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(isDark ? 0.12 : 0.22),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(rs.sp(10)),
              child: Icon(icon, color: Colors.white, size: rs.sp(22)),
            ),
          ),
        ),
      ),
    );
  }
}