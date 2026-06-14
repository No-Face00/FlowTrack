import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'finance_snapshot.dart';
import 'local_finance_brain.dart';

/// Optional Gemini Flash pass — fails silently; caller keeps local insight.
class GeminiFinanceClient {
  GeminiFinanceClient._();

  static const _model = 'gemini-1.5-flash';

  static Future<AssistantInsight?> tryGenerate(
    FinanceSnapshot snapshot,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) return null;

    final model = GenerativeModel(
      model: _model,
      apiKey: apiKey,
    );

    final prompt = StringBuffer()
      ..writeln(
          'You are Flow Advisor, a premium finance copilot. Output plain text only.')
      ..writeln('Rules:')
      ..writeln(
          '1) Line 1: one headline insight, max 130 characters, no quotes, no emojis.')
      ..writeln(
          '2) Then up to 3 more lines; each starts with "• " and is max 110 characters.')
      ..writeln('3) Reference specific numbers or categories from the JSON.')
      ..writeln('4) Be supportive, concise, and actionable.')
      ..writeln()
      ..writeln(jsonEncode(snapshot.toGeminiJson()));

    final resp = await model.generateContent([Content.text(prompt.toString())]);
    final text = resp.text?.trim();
    if (text == null || text.isEmpty) return null;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final headline = lines.first.length > 140
        ? '${lines.first.substring(0, 137)}…'
        : lines.first;
    final bullets = <String>[];
    for (var i = 1; i < lines.length && bullets.length < 3; i++) {
      var line = lines[i];
      if (line.startsWith('•')) line = line.substring(1).trim();
      if (line.startsWith('-')) line = line.substring(1).trim();
      if (line.length > 118) line = '${line.substring(0, 115)}…';
      bullets.add(line);
    }
    return AssistantInsight(headline: headline, bullets: bullets);
  }
}
