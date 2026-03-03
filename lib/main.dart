import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowTrack());
}

class FlowTrack extends StatelessWidget {
  const FlowTrack({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FlowTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(     // FIX 1
          seedColor:  AppColors.royalBlue,
          brightness: Brightness.light,
        ),
        textTheme:    GoogleFonts.dmSansTextTheme(),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),          // FIX 2
    );
  }
}