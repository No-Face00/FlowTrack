import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  OnboardingSlide  — PUBLIC (was _Slide, couldn't cross files)
// ═══════════════════════════════════════════════════════════════
class OnboardingSlide {
  const OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.particles,
  });

  final String       emoji;
  final String       title;
  final String       subtitle;
  final List<Color>  gradientColors;
  final List<String> particles;
}

// ═══════════════════════════════════════════════════════════════
//  kSlides  — PUBLIC constant list (was _slides, private)
// ═══════════════════════════════════════════════════════════════
const List<OnboardingSlide> kSlides = [
  OnboardingSlide(
    emoji: '💸',
    title: 'Track Every\nPenny',
    subtitle:
    'Effortlessly log income and expenses.\n'
        'Know exactly where your money goes.',
    gradientColors: [AppColors.midnight, AppColors.deepBlue, AppColors.royalBlue],
    particles: ['💳', '🏦', '💰', '📊', '💵', '🪙'],
  ),
  OnboardingSlide(
    emoji: '📊',
    title: 'Smart\nAnalytics',
    subtitle:
    'Beautiful charts and AI-powered insights\n'
        'to understand your spending patterns.',
    gradientColors: [AppColors.deepBlue, Color(0xFF3A00CC), AppColors.violet],
    particles: ['📈', '🎯', '🔍', '✨', '📉', '⚡'],
  ),
  OnboardingSlide(
    emoji: '🤖',
    title: 'AI That\nWorks For You',
    subtitle:
    'Gemini AI auto-categorizes transactions\n'
        'and gives personalized financial advice.',
    gradientColors: [Color(0xFF1A0060), Color(0xFF6B21A8), Color(0xFFC084FC)],
    particles: ['🧠', '⚡', '🌟', '🤖', '💡', '🔮'],
  ),
  OnboardingSlide(
    emoji: '🛡️',
    title: 'Bank-Level\nSecurity',
    subtitle:
    'Biometric lock, end-to-end encryption,\n'
        'and real-time sync across all your devices.',
    gradientColors: [AppColors.midnight, Color(0xFF004D2F), AppColors.income],
    particles: ['🔐', '✅', '🛡️', '📱', '☁️', '🔒'],
  ),
];