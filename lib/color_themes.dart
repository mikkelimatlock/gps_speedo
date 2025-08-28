import 'package:flutter/material.dart';

class ColorTheme {
  final Color background;
  final Color speedText;
  final Color speedTextSub;
  final Color headingText;
  final Color unitText;
  final String name;

  const ColorTheme({
    required this.background,
    required this.speedText,
    required this.speedTextSub,
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
      speedTextSub: Color.fromARGB(255, 245, 217, 245),
      headingText: Color.fromARGB(255, 244, 201, 255),
      unitText: Color.fromARGB(255, 244, 201, 255),
    ),
    ColorTheme(
      name: 'Yuuparo',
      background: Color.fromARGB(255, 85, 99, 112),
      speedText: Color.fromARGB(255, 255, 171, 16),
      speedTextSub: Color.fromARGB(255, 245, 204, 116),
      headingText: Color.fromARGB(255, 228, 235, 238),
      unitText: Color.fromARGB(255, 141, 196, 184),
    ),
    ColorTheme(
      name: 'Yuzuki Light',
      background: Color.fromARGB(255, 246, 224, 255),
      speedText: Color.fromARGB(255, 114, 85, 109),
      speedTextSub: Color.fromARGB(255, 161, 138, 170),
      headingText: Color.fromARGB(255, 140, 94, 151),
      unitText: Color.fromARGB(255, 114, 85, 109),
    ),
    ColorTheme(
      name: 'Yuuparo Light',
      background: Color.fromARGB(255, 228, 235, 238),
      speedText: Color.fromARGB(255, 85, 99, 112),
      speedTextSub: Color.fromARGB(255, 100, 100, 131),
      headingText: Color.fromARGB(255, 221, 118, 0),
      unitText: Color.fromARGB(255, 98, 124, 118),
    ),
  ];

  static ColorTheme getTheme(int index) {
    return themes[index % themes.length];
  }

  static int getNextThemeIndex(int currentIndex) {
    return (currentIndex + 1) % themes.length;
  }
}