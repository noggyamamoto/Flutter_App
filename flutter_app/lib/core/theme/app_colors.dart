import 'package:flutter/material.dart';

// Identidade visual do aplicativo (protótipo do TCC – Figma): fundo escuro,
// superfícies em roxo acinzentado e destaque em violeta.
//
// O modo escuro é o padrão (identidade do app). O modo claro usa os mesmos
// violetas sobre fundo lavanda claro e superfícies brancas, com o texto na
// cor da tinta da partitura. As cores ficam no tema (ThemeExtension):
// `context.colors.background` muda junto com o modo escolhido nas
// Configurações.
class AppColors extends ThemeExtension<AppColors> {
  final Brightness brightness;

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  // Superfície das listas (execuções, troféus) e dos campos.
  final Color surfaceLow;
  // Cartões das telas (configurações, repertório, conexão).
  final Color card;
  final Color border;

  final Color primary;
  final Color primarySoft;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Linhas e trilhas discretas (grades, barras de progresso, divisórias).
  final Color outline;
  final Color subtle;

  // Fundo dos campos de texto.
  final Color field;

  // Estado positivo (dispositivo conectado) e texto dourado (troféus).
  final Color positive;
  final Color goldText;

  // Teclas do guia de notas (teclado na tela de execução).
  final Color whiteKey;
  final Color whiteKeyLabel;
  final Color blackKey;

  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceLow,
    required this.card,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.outline,
    required this.subtle,
    required this.field,
    required this.positive,
    required this.goldText,
    required this.whiteKey,
    required this.whiteKeyLabel,
    required this.blackKey,
  });

  // Modo escuro (padrão): as cores do protótipo.
  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0F0E17),
    surface: Color(0xFF1E1B2E),
    surfaceHigh: Color(0xFF26233A),
    surfaceLow: Color(0xFF191827),
    card: Color(0xFF232136),
    border: Color(0xFF39374A),
    primary: Color(0xFF7C5CFA),
    primarySoft: Color(0xFF9B6DDA),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x80FFFFFF),
    outline: Color(0x3DFFFFFF),
    subtle: Color(0x1FFFFFFF),
    field: Color(0x14FFFFFF),
    positive: Color(0xFF69F0AE),
    goldText: Color(0xFFFFC107),
    whiteKey: Color(0xFFF2F1F7),
    whiteKeyLabel: Color(0xFF8A8799),
    blackKey: Color(0xFF1B1928),
  );

  // Modo claro: mesmos violetas; fundo lavanda, cartões brancos com borda
  // lilás e texto na cor da tinta da partitura.
  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF4F2FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEAE6F8),
    surfaceLow: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFDCD7EE),
    primary: Color(0xFF7C5CFA),
    primarySoft: Color(0xFF7E4FCB),
    textPrimary: Color(0xFF15131F),
    textSecondary: Color(0xFF4B4760),
    textMuted: Color(0xFF6E6A80),
    outline: Color(0x3315131F),
    subtle: Color(0x1415131F),
    field: Color(0xFFEAE6F8),
    positive: Color(0xFF16A34A),
    goldText: Color(0xFFA86B00),
    whiteKey: Color(0xFFFFFFFF),
    whiteKeyLabel: Color(0xFF8A8799),
    blackKey: Color(0xFF26233A),
  );

  bool get isDark => brightness == Brightness.dark;

  // Cores do tema atual. Sem a extensão no tema (ex.: testes com um
  // ThemeData simples), usa o modo escuro.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  // Cores iguais nos dois modos.

  // Botões e seleção (Colors.deepPurple do protótipo).
  static const accent = Color(0xFF673AB7);

  // Papel da partitura.
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15131F);

  // Feedback (RFA06): verde = acerto, amarelo = aproximado, vermelho = erro.
  static const correct = Color(0xFF1DB954);
  static const approximate = Color(0xFFE8A400);
  static const incorrect = Color(0xFFE5484D);

  // Troféus e estrelas.
  static const gold = Color(0xFFFFC233);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      surfaceLow: l(surfaceLow, other.surfaceLow),
      card: l(card, other.card),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      outline: l(outline, other.outline),
      subtle: l(subtle, other.subtle),
      field: l(field, other.field),
      positive: l(positive, other.positive),
      goldText: l(goldText, other.goldText),
      whiteKey: l(whiteKey, other.whiteKey),
      whiteKeyLabel: l(whiteKeyLabel, other.whiteKeyLabel),
      blackKey: l(blackKey, other.blackKey),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors.of(this);
}
