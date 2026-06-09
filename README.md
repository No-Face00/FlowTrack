🐦 Birdy
A comprehensive Flutter mobile application for bird care and management. Birdy provides users with valuable information, care tips, AI-powered assistance, and a community of experts to help you raise and care for your feathered friends.

📱 Demo Video Watch the app in action: https://youtube.com/shorts/SeYyaqvD2n4?si=pSY5qfjw90AJbT_B

📱 APK Downloads Link : https://github.com/No-Face00/Birdy/releases/tag/version

✨ Features
🏠 Home Screen
Quick Actions Grid - Fast access to essential bird care features
Dynamic Slider - Featured content and educational materials
Daily Tips - Receive daily bird care suggestions and advice
Need Help Section - Connect with expert ornithologists and bird care specialists
About Us - Learn more about the application and its mission
🤖 AI Assistant
Intelligent chatbot for bird-related queries
Real-time responses powered by AI
Context-aware bird care recommendations
Multi-language support (English & Bangla)
❤️ Favorites
Save your favorite articles and guides
Organized by category for easy access
Quick reference for frequently needed information
Share content with others
📚 Quick Action Categories
Search - Find specific bird species and information
Food - Nutritional guides and feeding schedules
Treatment - Health management and medical care
Tame - Bird behavior and taming techniques
Information - General bird care knowledge
🎨 User Interface
Beautiful, intuitive design
Dark mode support
Smooth animations and transitions
Responsive layouts for all screen sizes
Custom fonts (Quicksand and RubikBubbles)
🌍 Multi-Language Support
English
Bangla
Easy language switching in settings
🔧 Additional Features
Settings page with theme and language preferences
Firebase integration for real-time data
Lottie animations for enhanced UX
Loading states and error handling
Share content functionality
URL launching for external resources
🛠 Tech Stack
Frontend
Framework: Flutter 3.8.1+
State Management: GetX
UI Components: Material Design 3
Backend & Services
Firebase:
Cloud Firestore (database)
Firebase Core (initialization)
HTTP Client: HTTP package for API calls
Key Dependencies
Package	Version	Purpose
get	^4.7.3	State management & routing
firebase_core	^4.3.0	Firebase initialization
cloud_firestore	^6.1.1	Cloud database
lottie	3.3.1	Animations
flutter_markdown	^0.6.19	Markdown rendering
shared_preferences	^2.5.3	Local storage
url_launcher	^6.2.2	External links
cached_network_image	^3.3.1	Image caching
share_plus	^7.2.2	Share functionality
📁 Project Structure
lib/
├── main.dart                          # App entry point
├── config/                            # Configuration files
│   └── api_config.dart
├── data/                              # Data layer
│   ├── api_config/
│   ├── services/
│   │   ├── assistant_service.dart
│   │   ├── base_firestore_service.dart
│   │   ├── daily_tips_service.dart
│   │   ├── need_help_firestore_service.dart
│   │   └── translations.dart
│   └── firebase_options.dart
├── resource/                          # Resources
│   ├── colors/
│   │   └── colors.dart               # Theme colors
│   └── markdown/
│       └── markdown.dart              # Markdown styling
├── view/                              # UI Screens
│   ├── splash_view/                  # Splash screen
│   ├── onbording/                    # Onboarding screen
│   ├── main_navigation/              # Bottom navigation
│   ├── home/
│   │   ├── homePage/                 # Home screen
│   │   ├── quickActionPage/          # Quick actions
│   │   ├── needHelp/                 # Expert connection
│   │   └── daily_tips/               # Daily tips
│   ├── assistent/                    # AI Assistant
│   └── favorite/                     # Favorites page
└── viewmodel/                         # Business logic
    ├── assistant_controller.dart
    ├── favorite_page_controller.dart
    ├── daily_tips_controller.dart
    ├── need_help_controller.dart
    └── settings_controller.dart

assets/
├── animation/                         # Lottie animations
├── card/                              # Card animations
├── fonts/                             # Custom fonts
├── logo/                              # App logos
└── sliderImg/                         # Slider images
🚀 Getting Started
Prerequisites
Flutter SDK 3.8.1 or higher
Dart SDK (included with Flutter)
Android Studio / Xcode (for running on devices)
Git
Installation
Clone the Repository

git clone https://github.com/No-Face00/Birdy.git
cd Birdy-main
Install Dependencies

flutter pub get
Set Up Firebase

Follow Firebase setup guide
Create a Firebase project and configure it for Android and iOS
Place the google-services.json file in android/app/
Configure iOS through Xcode
Run the App

# On Android
flutter run

# On iOS
flutter run -d iPhone

# Web
flutter run -d chrome
Development Mode
flutter run -v  # Verbose mode for debugging
📱 Supported Platforms
✅ Android (API 21+)
✅ iOS (11.0+)
🎯 App Screens Overview
1. Splash Screen
Initial loading screen with app branding

2. Onboarding
Welcome guide for new users

3. Home Screen
Central hub with quick actions, daily tips, and expert connection

4. Quick Actions
Detailed views for each category:

Search for bird species
Feeding guidelines
Medical treatment info
Behavioral training
General information
5. AI Assistant
Chat interface with AI-powered responses

6. Favorites
Bookmarked content organized by category

7. Settings
User preferences:

Theme selection (Light/Dark)
Language preference
App information
🔐 Firebase Setup
This app uses Firebase Firestore for:

Storing bird species information
Managing expert profiles
Storing user favorites
Fetching daily tips

---

## 🎨 Theming

The app supports both light and dark themes with customizable colors:

```dart
// Primary Colors
primaryColor: #FF6B6B
secondaryColor: #FFD93D
backgroundColor: #F5F5F5

// Dark Mode
scaffoldBackgroundColor: #121212
surfaceColor: #1E1E1E
🌐 Multi-Language Implementation
The app uses GetX for localization. Supported languages:

English (en_US)
Bangla (bn_BD)
To add a new language, update the AppTranslations class in lib/data/services/translations.dart

📊 Architecture
The app follows the MVVM (Model-View-ViewModel) architecture:

View: Flutter widgets in lib/view/
ViewModel: GetX Controllers in lib/viewmodel/
Model & Data: Services in lib/data/
📝 Code Style
Follow Flutter best practices:

Use meaningful variable and function names
Add comments for complex logic
Follow Dart naming conventions
Keep functions small and focused
Use const constructors where possible
👥 Authors
No-Face00 - Initial development
🙏 Acknowledgments
Flutter team for the amazing framework
Firebase for reliable backend services
GetX for state management
All contributors and testers
📞 Support & Contact
For issues, questions, or suggestions:

Open an issue on GitHub
Review the existing documentation
Check the Flutter community forums
🗺️ Roadmap
 Push notifications for daily tips
 Video tutorials for bird care
 Community forum
 Bird health tracker
 Appointment scheduling with experts
 Offline mode
 Bird identification using ML
 Advanced analytics
Happy bird caring! 🐦✨

For more information about Flutter, visit flutter.dev
