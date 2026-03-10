// lib/features/transactions/presentation/transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../home/widgets/transaction_list_item.dart';
import '../Widgets/transaction_widgets.dart';
import '../domain/entities/transaction_entity.dart';
import 'cubit/transaction_cubit.dart';
import 'cubit/transaction_state.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionCubit>()..loadTransactions(),
      child: const _TransactionView(),
    );
  }
}

class _TransactionView extends StatefulWidget {
  const _TransactionView();
  @override
  State<_TransactionView> createState() => _TransactionViewState();
}

class _TransactionViewState extends State<_TransactionView> {
  static const _filters = ['All', 'Income', 'Expense', 'This Month'];

  String _filter = 'All';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<TransactionCubit>().loadMore();
    }
  }

  List<TransactionEntity> _filtered(List<TransactionEntity> all) {
    var list = all;
    switch (_filter) {
      case 'Income':
        list = list.where((t) => t.type == 'income').toList();
      case 'Expense':
        list = list.where((t) => t.type == 'expense').toList();
      case 'This Month':
        final now = DateTime.now();
        final m = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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

  Map<String, List<TransactionEntity>> _grouped(List<TransactionEntity> txns) {
    final map = <String, List<TransactionEntity>>{};
    for (final tx in txns) {
      map.putIfAbsent(DateFormat('MMMM d, yyyy').format(tx.date), () => [])
          .add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final rs = Rs.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgLavender,
      body: Column(
        children: [
          // ── Gradient header (fixed) ─────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    rs.sp(20), rs.sp(14), rs.sp(20), rs.sp(20)),
                child: Column(children: [
                  Row(children: [
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: rs.sp(26),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: rs.sp(40),
                      height: rs.sp(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(rs.sp(13)),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: Colors.white, size: rs.sp(20)),
                    ),
                  ]),
                  SizedBox(height: rs.sp(14)),
                  // Search bar
                  TxnSearchBar(
                    controller: _searchCtrl,
                    query: _searchQuery,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ]),
              ),
            ),
          ),

          // ── Filter chips ─────────────────────────────
          Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: rs.sp(12)),
              child: TxnFilterChips(
                filters: _filters,
                active: _filter,
                onSelect: (f) => setState(() => _filter = f),
              ),
            ),
          ),

          // ── Scrollable transaction list ───────────────
          Expanded(
            child: BlocConsumer<TransactionCubit, TransactionState>(
              listener: (ctx, state) {
                if (state is TransactionDeleted) {
                  ScaffoldMessenger.of(ctx)
                    ..clearSnackBars()
                    ..showSnackBar(_deleteSnackBar(ctx, state.deletedId));
                }
              },
              builder: (ctx, state) {
                if (state is TransactionLoading) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: AppColors.royalBlue,
                          strokeWidth: 2));
                }

                final txns = state is TransactionLoaded
                    ? _filtered(state.transactions)
                    : <TransactionEntity>[];

                if (txns.isEmpty) {
                  return TxnScreenEmptyState(filter: _filter);
                }

                final groups = _grouped(txns);
                final keys = groups.keys.toList();

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                      rs.sp(18), rs.sp(16), rs.sp(18), 110),
                  itemCount: keys.length,
                  itemBuilder: (_, i) {
                    final label = keys[i];
                    final items = groups[label]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TxnDateLabel(label: label),
                        TxnDateGroupCard(
                          children: items
                              .asMap()
                              .entries
                              .map((e) => TransactionListItem(
                            tx: e.value,
                            isLast: e.key == items.length - 1,
                            onDelete: () => ctx
                                .read<TransactionCubit>()
                                .softDelete(e.value.id),
                          ))
                              .toList(),
                        ),
                        SizedBox(height: rs.sp(18)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SnackBar _deleteSnackBar(BuildContext ctx, String id) => SnackBar(
    content: const Text('Transaction deleted'),
    backgroundColor: const Color(0xFF3D3B6E),
    duration: const Duration(seconds: 4),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
    action: SnackBarAction(
      label: 'UNDO',
      textColor: AppColors.violet,
      onPressed: () =>
          ctx.read<TransactionCubit>().undoDelete(id),
    ),
  );
}