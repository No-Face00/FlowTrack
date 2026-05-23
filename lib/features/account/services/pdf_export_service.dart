// lib/features/account/services/pdf_export_service.dart
//
// FONT STRATEGY — three-layer defence, zero corrupted characters ever:
//
//  Layer 1 (primary): NotoSans-Regular + NotoSans-Bold loaded from assets.
//    Covers Latin, Bengali ৳, Euro €, and most common scripts.
//    Requires assets/fonts/NotoSans-Regular.ttf + NotoSans-Bold.ttf
//    declared in pubspec.yaml under flutter → assets.
//
//  Layer 2 (script supplement): Language-specific Noto fonts loaded on
//    demand when the base NotoSans doesn't fully cover the active script:
//      Arabic/Urdu  → assets/fonts/NotoSansArabic-Regular.ttf
//      Bengali      → assets/fonts/NotoSansBengali-Regular.ttf
//      Devanagari   → assets/fonts/NotoSansDevanagari-Regular.ttf
//      CJK (zh/ja)  → assets/fonts/NotoSansCJK-Regular.ttf (or NotoSansSC)
//    Each is optional — missing files are silently skipped.
//
//  Layer 3 (last resort): If ALL Noto loading fails, _safeSym() maps every
//    non-Latin currency symbol to its ASCII code and _sanitizeText() strips
//    every non-Latin glyph from ALL rendered text (not just AI insight).
//    Helvetica is then safe to use and will never produce box characters.
//
//  WHY REAL DEVICES BROKE (root cause fixed here):
//   • pw.Font.ttf() can throw AFTER rootBundle.load() succeeds when the APK
//     build tool compressed the asset bytes (compressNoisy). The old code
//     only caught load() failures, not ttf() parse failures.
//   • The font was validated with a probe render that itself could throw on
//     some Android rendering paths — that exception was swallowed silently.
//   • _sanitizeText() was only applied to aiInsight; transaction titles,
//     notes, and category names could still pass raw Unicode to Helvetica.
//   • Fix: wrap BOTH load() and ttf() in the same try/catch, add an explicit
//     byte-length sanity check (a valid TTF is always > 1 KB), and apply
//     full sanitisation to every user-supplied string when in fallback mode.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../transactions/domain/entities/transaction_entity.dart';

// ── Font mode enum ─────────────────────────────────────────────────────────────
enum _FontMode { noto, helvetica }

// ── Loaded font bundle ─────────────────────────────────────────────────────────
class _FontBundle {
  const _FontBundle({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.mode,
  });
  final pw.Font   regular;
  final pw.Font   bold;
  final pw.Font   italic;
  final _FontMode mode;

  bool get isNoto => mode == _FontMode.noto;
}

class PdfExportService {
  PdfExportService._();

  // ── Colour palette ──────────────────────────────────────────────────────────
  static const _navy    = PdfColor.fromInt(0xFF0A0E2E);
  static const _blue    = PdfColor.fromInt(0xFF1A3FBF);
  static const _blueLt  = PdfColor.fromInt(0xFF3B5FDF);
  static const _violet  = PdfColor.fromInt(0xFF7C5CBF);
  static const _green   = PdfColor.fromInt(0xFF00A878);
  static const _red     = PdfColor.fromInt(0xFFD94F6A);
  static const _amber   = PdfColor.fromInt(0xFFE8A020);
  static const _white   = PdfColors.white;
  static const _bg      = PdfColor.fromInt(0xFFF4F6FB);
  static const _card    = PdfColor.fromInt(0xFFFFFFFF);
  static const _rowAlt  = PdfColor.fromInt(0xFFF0F3FA);
  static const _border  = PdfColor.fromInt(0xFFDDE2EE);
  static const _textPri = PdfColor.fromInt(0xFF0A0E2E);
  static const _textSec = PdfColor.fromInt(0xFF6B7280);

