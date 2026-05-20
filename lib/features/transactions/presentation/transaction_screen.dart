// lib/features/transactions/presentation/transaction_screen.dart
//
// REDESIGNED — Layered scroll UI matching HomeScreen exactly
//  • Layer 1: Fixed gradient header (title + subtitle + glass search + filter chips)
//    → fades out as the user scrolls (same headerOpacity formula as HomeScreen)
//  • Layer 2: bgLavender content card slides up over the header
//  • All existing logic preserved: BLoC, filters, search, swipe-delete, undo snackbar

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../home/widgets/home_widgets.dart';   // TransactionDetailSheet lives here
import '../Widgets/transaction_widgets.dart';
import '../../../core/widgets/delete_toast.dart';
import '../domain/entities/transaction_entity.dart';
import '../../../core/cubit/app_cubit.dart';
import 'cubit/transaction_cubit.dart';
import 'cubit/transaction_state.dart';

// ══════════════════════════════════════════════════════════════
// ENTRY
// ══════════════════════════════════════════════════════════════
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TransactionCubit is provided by MainNavigation — shared across all tabs.
    // No need to create a new provider here; just use the one from above.
    return const _TransactionView();
  }
}

// ══════════════════════════════════════════════════════════════
// VIEW
// ══════════════════════════════════════════════════════════════
class _TransactionView extends StatefulWidget {
  const _TransactionView();
  @override
  State<_TransactionView> createState() => _TransactionViewState();
}

class _TransactionViewState extends State<_TransactionView> {
  static const _filterKeys = [
    'filter_all',
    'filter_income',
    'filter_expense',
    'filter_transfer',
    'filter_this_month',
  ];

  String _filterKey = 'filter_all';
  String _searchQuery = '';
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  double _scrollOffset = 0;

  // Locally-tracked visible ids — updated ahead of BLoC so the
  // Dismissible is removed cleanly before state rebuilds.
  List<String> _visibleIds = [];

  // Handle to the currently-visible delete toast (if any)
  DeleteToastHandle? _toastHandle;

