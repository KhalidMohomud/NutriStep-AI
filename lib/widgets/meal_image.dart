import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [src] is what `Meal.image` holds: a signed https URL (from the bucket), a
/// local file path (a photo just taken) or an asset path (demo mode).
ImageProvider mealImageProvider(String src) {
  if (src.startsWith('http')) return NetworkImage(src);
  if (src.startsWith('assests/')) return AssetImage(src);
  return FileImage(File(src));
}

/// A meal photo that fails soft: a missing or expired image is a quiet tile,
/// never a red error box.
class MealImage extends StatelessWidget {
  const MealImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      child: const Icon(Icons.restaurant, color: Color(0xFFB4B4BC)),
    );
    if (src.isEmpty) return fallback;

    return Image(
      image: mealImageProvider(src),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}
