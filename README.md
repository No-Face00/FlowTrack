# 💸 FlowTrack
A comprehensive Flutter mobile application for personal finance tracking and management. FlowTrack gives you full visibility into your income, expenses, and budgets — backed by AI-powered insights, real-time sync, and a beautifully crafted UI that makes managing money feel effortless.

---

## 📱 App Screens Overview

### 1. Splash Screen
Native splash with branded dark-blue background and app logo — instant and polished on both Android and iOS.

### 2. Onboarding
A welcoming guide that introduces new users to FlowTrack's core features before they sign up.

### 3. Authentication
Secure sign-in with Email/Password, Google, and Facebook. Supports PIN lock as a second layer of local security.

### 4. Home Screen
Your financial command center — live balance card, recent transactions, budget alerts, and the Flow Advisor AI card all at a glance.

### 5. Transactions
Full transaction history with type filters (income, expense, transfer), category chips, and swipe-to-delete with undo toasts.

### 6. Analytics
Visual breakdowns of spending by category, monthly comparisons, and budget progress bars — all powered by `fl_chart`.

### 7. Account
Edit your profile, switch currency and language, toggle dark/light/system theme, manage PIN, configure budget alerts, and export PDF reports.

---

## ✨ Features

### 🏠 Home Screen
- **Live Balance Card** — real-time income vs. expense summary with a gradient hero banner
- **Recent Transactions** — scrollable list with category icons and color-coded amounts
- **Budget Alerts** — inline warnings when you approach or exceed a budget limit
- **Flow Advisor Card** — AI-generated financial insight surfaced right on the home screen (toggle in settings)
- **Offline Indicator** — automatic banner when network is unavailable

### 💳 Transactions
- Add income, expense, and transfer entries with title, amount, date, note, and category
- 9 expense categories: Food & Dining, Transport, Shopping, Health, Entertainment, Bills & Utilities, Education, Rent & Housing, Other
- 6 income categories: Salary, Freelance, Investment, Business, Gift, Other
- Soft-delete with undo toast (no accidental permanent data loss)
- Offline-first: saved to Hive locally, synced to Firestore when connectivity returns
- Pending sync counter shown in a success snackbar on reconnect

### 📊 Analytics
- Monthly income vs. expense bar charts
- Category breakdown pie/donut charts
- Budget progress cards with percentage fill indicators
- Month selector to browse historical data
- Default budget seeds on first launch (Food, Transport, Bills, Shopping, Health)

### 🤖 Flow Advisor (AI)
- Powered by **Google Gemini 1.5 Flash**
- Generates a headline financial insight + up to 3 actionable bullet points
- Uses your real spending snapshot (amounts, top categories, balance trend)
- Falls back gracefully to a local rule-based engine when Gemini is unavailable
- Toggle on/off from Account → Preferences

### 🔐 Authentication & Security
- Email/Password sign-in and registration
- **Google Sign-In** and **Facebook Login**
- **Biometric / PIN lock** — set a 4-digit PIN protected by `flutter_secure_storage`
- PIN reset flow via email verification
- Encrypted Android shared preferences for all sensitive keys

### 📄 PDF Export
- Export Monthly, Annual, or Complete transaction reports as polished PDFs
- Multi-script font support: NotoSans covers Latin, Bengali ৳, Arabic, Devanagari, and CJK
- Share directly via the system share sheet
- Accessible from Account → Export PDF Report

### 🎨 Themes & Personalization
- **Light, Dark, and System** theme modes
- Elegant gradient palette: Midnight → Deep Blue → Royal Blue → Violet
- DM Sans typography via Google Fonts
- Lottie animations for AI, analytics, wallet, and security states
- Shimmer loading skeletons on async screens

### 🌍 Multi-Language Support
| Language | Code |
|---|---|
| English | `en` |
| Bangla | `bn` |
| Arabic | `ar` |
| Hindi | `hi` |
| Urdu | `ur` |
| Spanish | `es` |
| French | `fr` |
| German | `de` |
| Chinese | `zh` |
| Japanese | `ja` |

Language switching is instant with no app restart required.

### 🔔 Budget Notifications
- In-app notification center for budget warnings (50 %, 80 %, 100 %+ thresholds)
- Push banners on Home and Analytics screens when a limit is crossed
- Per-category budget management — add, edit, or remove limits any time

### 🔁 Offline-First Sync
- All transactions written to **Hive** (local NoSQL) before any network call
- Background Firestore sync triggered automatically when connectivity is restored
- `connectivity_plus` monitors network changes in real time
- Synced transaction count reported via in-app snackbar and notification

---

## 🛠 Tech Stack

### Frontend
- **Framework:** Flutter 3.x (Dart SDK ^3.10.7)
- **State Management:** flutter_bloc + Cubit
- **Navigation:** go_router
- **UI Components:** Material Design 3
- **Charts:** fl_chart
- **Animations:** Lottie
- **Fonts:** DM Sans (Google Fonts) + NotoSans (assets)

