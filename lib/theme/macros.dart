import 'package:flutter/material.dart';

enum Macro {
  protein('Protein', Icons.local_fire_department, Color(0xFFF4685C)),
  carbs('Carbs', Icons.eco, Color(0xFFF0A424)),
  fat('Fat', Icons.water_drop, Color(0xFFF7C948));

  const Macro(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
