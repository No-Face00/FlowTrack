import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/app_cubit.dart';
import '../di/service_locator.dart';
import 'app_translations.dart';

extension L10nContext on BuildContext {
  /// Current language code from [AppCubit].
  String get langCode =>
      read<AppCubit>().state.languageCode;

  /// Translate [key] for the active locale.
  String tr(String key) =>
      AppTranslations.tr(langCode, key);
}

/// Same as [L10nContext.tr] when no [BuildContext] is available.
String trGlobal(String key) =>
    AppTranslations.tr(getIt<AppCubit>().state.languageCode, key);
