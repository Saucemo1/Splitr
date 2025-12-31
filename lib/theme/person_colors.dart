import 'package:flutter/material.dart';

class PersonColors {
  static const Map<String, Map<String, Color>> palette = {
    'Lavender': {
      'unselected': Color(0xFFF3EFFE), // Very light lavender
      'selected': Color(0xFFE6E2FF),   // Light lavender
      'ring': Color(0xFF6B5BFF),       // Primary indigo-violet
    },
    'Rose': {
      'unselected': Color(0xFFFDF2F8), // Very light rose
      'selected': Color(0xFFFCE7F3),   // Light rose
      'ring': Color(0xFFFF71B8),       // Secondary pink
    },
    'Mint': {
      'unselected': Color(0xFFF0FDF4), // Very light mint
      'selected': Color(0xFFDCFCE7),   // Light mint
      'ring': Color(0xFF4DD0E1),       // Tertiary cyan
    },
    'Peach': {
      'unselected': Color(0xFFFFF7ED), // Very light peach
      'selected': Color(0xFFFFEDD5),   // Light peach
      'ring': Color(0xFFFF8A65),       // Orange accent
    },
    'Sky': {
      'unselected': Color(0xFFF0F9FF), // Very light sky
      'selected': Color(0xFFE0F2FE),   // Light sky
      'ring': Color(0xFF0EA5E9),       // Sky blue
    },
    'Lilac': {
      'unselected': Color(0xFFFAF5FF), // Very light lilac
      'selected': Color(0xFFF3E8FF),   // Light lilac
      'ring': Color(0xFF8B5CF6),       // Purple
    },
    'Sage': {
      'unselected': Color(0xFFF6F7F6), // Very light sage
      'selected': Color(0xFFECFDF5),   // Light sage
      'ring': Color(0xFF10B981),       // Emerald
    },
    'Coral': {
      'unselected': Color(0xFFFFF1F2), // Very light coral
      'selected': Color(0xFFFFE4E6),   // Light coral
      'ring': Color(0xFFEF4444),       // Red
    },
  };

  static const List<String> colorNames = [
    'Lavender',
    'Rose',
    'Mint',
    'Peach',
    'Sky',
    'Lilac',
    'Sage',
    'Coral',
  ];

  static Map<String, Color> getColorTheme(String colorName) {
    return palette[colorName] ?? palette['Lavender']!;
  }
}
