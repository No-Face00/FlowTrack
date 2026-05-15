import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.lottieAsset,
    required this.titleKey,
    required this.subtitleKey,
    required this.gradientColors,
    required this.particles,
  });

  final String lottieAsset;
  final String titleKey;
  final String subtitleKey;
  final List<Color> gradientColors;
  final List<String> particles;
}

const List<OnboardingSlide> kSlides = [
  OnboardingSlide(
    lottieAsset: 'assets/icons/Wallet_animation.json',
    titleKey: 'onboard_title_1',
    subtitleKey: 'onboard_sub_1',
    gradientColors: [AppColors.midnight, AppColors.deepBlue, AppColors.royalBlue],
    particles: ['💳', '🏦', '💰', '📊', '💵', '🪙'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/Data_Analysis.json',
    titleKey: 'onboard_title_2',
    subtitleKey: 'onboard_sub_2',
    gradientColors: [AppColors.deepBlue, Color(0xFF3A00CC), AppColors.violet],
    particles: ['📈', '🎯', '🔍', '✨', '📉', '⚡'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/AI_Assist.json',
    titleKey: 'onboard_title_3',
    subtitleKey: 'onboard_sub_3',
    gradientColors: [Color(0xFF1A0060), Color(0xFF6B21A8), Color(0xFFC084FC)],
    particles: ['🧠', '⚡', '🌟', '🤖', '💡', '🔮'],
  ),
  OnboardingSlide(
    lottieAsset: 'assets/icons/Security.json',
    titleKey: 'onboard_title_4',
    subtitleKey: 'onboard_sub_4',
    gradientColors: [AppColors.midnight, Color(0xFF004D2F), AppColors.income],
    particles: ['🔐', '✅', '🛡️', '📱', '☁️', '🔒'],
  ),
];
