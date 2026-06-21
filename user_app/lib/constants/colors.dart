import 'package:flutter/material.dart';

const Color bgColor = Color(0xFF121212);
const Color accentYellow = Color(0xFFFFC107);

const kYellow = Color(0xFFF6C000);
const kBg = Color(0xFF0D0D0D);
const kCard = Color(0xFF1E1E1E);
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
);
