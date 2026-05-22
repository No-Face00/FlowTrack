// Edit Profile — glass UI, Firebase Auth + Firestore + optional Storage photo.

import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_themes.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  Uint8List? _pickedBytes;
  bool _loadingDoc = true;
  bool _saving = false;
  String _initial = '?';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() => setState(() => _scrollOffset = _scrollCtrl.offset));
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingDoc = false);
      return;
    }
    String name = user.displayName?.trim() ?? '';
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
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    HapticFeedback.selectionClick();
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _pickedBytes = bytes);
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPremiumSnackBar(
        context,
        message: context.tr(S.nameEnterRequired),
        icon: Icons.info_outline_rounded,
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    final nav = Navigator.of(context, rootNavigator: true);
    try {
      await user.updateDisplayName(name);
      final uid = user.uid;
      final batch = <String, dynamic>{'name': name};

      if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$uid.jpg');
        await ref.putData(
          _pickedBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await ref.getDownloadURL();
        await user.updatePhotoURL(url);
        batch['photoUrl'] = url;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        batch,
        SetOptions(merge: true),
      );

      await user.reload();
      if (!mounted) return;
      setState(() => _saving = false);
      nav.pop();
      Future.delayed(const Duration(milliseconds: 120), () {
        showPremiumSnackBar(
          nav.context,
          message: context.tr(S.profileUpdated),
          subtitle: context.tr(S.profileUpdatedSub),
          icon: Icons.check_circle_rounded,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showPremiumSnackBar(
          context,
          message: context.tr(S.profileError),
          subtitle: e.toString(),
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final ImageProvider<Object>? avatarImage = _pickedBytes != null
        ? MemoryImage(_pickedBytes!)
        : (photoUrl != null && photoUrl.isNotEmpty
        ? NetworkImage(photoUrl)
        : null);
    final headerFade = (1.0 - ((_scrollOffset - 40) / 120).clamp(0.0, 1.0));

    final surfaceGlass = isDark
        ? DarkColors.surface.withOpacity(0.92)
        : Colors.white.withOpacity(0.94);
    final borderGlass =
    isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.75);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: headerFade,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.heroGradient),
                ),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + rs.sp(8)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: rs.sp(16)),
                      child: Row(
                        children: [
                          _GlassIconButton(
                            rs: rs,
                            isDark: isDark,
                            icon: Icons.arrow_back_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.pop();
                            },
                          ),
                          SizedBox(width: rs.sp(10)),
                          Text(
                            context.tr(S.editProfile),
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: rs.sp(22),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: rs.sp(28)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: rs.sp(20)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(rs.sp(28)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: EdgeInsets.all(rs.sp(22)),
                            decoration: BoxDecoration(
                              color: surfaceGlass,
                              borderRadius: BorderRadius.circular(rs.sp(28)),
                              border: Border.all(color: borderGlass, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: AppColors.royalBlue.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _loadingDoc
                                ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(rs.sp(24)),
                                child: CircularProgressIndicator(
                                  color: AppColors.royalBlue,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: GestureDetector(
                                    onTap: _pickPhoto,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Colors.white,
                                                AppColors.violet,
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: CircleAvatar(
                                            radius: rs.sp(52),
                                            backgroundColor:
                                            theme.colorScheme.surfaceContainerHighest,
                                            backgroundImage: avatarImage,
                                            child: avatarImage == null
                                                ? Text(
                                              _initial,
                                              style: TextStyle(
                                                fontSize: rs.sp(36),
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.royalBlue,
                                                fontFamily: 'Sora',
                                              ),
                                            )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          right: 4,
                                          bottom: 4,
                                          child: Container(
                                            padding: EdgeInsets.all(rs.sp(8)),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.buttonGradient,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.9),
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.royalBlue
                                                      .withOpacity(0.45),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.photo_camera_rounded,
                                              color: Colors.white,
                                              size: rs.sp(16),
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
                                    context.tr(S.tapToChangePhoto),
                                    style: TextStyle(
                                      fontSize: rs.sp(12),
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: rs.sp(28)),
                                Text(
                                  context.tr(S.displayName),
                                  style: TextStyle(
                                    fontSize: rs.sp(12),
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: rs.sp(8)),
                                TextField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  style: TextStyle(
                                    fontSize: rs.sp(16),
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.tr(S.yourNameHint),
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      color: AppColors.royalBlue.withOpacity(0.85),
                                      size: rs.sp(22),
                                    ),
                                  ),
                                ),
                                SizedBox(height: rs.sp(28)),
                                SizedBox(
                                  height: rs.sp(52),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.buttonGradient,
                                      borderRadius:
                                      BorderRadius.circular(rs.sp(16)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.royalBlue
                                              .withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                        BorderRadius.circular(rs.sp(16)),
                                        onTap: _saving ? null : _save,
                                        child: Center(
                                          child: _saving
                                              ? SizedBox(
                                            width: rs.sp(22),
                                            height: rs.sp(22),
                                            child:
                                            const CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                              : Text(
                                            context.tr(S.saveChanges),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: rs.sp(16),
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Sora',
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
                        height: MediaQuery.of(context).padding.bottom + rs.sp(32)),
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.rs,
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  final Rs rs;
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(14)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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