### Backend & Services
- **Firebase Auth** — email, Google, Facebook sign-in
- **Cloud Firestore** — remote transaction and budget storage
- **Hive** — local offline-first database
- **Google Gemini 1.5 Flash** — AI financial insights
- **ImgBB HTTP API** — profile photo hosting

### Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_bloc` | ^9.1.1 | State management |
| `go_router` | ^14.2.7 | Declarative routing |
| `firebase_core` | ^4.5.0 | Firebase initialization |
| `firebase_auth` | ^6.2.0 | Authentication |
| `cloud_firestore` | ^6.1.3 | Cloud database |
| `hive` + `hive_flutter` | ^2.2.3 | Local offline storage |
| `google_generative_ai` | ^0.4.7 | Gemini AI integration |
| `fl_chart` | ^0.68.0 | Financial charts |
| `lottie` | ^3.3.2 | Animations |
| `google_sign_in` | ^6.2.2 | Google OAuth |
| `flutter_facebook_auth` | ^7.0.1 | Facebook OAuth |
| `local_auth` | ^2.3.0 | Biometric authentication |
| `flutter_secure_storage` | ^9.2.2 | Encrypted local storage |
| `pdf` + `printing` | ^3.11.1 / ^5.13.2 | PDF export & sharing |
| `share_plus` | ^12.0.2 | Native share sheet |
| `connectivity_plus` | ^6.1.4 | Network state monitoring |
| `shimmer` | ^3.0.0 | Loading skeletons |
| `get_it` | ^9.2.1 | Dependency injection |
| `equatable` | ^2.0.8 | Value equality for BLoC |
| `intl` | ^0.20.2 | Date/number formatting |

---

## 📁 Project Structure

lib/
├── main.dart                               # App entry point + connectivity listener
├── app.dart                                # Root widget + theme/locale binding
├── firebase_options.dart                   # Firebase platform config
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart                 # Design tokens & gradients
│   │   ├── app_themes.dart                 # Light & dark ThemeData
│   │   └── app_categories.dart             # Centralized category system
│   ├── cubit/
│   │   └── app_cubit.dart                  # Global app state (theme, currency, locale)
│   ├── di/
│   │   └── service_locator.dart            # get_it DI setup
│   ├── errors/
│   │   └── app_error_handler.dart          # Global error boundaries
│   ├── l10n/
│   │   ├── app_strings.dart                # Stable localization key constants
│   │   ├── app_translations.dart           # 10-language translation maps
│   │   ├── app_locale.dart                 # Locale resolution helpers
│   │   └── l10n_extension.dart             # BuildContext .tr() extension
│   ├── notifications/
│   │   ├── notification_cubit.dart         # In-app notification state
│   │   ├── budget_notification_formatter.dart
│   │   └── notification_widgets.dart
│   ├── router/
│   │   └── appRouter.dart                  # go_router route definitions
│   ├── services/
│   │   ├── connectivity_service.dart       # Network state wrapper
│   │   ├── hive_service.dart               # Hive init + box registration
│   │   └── profile_image_service.dart      # ImgBB upload + caching
│   ├── utils/
│   │   ├── email_validator.dart
│   │   └── responsive_helper.dart          # Screen-size breakpoints
│   └── widgets/
│       ├── delete_toast.dart               # Undo-delete toast widget
│       └── premium_snackbar.dart           # Branded global snackbar
│
├── features/
│   ├── onboarding/                         # Onboarding slides + widgets
│   ├── auth/
│   │   ├── cubit/                          # Auth, PIN, PIN-reset cubits & states
│   │   ├── presentation/                   # Auth, PIN lock, PIN setup, reset screens
│   │   └── widgets/                        # Auth form & PIN pad widgets
│   ├── home/
│   │   ├── presentation/home_screen.dart
│   │   └── widgets/                        # Balance card, transaction item, home widgets
│   ├── transactions/
│   │   ├── data/
│   │   │   ├── local/transaction_local_ds.dart   # Hive data source
│   │   │   ├── remote/transaction_remote_ds.dart # Firestore data source
│   │   │   └── models/                           # Hive-annotated models
│   │   ├── domain/entities/transaction_entity.dart
│   │   └── presentation/
│   │       ├── cubit/                            # TransactionCubit, BalanceCubit + states
│   │       ├── transaction_screen.dart
│   │       ├── add_transaction_screen.dart
│   │       └── Widgets/
│   ├── budget/
│   │   ├── data/                           # Local + remote budget data sources
│   │   ├── domain/entities/budget_entity.dart
│   │   └── presentation/cubit/             # BudgetCubit + states
│   ├── analytics/
│   │   ├── presentation/analytics_screen.dart
│   │   └── Widgets/analytics_widgets.dart
│   ├── ai/
│   │   ├── cubit/finance_assistant_cubit.dart
│   │   ├── data/
│   │   │   ├── gemini_finance_client.dart  # Gemini 1.5 Flash integration
│   │   │   ├── local_finance_brain.dart    # Offline rule-based fallback
│   │   │   ├── finance_snapshot.dart       # Spending context builder
│   │   │   ├── finance_assistant_prefs.dart
│   │   │   └── insight_type.dart
│   │   └── presentation/flow_advisor_card.dart
│   └── account/
│       ├── presentation/                   # Account, edit profile, language picker, PDF modal
│       ├── services/pdf_export_service.dart
│       └── Widgets/account_widgets.dart
assets/
├── fonts/
│   ├── NotoSans-Regular.ttf
│   └── NotoSans-Bold.ttf
├── icons/
│   ├── AI_Assist.json                      # Lottie animation
│   ├── Data_Analysis.json
│   ├── Security.json
│   └── Wallet_animation.json
└── logo/
└── AppLogo.png
---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ^3.10.7
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for device/simulator builds)
- A Firebase project with Auth and Firestore enabled
- A Google Gemini API key (optional — app falls back to local AI if not set)

