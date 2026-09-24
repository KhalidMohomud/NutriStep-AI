import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const logoMark = 'assests/image/logo-mark.png';
const phoneMockup = 'assests/image/phone-mockup.png';
const demoMeal = 'assests/image/demo-meal.jpg';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(logoMark, width: size, height: size, fit: BoxFit.contain);
}

/// Logo mark + "NutriStep AI", the header on welcome and home.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.fontSize, required this.markSize});

  final double fontSize;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMark(size: markSize),
        SizedBox(width: fontSize * 0.3),
        Text(
          'NutriStep',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.brandNavy,
          ),
        ),
        SizedBox(width: fontSize * 0.18),
        // the logo sets "AI" white in a green rounded tag
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.22,
            vertical: fontSize * 0.02,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF20CF51), AppColors.brandGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(fontSize * 0.28),
          ),
          child: Text(
            'AI',
            style: TextStyle(
              fontSize: fontSize * 0.86,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Four-colour Google "G", drawn rather than shipped as an image.
class GoogleG extends StatelessWidget {
  const GoogleG({super.key, this.size = 19});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final arc = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // angles in radians, clockwise from 3 o'clock
    void seg(double from, double sweep, Color c) =>
        canvas.drawArc(arc, from, sweep, false, paint..color = c);

    seg(-0.72, -1.72, const Color(0xFFEA4335)); // red, top
    seg(-2.44, -1.32, const Color(0xFFFBBC05)); // yellow, left
    seg(2.52, -1.62, const Color(0xFF34A853)); // green, bottom
    seg(0.9, -0.9, const Color(0xFF4285F4)); // blue, right

    canvas.drawRect(
      Rect.fromLTWH(
        s * 0.5,
        s * 0.5 - stroke / 2,
        s * 0.5 - stroke * 0.05,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
