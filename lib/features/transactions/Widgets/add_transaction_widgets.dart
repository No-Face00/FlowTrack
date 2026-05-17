// lib/features/transactions/Widgets/add_transaction_widgets.dart
//
// ══════════════════════════════════════════════════════════════
// REDESIGNED v3 — AppColors system + Material icons for categories
// ══════════════════════════════════════════════════════════════

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/utils/responsive_helper.dart';

// AppCategory from app_categories.dart is the canonical type.
// TxnCategory alias kept for any remaining internal usages.
typedef TxnCategory = AppCategory;

// ══════════════════════════════════════════════════════════════
// GLASS CARD
// ══════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
    this.borderRadius,
    this.opacity       = 0.15,
    this.border        = true,
    this.borderOpacity = 0.28,
    this.shadowOpacity = 0.0,
  });
  final Widget              child;
  final EdgeInsetsGeometry? padding;
  final double?             borderRadius;
  final double              opacity;
  final bool                border;
  final double              borderOpacity;
  final double              shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? 20.0;

    // The add-transaction screen always shows a blue gradient background
    // regardless of theme mode. _GlassCard is a frosted-glass surface
    // on top of that gradient in both light and dark mode.
    //
    // Dark mode tweak: slightly lower the opacity so the glass feels more
    // translucent (dark system bg behind the gradient = less light scatter).
    // We do NOT switch to an indigo fill — that killed the glass effect.
    final effectiveOpacity = Theme.of(context).brightness == Brightness.dark
        ? opacity * 0.80   // 20% more transparent in dark — same glass, softer
        : opacity;
    final effectiveBorderOpacity = Theme.of(context).brightness == Brightness.dark
        ? borderOpacity * 0.85
        : borderOpacity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // Always white-opacity tint — the gradient bg is always present.
            // Low opacity is the key: blur bleeds through, glass is visible.
            color: Colors.white.withOpacity(effectiveOpacity),
            borderRadius: BorderRadius.circular(r),
            border: border
                ? Border.all(
              color: Colors.white.withOpacity(effectiveBorderOpacity),
              width: 1.1,
            )
                : null,
            boxShadow: shadowOpacity > 0
                ? [
              BoxShadow(
                color:      Colors.black.withOpacity(shadowOpacity),
                blurRadius: 20,
                offset:     const Offset(0, 10),
              ),
            ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER
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


        SizedBox(height: rs.sp(16)),
        Row(children: [
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onBack(); },
            child: _GlassCard(
              borderRadius:  14,
              opacity:       0.18,
              borderOpacity: 0.30,
              shadowOpacity: 0.20,
              padding: EdgeInsets.all(rs.sp(9)),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: rs.sp(17), color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              context.tr('add_transaction'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:      rs.sp(20),
                fontWeight:    FontWeight.w800,
                color:         Colors.white,
                fontFamily:    'Sora',
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
// TYPE TOGGLE — uses AppColors.buttonGradient + royalBlue glow
// ══════════════════════════════════════════════════════════════
class TypeToggleRow extends StatelessWidget {
  const TypeToggleRow({
    super.key,
    required this.activeType,
    required this.onSelect,
  });
  final String               activeType;
  final ValueChanged<String> onSelect;

  static const _types = ['expense', 'income', 'transfer'];
  static const _labelKeys = ['expense', 'income', 'transfer'];

  @override
  Widget build(BuildContext context) {
    final rs        = Rs.of(context);
    final activeIdx = _types.indexOf(activeType).clamp(0, 2);

    return _GlassCard(
      borderRadius:  22,
      opacity:       0.10,
      borderOpacity: 0.22,
      shadowOpacity: 0.15,
      padding: EdgeInsets.all(rs.sp(5)),
      child: Stack(children: [
        AnimatedAlign(
          duration:  const Duration(milliseconds: 220),
          curve:     Curves.easeOutCubic,
          alignment: Alignment(-1 + activeIdx.toDouble(), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / 3,
            child: Container(
              height: rs.sp(38),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(rs.sp(17)),
                boxShadow: [
                  BoxShadow(
                    color:        AppColors.royalBlue.withOpacity(0.55),
                    blurRadius:   20,
                    offset:       const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: List.generate(3, (i) {
            final isActive = i == activeIdx;
            return Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onSelect(_types[i]); },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: rs.sp(38),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize:      rs.sp(13),
                        fontWeight:    FontWeight.w700,
                        color:         isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.55),
                        letterSpacing: 0.2,
                      ),
                      child: Text(context.tr(_labelKeys[i])),
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
// AMOUNT FIELD
// ══════════════════════════════════════════════════════════════
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.typeColor,
    required this.validator,
    this.currencySymbol = '৳',
  });
  final TextEditingController      controller;
  final Color                      typeColor;
  final FormFieldValidator<String> validator;
  final String                     currencySymbol;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _glowAnim =
  CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

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
              color:      Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
            BoxShadow(
              color:        widget.typeColor.withOpacity(0.30 * _glowAnim.value),
              blurRadius:   40 * _glowAnim.value,
              spreadRadius: 2  * _glowAnim.value,
            ),
          ],
        ),
        child: child,
      ),
      child: _GlassCard(
        borderRadius:  rs.sp(24),
        opacity:       0.12,
        borderOpacity: 0.26,
        padding: EdgeInsets.fromLTRB(
            rs.sp(24), rs.sp(20), rs.sp(24), rs.sp(20)),
        child: Focus(
          onFocusChange: (f) => f ? _glowCtrl.forward() : _glowCtrl.reverse(),
          child: Column(children: [
            Text(
              context.tr('enter_amount'),
              style: TextStyle(
                color:         Colors.white.withOpacity(0.60),
                fontSize:      rs.sp(10),
                fontWeight:    FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: rs.sp(8)),
            Row(
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.currencySymbol,
                  style: TextStyle(
                    fontSize:   rs.sp(26),
                    fontWeight: FontWeight.w700,
                    color:      Colors.white.withOpacity(0.70),
                    fontFamily: 'Sora',
                    height:     1.2,
                  ),
                ),
                SizedBox(width: rs.sp(6)),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextFormField(
                      controller:   widget.controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: TextStyle(
                        fontSize:      rs.sp(48),
                        fontWeight:    FontWeight.w800,
                        color:         Colors.white.withOpacity(0.95),
                        fontFamily:    'Sora',
                        letterSpacing: -2,
                        height:        1.0,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border:         InputBorder.none,
                        enabledBorder:  InputBorder.none,
                        focusedBorder:  InputBorder.none,
                        errorBorder:    InputBorder.none,
                        // Override global fillColor:white — must be transparent
                        // inside the glass card or a white box appears.
                        filled:         true,
                        fillColor:      Colors.transparent,
                        isDense:        true,
                        hintText:       '0.00',
                        hintStyle: TextStyle(
                          fontSize:      rs.sp(48),
                          fontWeight:    FontWeight.w800,
                          color:         Colors.white.withOpacity(0.30),
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
// CATEGORY GRID — responsive Wrap layout
// Fixes overflow on long names: "Food & Dining", "Health & Medical",
// "Bills & Utilities", "Entertainment", "Rent & Housing"
// ══════════════════════════════════════════════════════════════
class CategoryChipList extends StatelessWidget {
  const CategoryChipList({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  final List<TxnCategory>    categories;
  final String?              selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final rs          = Rs.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // 3 tiles per row; account for horizontal padding (40) + 2 gaps (10*2)
    final tileW = (screenWidth - rs.sp(40) - rs.sp(20)) / 3;

    return Wrap(
      spacing:    rs.sp(10),
      runSpacing: rs.sp(10),
      children: categories.map((cat) {
        final isSelected = selected == cat.value;
        return SizedBox(
          width: tileW,
          child: _CategoryTile(
            cat:        cat,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(cat.value);
            },
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.cat,
    required this.isSelected,
    required this.onTap,
  });
  final TxnCategory  cat;
  final bool         isSelected;
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
    final rs  = Rs.of(context);
    final sel = widget.isSelected;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutCubic,
          // NO hardcoded width — SizedBox parent controls width
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(6), vertical: rs.sp(10)),
          decoration: BoxDecoration(
            gradient: sel ? AppColors.buttonGradient : null,
            color:    sel ? null : Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(rs.sp(18)),
            border: Border.all(
              color: sel
                  ? Colors.white.withOpacity(0.40)
                  : Colors.white.withOpacity(0.25),
              width: sel ? 1.5 : 1.0,
            ),
            boxShadow: sel
                ? [BoxShadow(
              color:        AppColors.royalBlue.withOpacity(0.50),
              blurRadius:   20,
              offset:       const Offset(0, 6),
              spreadRadius: 1,
            )]
                : [BoxShadow(
              color:      Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset:     const Offset(0, 4),
            )],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  rs.sp(38),
                height: rs.sp(38),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.22)
                      : widget.cat.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(rs.sp(12)),
                ),
                child: Center(
                  child: Icon(
                    widget.cat.icon,
                    size:  rs.sp(19),
                    color: sel ? Colors.white : widget.cat.color,
                  ),
                ),
              ),
              SizedBox(height: rs.sp(5)),
              // FittedBox + 2-line text: long names scale down instead of clipping
              LayoutBuilder(builder: (_, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Text(
                    widget.cat.label,
                    textAlign: TextAlign.center,
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:      rs.sp(10.5),
                      fontWeight:    FontWeight.w600,
                      color:         sel
                          ? Colors.white
                          : Colors.white.withOpacity(0.82),
                      letterSpacing: 0.1,
                      height:        1.25,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI SUGGESTION BADGE — royalBlue/violet gradient
// ══════════════════════════════════════════════════════════════
class AiSuggestionBadge extends StatelessWidget {
  const AiSuggestionBadge({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });
  final String       suggestion;
  final VoidCallback onAccept, onDismiss;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rs.sp(18)),
        boxShadow: [
          BoxShadow(
            color:        AppColors.violet.withOpacity(0.20),
            blurRadius:   20,
            offset:       const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rs.sp(18)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: rs.sp(16), vertical: rs.sp(13)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [
                  AppColors.royalBlue.withOpacity(0.28),
                  AppColors.violet.withOpacity(0.22),
                ],
              ),
              borderRadius: BorderRadius.circular(rs.sp(18)),
              border: Border.all(
                color: AppColors.violet.withOpacity(0.40),
                width: 1.2,
              ),
            ),
            child: Row(children: [
              Container(
                width:  rs.sp(36),
                height: rs.sp(36),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(rs.sp(11)),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.violet.withOpacity(0.50),
                      blurRadius: 12,
                      offset:     const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: rs.sp(17)),
                ),
              ),
              SizedBox(width: rs.sp(11)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI SUGGESTS',
                      style: TextStyle(
                        color:         Colors.white.withOpacity(0.70),
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
                        fontSize:   rs.sp(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onAccept(); },
                child: Container(
                  width:  rs.sp(36),
                  height: rs.sp(36),
                  decoration: BoxDecoration(
                    color:        AppColors.income.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(rs.sp(11)),
                    border: Border.all(
                        color: AppColors.income.withOpacity(0.50), width: 1.2),
                  ),
                  child: Icon(Icons.check_rounded,
                      color: AppColors.income, size: rs.sp(18)),
                ),
              ),
              SizedBox(width: rs.sp(8)),
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onDismiss(); },
                child: Container(
                  width:  rs.sp(36),
                  height: rs.sp(36),
                  decoration: BoxDecoration(
                    color:        AppColors.expense.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(rs.sp(11)),
                    border: Border.all(
                        color: AppColors.expense.withOpacity(0.50), width: 1.2),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.expense, size: rs.sp(18)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION LABEL — buttonGradient accent bar + royalBlue glow
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
        height: rs.sp(20),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color:      AppColors.royalBlue.withOpacity(0.50),
              blurRadius: 8,
              offset:     const Offset(2, 0),
            ),
          ],
        ),
      ),
      SizedBox(width: rs.sp(10)),
      Text(
        text,
        style: TextStyle(
          fontSize:      rs.sp(15),
          fontWeight:    FontWeight.w700,
          color:         Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// GLASS INPUT CARD — royalBlue focus glow
// ══════════════════════════════════════════════════════════════
class TxnInputCard extends StatefulWidget {
  const TxnInputCard({super.key, required this.child, this.icon});
  final Widget    child;
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
              color:        AppColors.royalBlue.withOpacity(0.35),
              blurRadius:   24,
              spreadRadius: 1,
            ),
          ]
              : [
            BoxShadow(
              color:      Colors.black.withOpacity(0.20),
              blurRadius: 12,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: _GlassCard(
          borderRadius:  rs.sp(18),
          opacity:       _focused ? 0.15 : 0.10,
          borderOpacity: _focused ? 0.35 : 0.22,
          padding: EdgeInsets.symmetric(
              horizontal: rs.sp(16), vertical: rs.sp(15)),
          child: widget.child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DATE ROW — buttonGradient icon tile
// ══════════════════════════════════════════════════════════════
class TxnDateRow extends StatelessWidget {
  const TxnDateRow({super.key, required this.date, required this.onTap});
  final DateTime     date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Container(
          width:  rs.sp(34),
          height: rs.sp(34),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(rs.sp(10)),
            boxShadow: [
              BoxShadow(
                color:      AppColors.royalBlue.withOpacity(0.50),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.calendar_today_rounded,
              color: Colors.white, size: rs.sp(16)),
        ),
        SizedBox(width: rs.sp(12)),
        Expanded(
          child: Text(
            DateFormat('EEE, d MMM yyyy').format(date),
            style: TextStyle(
              fontSize:   rs.sp(14),
              fontWeight: FontWeight.w600,
              color:      Colors.white.withOpacity(0.95),
            ),
          ),
        ),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.60), size: rs.sp(22)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SAVE BUTTON — AppColors.buttonGradient + dual glow shadow
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
          height:   rs.sp(60),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white38,width: 1.5),

            gradient: widget.isSubmitting ? null : AppColors.buttonGradient,
            color:    widget.isSubmitting
                ? Colors.white.withOpacity(0.18)
                : null,
            borderRadius: BorderRadius.circular(rs.sp(20)),
            boxShadow: widget.isSubmitting
                ? null
                : [
              BoxShadow(
                color:        AppColors.royalBlue.withOpacity(0.55),
                blurRadius:   30,
                offset:       const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color:      AppColors.violet.withOpacity(0.30),
                blurRadius: 20,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isSubmitting
                ? SizedBox(
              width:  rs.sp(22),
              height: rs.sp(22),
              child: const CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: rs.sp(20)),
                SizedBox(width: rs.sp(10)),
                Text(
                  context.tr('save_transaction'),
                  style: TextStyle(
                    color:         Colors.white,
                    fontSize:      rs.sp(17),
                    fontWeight:    FontWeight.w800,
                    fontFamily:    'Sora',
                    letterSpacing: 0.4,
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