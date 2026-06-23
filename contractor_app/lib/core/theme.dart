import 'package:flutter/material.dart';

const kYellow = Color(0xFFF6C000);
const kBg = Color(0xFF0D0D0D);
const kCard = Color(0xFF1F1F1F);
const kBorder = Color(0xFF333333);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kYellow,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1A1A),
    elevation: 0,
  ),
  cardTheme: CardTheme(
    color: kCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: kBorder),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0D0D0D),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kYellow),
    ),
  ),
);