  // ── The height of the gradient header content (without status bar).
  // Adjust if you change padding / font sizes.
  static const double _headerContentH = 185.0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollCtrl.offset);
    // Infinite-scroll trigger
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<TransactionCubit>().loadMore();
    }
  }

  // ── Same fade formula as HomeScreen ───────────────────────────
  double get _headerOpacity =>
      (1.0 - ((_scrollOffset - 40.0) / 85.0).clamp(0.0, 1.0));

  // ── Filtering ────────────────────────────────────────────────
  List<TransactionEntity> _filtered(List<TransactionEntity> all) {
    var list = all;
    switch (_filterKey) {
      case 'filter_income':
        list = list.where((t) => t.type == 'income').toList();
      case 'filter_expense':
        list = list.where((t) => t.type == 'expense').toList();
      case 'filter_transfer':
        list = list.where((t) => t.type == 'transfer').toList();
      case 'filter_this_month':
        final now = DateTime.now();
        final m   = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        list = list.where((t) => t.month == m).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
      t.title.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  // ── Group by formatted date string ───────────────────────────
  Map<String, List<TransactionEntity>> _grouped(
      List<TransactionEntity> txns) {
    final map = <String, List<TransactionEntity>>{};
    for (final tx in txns) {
      map
          .putIfAbsent(
          DateFormat('MMMM d, yyyy').format(tx.date), () => [])
          .add(tx);
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD — mirrors Analytics screen pattern exactly:
  //
  //   Layer 1 (bottom): Positioned.fill gradient background
  //                     Fades out via _headerOpacity as card scrolls up.
  //                     IgnorePointer — never receives touches.
  //
  //   Layer 2 (middle): Positioned.fill SingleChildScrollView
  //                     Transparent SizedBox spacer pushes the bgLavender
  //                     card below the header on first load. As the user
  //                     scrolls, the solid bgLavender card slides up and
  //                     PHYSICALLY COVERS the header — so header widgets
  //                     can never visually overlap the cards.
  //
  //   Layer 3 (top):    Positioned header (title, search, filter chips)
  //                     Above the scroll view in z-order so it wins taps
  //                     while visible. IgnorePointer once scrolled away.
  //                     Because the card is a solid colour it covers this
  //                     layer completely — chips never show over cards.
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final rs      = Rs.of(context);
    final statusH = MediaQuery.of(context).padding.top;
    // Total height the transparent spacer must reserve so the card
    // starts below the header on first load.
    final spacerH = statusH + _headerContentH;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        body: BlocListener<TransactionCubit, TransactionState>(
          listener: (ctx, state) {
            if (state is TransactionDeleted) {
              _toastHandle?.dismiss();
              _toastHandle = showDeleteToast(
                ctx,
                onUndo: () => ctx.read<TransactionCubit>().undoDelete(state.deletedId),
              );
            }
          },
          child: Stack(children: [

            // ════════════════════════════════════════════════
            // LAYER 1 — gradient + decorative orbs background.
            // Fades via _headerOpacity as card scrolls up.
            // IgnorePointer: never intercepts any touches.
            // Orbs are INSIDE this layer so they fade with the
            // background and never overlap foreground content.
            // ════════════════════════════════════════════════
            Positioned.fill(
              child: IgnorePointer(
                child: _TxnHeaderBackground(bgOpacity: _headerOpacity),
              ),
            ),

            // ════════════════════════════════════════════════
            // LAYER 2 — conditional scroll content.
            //
            // • EMPTY STATE  → fixed layout, no scroll.
            //   The header sits on top (Layer 3). The bgLavender
            //   card fills the space below it and the empty-state
            //   content is centred inside.
            //
            // • DATA STATE   → SingleChildScrollView (original
            //   behaviour). Transparent spacer pushes the card
            //   below the header at rest; solid card slides up
            //   and covers Layer 3 as the user scrolls.
            // ════════════════════════════════════════════════
            Positioned.fill(
              child: BlocBuilder<TransactionCubit, TransactionState>(
                buildWhen: (_, curr) =>
                curr is TransactionLoaded ||
                    curr is TransactionLoading ||
                    curr is TransactionInitial,
                // TransactionDeleted is NOT here — the cubit already
                // emitted TransactionLoaded (with the item removed)
                // before TransactionDeleted. BlocListener handles the toast.
                builder: (ctx, state) {
                  // ── Single source of truth ────────────────────────────
                  // The cubit always emits TransactionLoaded after any
                  // mutation (add / delete / undo). We NEVER derive the
                  // display list from any other state type.
                  final isLoading = state is TransactionLoading ||
                      state is TransactionInitial;

                  // Always read from the authoritative cubit list.
                  // TransactionDeleted is a side-effect signal only —
                  // by the time it arrives, TransactionLoaded has already
                  // been emitted with the item removed.
                  final allTxns = state is TransactionLoaded
                      ? state.transactions
                      : <TransactionEntity>[];

                  // Apply filter (type/search) — never mutates allTxns.
                  final filtered = _filtered(allTxns);

                  // _visibleIds is a purely LOCAL swipe-ahead gate:
                  // when the user swipes an item, we remove it from
                  // _visibleIds immediately so the row vanishes before the
                  // cubit emits. On the next TransactionLoaded, we reset
                  // _visibleIds to the authoritative set so it has zero effect.
                  if (state is TransactionLoaded) {
                    _visibleIds = filtered.map((t) => t.id).toList();
                  }

                  final txns = filtered
                      .where((t) => _visibleIds.contains(t.id))
                      .toList();

                  final isEmpty = !isLoading && filtered.isEmpty;

                  // ── EMPTY STATE — fixed, no scroll ────────
                  if (isEmpty) {
                    return Column(
                      children: [
                        // Transparent spacer matching the header height.
                        SizedBox(height: spacerH),

                        // Fixed card — fills ALL remaining screen space
                        // (extends under the bottom nav bar so no gap shows).
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(rs.sp(28))),
                            ),
                            child: Center(
                              child: TxnScreenEmptyState(filterKey: _filterKey),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // ── DATA / LOADING STATE — scrollable ─────
                  return SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics:    const BouncingScrollPhysics(),
                    child: Column(children: [

                      // Transparent spacer — same height as the header.
                      SizedBox(height: spacerH),

                      // bgLavender card with content list.
                      Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(rs.sp(28))),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          rs.sp(16), rs.sp(0), rs.sp(16),
                          rs.sp(40),
                        ),
                        child: isLoading
                            ? _TxnShimmer(rs: rs)
                            : _buildList(ctx, rs, txns),
                      ),
                    ]),
                  );
                },
              ),
            ),

            // ════════════════════════════════════════════════
            // LAYER 3 — foreground header content only.
            // Title, search bar, filter chips — NO background,
            // NO orbs. Exactly like Analytics Layer 3.
            // Fades independently from the background so UI
            // elements never appear to merge with orbs.
            // IgnorePointer once fully scrolled away.
            // ════════════════════════════════════════════════
            Positioned(
              top: 0, left: 0, right: 0,
              child: Opacity(
                opacity: _headerOpacity,
                child: IgnorePointer(
                  ignoring: _headerOpacity < 0.05,
                  child: _TxnHeaderForeground(
                    rs:              rs,
                    searchCtrl:      _searchCtrl,
                    searchQuery:     _searchQuery,
                    filterKeys:      _filterKeys,
                    activeFilterKey: _filterKey,
                    onSearchChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    onSearchClear:   () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    onFilterSelect:  (f) => setState(() => _filterKey = f),
                  ),
                ),
              ),
            ),

          ]),
        ),
      ),
    );
  }

  // ── Builds the grouped transaction list (data state only) ──────────────────
  Widget _buildList(BuildContext ctx, Rs rs, List<TransactionEntity> txns) {
    final groups = _grouped(txns);
    final keys   = groups.keys.toList();
    return ListView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      itemCount:   keys.length,
      itemBuilder: (_, i) {
        final label = keys[i];
        final items = groups[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TxnDateLabel(label: label),
            TxnDateGroupCard(
              children: items.asMap().entries.map((e) {
                return _TxnListItem(
                  key:    ValueKey(e.value.id),
                  tx:     e.value,
                  isLast: e.key == items.length - 1,
                  onDelete: () {
                    // Remove locally first (this frame), then persist.
                    setState(() => _visibleIds.remove(e.value.id));
                    ctx.read<TransactionCubit>().softDelete(e.value.id);
                  },
                );
              }).toList(),
            ),
            SizedBox(height: rs.sp(20)),
          ],
        );
      },
    );
  }

