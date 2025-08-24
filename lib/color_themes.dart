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
      name: 'Yuzuki',
      background: Color.fromARGB(255, 114, 85, 109),
      speedText: Color.fromARGB(255, 246, 224, 255),
      headingText: Color.fromARGB(255, 244, 201, 255),
      unitText: Color.fromARGB(255, 244, 201, 255),
    ),
    ColorTheme(
      name: 'Yuubari',
      background: Color.fromARGB(255, 85, 99, 112),
      speedText: Color.fromARGB(255, 255, 166, 0),
      headingText: Color.fromARGB(255, 228, 235, 238),
      unitText: Color.fromARGB(255, 141, 196, 184),
    ),
    ColorTheme(
      name: 'Yuzuki Light',
      background: Color.fromARGB(255, 246, 224, 255),
      speedText: Color.fromARGB(255, 114, 85, 109),
      headingText: Color.fromARGB(255, 140, 94, 151),
      unitText: Color.fromARGB(255, 114, 85, 109),
    ),
  ];

  static ColorTheme getTheme(int index) {
    return themes[index % themes.length];
  }

  static int getNextThemeIndex(int currentIndex) {
    return (currentIndex + 1) % themes.length;
  }
}