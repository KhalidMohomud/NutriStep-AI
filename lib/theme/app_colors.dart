import 'package:flutter/material.dart';

/// Design tokens: the Cal AI layout (white cards, hairline borders, big type)
/// in the NutriStep palette, sampled straight from `assests/image/logo.png`.
///
/// Text is the wordmark's navy, never pure black; actions and progress use the
/// logo's green → blue gradient.
abstract final class AppColors {
  static const background = Color(0xFFFCFEFC);
  static const card = Color(0xFFFFFFFF);
  static const ink = brandNavy;

  static const textSecondary = Color(0xFF4A4A52);
  static const textMuted = Color(0xFF6E6E78);
  static const textFaint = Color(0xFF8A8A90);
  static const iconInactive = Color(0xFF9A9AA0);

  static const border = Color(0xFFEDEDEF);
  static const borderStrong = Color(0xFFDEDEE2);
  static const divider = Color(0xFFF2F2F4);
  static const track = Color(0xFFEDEDF5);
  static const segmentOff = Color(0xFFD9D9DA);
  static const disabled = Color(0xFFC8C8CC);
  static const surfaceMuted = Color(0xFFF3F3F7);
  static const skeleton = Color(0xFFECECEF);

  static const error = Color(0xFFC4453C);
  static const warning = Color(0xFF8A6D2F);

  // NutriStep brand — sampled from the logo
  static const brandLeaf = Color(0xFF58CF05); // the leaf
  static const brandGreen = Color(0xFF05A029); // the N's green stroke
  static const brandGreenDark = Color(0xFF037D23);
  static const brandGreenTint = Color(0xFFEAF7E6);
  static const brandGreenTintStrong = Color(0xFFCDEFC4);
  static const brandAzure = Color(0xFF0199DE); // mid-diagonal of the N
  static const brandBlue = Color(0xFF003AD4); // the runner's pill
  static const brandNavy = Color(0xFF02203E); // the wordmark

  /// The logo's sweep, left → right: green N into the blue pill.
  static const brandGradient = LinearGradient(
    colors: [brandGreen, brandAzure, brandBlue],
    stops: [0, 0.55, 1],
  );
}
