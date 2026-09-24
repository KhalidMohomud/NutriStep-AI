import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../plan/plan.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';

const _lines = [
  'Reading your answers…',
  'Estimating your daily burn…',
  'Balancing your macros…',
  'Finishing your plan…',
];
const _tick = Duration(milliseconds: 700);

class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key});

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  int _i = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => setState(() => _i++));
    _generate();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = answersAsInput();
    if (input == null) {
      // landed here without answers — start over
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return;
    }

    // The Supabase `generate-plan` Edge Function (Gemini, with this formula as its
    // fallback) slots in here. Held to the animation's length so the screen reads.
    final results = await Future.wait([
      Future(() => formulaPlan(input)),
      Future<void>.delayed(_tick * _lines.length),
    ]);
    draftPlan = results.first as Plan;

    if (mounted) context.pushReplacement('/onboarding/plan');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ((_i + 1) / _lines.length * 0.95).clamp(0.0, 0.95);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 96),
              const SizedBox(height: 34),
              const Text(
                'Building your plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lines[_i.clamp(0, _lines.length - 1)],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 30),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 210,
                  height: 5,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      backgroundColor: const Color(0xFFE8E8EA),
                      color: AppColors.brandGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
