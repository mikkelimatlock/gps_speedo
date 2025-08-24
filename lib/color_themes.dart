import 'package:flutter/material.dart';

class ColorTheme {
  final Color background;
  final Color speedText;
  final Color headingText;
  final Color unitText;
  final String name;

  const ColorTheme({
    required this.background,
    required this.speedText,
    required this.headingText,
    required this.unitText,
    required this.name,
  });
}

class ColorThemes {
  static const List<ColorTheme> themes = [
    ColorTheme(
      name: 'Classic Dark',
      background: Color(0xFF121212),
      speedText: Color(0xFF4CAF50),
      headingText: Color(0xFFFF9800),
      unitText: Color(0xFF9E9E9E),
    ),
    ColorTheme(
      name: 'Electric Blue',
      background: Color(0xFF0D1421),
      speedText: Color(0xFF00E5FF),
      headingText: Color(0xFFFFEB3B),
      unitText: Color(0xFF78909C),
    ),
    ColorTheme(
      name: 'Racing Red',
      background: Color(0xFF1A0A0A),
      speedText: Color(0xFFFF1744),
      headingText: Color(0xFFFFFFFF),
      unitText: Color(0xFFB0BEC5),
    ),
  ];

  static ColorTheme getTheme(int index) {
    return themes[index % themes.length];
  }

  static int getNextThemeIndex(int currentIndex) {
    return (currentIndex + 1) % themes.length;
  }
}