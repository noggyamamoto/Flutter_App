import 'package:flutter/material.dart';

import 'app_colors.dart';

// Temas do aplicativo: escuro (padrão, identidade visual) e claro.
//
// Os dois partem do mesmo esquema violeta do Material (botões, campos e
// diálogos sem cor própria ficam iguais ao que o app já usava); as cores das
// telas vêm de AppColors, registradas como extensão do tema.
class AppTheme {
  AppTheme._();

  static final dark = _build(AppColors.dark);
  static final light = _build(AppColors.light);

  static ThemeData _build(AppColors colors) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
