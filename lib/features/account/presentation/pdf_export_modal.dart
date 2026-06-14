

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../services/pdf_export_service.dart';

// ── Report option model ───────────────────────────────────────────────────────
class _ReportOption {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ReportOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

// ── Helper: month name from DateTime ─────────────────────────────────────────
String _monthName(DateTime date) => DateFormat('MMMM').format(date);

// ── Widget ────────────────────────────────────────────────────────────────────
class PdfExportModal extends StatefulWidget {

  final List<TransactionEntity> transactions;
  final String currencySymbol;
  final String languageCode;
  final String? aiInsight;

  const PdfExportModal({
    super.key,
    required this.transactions,
    required this.currencySymbol,
    required this.languageCode,
    this.aiInsight,
  });

  @override
  State<PdfExportModal> createState() => _PdfExportModalState();
}

class _PdfExportModalState extends State<PdfExportModal> {
  String? _selected;
  bool _loading = false;
  String? _errorMsg;
  // Pre-resolved during build() so _export() never calls context.tr()
  // from inside a gesture callback (which would trigger the Provider.of
  // listen:true assertion error).
  String _resolvedPdfError = '';


  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;

  // ── Build options dynamically so subtitle reflects chosen period ──────────
  List<_ReportOption> get _options => [
    _ReportOption(
      key: 'monthly',
      title: context.tr(S.monthlyReport),
      subtitle:
      '${_monthName(_selectedMonth)} ${_selectedMonth.year} - ${context.tr(S.monthlyReportSub)}',
      icon: Icons.calendar_month_rounded,
      accent: AppColors.royalBlue,
    ),
    _ReportOption(
      key: 'annual',
      title: context.tr(S.annualReport),
      subtitle:
      '$_selectedYear - ${context.tr(S.annualReportSub)}',
      icon: Icons.bar_chart_rounded,
      accent: AppColors.violet,
    ),
    _ReportOption(
      key: 'full',
      title: context.tr(S.completeReport),
      subtitle: context.tr(S.completeReportSub),
      icon: Icons.receipt_long_rounded,
      accent: AppColors.income,
    ),
  ];

