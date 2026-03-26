// lib/features/transactions/Widgets/add_transaction_widgets.dart
//
// ══════════════════════════════════════════════════════════════
// REDESIGNED — Premium dark fintech theme matching HomeScreen
// ══════════════════════════════════════════════════════════════
// Design system:
//   • Full dark gradient background (midnight → deepBlue → royalBlue)
//   • Glassmorphism cards (BackdropFilter + white 10-15% opacity)
//   • Perfect GridView category layout (4 per row, equal tiles)
//   • Animated category selection (scale + glow)
//   • Pill-style type toggle with animated slider
//   • Large focal amount with animated glow on focus
//   • Embedded AI badge with glass background
//   • Press-to-save button with haptic + scale animation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_helper.dart';

// ══════════════════════════════════════════════════════════════
// CATEGORY MODEL
// ══════════════════════════════════════════════════════════════
class TxnCategory {
  final String emoji, label, value;
  const TxnCategory(this.emoji, this.label, this.value);
}

const expenseCategories = [
  TxnCategory('🍔', 'Food',          'food'),
  TxnCategory('🚗', 'Transport',     'transport'),
  TxnCategory('🛍️', 'Shopping',     'shopping'),
  TxnCategory('💊', 'Health',        'health'),
  TxnCategory('🎬', 'Fun',           'entertainment'),
  TxnCategory('⚡', 'Bills',         'bills'),
  TxnCategory('📚', 'Education',     'education'),
  TxnCategory('🏠', 'Rent',          'rent'),
  TxnCategory('💳', 'Other',         'other'),
];

const incomeCategories = [
  TxnCategory('💼', 'Salary',        'salary'),
  TxnCategory('💻', 'Freelance',     'freelance'),
  TxnCategory('📈', 'Investment',    'investment'),
  TxnCategory('🏢', 'Business',      'business'),
  TxnCategory('🎁', 'Gift',          'gift'),
  TxnCategory('💳', 'Other',         'other'),
];

const transferCategories = [
  TxnCategory('🔄', 'Transfer',      'transfer'),
];

