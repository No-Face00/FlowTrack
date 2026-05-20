import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/responsive_helper.dart';

void showLanguagePicker(BuildContext context) {
  final rs = Rs.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetCtx) => BlocBuilder<AppCubit, AppSettings>(
      bloc: getIt<AppCubit>(),
      builder: (_, appState) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mq = MediaQuery.of(context);
        final maxH = mq.size.height * 0.62;

        return Container(
          margin: EdgeInsets.fromLTRB(
            rs.sp(12),
            0,
            rs.sp(12),
            rs.sp(12) + mq.padding.bottom,
          ),
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(rs.sp(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.midnight.withOpacity(isDark ? 0.5 : 0.15),
                blurRadius: 48,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: rs.sp(36),
                  height: rs.sp(4),
                  margin: EdgeInsets.symmetric(vertical: rs.sp(14)),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(rs.sp(22), 0, rs.sp(22), rs.sp(12)),
                child: Row(
                  children: [
                    Container(
                      width: rs.sp(42),
                      height: rs.sp(42),
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(rs.sp(14)),
                      ),
                      child: Icon(
                        Icons.language_rounded,
                        color: Colors.white,
                        size: rs.sp(20),
                      ),
                    ),
                    SizedBox(width: rs.sp(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('select_language'),
                            style: TextStyle(
                              fontSize: rs.sp(17),
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              fontFamily: 'Sora',
                            ),
                          ),
                          Text(
                            context.tr('language_subtitle'),
                            style: TextStyle(
                              fontSize: rs.sp(11),
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(rs.sp(16), 0, rs.sp(16), rs.sp(16)),
                  itemCount: AppLocales.options.length,
                  itemBuilder: (_, i) {
                    final opt = AppLocales.options[i];
                    final sel = opt.code == appState.languageCode;
                    return GestureDetector(
                      onTap: () {
                        getIt<AppCubit>().setLanguage(opt.code);
                        Navigator.of(sheetCtx).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(bottom: rs.sp(6)),
                        padding: EdgeInsets.symmetric(
                          horizontal: rs.sp(14),
                          vertical: rs.sp(12),
                        ),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? LinearGradient(
                                  colors: [
                                    AppColors.royalBlue.withOpacity(0.12),
                                    AppColors.violet.withOpacity(0.08),
                                  ],
                                )
                              : null,
                          color: sel ? null : cs.onSurface.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(rs.sp(16)),
                          border: Border.all(
                            color: sel
                                ? AppColors.royalBlue.withOpacity(0.35)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.nativeName,
                                    style: TextStyle(
                                      fontSize: rs.sp(15),
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? AppColors.royalBlue
                                          : cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    opt.name,
                                    style: TextStyle(
                                      fontSize: rs.sp(11),
                                      color: cs.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (opt.rtl)
                              Container(
                                margin: EdgeInsets.only(right: rs.sp(8)),
                                padding: EdgeInsets.symmetric(
                                  horizontal: rs.sp(6),
                                  vertical: rs.sp(2),
                                ),
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(rs.sp(6)),
                                ),
                                child: Text(
                                  'RTL',
                                  style: TextStyle(
                                    fontSize: rs.sp(9),
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            AnimatedOpacity(
                              opacity: sel ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: rs.sp(24),
                                height: rs.sp(24),
                                decoration: const BoxDecoration(
                                  gradient: AppColors.buttonGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: rs.sp(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
