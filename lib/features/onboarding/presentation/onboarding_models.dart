import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  OnboardingSlide  — PUBLIC (now with Lottie asset paths)
// ═══════════════════════════════════════════════════════════════
class OnboardingSlide {
  const OnboardingSlide({
    required this.lottieAsset,  // ← Changed from emoji to Lottie asset path
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.particles,
  });

  final String       lottieAsset;  // e.g., 'assets/animations/track_money.json'
  final String       title;
  final String       subtitle;
  final List<Color>  gradientColors;
  final List<String> particles;
}

// ═══════════════════════════════════════════════════════════════
//  kSlides  — PUBLIC constant list (with Lottie paths)
// ═══════════════════════════════════════════════════════════════
const List<OnboardingSlide> kSlides = [
  OnboardingSlide(
    lottieAsset: 'assets/icons/Wallet_animation.json',
    title: 'Track Every\nPenny',
    subtitle:
    'Effortlessly log income and expenses.\n'
        'Know exactly where your money goes.',
    gradientColors: [AppColors.midnight, AppColors.deepBlue, AppColors.royalBlue],
    particles: ['💳', '🏦', '💰', '📊', '💵', '🪙'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/Data_Analysis.json',
    title: 'Smart\nAnalytics',
    subtitle:
    'Beautiful charts and AI-powered insights\n'
        'to understand your spending patterns.',
    gradientColors: [AppColors.deepBlue, Color(0xFF3A00CC), AppColors.violet],
    particles: ['📈', '🎯', '🔍', '✨', '📉', '⚡'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/AI_Assist.json',
    title: 'AI That\nWorks For You',
    subtitle:
    'Gemini AI auto-categorizes transactions\n'
        'and gives personalized financial advice.',
    gradientColors: [Color(0xFF1A0060), Color(0xFF6B21A8), Color(0xFFC084FC)],
    particles: ['🧠', '⚡', '🌟', '🤖', '💡', '🔮'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/Security.json',
    title: 'Bank-Level\nSecurity',
    subtitle:
    'Biometric lock, end-to-end encryption,\n'
        'and real-time sync across all your devices.',
    gradientColors: [AppColors.midnight, Color(0xFF004D2F), AppColors.income],
    particles: ['🔐', '✅', '🛡️', '📱', '☁️', '🔒'],
  ),
];