### Installation

**Clone the repository**
```bash
git clone https://github.com/your-username/FlowTrack.git
cd FlowTrack
```

**Install dependencies**
```bash
flutter pub get
```

**Set up Firebase**
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Email/Password, Google, and Facebook in Authentication
3. Create a Firestore database in production mode
4. Place `google-services.json` in `android/app/`
5. Configure iOS via Xcode with `GoogleService-Info.plist`

**Run the app**
```bash
# Android
flutter run

# iOS
flutter run -d iPhone

# Verbose (debug)
flutter run -v
```

**Generate Hive adapters** (if you modify models)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📱 Supported Platforms

| Platform | Support |
|---|---|
| ✅ Android | API 21+ |
| ✅ iOS | 11.0+ |

---

## 🎨 Theming

FlowTrack ships with a full light and dark theme. All colors are sourced from `AppColors`:

```dart
// Primary gradient
midnight:   #00033D
deepBlue:   #0600AB
royalBlue:  #0033FF
violet:     #977DFF

// Semantic
income:   #00C48C   // green
expense:  #FF647C   // red/pink

// Backgrounds
bgLavender: #F0EEF8  // light mode scaffold
dark scaffold: #0A0E21

// Text
textDark:  #0A0A2E
textMid:   #3D3B6E
textMuted: #7B78A8
```

---

## 🔐 Firebase Setup

FlowTrack uses Firebase for:

- **Firebase Auth** — user identity, session management
- **Cloud Firestore** — transaction and budget documents, keyed by `uid`
- **Firestore security rules** — scoped to the authenticated user's documents

All sensitive local data (PIN hash, secure keys) is stored in `flutter_secure_storage` with `AndroidOptions(encryptedSharedPreferences: true)`.

---

## 📊 Architecture

FlowTrack follows **Clean Architecture** with BLoC/Cubit for state management:

- **Presentation:** Flutter widgets in `lib/features/*/presentation/` and `widgets/`
- **Cubit/BLoC:** Business logic in `lib/features/*/cubit/` and `lib/core/cubit/`
- **Domain:** Pure Dart entities in `lib/features/*/domain/entities/`
- **Data:** Remote (Firestore) and local (Hive) data sources in `lib/features/*/data/`
- **DI:** `get_it` service locator initialized in `core/di/service_locator.dart`

---

## 📝 Code Style

- Clean Architecture — domain layer has zero Flutter or Firebase imports
- `Equatable` on all entities and states for value equality in BLoC
- Single source of truth for categories via `app_categories.dart`
- Stable localization keys via `app_strings.dart` (never hardcoded strings in widgets)
- `const` constructors wherever possible
- Each screen is thin — all widget building extracted to a dedicated `*_widgets.dart` file

---

## 🗺️ Roadmap

- [ ] Recurring transactions (weekly / monthly auto-entries)
- [ ] Multiple account wallets (cash, bank, card)
- [ ] Cloud backup and cross-device restore
- [ ] Widget for home screen balance summary
- [ ] Receipt photo attachment per transaction
- [ ] Advanced AI spending forecasting
- [ ] Web support

---

## 👥 Authors

- **No-Face00** — Initial development

---

## 🙏 Acknowledgments

- Flutter team for the incredible framework
- Firebase for scalable backend services
- Google Gemini for powering Flow Advisor
- fl_chart for beautiful financial visualizations
- All contributors and beta testers

---

## 📞 Support & Contact

For issues, questions, or feature requests:

- Open an issue on GitHub
- Review the existing documentation
- Check the [Flutter community forums](https://flutter.dev/community)

---

Happy tracking! 💸✨

For more information about Flutter, visit [flutter.dev](https://flutter.dev)
