import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// The brand-gradient 50pt CTA every onboarding screen ends with.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 50,
    this.radius = 15,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double radius;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Pressable(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onPressed == null ? AppColors.disabled : null,
          gradient: onPressed == null ? null : AppColors.brandGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: onPressed == null
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x2E0199DE),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (loading)
              const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            if (trailing != null)
              PositionedDirectional(
                end: 22,
                top: 0,
                bottom: 0,
                child: Center(child: trailing!),
              ),
          ],
        ),
      ),
    );
  }
}