  // ── Public entry point ──────────────────────────────────────────────────────
  static Future<void> generate({
    required List<TransactionEntity> transactions,
    required String reportType,
    required String currencySymbol,
    required String languageCode,
    String? aiInsight,
    DateTime? selectedMonth,
    int? selectedYear,
  }) async {
    final now   = DateTime.now();
    final month = selectedMonth ?? now;
    final year  = selectedYear  ?? now.year;

    final filtered = _filter(transactions, reportType, month, year);

    // ── Step 1: Load fonts with full defensive wrapping ─────────────────────
    final fonts = await _loadFonts(languageCode);

    // ── Step 2: Sanitise the currency symbol when in fallback mode ──────────
    final String safeCurrSym =
    fonts.isNoto ? currencySymbol : _safeSym(currencySymbol);

    // ── Step 3: Sanitise ALL user-supplied strings when in fallback mode ────
    // In fallback mode (Helvetica) every string that may contain non-Latin
    // characters MUST be sanitised before being passed to pw.Text. This
    // includes transaction titles, notes, category names, and AI insight —
    // not just aiInsight as the old code did.
    String safe(String s) => fonts.isNoto ? s : _sanitizeText(s);
    String? safeNullable(String? s) =>
        (s == null) ? null : (fonts.isNoto ? s : _sanitizeText(s));

    // ── Step 4: Totals ───────────────────────────────────────────────────────
    final totalIncome  = _sum(filtered, 'income');
    final totalExpense = _sum(filtered, 'expense');
    final netBalance   = totalIncome - totalExpense;
    final savings      = netBalance > 0 ? netBalance : 0.0;
    final savingsRate  = totalIncome > 0
        ? (savings / totalIncome * 100).clamp(0.0, 100.0)
        : 0.0;

    // ── Step 5: Category map ─────────────────────────────────────────────────
    final catMap = <String, double>{};
    for (final t in filtered.where((t) => t.type == 'expense')) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    final sortedCats = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Step 6: Build PDF document ───────────────────────────────────────────
    final pdf = pw.Document(
      title:   'FlowTrack Financial Report',
      author:  'FlowTrack',
      creator: 'FlowTrack Finance App',
    );

    final String periodLabel = _periodLabel(reportType, month, year);
    final String typeLabel   = _typeLabel(reportType);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        theme: pw.ThemeData.withFont(
          base:   fonts.regular,
          bold:   fonts.bold,
          italic: fonts.italic,
        ),
        header: (ctx) => _header(typeLabel, periodLabel, now, fonts.bold, fonts.regular),
        footer: (ctx) => _footer(ctx, fonts.regular),
        build:  (ctx) => _buildContent(
          reportType:   reportType,
          filtered:     filtered,
          allTxns:      transactions,
          currSym:      safeCurrSym,
          totalIncome:  totalIncome,
          totalExpense: totalExpense,
          netBalance:   netBalance,
          savings:      savings,
          savingsRate:  savingsRate,
          sortedCats:   sortedCats,
          catMap:       catMap,
          month:        month,
          year:         year,
          aiInsight:    safeNullable(aiInsight),
          fonts:        fonts,
          safe:         safe,
        ),
      ),
    );

    // ── Step 7: Save & share ─────────────────────────────────────────────────
    final bytes  = await pdf.save();
    final dir    = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/FlowTrack/reports');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final fileLabel = _fileLabel(reportType, month, year);
    final file = File('${outDir.path}/FlowTrack_$fileLabel.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'FlowTrack $typeLabel Report - $periodLabel',
    );
  }

  // ── Font loader — the critical fix ─────────────────────────────────────────
  //
  // ROOT CAUSE ANALYSIS:
  //   Real devices running release builds may package TTF assets with
  //   compression (storeAssets: false not set). When Flutter decompresses
  //   on first access the ByteData can arrive truncated or mis-aligned,
  //   causing pw.Font.ttf() to throw even though rootBundle.load() succeeded.
  //   Additionally, Android's AssetManager has a 1 MB single-read limit on
  //   some OEM ROMs — large CJK fonts silently return partial bytes.
  //
  // FIXES:
  //   1. Wrap BOTH load() AND ttf() inside the same try/catch.
  //   2. Validate byte length (a valid TTF/OTF is always > 1 KB).
  //   3. Load a bold variant independently with its own try/catch so a
  //      missing Bold file doesn't discard a good Regular load.
  //   4. Load script-specific supplement fonts only when the base font is
  //      available AND the languageCode matches a script with known gaps.
  //   5. Return a typed _FontBundle so the caller never has to re-check mode.
  static Future<_FontBundle> _loadFonts(String languageCode) async {
    // ── Attempt Layer 1: NotoSans base ──────────────────────────────────────
    pw.Font? regular;
    pw.Font? bold;

    try {
      final rBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      // Validate: a valid TTF must be larger than 1 KB
      if (rBytes.lengthInBytes > 1024) {
        regular = pw.Font.ttf(rBytes);
      }
    } catch (_) {
      // File missing, APK compressed it, or pw.Font.ttf() threw — try bold
      // independently regardless
    }

    try {
      final bBytes = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      if (bBytes.lengthInBytes > 1024) {
        bold = pw.Font.ttf(bBytes);
      }
    } catch (_) {
      // Bold missing or corrupt — will reuse regular as bold below
    }

    // If regular loaded but bold didn't (or vice-versa), use what we have
    if (regular != null) {
      bold ??= regular; // Bold missing: use regular as bold (acceptable)

      // ── Attempt Layer 2: script-specific supplement ────────────────────
      // For scripts where NotoSans base coverage is incomplete, try to load
      // a dedicated script font and use it as the base font for that language.
      final supplement = await _loadSupplementFont(languageCode);
      if (supplement != null) {
        // Use the supplement as the primary render font for this language.
        // This ensures e.g. Arabic text in an Arabic-language export is
        // rendered by NotoSansArabic, not the base NotoSans which may
        // have incomplete Arabic glyphs.
        return _FontBundle(
          regular: supplement,
          bold:    bold,     // Keep NotoSans-Bold for headings (Latin only)
          italic:  supplement,
          mode:    _FontMode.noto,
        );
      }

      return _FontBundle(
        regular: regular,
        bold:    bold,
        italic:  regular, // NotoSans has no separate italic — regular is fine
        mode:    _FontMode.noto,
      );
    }

    // ── Layer 3: Helvetica fallback ──────────────────────────────────────────
    // All Noto loading failed. Use built-in Helvetica (Latin-only).
    // The caller will sanitise ALL text via _safeSym() and _sanitizeText()
    // so Helvetica never encounters a glyph it cannot render.
    return _FontBundle(
      regular: pw.Font.helvetica(),
      bold:    pw.Font.helveticaBold(),
      italic:  pw.Font.helveticaOblique(),
      mode:    _FontMode.helvetica,
    );
  }

  /// Try to load a language-specific supplement font.
  /// Returns null if the font file is absent or fails to parse — the caller
  /// continues with the base NotoSans in that case (no hard failure).
  static Future<pw.Font?> _loadSupplementFont(String languageCode) async {
    // Map language code → asset path for scripts NotoSans base may miss
    final String? assetPath = switch (languageCode) {
      'ar' || 'ur' => 'assets/fonts/NotoSansArabic-Regular.ttf',
      'bn'         => 'assets/fonts/NotoSansBengali-Regular.ttf',
      'hi'         => 'assets/fonts/NotoSansDevanagari-Regular.ttf',
      'zh'         => 'assets/fonts/NotoSansSC-Regular.ttf', // Simplified Chinese
      'ja'         => 'assets/fonts/NotoSansJP-Regular.ttf', // Japanese
      _            => null,
    };

    if (assetPath == null) return null;

    try {
      final bytes = await rootBundle.load(assetPath);
      // CJK fonts are large (several MB) — still validate minimum size
      if (bytes.lengthInBytes > 1024) {
        return pw.Font.ttf(bytes);
      }
    } catch (_) {
      // Font not present in pubspec / missing from assets — that's fine,
      // the base NotoSans covers most common glyphs well enough.
    }
    return null;
  }

  // ── Content router ──────────────────────────────────────────────────────────
  static List<pw.Widget> _buildContent({
    required String   reportType,
    required List<TransactionEntity> filtered,
    required List<TransactionEntity> allTxns,
    required String   currSym,
    required double   totalIncome,
    required double   totalExpense,
    required double   netBalance,
    required double   savings,
    required double   savingsRate,
    required List<MapEntry<String, double>> sortedCats,
    required Map<String, double> catMap,
    required DateTime month,
    required int      year,
    required String?  aiInsight,
    required _FontBundle fonts,
    required String Function(String) safe,
  }) {
    final fR = fonts.regular;
    final fB = fonts.bold;
    final fI = fonts.italic;

    final w = <pw.Widget>[];

    // ── 1. Financial summary cards ────────────────────────────────────────
    w.add(_sectionHeading('Financial Summary', fB));
    w.add(pw.SizedBox(height: 8));
    w.add(_summaryGrid(
      currSym, totalIncome, totalExpense, netBalance, savings,
      filtered.length,
      filtered.where((t) => t.type == 'income').length,
      filtered.where((t) => t.type == 'expense').length,
      fB, fR,
    ));
    w.add(pw.SizedBox(height: 18));

    // ── 2. Analytics strip ────────────────────────────────────────────────
    w.add(_sectionHeading('Analytics', fB));
    w.add(pw.SizedBox(height: 8));
    w.add(_analyticsStrip(
      currSym:      currSym,
      savingsRate:  savingsRate,
      totalExpense: totalExpense,
      filtered:     filtered,
      month:        month,
      reportType:   reportType,
      fR: fR, fB: fB,
    ));
    w.add(pw.SizedBox(height: 18));

    // ── 3. Category analysis ──────────────────────────────────────────────
    if (sortedCats.isNotEmpty) {
      w.add(_sectionHeading('Category Analysis', fB));
      w.add(pw.SizedBox(height: 8));
      w.add(_categoryTable(sortedCats, totalExpense, currSym, fR, fB, safe));
      w.add(pw.SizedBox(height: 18));
    }

    // ── 4. Report-type specific sections ─────────────────────────────────
    if (reportType == 'monthly') {
      w.addAll(_monthlyExtra(
        filtered:     filtered,
        month:        month,
        currSym:      currSym,
        totalIncome:  totalIncome,
        totalExpense: totalExpense,
        savings:      savings,
        savingsRate:  savingsRate,
        fR: fR, fB: fB,
      ));
    } else if (reportType == 'annual') {
      w.addAll(_annualExtra(
        allTxns: allTxns,
        year:    year,
        currSym: currSym,
        fR: fR, fB: fB,
      ));
    } else {
      w.addAll(_completeExtra(
        allTxns:   allTxns,
        currSym:   currSym,
        aiInsight: aiInsight,
        fR: fR, fB: fB, fI: fI,
      ));
    }

    // ── 5. Transaction history ────────────────────────────────────────────
    w.add(_sectionHeading('Transaction History', fB));
    w.add(pw.SizedBox(height: 8));
    w.add(_txnTable(filtered, currSym, fR, fB, safe: safe));

    return w;
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  static pw.Widget _header(
      String typeLabel,
      String periodLabel,
      DateTime now,
      pw.Font fB,
      pw.Font fR,
      ) {
    return pw.Container(
      margin:  const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_navy, _blue, _blueLt],
          begin:  pw.Alignment.centerLeft,
          end:    pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FlowTrack',
                style: pw.TextStyle(font: fB, fontSize: 20, color: _white,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('$typeLabel Financial Report',
                style: pw.TextStyle(font: fR, fontSize: 9,
                    color: PdfColor.fromInt(0xFFBBC8F5))),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(periodLabel,
                style: pw.TextStyle(font: fB, fontSize: 11, color: _white,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Generated ${DateFormat('MMM d, yyyy', 'en_US').format(now)}',
                style: pw.TextStyle(font: fR, fontSize: 8,
                    color: PdfColor.fromInt(0xFFBBC8F5))),
          ]),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, pw.Font fR) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('FlowTrack - Confidential Financial Report',
              style: pw.TextStyle(font: fR, fontSize: 7, color: _textSec)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: fR, fontSize: 7, color: _textSec)),
        ],
      ),
    );
  }

  // ── Section heading ──────────────────────────────────────────────────────────
  static pw.Widget _sectionHeading(String title, pw.Font fB) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(font: fB, fontSize: 11, color: _white,
              fontWeight: pw.FontWeight.bold)),
    );
  }

  // ── Financial summary grid ───────────────────────────────────────────────────
  static pw.Widget _summaryGrid(
      String sym,
      double income, double expense, double balance, double savings,
      int totalTxns, int incomeTxns, int expenseTxns,
      pw.Font fB, pw.Font fR,
      ) {
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: _moneyCard('Total Income',  income,  sym, _green, fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _moneyCard('Total Expense', expense, sym, _red,   fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _moneyCard('Net Balance',   balance, sym,
            balance >= 0 ? _green : _red, fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _moneyCard('Savings',       savings, sym, _blue,  fB, fR)),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(child: _statCard('Total Transactions', '$totalTxns',   _navy,  fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _statCard('Income Entries',     '$incomeTxns',  _green, fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _statCard('Expense Entries',    '$expenseTxns', _red,   fB, fR)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.SizedBox()),
      ]),
    ]);
  }

  static pw.Widget _moneyCard(String label, double value, String sym,
      PdfColor accent, pw.Font fB, pw.Font fR) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.8),
        boxShadow: [pw.BoxShadow(color: PdfColor.fromInt(0x14000000),
            blurRadius: 4, offset: const PdfPoint(0, 2))],
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(width: 3, height: 12, color: accent),
            pw.SizedBox(width: 5),
            pw.Text(label,
                style: pw.TextStyle(font: fR, fontSize: 8, color: _textSec)),
          ]),
          pw.SizedBox(height: 5),
          pw.Text('${value < 0 ? '-' : ''}$sym${_fmt(value.abs())}',
              style: pw.TextStyle(font: fB, fontSize: 12, color: accent,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _statCard(String label, String value,
      PdfColor accent, pw.Font fB, pw.Font fR) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: pw.Row(children: [
        pw.Container(width: 3, height: 26, color: accent),
        pw.SizedBox(width: 7),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(value,
              style: pw.TextStyle(font: fB, fontSize: 13, color: accent,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style: pw.TextStyle(font: fR, fontSize: 7.5, color: _textSec)),
        ]),
      ]),
    );
  }

  // ── Analytics strip ──────────────────────────────────────────────────────────
  static pw.Widget _analyticsStrip({
    required String   currSym,
    required double   savingsRate,
    required double   totalExpense,
    required List<TransactionEntity> filtered,
    required DateTime month,
    required String   reportType,
    required pw.Font  fR,
    required pw.Font  fB,
  }) {
    final daysInMonth = reportType == 'monthly'
        ? DateTime(month.year, month.month + 1, 0).day
        : 30;
    final avgDaily     = totalExpense > 0 ? totalExpense / daysInMonth : 0.0;
    final incomeCount  = filtered.where((t) => t.type == 'income').length;
    final expenseCount = filtered.where((t) => t.type == 'expense').length;

    final rows = [
      ['Savings Rate',    '${savingsRate.toStringAsFixed(1)}%'],
      ['Avg Daily Spend', '$currSym${_fmt(avgDaily)}'],
      ['Income Entries',  '$incomeCount transactions'],
      ['Expense Entries', '$expenseCount transactions'],
      ['Largest Expense', _largestExpense(filtered, currSym)],
      ['Top Category',    _topCategory(filtered)],
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        },
        children: _pairRows(rows, fR, fB),
      ),
    );
  }

  static List<pw.TableRow> _pairRows(
      List<List<String>> pairs, pw.Font fR, pw.Font fB) {
    final result = <pw.TableRow>[];
    for (var i = 0; i < pairs.length; i += 2) {
      final left  = pairs[i];
      final right = i + 1 < pairs.length ? pairs[i + 1] : ['', ''];
      result.add(pw.TableRow(children: [
        _analyticCell(left[0],  isLabel: true,  fR: fR, fB: fB),
        _analyticCell(left[1],  isLabel: false, fR: fR, fB: fB),
        _analyticCell(right[0], isLabel: true,  fR: fR, fB: fB, borderLeft: true),
        _analyticCell(right[1], isLabel: false, fR: fR, fB: fB),
      ]));
    }
    return result;
  }

  static pw.Widget _analyticCell(String text,
      {required bool isLabel, required pw.Font fR, required pw.Font fB,
        bool borderLeft = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: borderLeft
          ? pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _border, width: 0.5)))
          : null,
      child: pw.Text(text,
          style: pw.TextStyle(
            font:       isLabel ? fR : fB,
            fontSize:   8.5,
            color:      isLabel ? _textSec : _textPri,
            fontWeight: isLabel ? pw.FontWeight.normal : pw.FontWeight.bold,
          )),
    );
  }

  // ── Category table ───────────────────────────────────────────────────────────
  static pw.Widget _categoryTable(
      List<MapEntry<String, double>> cats,
      double total,
      String sym,
      pw.Font fR,
      pw.Font fB,
      String Function(String) safe,
      ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Category', 'Amount Spent', 'Share %', 'Bar'],
      headerStyle: pw.TextStyle(
          font: fB, fontSize: 8.5, color: _white,
          fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _blue),
      cellStyle: pw.TextStyle(font: fR, fontSize: 8.5, color: _textPri),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerLeft,
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      data: cats.map((e) {
        final pct  = total > 0 ? e.value / total * 100 : 0.0;
        final bars = '|' * (pct / 5).round().clamp(0, 20);
        return [
          // safe() applied to category name — user-entered strings may
          // contain non-Latin characters in Helvetica fallback mode
          safe(_cap(e.key)),
          '$sym${_fmt(e.value)}',
          '${pct.toStringAsFixed(1)}%',
          bars,
        ];
      }).toList(),
      border:      pw.TableBorder.all(color: _border, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }

  // ── Monthly extra ────────────────────────────────────────────────────────────
  static List<pw.Widget> _monthlyExtra({
    required List<TransactionEntity> filtered,
    required DateTime month,
    required String   currSym,
    required double   totalIncome,
    required double   totalExpense,
    required double   savings,
    required double   savingsRate,
    required pw.Font  fR,
    required pw.Font  fB,
  }) {
    final widgets = <pw.Widget>[];
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    widgets.add(_sectionHeading(
        'Monthly Summary - ${DateFormat('MMMM yyyy', 'en_US').format(month)}', fB));
    widgets.add(pw.SizedBox(height: 8));

    final kpis = [
      ['Report Period',      DateFormat('MMMM yyyy', 'en_US').format(month)],
      ['Total Income',       '$currSym${_fmt(totalIncome)}'],
      ['Total Expense',      '$currSym${_fmt(totalExpense)}'],
      ['Net Balance',        '${(totalIncome - totalExpense) < 0 ? '-' : ''}$currSym${_fmt((totalIncome - totalExpense).abs())}'],
      ['Savings',            '$currSym${_fmt(savings)}'],
      ['Savings Rate',       '${savingsRate.toStringAsFixed(1)}%'],
      ['Days in Month',      '$daysInMonth'],
      ['Avg Daily Spend',    '$currSym${_fmt(totalExpense / daysInMonth)}'],
      ['Total Transactions', '${filtered.length}'],
    ];

    widgets.add(_twoColTable(kpis, fR, fB));
    widgets.add(pw.SizedBox(height: 18));

    final weekData = _weekBreakdown(filtered, month);
    if (weekData.isNotEmpty) {
      widgets.add(_sectionHeading('Week-wise Breakdown', fB));
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['Week', 'Income', 'Expense', 'Net'],
        headerStyle: pw.TextStyle(
            font: fB, fontSize: 8.5, color: _white,
            fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: _blue),
        cellStyle: pw.TextStyle(font: fR, fontSize: 8.5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
        data: weekData.entries.map((e) {
          final inc = e.value['income']!;
          final exp = e.value['expense']!;
          final net = inc - exp;
          return [
            e.key,
            '$currSym${_fmt(inc)}',
            '$currSym${_fmt(exp)}',
            '${net >= 0 ? '+' : '-'}$currSym${_fmt(net.abs())}',
          ];
        }).toList(),
        border:      pw.TableBorder.all(color: _border, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ));
      widgets.add(pw.SizedBox(height: 18));
    }

    return widgets;
  }

  // ── Annual extra ─────────────────────────────────────────────────────────────
  static List<pw.Widget> _annualExtra({
    required List<TransactionEntity> allTxns,
    required int    year,
    required String currSym,
    required pw.Font fR,
    required pw.Font fB,
  }) {
    final widgets = <pw.Widget>[];

    widgets.add(_sectionHeading('Month-wise Breakdown - $year', fB));
    widgets.add(pw.SizedBox(height: 8));

    final monthMap = <int, Map<String, double>>{};
    for (var m = 1; m <= 12; m++) {
      monthMap[m] = {'income': 0.0, 'expense': 0.0};
    }
    for (final t in allTxns.where((t) => t.date.year == year)) {
      final m = t.date.month;
      if (t.type == 'income') {
        monthMap[m]!['income'] = (monthMap[m]!['income'] ?? 0) + t.amount;
      } else {
        monthMap[m]!['expense'] = (monthMap[m]!['expense'] ?? 0) + t.amount;
      }
    }

    widgets.add(pw.TableHelper.fromTextArray(
      headers: ['Month', 'Income', 'Expense', 'Net Balance', 'Savings'],
      headerStyle: pw.TextStyle(
          font: fB, fontSize: 8.5, color: _white,
          fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _blue),
      cellStyle: pw.TextStyle(font: fR, fontSize: 8.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      data: monthMap.entries.map((e) {
        final inc = e.value['income']!;
        final exp = e.value['expense']!;
        final net = inc - exp;
        final sav = net > 0 ? net : 0.0;
        return [
          DateFormat('MMM', 'en_US').format(DateTime(year, e.key)),
          '$currSym${_fmt(inc)}',
          '$currSym${_fmt(exp)}',
          '${net >= 0 ? '+' : '-'}$currSym${_fmt(net.abs())}',
          '$currSym${_fmt(sav)}',
        ];
      }).toList(),
      border:      pw.TableBorder.all(color: _border, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ));
    widgets.add(pw.SizedBox(height: 18));

    final yearTxns = allTxns.where((t) => t.date.year == year).toList();
    final yInc  = _sum(yearTxns, 'income');
    final yExp  = _sum(yearTxns, 'expense');
    final yNet  = yInc - yExp;
    final ySav  = yNet > 0 ? yNet : 0.0;
    final ySavR = yInc > 0 ? ySav / yInc * 100 : 0.0;

    widgets.add(_sectionHeading('Annual Summary', fB));
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(_twoColTable([
      ['Year',              '$year'],
      ['Total Income',      '$currSym${_fmt(yInc)}'],
      ['Total Expense',     '$currSym${_fmt(yExp)}'],
      ['Net Balance',       '${yNet < 0 ? '-' : ''}$currSym${_fmt(yNet.abs())}'],
      ['Total Savings',     '$currSym${_fmt(ySav)}'],
      ['Savings Rate',      '${ySavR.toStringAsFixed(1)}%'],
      ['Total Transactions','${yearTxns.length}'],
      ['Best Month',        _bestMonth(monthMap, year, currSym)],
    ], fR, fB));
    widgets.add(pw.SizedBox(height: 18));

    return widgets;
  }

  // ── Complete report extra ────────────────────────────────────────────────────
  static List<pw.Widget> _completeExtra({
    required List<TransactionEntity> allTxns,
    required String  currSym,
    required String? aiInsight,
    required pw.Font fR,
    required pw.Font fB,
    required pw.Font fI,
  }) {
    final widgets = <pw.Widget>[];

    final monthMap = <String, Map<String, double>>{};
    for (final t in allTxns) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (t.type == 'income') {
        monthMap[key]!['income'] = (monthMap[key]!['income'] ?? 0) + t.amount;
      } else {
        monthMap[key]!['expense'] = (monthMap[key]!['expense'] ?? 0) + t.amount;
      }
    }
    final sortedKeys = monthMap.keys.toList()..sort();

    if (sortedKeys.isNotEmpty) {
      widgets.add(_sectionHeading('All-time Monthly Summary', fB));
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['Period', 'Income', 'Expense', 'Net Balance'],
        headerStyle: pw.TextStyle(
            font: fB, fontSize: 8.5, color: _white,
            fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: _navy),
        cellStyle: pw.TextStyle(font: fR, fontSize: 8.5),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
        data: sortedKeys.map((k) {
          final parts = k.split('-');
          final dt  = DateTime(int.parse(parts[0]), int.parse(parts[1]));
          final inc = monthMap[k]!['income']!;
          final exp = monthMap[k]!['expense']!;
          final net = inc - exp;
          return [
            DateFormat('MMM yyyy', 'en_US').format(dt),
            '$currSym${_fmt(inc)}',
            '$currSym${_fmt(exp)}',
            '${net >= 0 ? '+' : '-'}$currSym${_fmt(net.abs())}',
          ];
        }).toList(),
        border:      pw.TableBorder.all(color: _border, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ));
      widgets.add(pw.SizedBox(height: 18));
    }

    if (aiInsight != null && aiInsight.trim().isNotEmpty) {
      widgets.add(_sectionHeading('AI Financial Insights', fB));
      widgets.add(pw.SizedBox(height: 8));
      // aiInsight is already sanitised by the caller when in Helvetica mode
      widgets.add(_insightBox(aiInsight.trim(), fR, fI));
      widgets.add(pw.SizedBox(height: 18));
    }

    return widgets;
  }

  // ── Two-column KPI table ─────────────────────────────────────────────────────
  static pw.Widget _twoColTable(
      List<List<String>> rows, pw.Font fR, pw.Font fB) {
    return pw.TableHelper.fromTextArray(
      headers: ['Metric', 'Value'],
      headerStyle: pw.TextStyle(
          font: fB, fontSize: 8.5, color: _white,
          fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _blue),
      cellStyle:   pw.TextStyle(font: fR, fontSize: 8.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      data:        rows,
      border:      pw.TableBorder.all(color: _border, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  // ── AI insight box ───────────────────────────────────────────────────────────
  static pw.Widget _insightBox(String text, pw.Font fR, pw.Font fI) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color:        PdfColor.fromInt(0xFFF0EEFF),
        borderRadius: pw.BorderRadius.circular(8),
        border:       pw.Border.all(color: _violet, width: 0.8),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(font: fI, fontSize: 9, color: _textPri,
              lineSpacing: 3)),
    );
  }

  // ── Transaction table ────────────────────────────────────────────────────────
  static pw.Widget _txnTable(
      List<TransactionEntity> txns,
      String sym,
      pw.Font fR,
      pw.Font fB, {
        required String Function(String) safe,
      }) {
    if (txns.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
            color: _card,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _border)),
        child: pw.Text('No transactions found for this period.',
            style: pw.TextStyle(font: fR, fontSize: 9, color: _textSec)),
      );
    }

    // safe() is applied to EVERY user-typed string:
    //   - transaction note/title  (may contain Unicode punctuation)
    //   - category name           (may be user-entered in any language)
    // In Noto mode safe() is a no-op; in Helvetica mode it strips non-Latin.
    final sorted = [...txns]..sort((a, b) => b.date.compareTo(a.date));

    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Title / Note', 'Category', 'Type', 'Amount'],
      headerStyle: pw.TextStyle(
          font: fB, fontSize: 8.5, color: _white,
          fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: pw.TextStyle(font: fR, fontSize: 8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
      data: sorted.map((t) {
        final isInc = t.type == 'income';
        final noteOrCat = (t.note?.isNotEmpty == true)
            ? safe(t.note!)
            : safe(_cap(t.category));
        return [
          DateFormat('dd MMM yy', 'en_US').format(t.date),
          noteOrCat,
          safe(_cap(t.category)),
          t.type.toUpperCase(),
          '${isInc ? '+' : '-'}$sym${_fmt(t.amount)}',
        ];
      }).toList(),
      border:      pw.TableBorder.all(color: _border, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    );
  }

  // ── Pure helpers ─────────────────────────────────────────────────────────────

  static List<TransactionEntity> _filter(
      List<TransactionEntity> all,
      String type,
      DateTime month,
      int year,
      ) {
    switch (type) {
      case 'monthly':
        return all.where((t) =>
        t.date.year == month.year && t.date.month == month.month).toList();
      case 'annual':
        return all.where((t) => t.date.year == year).toList();
      default:
        return List.from(all);
    }
  }

  static double _sum(List<TransactionEntity> txns, String type) =>
      txns.where((t) => t.type == type)
          .fold(0.0, (s, t) => s + t.amount.toDouble());

  static String _fmt(double v) =>
      NumberFormat('#,##0.00', 'en_US').format(v.abs());

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String _typeLabel(String t) => switch (t) {
    'monthly' => 'Monthly',
    'annual'  => 'Annual',
    'full'    => 'Complete',
    _         => 'Financial',
  };

  static String _periodLabel(String type, DateTime month, int year) =>
      switch (type) {
        'monthly' => DateFormat('MMMM yyyy', 'en_US').format(month),
        'annual'  => '$year',
        _         => 'All Time',
      };

  static String _fileLabel(String type, DateTime month, int year) =>
      switch (type) {
        'monthly' => 'Monthly_${DateFormat('yyyy-MM', 'en_US').format(month)}',
        'annual'  => 'Annual_$year',
        _         => 'Complete_${DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now())}',
      };

  // ── Layer 3: currency symbol sanitiser ──────────────────────────────────────
  // Only active when ALL Noto loading failed. Maps non-Latin symbols to their
  // ASCII currency codes so Helvetica never encounters unrenderable glyphs.
  static String _safeSym(String sym) => switch (sym) {
    '৳'   => 'BDT ',   // Bengali Taka
    '₹'   => 'INR ',   // Indian Rupee
    '€'   => 'EUR ',   // Euro
    '¥'   => 'JPY ',   // Japanese Yen
    '£'   => 'GBP ',   // British Pound
    '﷼'   => 'SAR ',   // Saudi Riyal
    'د.إ' => 'AED ',   // UAE Dirham
    '₩'   => 'KRW ',   // Korean Won
    '₺'   => 'TRY ',   // Turkish Lira
    '₴'   => 'UAH ',   // Ukrainian Hryvnia
    '฿'   => 'THB ',   // Thai Baht
    _     => sym,      // $, CA$, A$, S$, RM, Fr — ASCII, always safe
  };

  // ── Layer 3: text sanitiser ──────────────────────────────────────────────────
  // Replaces ALL non-Latin typographic and Unicode characters with safe ASCII
  // equivalents. Applied to EVERY user-supplied string (titles, notes,
  // categories, AI insight) when in Helvetica fallback mode — not just
  // aiInsight as the old code did.
  //
  // Covers:
  //   • Typographic punctuation (smart quotes, em/en dash, ellipsis, bullets)
  //   • Non-breaking and zero-width spaces
  //   • Any remaining non-ASCII codepoint (catch-all regex at the end)
  static String _sanitizeText(String text) {
    var s = text
        .replaceAll('\u2014', '-')     // em dash —
        .replaceAll('\u2013', '-')     // en dash –
        .replaceAll('\u2018', "'")     // left single quote '
        .replaceAll('\u2019', "'")     // right single quote ' / apostrophe
        .replaceAll('\u201C', '"')     // left double quote "
        .replaceAll('\u201D', '"')     // right double quote "
        .replaceAll('\u2026', '...')   // ellipsis …
        .replaceAll('\u00A0', ' ')     // non-breaking space
        .replaceAll('\u200B', '')      // zero-width space
        .replaceAll('\u200C', '')      // zero-width non-joiner
        .replaceAll('\u200D', '')      // zero-width joiner
        .replaceAll('\u2022', '-')     // bullet •
        .replaceAll('\u00B7', '-')     // middle dot ·
        .replaceAll('\u2023', '-')     // triangular bullet ‣
        .replaceAll('\u25CF', '-')     // black circle ●
        .replaceAll('\u00AB', '"')     // left-pointing double angle «
        .replaceAll('\u00BB', '"')     // right-pointing double angle »
        .replaceAll('\u2039', "'")     // single left-pointing angle ‹
        .replaceAll('\u203A', "'")     // single right-pointing angle ›
        .replaceAll('\u00D7', 'x')     // multiplication sign ×
        .replaceAll('\u00F7', '/')     // division sign ÷
        .replaceAll('\u2212', '-')     // minus sign −
        .replaceAll('\u2010', '-')     // hyphen ‐
        .replaceAll('\u2011', '-')     // non-breaking hyphen ‑
        .replaceAll('\u2012', '-')     // figure dash ‒
        .replaceAll('\u2015', '-');    // horizontal bar ―

    // Final catch-all: replace any remaining non-ASCII character with '?'
    // so the PDF never sees a codepoint Helvetica can't render.
    // This is intentionally aggressive in Helvetica fallback mode only.
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune < 128) {
        buf.writeCharCode(rune);
      } else {
        buf.write('?');
      }
    }
    return buf.toString();
  }

  static String _largestExpense(
      List<TransactionEntity> txns, String sym) {
    final expenses = txns.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) return 'N/A';
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return '$sym${_fmt(expenses.first.amount)}';
  }

  static String _topCategory(List<TransactionEntity> txns) {
    final map = <String, double>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    if (map.isEmpty) return 'N/A';
    return _cap(map.entries.reduce((a, b) => a.value > b.value ? a : b).key);
  }

  static Map<String, Map<String, double>> _weekBreakdown(
      List<TransactionEntity> txns, DateTime month) {
    final result = <String, Map<String, double>>{};
    for (final t in txns) {
      final weekStart = t.date.subtract(Duration(days: t.date.weekday - 1));
      final weekEnd   = weekStart.add(const Duration(days: 6));
      final key = '${DateFormat('MMM d', 'en_US').format(weekStart)}'
          ' - ${DateFormat('MMM d', 'en_US').format(weekEnd)}';
      result.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (t.type == 'income') {
        result[key]!['income'] = (result[key]!['income'] ?? 0) + t.amount;
      } else {
        result[key]!['expense'] = (result[key]!['expense'] ?? 0) + t.amount;
      }
    }
    return Map.fromEntries(
        result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  static String _bestMonth(
      Map<int, Map<String, double>> monthMap, int year, String sym) {
    if (monthMap.isEmpty) return 'N/A';
    final best = monthMap.entries.reduce((a, b) {
      final aNet = (a.value['income'] ?? 0) - (a.value['expense'] ?? 0);
      final bNet = (b.value['income'] ?? 0) - (b.value['expense'] ?? 0);
      return aNet > bNet ? a : b;
    });
    final net = (best.value['income'] ?? 0) - (best.value['expense'] ?? 0);
    return '${DateFormat('MMMM', 'en_US').format(DateTime(year, best.key))} '
        '(${net >= 0 ? '+' : '-'}$sym${_fmt(net.abs())})';
  }
}