// _deleteSnackBar removed — replaced by showDeleteToast overlay
}

// ══════════════════════════════════════════════════════════════
// LAYER 1 — Background only: gradient fill + decorative orbs.
//
// This widget is ONLY the background. It has NO interactive
// content (no text, no search bar, no chips). Placed in
// Positioned.fill under Layer 2 and Layer 3.
//
// bgOpacity is applied per-element (same as AnalyticsHeader)
// so gradient and orbs fade together as the card scrolls up,
// while foreground content in Layer 3 fades independently.
// ══════════════════════════════════════════════════════════════
class _TxnHeaderBackground extends StatelessWidget {
  const _TxnHeaderBackground({super.key, required this.bgOpacity});
  final double bgOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [

      // ── Full-screen gradient fill ──────────────────────────
      Positioned.fill(
        child: Opacity(
          opacity: bgOpacity,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [
                  AppColors.midnight,
                  AppColors.deepBlue,
                  AppColors.royalBlue,
                  AppColors.violet,
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
        ),
      ),

      // ── Top 2 decorative orbs — each fades with bgOpacity ─
      // Keeping them in the background layer ensures they NEVER
      // overlap foreground content regardless of scroll position.
      Positioned(top: -50, left:  -50,
          child: Opacity(opacity: bgOpacity, child: const _Orb(180, 0.06))),
      Positioned(top:   8, right: -60,
          child: Opacity(opacity: bgOpacity, child: const _Orb(200, 0.05))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// LAYER 3 — Foreground content only: title, search, chips.
//
// NO gradient background, NO orbs — purely the interactive
// UI elements. Positioned above Layer 2 in z-order so it
// receives touch events while visible.
//
// Fades via its own Opacity in the parent Stack (same as
// AnalyticsPeriodChip in Layer 3 of the Analytics screen).
// ══════════════════════════════════════════════════════════════
class _TxnHeaderForeground extends StatelessWidget {
  const _TxnHeaderForeground({
    required this.rs,
    required this.searchCtrl,
    required this.searchQuery,
    required this.filterKeys,
    required this.activeFilterKey,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onFilterSelect,
  });

  final Rs                    rs;
  final TextEditingController searchCtrl;
  final String                searchQuery;
  final List<String>          filterKeys;
  final String                activeFilterKey;
  final ValueChanged<String>  onSearchChanged;
  final VoidCallback          onSearchClear;
  final ValueChanged<String>  onFilterSelect;

  @override
  Widget build(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        rs.sp(20),
        statusH + rs.sp(16),
        rs.sp(20),
        rs.sp(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [

          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('transactions'),
                    style: TextStyle(
                      fontSize:      rs.sp(26),
                      fontWeight:    FontWeight.w800,
                      color:         Colors.white,
                      fontFamily:    'Sora',
                      letterSpacing: -0.6,
                      height:        1.1,
                    ),
                  ),
                  SizedBox(height: rs.sp(4)),
                  Text(
                    context.tr('txn_activity_sub'),
                    style: TextStyle(
                      fontSize:   rs.sp(14),
                      color:      Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),

          SizedBox(height: rs.sp(14)),

          // Search bar
          TxnSearchBar(
            controller: searchCtrl,
            query:      searchQuery,
            onChanged:  onSearchChanged,
            onClear:    onSearchClear,
          ),

          SizedBox(height: rs.sp(10)),

          // Filter chips
          _GlassFilterChips(
            filterKeys: filterKeys,
            activeKey:  activeFilterKey,
            onSelect:   onFilterSelect,
            rs:         rs,
          ),

          SizedBox(height: rs.sp(4)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GLASS FILTER CHIPS  (on gradient, same as previous design)
// Active: solid white pill with gradient ShaderMask text
// Inactive: semi-transparent glass pill with white text
// ══════════════════════════════════════════════════════════════
class _GlassFilterChips extends StatelessWidget {
  const _GlassFilterChips({
    required this.filterKeys,
    required this.activeKey,
    required this.onSelect,
    required this.rs,
  });
  final List<String>         filterKeys;
  final String               activeKey;
  final ValueChanged<String> onSelect;
  final Rs                   rs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rs.sp(36),
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          EdgeInsets.zero,
        itemCount:        filterKeys.length,
        separatorBuilder: (_, __) => SizedBox(width: rs.sp(8)),
        itemBuilder: (_, i) {
          final f        = filterKeys[i];
          final label    = context.tr(f);
          final isActive = activeKey == f;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutCubic,
              padding:  EdgeInsets.symmetric(horizontal: rs.sp(18)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(rs.sp(22)),
                border: isActive
                    ? null
                    : Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1.2),
                boxShadow: isActive
                    ? [
                  BoxShadow(
                    color:      AppColors.royalBlue.withOpacity(0.25),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  )
                ]
                    : null,
              ),
              child: isActive
                  ? ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.violet],
                ).createShader(b),
                child: Text(label,
                    style: TextStyle(
                      fontSize:      rs.sp(12.5),
                      fontWeight:    FontWeight.w800,
                      color:         Colors.white,
                      letterSpacing: 0.1,
                    )),
              )
                  : Text(label,
                  style: TextStyle(
                    fontSize:      rs.sp(12.5),
                    fontWeight:    FontWeight.w600,
                    color:         Colors.white.withOpacity(0.85),
                    letterSpacing: 0.1,
                  )),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TRANSACTION LIST ITEM  (unchanged from original — full fidelity)
// ══════════════════════════════════════════════════════════════
class _TxnListItem extends StatelessWidget {
  const _TxnListItem({
    super.key,
    required this.tx,
    required this.isLast,
    required this.onDelete,
  });

  final TransactionEntity tx;
  final bool              isLast;
  final VoidCallback      onDelete;

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color    get _catColor   => kTxnCatColors[tx.category] ?? AppColors.textMuted;
  IconData get _catIcon    => kTxnCatIcons[tx.category]  ?? Icons.category_rounded;
  bool     get _isIncome   => tx.type == 'income';
  bool     get _isTransfer => tx.type == 'transfer';

  Color get _amtColor => _isIncome
      ? AppColors.income
      : _isTransfer
      ? AppColors.royalBlue
      : AppColors.expense;

  String get _amtPrefix => _isIncome ? '+' : '-';

  @override
  Widget build(BuildContext context) {
    final rs        = Rs.of(context);
    // Read symbol from AppCubit — the single source of truth for currency.
    // context.select rebuilds only this widget when currency changes.
    final symbol    = context.select<AppCubit, String>(
            (c) => c.state.symbol);
    final formatted =
        '$_amtPrefix$symbol${fmtFullGlobal(tx.amount)}';
    final timeLabel = DateFormat('h:mm a').format(tx.date);

    return Dismissible(
      key:              ValueKey(tx.id),
      direction:        DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 300),
      resizeDuration:   const Duration(milliseconds: 200),
      background: _SwipeBackground(rs: rs, isLast: isLast),
      // Return false — parent removes key from _visibleIds first,
      // triggering a clean list rebuild. The Dismissible never has to
      // remove itself, so Flutter never throws "dismissed widget still in tree".
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.vertical(
              bottom: isLast
                  ? Radius.circular(rs.sp(22))
                  : Radius.zero,
            ),
            splashColor:    _catColor.withOpacity(0.08),
            highlightColor: _catColor.withOpacity(0.04),
            onTap: () => showModalBottomSheet(
              context:            context,
              isScrollControlled: true,
              backgroundColor:    Colors.transparent,
              builder: (_) => TransactionDetailSheet(tx: tx),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: rs.sp(16), vertical: rs.sp(14)),
              child: Row(children: [

                // ── Category icon tile ───────────────────────────
                Container(
                  width:  rs.sp(48),
                  height: rs.sp(48),
                  decoration: BoxDecoration(
                    color:        _catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(rs.sp(15)),
                    border:       Border.all(
                        color: _catColor.withOpacity(0.18), width: 1),
                  ),
                  child: Icon(_catIcon, color: _catColor, size: rs.sp(22)),
                ),

                SizedBox(width: rs.sp(13)),

                // ── Title · category tag · time ──────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cap(tx.title),
                        style: TextStyle(
                          fontSize:      rs.sp(14),
                          fontWeight:    FontWeight.w700,
                          color:         Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: rs.sp(4)),
                      Row(children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: rs.sp(8), vertical: rs.sp(3)),
                          decoration: BoxDecoration(
                            color:        _catColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(rs.sp(8)),
                          ),
                          child: Text(
                            _cap(tx.category),
                            style: TextStyle(
                              fontSize:      rs.sp(10),
                              fontWeight:    FontWeight.w700,
                              color:         _catColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        SizedBox(width: rs.sp(6)),
                        Container(
                          width:  rs.sp(3),
                          height: rs.sp(3),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                              shape: BoxShape.circle),
                        ),
                        SizedBox(width: rs.sp(6)),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize:   rs.sp(11),
                            color:      Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                SizedBox(width: rs.sp(10)),

                // ── Amount + IN / OUT / TR badge ─────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatted,
                      style: TextStyle(
                        fontSize:      rs.sp(14.5),
                        fontWeight:    FontWeight.w800,
                        color:         _amtColor,
                        fontFamily:    'Sora',
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: rs.sp(4)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(7), vertical: rs.sp(3)),
                      decoration: BoxDecoration(
                        color:        _amtColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(rs.sp(8)),
                      ),
                      child: Text(
                        _isIncome
                            ? 'IN'
                            : _isTransfer
                            ? 'TR'
                            : 'OUT',
                        style: TextStyle(
                          fontSize:      rs.sp(9),
                          fontWeight:    FontWeight.w800,
                          color:         _amtColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(width: rs.sp(6)),

                Icon(
                  Icons.chevron_right_rounded,
                  size:  rs.sp(20),
                  color: AppColors.textMuted.withOpacity(0.45),
                ),
              ]),
            ),
          ),
        ),

        // Thin divider between rows (not after last item)
        if (!isLast)
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: rs.sp(16)),
            color:  Theme.of(context).scaffoldBackgroundColor,
          ),
      ]),
    );
  }
}

// ── Swipe-to-delete background ─────────────────────────────────
// Matches TransactionListItem (home screen) exactly:
// same gradient, same icon tile, same rounded corner logic.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.rs, this.isLast = false});
  final Rs   rs;
  final bool isLast;

  @override
  Widget build(_) => Container(
    alignment: Alignment.centerRight,
    padding:   EdgeInsets.only(right: rs.sp(22)),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
        begin:  Alignment.centerLeft,
        end:    Alignment.centerRight,
      ),
      borderRadius: isLast
          ? BorderRadius.only(
        bottomLeft:  Radius.circular(rs.sp(22)),
        bottomRight: Radius.circular(rs.sp(22)),
      )
          : BorderRadius.circular(rs.sp(16)),
      boxShadow: [
        BoxShadow(
          color:      AppColors.expense.withOpacity(0.30),
          blurRadius: 12,
          offset:     const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize:       MainAxisSize.min,
      mainAxisAlignment:  MainAxisAlignment.center,
      children: [
        Container(
          width:  rs.sp(38),
          height: rs.sp(38),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(rs.sp(12)),
          ),
          child: Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: rs.sp(20)),
        ),
        SizedBox(height: rs.sp(4)),
        Text(context.tr(S.deleteLabel),
            style: TextStyle(
              color:      Colors.white,
              fontSize:   rs.sp(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ],
    ),
  );
}

// ── Decorative orb (same helper used in HomeHeader) ────────────
class _Orb extends StatelessWidget {
  const _Orb(this.size, this.opacity);
  final double size, opacity;
  @override
  Widget build(_) => Container(
    width:  size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ── Glass icon button (header top-right) ──────────────────────
class _GlassIconBtn extends StatelessWidget {
  const _GlassIconBtn(
      {required this.icon, required this.rs, required this.onTap});
  final IconData     icon;
  final Rs           rs;
  final VoidCallback onTap;

  @override
  Widget build(_) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(rs.sp(14)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width:  rs.sp(44),
          height: rs.sp(44),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(rs.sp(14)),
            border:       Border.all(
                color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: rs.sp(21)),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// SHIMMER LOADING STATE  (unchanged)
// ══════════════════════════════════════════════════════════════
class _TxnShimmer extends StatelessWidget {
  const _TxnShimmer({required this.rs});
  final Rs rs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (gi) => Padding(
        padding: EdgeInsets.only(bottom: rs.sp(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date label placeholder
            Row(children: [
              _box(context, rs, rs.sp(4),  rs.sp(18), r: 3),
              SizedBox(width: rs.sp(9)),
              _box(context, rs, rs.sp(11), rs.sp(100)),
            ]),
            SizedBox(height: rs.sp(10)),
            // Card placeholder
            Container(
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(rs.sp(22)),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.royalBlue.withOpacity(0.06),
                    blurRadius: 20,
                    offset:     const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(3, (i) => Column(children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: rs.sp(16), vertical: rs.sp(14)),
                    child: Row(children: [
                      _box(context, rs, rs.sp(48), rs.sp(48), r: rs.sp(15)),
                      SizedBox(width: rs.sp(13)),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _box(context, rs, rs.sp(13), rs.sp(130)),
                          SizedBox(height: rs.sp(7)),
                          _box(context, rs, rs.sp(10), rs.sp(80)),
                        ],
                      )),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _box(context, rs, rs.sp(13), rs.sp(60)),
                          SizedBox(height: rs.sp(5)),
                          _box(context, rs, rs.sp(16), rs.sp(28), r: rs.sp(8)),
                        ],
                      ),
                    ]),
                  ),
                  if (i < 2)
                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(
                          horizontal: rs.sp(16)),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                ])),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _box(BuildContext context, Rs rs, double h, double w, {double r = 6}) => Container(
    height: h,
    width:  w,
    decoration: BoxDecoration(
      color:        Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}