// ══════════════════════════════════════════════════════════════
// GLASS CARD — reusable glass container
// ══════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
    this.borderRadius,
    this.opacity = 0.10,
    this.border  = true,
  });
  final Widget  child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double  opacity;
  final bool    border;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? 20.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(r),
            border: border
                ? Border.all(color: Colors.white.withOpacity(0.20), width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER — drag handle + back + title (dark version)
// ══════════════════════════════════════════════════════════════
class AddTxnHeader extends StatelessWidget {
  const AddTxnHeader({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(rs.sp(20), rs.sp(14), rs.sp(20), 0),
      child: Column(children: [
        // Drag handle
        Container(
          width: rs.sp(44), height: rs.sp(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(height: rs.sp(16)),
        Row(children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onBack();
            },
            child: _GlassCard(
              borderRadius: 14,
              opacity: 0.15,
              padding: EdgeInsets.all(rs.sp(9)),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: rs.sp(17),
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Add Transaction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   rs.sp(20),
                fontWeight: FontWeight.w800,
                color:      Colors.white,
                fontFamily: 'Sora',
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(width: rs.sp(38)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TYPE TOGGLE — animated pill with sliding indicator
// ══════════════════════════════════════════════════════════════
class TypeToggleRow extends StatelessWidget {
  const TypeToggleRow({
    super.key,
    required this.activeType,
    required this.onSelect,
  });
  final String activeType;
  final ValueChanged<String> onSelect;

  static const _types  = ['expense', 'income', 'transfer'];
  static const _labels = ['Expense', 'Income',  'Transfer'];

  @override
  Widget build(BuildContext context) {
    final rs       = Rs.of(context);
    final activeIdx = _types.indexOf(activeType).clamp(0, 2);

    return _GlassCard(
      borderRadius: 22,
      opacity: 0.12,
      padding: EdgeInsets.all(rs.sp(5)),
      child: Stack(children: [
        // Animated active pill
        AnimatedAlign(
          duration:  const Duration(milliseconds: 220),
          curve:     Curves.easeOutCubic,
          alignment: Alignment(-1 + activeIdx.toDouble(), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / 3,
            child: Container(
              height: rs.sp(38),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.violet],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(rs.sp(17)),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.royalBlue.withOpacity(0.50),
                    blurRadius: 16,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Labels
        Row(
          children: List.generate(3, (i) {
            final isActive = i == activeIdx;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(_types[i]);
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: rs.sp(38),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize:   rs.sp(13),
                        fontWeight: FontWeight.w700,
                        color:      isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        letterSpacing: 0.2,
                      ),
                      child: Text(_labels[i]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AMOUNT FIELD — large focal number with glow on focus
// ══════════════════════════════════════════════════════════════
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.typeColor,
    required this.validator,
    this.currencySymbol = '৳',
  });
  final TextEditingController     controller;
  final Color                     typeColor;
  final FormFieldValidator<String> validator;
  final String                    currencySymbol;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _glowAnim =
  CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

  bool _focused = false;

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rs.sp(24)),
          boxShadow: [
            BoxShadow(
              color:      widget.typeColor.withOpacity(0.25 * _glowAnim.value),
              blurRadius: 40 * _glowAnim.value,
              spreadRadius: 2 * _glowAnim.value,
            ),
          ],
        ),
        child: child,
      ),
      child: _GlassCard(
        borderRadius: rs.sp(24),
        opacity:      0.13,
        padding: EdgeInsets.fromLTRB(
            rs.sp(24), rs.sp(20), rs.sp(24), rs.sp(20)),
        child: Focus(
          onFocusChange: (hasFocus) {
            setState(() => _focused = hasFocus);
            hasFocus ? _glowCtrl.forward() : _glowCtrl.reverse();
          },
          child: Column(children: [
            Text(
              'ENTER AMOUNT',
              style: TextStyle(
                color:         Colors.white.withOpacity(0.45),
                fontSize:      rs.sp(10),
                fontWeight:    FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: rs.sp(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.currencySymbol,
                  style: TextStyle(
                    fontSize:   rs.sp(26),
                    fontWeight: FontWeight.w700,
                    color:      Colors.white.withOpacity(0.50),
                    fontFamily: 'Sora',
                    height:     1.2,
                  ),
                ),
                SizedBox(width: rs.sp(6)),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextFormField(
                      controller:   widget.controller,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: TextStyle(
                        fontSize:      rs.sp(48),
                        fontWeight:    FontWeight.w800,
                        color:         Colors.white,
                        fontFamily:    'Sora',
                        letterSpacing: -2,
                        height:        1.0,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border:      InputBorder.none,
                        isDense:     true,
                        hintText:    '0.00',
                        hintStyle: TextStyle(
                          fontSize:      rs.sp(48),
                          fontWeight:    FontWeight.w800,
                          color:         Colors.white.withOpacity(0.18),
                          fontFamily:    'Sora',
                          letterSpacing: -2,
                          height:        1.0,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: widget.validator,
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CATEGORY GRID — perfect 4-column grid, equal tiles
// ══════════════════════════════════════════════════════════════
class CategoryChipList extends StatelessWidget {
  const CategoryChipList({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  final List<TxnCategory> categories;
  final String?           selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GridView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   4,
        crossAxisSpacing: rs.sp(10),
        mainAxisSpacing:  rs.sp(10),
        childAspectRatio: 0.90,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat       = categories[i];
        final isSelected = selected == cat.value;
        return _CategoryTile(
          cat:        cat,
          isSelected: isSelected,
          onTap:      () {
            HapticFeedback.selectionClick();
            onSelect(cat.value);
          },
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.cat,
    required this.isSelected,
    required this.onTap,
  });
  final TxnCategory cat;
  final bool        isSelected;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 120));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    final sel = widget.isSelected;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: sel
                ? const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.royalBlue, AppColors.violet])
                : null,
            color: sel ? null : Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            border: Border.all(
              color: sel
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: sel
                ? [
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.55),
                blurRadius: 20,
                offset:     const Offset(0, 6),
              ),
            ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  rs.sp(36),
                height: rs.sp(36),
                decoration: BoxDecoration(
                  color:        sel
                      ? Colors.white.withOpacity(0.20)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(rs.sp(12)),
                ),
                child: Center(
                  child: Text(widget.cat.emoji,
                      style: TextStyle(fontSize: rs.sp(20))),
                ),
              ),
              SizedBox(height: rs.sp(6)),
              Text(
                widget.cat.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize:   rs.sp(10),
                  fontWeight: FontWeight.w600,
                  color:      sel
                      ? Colors.white
                      : Colors.white.withOpacity(0.65),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI SUGGESTION BADGE — glass + gradient glow
// ══════════════════════════════════════════════════════════════
class AiSuggestionBadge extends StatelessWidget {
  const AiSuggestionBadge({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });
  final String     suggestion;
  final VoidCallback onAccept, onDismiss;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return _GlassCard(
      borderRadius: rs.sp(18),
      opacity:      0.12,
      padding: EdgeInsets.symmetric(
          horizontal: rs.sp(16), vertical: rs.sp(13)),
      child: Row(children: [
        // AI icon tile
        Container(
          width:  rs.sp(34),
          height: rs.sp(34),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.violet, AppColors.royalBlue],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(rs.sp(11)),
            boxShadow: [
              BoxShadow(
                color:      AppColors.violet.withOpacity(0.45),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: rs.sp(16)),
          ),
        ),
        SizedBox(width: rs.sp(11)),

        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI SUGGESTS',
                style: TextStyle(
                  color:         AppColors.violet,
                  fontSize:      rs.sp(9),
                  fontWeight:    FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: rs.sp(2)),
              Text(
                suggestion,
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   rs.sp(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Accept button
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onAccept();
          },
          child: Container(
            width:  rs.sp(34),
            height: rs.sp(34),
            decoration: BoxDecoration(
              color:        AppColors.income.withOpacity(0.20),
              borderRadius: BorderRadius.circular(rs.sp(11)),
              border: Border.all(
                  color: AppColors.income.withOpacity(0.40), width: 1),
            ),
            child: Icon(Icons.check_rounded,
                color: AppColors.income, size: rs.sp(18)),
          ),
        ),
        SizedBox(width: rs.sp(8)),

        // Dismiss button
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onDismiss();
          },
          child: Container(
            width:  rs.sp(34),
            height: rs.sp(34),
            decoration: BoxDecoration(
              color:        AppColors.expense.withOpacity(0.20),
              borderRadius: BorderRadius.circular(rs.sp(11)),
              border: Border.all(
                  color: AppColors.expense.withOpacity(0.40), width: 1),
            ),
            child: Icon(Icons.close_rounded,
                color: AppColors.expense, size: rs.sp(18)),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION LABEL
// ══════════════════════════════════════════════════════════════
class TxnSectionLabel extends StatelessWidget {
  const TxnSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Row(children: [
      Container(
        width:  rs.sp(4),
        height: rs.sp(18),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      SizedBox(width: rs.sp(8)),
      Text(
        text,
        style: TextStyle(
          fontSize:      rs.sp(14),
          fontWeight:    FontWeight.w700,
          color:         Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// GLASS INPUT FIELD — dark glass wrapper for text fields
// ══════════════════════════════════════════════════════════════
class TxnInputCard extends StatefulWidget {
  const TxnInputCard({
    super.key,
    required this.child,
    this.icon,
  });
  final Widget  child;
  final IconData? icon;

  @override
  State<TxnInputCard> createState() => _TxnInputCardState();
}

class _TxnInputCardState extends State<TxnInputCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rs.sp(18)),
          boxShadow: _focused
              ? [
            BoxShadow(
              color:      AppColors.royalBlue.withOpacity(0.30),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: _GlassCard(
          borderRadius: rs.sp(18),
          opacity:      _focused ? 0.18 : 0.10,
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(16), vertical: rs.sp(14)),
          child: widget.child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATE ROW
// ══════════════════════════════════════════════════════════════
class TxnDateRow extends StatelessWidget {
  const TxnDateRow({super.key, required this.date, required this.onTap});
  final DateTime     date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Container(
          width:  rs.sp(32),
          height: rs.sp(32),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(rs.sp(10)),
            boxShadow: [
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.40),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.calendar_today_rounded,
              color: Colors.white, size: rs.sp(15)),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(
          child: Text(
            DateFormat('EEE, d MMM yyyy').format(date),
            style: TextStyle(
              fontSize:   rs.sp(14),
              fontWeight: FontWeight.w600,
              color:      Colors.white,
            ),
          ),
        ),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.45), size: rs.sp(20)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SAVE BUTTON — gradient with press animation + haptic
// ══════════════════════════════════════════════════════════════
class SaveButton extends StatefulWidget {
  const SaveButton({
    super.key,
    required this.isSubmitting,
    required this.onTap,
  });
  final bool         isSubmitting;
  final VoidCallback onTap;

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTap() async {
    if (widget.isSubmitting) return;
    HapticFeedback.mediumImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: rs.sp(58),
          decoration: BoxDecoration(
            gradient: widget.isSubmitting
                ? null
                : const LinearGradient(
                colors: [AppColors.royalBlue, AppColors.violet],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight),
            color: widget.isSubmitting
                ? Colors.white.withOpacity(0.15)
                : null,
            borderRadius: BorderRadius.circular(rs.sp(20)),
            boxShadow: widget.isSubmitting
                ? null
                : [
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.55),
                blurRadius: 30,
                offset:     const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: widget.isSubmitting
                ? SizedBox(
              width: rs.sp(22), height: rs.sp(22),
              child: const CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: rs.sp(18)),
                SizedBox(width: rs.sp(8)),
                Text(
                  'Save Transaction',
                  style: TextStyle(
                    color:         Colors.white,
                    fontSize:      rs.sp(16),
                    fontWeight:    FontWeight.w800,
                    fontFamily:    'Sora',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}