  // ── Month picker ─────────────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    final rs = Rs.of(context);
    final now = DateTime.now();
    DateTime temp = _selectedMonth;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rs.sp(22))),
          title: Text(
            'Select Month & Year',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(17)),
          ),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Year row ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => setLocal(
                              () => temp = DateTime(temp.year - 1, temp.month)),
                    ),
                    Text(
                      '${temp.year}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: rs.sp(16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: temp.year >= now.year
                          ? null
                          : () => setLocal(() =>
                      temp = DateTime(temp.year + 1, temp.month)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Month grid ────────────────────────────────────
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.0,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6),
                  itemCount: 12,
                  itemBuilder: (_, i) {
                    final m = i + 1;
                    final isFuture =
                        temp.year == now.year && m > now.month;
                    final isSel = temp.month == m;
                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () => setLocal(
                              () => temp = DateTime(temp.year, m)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          gradient: isSel ? AppColors.buttonGradient : null,
                          color: isSel
                              ? null
                              : isFuture
                              ? Colors.grey.withOpacity(0.06)
                              : AppColors.royalBlue.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(rs.sp(8)),
                        ),
                        child: Center(
                          child: Text(
                            DateFormat('MMM').format(DateTime(2000, m)),
                            style: TextStyle(
                              fontSize: rs.sp(11),
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : isFuture
                                  ? Colors.grey.withOpacity(0.4)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45))),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedMonth = temp);
                Navigator.pop(ctx);
              },
              child: Text('OK',
                  style: TextStyle(
                      color: AppColors.royalBlue,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Year picker ──────────────────────────────────────────────────────────
  Future<void> _pickYear() async {
    final rs = Rs.of(context);
    final now = DateTime.now();
    int tempYear = _selectedYear;

    // Build list of available years (last 10 years)
    final years = List.generate(
      10,
          (i) => now.year - i,
    );

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rs.sp(22))),
          title: Text(
            'Select Year',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                fontSize: rs.sp(17)),
          ),
          content: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: years.map((y) {
                final isSel = tempYear == y;
                return GestureDetector(
                  onTap: () => setLocal(() => tempYear = y),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSel ? AppColors.buttonGradient : null,
                      color: isSel
                          ? null
                          : AppColors.royalBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(rs.sp(12)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$y',
                          style: TextStyle(
                            fontSize: rs.sp(14),
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSel ? Colors.white : null,
                          ),
                        ),
                        const Spacer(),
                        if (isSel)
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45))),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedYear = tempYear);
                Navigator.pop(ctx);
              },
              child: Text('OK',
                  style: TextStyle(
                      color: AppColors.royalBlue,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    if (_selected == null) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await PdfExportService.generate(
        transactions:   widget.transactions,
        reportType:     _selected!,
        currencySymbol: widget.currencySymbol,
        languageCode:   widget.languageCode,
        aiInsight:      widget.aiInsight,
        selectedMonth:  _selectedMonth,
        selectedYear:   _selectedYear,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('PdfExportService error: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMsg = _resolvedPdfError; // safe: resolved during build(), not here
          _loading  = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve translations here (inside build) where watch/Provider.of is legal.
    _resolvedPdfError = context.tr(S.pdfError);

    final rs = Rs.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
    final onSheet = cs.onSurface;
    final muted = onSheet.withOpacity(0.50);
    final border = onSheet.withOpacity(0.08);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(rs.sp(28))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
          EdgeInsets.fromLTRB(rs.sp(20), 0, rs.sp(20), rs.sp(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────
              Center(
                child: Container(
                  width: rs.sp(38),
                  height: rs.sp(4),
                  margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(rs.sp(3)),
                  ),
                ),
              ),

              // ── Title row ────────────────────────────────────────
              Row(children: [
                Container(
                  width: rs.sp(44),
                  height: rs.sp(44),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(rs.sp(14)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalBlue.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white, size: rs.sp(22)),
                ),
                SizedBox(width: rs.sp(14)),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr(S.exportPdfTitle),
                            style: TextStyle(
                              fontSize: rs.sp(17),
                              fontWeight: FontWeight.w800,
                              color: onSheet,
                              fontFamily: 'Sora',
                              letterSpacing: -0.3,
                            )),
                        SizedBox(height: rs.sp(2)),
                        Text(context.tr(S.exportPdfSubtitle),
                            style: TextStyle(
                              fontSize: rs.sp(12),
                              color: muted,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    )),
              ]),

              SizedBox(height: rs.sp(20)),

              // ── Report options ───────────────────────────────────
              ..._options.map((opt) => _OptionTile(
                option: opt,
                selected: _selected == opt.key,
                onTap: _loading
                    ? null
                    : () async {
                  setState(() => _selected = opt.key);

                  if (opt.key == 'monthly') await _pickMonth();
                  if (opt.key == 'annual') await _pickYear();
                },
                rs: rs,
                isDark: isDark,
                border: border,
                onSheet: onSheet,
                muted: muted,
              )),

              // ── Error ────────────────────────────────────────────
              if (_errorMsg != null) ...[
                SizedBox(height: rs.sp(10)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.sp(14), vertical: rs.sp(10)),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(rs.sp(12)),
                    border: Border.all(
                        color: AppColors.expense.withOpacity(0.30), width: 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.expense, size: rs.sp(16)),
                    SizedBox(width: rs.sp(8)),
                    Expanded(
                        child: Text(_errorMsg!,
                            style: TextStyle(
                              color: AppColors.expense,
                              fontSize: rs.sp(12),
                            ))),
                  ]),
                ),
              ],

              SizedBox(height: rs.sp(16)),

              // ── Export button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: rs.sp(52),
                child: _loading
                    ? Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(rs.sp(16)),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
                    : GestureDetector(
                  onTap: _selected == null ? null : _export,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: _selected != null
                          ? AppColors.buttonGradient
                          : null,
                      color: _selected == null
                          ? onSheet.withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(rs.sp(16)),
                      boxShadow: _selected != null
                          ? [
                        BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_rounded,
                            color: _selected != null
                                ? Colors.white
                                : onSheet.withOpacity(0.30),
                            size: rs.sp(18),
                          ),
                          SizedBox(width: rs.sp(8)),
                          Text(
                            context.tr(S.exportShare),
                            style: TextStyle(
                              color: _selected != null
                                  ? Colors.white
                                  : onSheet.withOpacity(0.30),
                              fontSize: rs.sp(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.rs,
    required this.isDark,
    required this.border,
    required this.onSheet,
    required this.muted,
  });

  final _ReportOption option;
  final bool selected;
  final VoidCallback? onTap;
  final Rs rs;
  final bool isDark;
  final Color border, onSheet, muted;

  @override
  Widget build(BuildContext context) {
    final accent = option.accent;
    final tileBg =
    selected ? accent.withOpacity(isDark ? 0.14 : 0.07) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: rs.sp(10)),
        padding: EdgeInsets.all(rs.sp(14)),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(rs.sp(16)),
          border: Border.all(
            color: selected ? accent.withOpacity(0.50) : border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.18 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          ]
              : null,
        ),
        child: Row(children: [
          // Icon tile
          Container(
            width: rs.sp(44),
            height: rs.sp(44),
            decoration: BoxDecoration(
              color: accent.withOpacity(
                  selected ? (isDark ? 0.22 : 0.12) : (isDark ? 0.10 : 0.07)),
              borderRadius: BorderRadius.circular(rs.sp(13)),
              border: Border.all(
                color: accent.withOpacity(selected ? 0.40 : 0.20),
                width: 1,
              ),
            ),
            child: Icon(option.icon,
                color: accent.withOpacity(selected ? 1.0 : 0.70),
                size: rs.sp(21)),
          ),

          SizedBox(width: rs.sp(14)),

          // Text
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title,
                      style: TextStyle(
                        fontSize: rs.sp(13.5),
                        fontWeight: FontWeight.w700,
                        color: selected ? accent : onSheet,
                        letterSpacing: -0.2,
                      )),
                  SizedBox(height: rs.sp(3)),
                  Text(option.subtitle,
                      style: TextStyle(
                        fontSize: rs.sp(11),
                        color: muted,
                      )),
                ],
              )),

          SizedBox(width: rs.sp(8)),

          // Selection indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: rs.sp(22),
            height: rs.sp(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Colors.transparent,
              border: Border.all(
                color: selected ? accent : border,
                width: selected ? 0 : 1.5,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: accent.withOpacity(0.50),
                  blurRadius: 8,
                )
              ]
                  : null,
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                color: Colors.white, size: rs.sp(13))
                : null,
          ),
        ]),
      ),
    );
  }
}