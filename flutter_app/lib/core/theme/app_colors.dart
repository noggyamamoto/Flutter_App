import 'package:flutter/material.dart';

// Identidade visual do aplicativo (protótipo do TCC – Figma): fundo escuro,
// superfícies em roxo acinzentado e destaque em violeta.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0F0E17);
  static const surface = Color(0xFF1E1B2E);
  static const surfaceHigh = Color(0xFF26233A);
  static const border = Color(0xFF39374A);

  static const primary = Color(0xFF7C5CFA);
  static const primarySoft = Color(0xFF9B6DDA);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xB3FFFFFF);
  static const textMuted = Color(0x80FFFFFF);

  // Papel da partitura.
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15131F);

  // Feedback (RFA06): verde = acerto, amarelo = aproximado, vermelho = erro.
  static const correct = Color(0xFF1DB954);
  static const approximate = Color(0xFFE8A400);
  static const incorrect = Color(0xFFE5484D);
}
