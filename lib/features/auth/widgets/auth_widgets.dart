
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../cubit/auth_cubit.dart';

const _placeholder = Color(0xFFB0AECF);
const _fieldBg     = Color(0xFFF8F7FF);

// ══════════════════════════════════════════════════════════════
//  SIGN IN FORM
// ══════════════════════════════════════════════════════════════
class SignInForm extends StatefulWidget {
  const SignInForm({super.key, required this.rs});
  final Rs rs;
  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool  _obscure   = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().signInWithEmail(
        email: _emailCtrl.text, password: _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (ctx, state) {
        final loading = state is AuthLoading;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              rs.sp(24), rs.sp(42), rs.sp(24), rs.sp(32)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Email ────────────────────────────────
                _IconField(
                  ctrl:     _emailCtrl,
                  label:    context.tr('auth_email'),
                  hint:     context.tr('auth_email'),
                  icon:     Icons.mail_outline_rounded,
                  rs:       rs,
                  keyboard: TextInputType.emailAddress,
                  validator: EmailValidator.validate,
                ),

                SizedBox(height: rs.sp(16)),

                // ── Password ─────────────────────────────
                _IconField(
                  ctrl:    _passCtrl,
                  label:   context.tr('auth_password'),
                  hint:    context.tr('auth_password'),
                  icon:    Icons.lock_outline_rounded,
                  rs:      rs,
                  obscure: _obscure,
                  rightWidget: _EyeToggle(
                    obscure: _obscure,
                    rs: rs,
                    onTap: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                ),

                // ── Forgot password ───────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotDialog(ctx, rs),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: rs.sp(6), horizontal: rs.sp(4)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.dmSans(
                        color:      AppColors.royalBlue,
                        fontSize:   rs.sp(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: rs.sp(6)),

                // ── Sign In button ────────────────────────
                _GradientButton(
                  label:   context.tr('auth_sign_in'),
                  loading: loading,
                  rs:      rs,
                  onTap:   loading ? null : _submit,
                ),

                SizedBox(height: rs.sp(24)),
                _OrDivider(rs: rs),
                SizedBox(height: rs.sp(20)),

                // ── Google + Facebook ─────────────────────
                _SocialRow(
                  rs:         rs,
                  loading:    loading,
                  onGoogle:   loading ? null : () => ctx.read<AuthCubit>().signInWithGoogle(),
                  onFacebook: loading ? null : () => ctx.read<AuthCubit>().signInWithFacebook(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForgotDialog(BuildContext ctx, Rs rs) {
    final ec = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rs.sp(20))),
        title: Text(ctx.tr(S.resetPassword),
            style: GoogleFonts.sora(
                fontWeight: FontWeight.w700, fontSize: rs.sp(18))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Enter your email and we\'ll send a reset link.',
            style: GoogleFonts.dmSans(
                color: AppColors.textMuted, fontSize: rs.sp(13)),
          ),
          SizedBox(height: rs.sp(14)),
          _IconField(
            ctrl:     ec,
            label:    'Email',
            hint:     ctx.tr(S.authEmail),
            icon:     Icons.mail_outline_rounded,
            rs:       rs,
            keyboard: TextInputType.emailAddress,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(ctx.tr(S.cancel),
                style: GoogleFonts.dmSans(
                    color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(rs.sp(12))),
            ),
            onPressed: () {
              Navigator.pop(dCtx);
              ctx.read<AuthCubit>().sendPasswordReset(ec.text);
            },
            child: Text(ctx.tr(S.sendLink),
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SIGN UP FORM
// ══════════════════════════════════════════════════════════════
class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key, required this.rs});
  final Rs rs;
  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool  _obs1        = true;
  bool  _obs2        = true;
  int   _strength    = 0;

  void _calcStrength(String v) {
    int s = 0;
    if (v.length >= 6)  s++;
    if (v.length >= 10) s++;
    if (v.length >= 14) s++;
    if (v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    setState(() => _strength = s.clamp(0, 4));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().signUpWithEmail(
      email:    _emailCtrl.text,
      password: _passCtrl.text,
      fullName: _nameCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (ctx, state) {
        final loading = state is AuthLoading;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              rs.sp(24), rs.sp(42), rs.sp(24), rs.sp(32)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Full Name ─────────────────────────────
                _IconField(
                  ctrl:  _nameCtrl,
                  label: context.tr('auth_full_name'),
                  hint:  'Enter your full name',
                  icon:  Icons.person_outline_rounded,
                  rs:    rs,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Name is required';
                    return null;
                  },
                ),

                SizedBox(height: rs.sp(16)),

                // ── Email ─────────────────────────────────
                _IconField(
                  ctrl:     _emailCtrl,
                  label:    context.tr('auth_email'),
                  hint:     context.tr('auth_email'),
                  icon:     Icons.mail_outline_rounded,
                  rs:       rs,
                  keyboard: TextInputType.emailAddress,
                  validator: EmailValidator.validate,
                ),

                SizedBox(height: rs.sp(16)),

                // ── Password ──────────────────────────────
                _IconField(
                  ctrl:      _passCtrl,
                  label:     'Password',
                  hint:      'Enter your password',
                  icon:      Icons.lock_outline_rounded,
                  rs:        rs,
                  obscure:   _obs1,
                  onChanged: _calcStrength,
                  rightWidget: _EyeToggle(
                    obscure: _obs1,
                    rs: rs,
                    onTap: () => setState(() => _obs1 = !_obs1),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6)
                      return 'Min 6 characters';
                    return null;
                  },
                ),

                // 4-segment strength bar
                if (_passCtrl.text.isNotEmpty) ...[
                  SizedBox(height: rs.sp(8)),
                  _StrengthBar(strength: _strength, rs: rs),
                ],

                SizedBox(height: rs.sp(16)),

                // ── Confirm Password ──────────────────────
                _IconField(
                  ctrl:    _confirmCtrl,
                  label:   'Confirm Password',
                  hint:    'Re-enter your password',
                  icon:    Icons.lock_outline_rounded,
                  rs:      rs,
                  obscure: _obs2,
                  rightWidget: _EyeToggle(
                    obscure: _obs2,
                    rs: rs,
                    onTap: () => setState(() => _obs2 = !_obs2),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text)
                      return "Passwords don't match";
                    return null;
                  },
                ),

                SizedBox(height: rs.sp(24)),

                // ── Create Account button ─────────────────
                _GradientButton(
                  label:   context.tr('create_account'),
                  loading: loading,
                  rs:      rs,
                  onTap:   loading ? null : _submit,
                ),

                SizedBox(height: rs.sp(24)),
                _OrDivider(rs: rs),
                SizedBox(height: rs.sp(20)),

                // ── Google + Facebook ─────────────────────
                _SocialRow(
                  rs:         rs,
                  loading:    loading,
                  onGoogle:   loading ? null : () => ctx.read<AuthCubit>().signInWithGoogle(),
                  onFacebook: loading ? null : () => ctx.read<AuthCubit>().signInWithFacebook(),
                ),

                SizedBox(height: rs.sp(24)),
                AuthWidgets.termsText(rs),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _IconField  — focus-reactive field with Material icon prefix
// ══════════════════════════════════════════════════════════════
class _IconField extends StatefulWidget {
  const _IconField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.rs,
    this.obscure     = false,
    this.keyboard    = TextInputType.text,
    this.validator,
    this.onChanged,
    this.rightWidget,
  });

  final TextEditingController      ctrl;
  final String                     label, hint;
  final IconData                   icon;
  final Rs                         rs;
  final bool                       obscure;
  final TextInputType              keyboard;
  final String? Function(String?)? validator;
  final ValueChanged<String>?      onChanged;
  final Widget?                    rightWidget;

  @override
  State<_IconField> createState() => _IconFieldState();
}

class _IconFieldState extends State<_IconField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final rs = widget.rs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Uppercase label — changes colour on focus
        Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize:      rs.sp(11),
            fontWeight:    FontWeight.w700,
            color: _focused ? AppColors.royalBlue : AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),

        SizedBox(height: rs.sp(7)),

        // Animated container with clean border
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _focused ? AppColors.white : _fieldBg,
              borderRadius: BorderRadius.circular(rs.sp(14)),
              border: Border.all(
                color: _focused
                    ? AppColors.royalBlue
                    : Colors.black.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: _focused
                  ? [
                BoxShadow(
                  color:        AppColors.royalBlue.withOpacity(0.10),
                  blurRadius:   0,
                  spreadRadius: 3,
                ),
              ]
                  : [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller:   widget.ctrl,
              obscureText:  widget.obscure,
              keyboardType: widget.keyboard,
              onChanged:    widget.onChanged,
              validator:    widget.validator,
              style: GoogleFonts.dmSans(
                fontSize:   rs.sp(14),
                color:      AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:  widget.hint,
                hintStyle: GoogleFonts.dmSans(
                  color:    _placeholder,
                  fontSize: rs.sp(14),
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.symmetric(horizontal: rs.sp(14)),
                  child: Icon(
                    widget.icon,
                    size:  rs.sp(20),
                    color: _focused
                        ? AppColors.royalBlue
                        : const Color(0xFFB0AECF),
                  ),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth:  rs.sp(50),
                  minHeight: rs.sp(50),
                ),
                suffixIcon: widget.rightWidget,
                suffixIconConstraints: BoxConstraints(
                  minWidth:  rs.sp(44),
                  minHeight: rs.sp(44),
                ),
                filled:             true,
                fillColor:          Colors.transparent,
                border:             InputBorder.none,
                enabledBorder:      InputBorder.none,
                focusedBorder:      InputBorder.none,
                errorBorder:        InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: rs.sp(16),
                  vertical:   rs.sp(15),
                ),
                errorStyle: GoogleFonts.dmSans(
                  color:    AppColors.expense,
                  fontSize: rs.sp(11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Eye toggle button ─────────────────────────────────────────
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({
    required this.obscure,
    required this.rs,
    required this.onTap,
  });
  final bool          obscure;
  final Rs            rs;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(right: rs.sp(14)),
        child: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size:  rs.sp(20),
          color: const Color(0xFFB0AECF),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _GradientButton  — royal→violet gradient, shimmer when active
// ══════════════════════════════════════════════════════════════
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.rs,
    this.onTap,
  });
  final String        label;
  final bool          loading;
  final Rs            rs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: rs.sp(56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rs.sp(16)),
          gradient: loading
              ? const LinearGradient(
              colors: [Color(0xFFC5B8FF), Color(0xFFC5B8FF)])
              : AppColors.buttonGradient,
          boxShadow: loading
              ? []
              : [
            BoxShadow(
              color:      AppColors.royalBlue.withOpacity(0.32),
              blurRadius: 24,
              offset:     const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(rs.sp(16)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!loading) const _Shimmer(),
              loading
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: rs.sp(18), height: rs.sp(18),
                    child: const CircularProgressIndicator(
                      color:       AppColors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: rs.sp(10)),
                  Text(
                    label.contains('Account')
                        ? 'Creating account...'
                        : 'Signing in...',
                    style: GoogleFonts.dmSans(
                      color:      AppColors.white,
                      fontSize:   rs.sp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
                  : Text(
                label,
                style: GoogleFonts.sora(
                  color:         AppColors.white,
                  fontSize:      rs.sp(16),
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shimmer sweep
class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2500),
  )..repeat();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.translate(
        offset: Offset(w * (_c.value * 3 - 1), 0),
        child: Container(
          width: 60, height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.15),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _SocialRow  — Google + Apple side by side with proper SVG logos
// ══════════════════════════════════════════════════════════════
class _SocialRow extends StatelessWidget {
  const _SocialRow(
      {required this.rs, required this.loading, this.onGoogle, this.onFacebook});
  final Rs rs;
  final bool loading;
  final VoidCallback? onGoogle;
  final VoidCallback? onFacebook;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _SocialBtn(
          isGoogle: true,  label: 'Google', rs: rs, onTap: onGoogle)),
      SizedBox(width: rs.sp(12)),
      Expanded(child: _SocialBtn(
          isGoogle: false, label: 'Facebook', rs: rs, onTap: onFacebook)),
    ]);
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({
    required this.isGoogle,
    required this.label,
    required this.rs,
    this.onTap,
  });
  final bool          isGoogle;
  final String        label;
  final Rs            rs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: rs.sp(52),
        decoration: BoxDecoration(
          color:        AppColors.white,
          borderRadius: BorderRadius.circular(rs.sp(14)),
          border: Border.all(
              color: Colors.black.withOpacity(0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Proper brand logo icons
            if (isGoogle)
              _GoogleLogo(size: rs.sp(20))
            else
              Icon(Icons.facebook, size: rs.sp(22), color: Colors.black87),
            SizedBox(width: rs.sp(8)),
            Text(label,
                style: GoogleFonts.dmSans(
                  fontSize:   rs.sp(14),
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textDark,
                )),
          ],
        ),
      ),
    );
  }
}

/// Custom painted Google "G" logo with correct brand colors
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2;

    // Draw the coloured arcs of the Google logo
    final segments = [
      // [startAngle, sweepAngle, color]
      [-0.52,  1.57, const Color(0xFF4285F4)], // blue
      [ 1.05,  1.57, const Color(0xFF34A853)], // green
      [ 2.62,  0.79, const Color(0xFFFBBC05)], // yellow
      [ 3.41,  1.57, const Color(0xFFEA4335)], // red
      [ 4.98,  0.79, const Color(0xFFFBBC05)], // yellow tail
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;

    for (final seg in segments) {
      paint.color = seg[2] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        seg[0] as double,
        seg[1] as double,
        false,
        paint,
      );
    }

    // White cutout center + horizontal bar (the "G" mouth)
    final cutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.40, cutPaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy - r * 0.12, r * 0.72, r * 0.24),
        Radius.circular(r * 0.12),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── "or continue with" divider ───────────────────────────────────
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.rs});
  final Rs rs;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(
          color: Colors.black.withOpacity(0.08), thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: rs.sp(12)),
        child: Text('or continue with',
            style: GoogleFonts.dmSans(
              color:      AppColors.textMuted,
              fontSize:   rs.sp(12),
              fontWeight: FontWeight.w500,
            )),
      ),
      Expanded(child: Divider(
          color: Colors.black.withOpacity(0.08), thickness: 1)),
    ]);
  }
}

// ── 4-segment password strength bar ─────────────────────────────
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength, required this.rs});
  final int strength;
  final Rs  rs;

  static const _colors = [
    AppColors.expense,
    Color(0xFFFF9F43),
    Color(0xFFEFBF4D),
    AppColors.income,
  ];
  static const _labels = ['Too short', 'Fair', 'Good', 'Strong'];

  @override
  Widget build(BuildContext context) {
    final s = strength.clamp(0, 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: List.generate(4, (i) {
          final filled = s > 0 && i < s;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              height: rs.sp(4),
              margin: EdgeInsets.only(right: i < 3 ? rs.sp(4) : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rs.sp(2)),
                color: filled
                    ? _colors[s - 1]
                    : const Color(0xFFE2E8F0),
              ),
            ),
          );
        })),
        if (s > 0) ...[
          SizedBox(height: rs.sp(5)),
          Text(_labels[s - 1],
              style: GoogleFonts.dmSans(
                fontSize:   rs.sp(11),
                color:      _colors[s - 1],
                fontWeight: FontWeight.w500,
              )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AuthWidgets — static helpers
// ══════════════════════════════════════════════════════════════
abstract class AuthWidgets {

  static Widget termsText(Rs rs) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.dmSans(
            fontSize: rs.sp(11), color: AppColors.textMuted, height: 1.6),
        children: [
          const TextSpan(
              text: 'By creating an account you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: GoogleFonts.dmSans(
              color:      AppColors.royalBlue,
              fontWeight: FontWeight.w600,
              fontSize:   rs.sp(11),
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.dmSans(
              color:      AppColors.royalBlue,
              fontWeight: FontWeight.w600,
              fontSize:   rs.sp(11),
            ),
          ),
        ],
      ),
    );
  }

  static void showErrorSnackbar(BuildContext ctx, String msg) {
    AppSnack.show(ctx, message: msg, type: SnackType.error);
  }

  static void showSuccessSnackbar(BuildContext ctx, String msg) {
    AppSnack.show(ctx, message: msg, type: SnackType.success);
  }
}