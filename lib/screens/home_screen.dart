import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../state/session.dart';
import '../state/steps.dart';
import '../theme/app_colors.dart';
import '../theme/macros.dart';
import '../widgets/brand.dart';
import '../widgets/meal_image.dart';
import '../widgets/pressable.dart';
import '../widgets/ring.dart';
import '../widgets/sheets.dart';
import 'plan_reveal_screen.dart';

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _stepGoal = 10000;

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _stepsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.resumeSteps();
    // HealthKit has no live stream; Android's sensor does, this just backs it up
    _stepsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => session.refreshSteps(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) session.refreshSteps();
  }

  final DateTime _today = _midnight(DateTime.now());
  late DateTime _selected = _today;

  // Two past weeks plus the current one, a week per page; future days are disabled.
  late final List<DateTime> _days = () {
    final start = _today.subtract(Duration(days: _today.weekday % 7 + 14));
    return List.generate(
      21,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }();

  final _strip = PageController(initialPage: 2);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepsTimer?.cancel();
    _strip.dispose();
    super.dispose();
  }

  // Home stays mounted behind the other tabs, so it listens rather than refetching.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final plan = session.profile?.plan;
    final isToday = _selected == _today;
    final meals = session.mealsOn(_selected);
    final streak = session.streak;

    // don't count a meal the model hasn't read yet
    final done = meals.where((m) => m.status == MealStatus.completed);
    final eatenCalories = done.fold(0, (t, m) => t + m.calories);
    final eaten = {
      for (final macro in Macro.values)
        macro: done.fold(0, (t, m) => t + m.grams(macro)),
    };

    final steps = session.stepsToday;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                children: [
                  const Wordmark(fontSize: 26, markSize: 32),
                  const Spacer(),
                  Pressable(
                    onTap: () => showStreakSheet(context, streak),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: Color(0xFFF4685C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$streak',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 78,
              child: PageView.builder(
                controller: _strip,
                itemCount: 3,
                itemBuilder: (context, week) => Row(
                  children: [
                    for (final d in _days.sublist(week * 7, week * 7 + 7))
                      Expanded(
                        child: _DayCell(
                          date: d,
                          selected: d == _selected,
                          future: d.isAfter(_today),
                          onTap: () => setState(() => _selected = d),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _Card(
              margin: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              radius: 22,
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatThousands(
                            max(0, (plan?.calories ?? 0) - eatenCalories),
                          ),
                          style: const TextStyle(
                            fontSize: 46,
                            height: 52 / 46,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Calories left',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Ring(
                    size: 96,
                    stroke: 10,
                    progress: eatenCalories / (plan?.calories ?? 0),
                    gradient: const [
                      AppColors.brandGreen,
                      AppColors.brandAzure,
                      AppColors.brandBlue,
                    ],
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 32,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  for (final macro in Macro.values) ...[
                    if (macro != Macro.protein) const SizedBox(width: 10),
                    Expanded(
                      child: _MacroCard(
                        macro: macro,
                        target: plan?.grams(macro) ?? 0,
                        eaten: eaten[macro]!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // steps are a today thing; past days show meals only
            if (isToday) _StepsCard(steps: steps, status: session.stepsStatus),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
              child: Text(
                isToday ? "Today's meals" : _longDate(_selected),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (meals.isEmpty)
              _EmptyMeals(isToday: isToday)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Column(
                  children: [
                    for (final meal in meals) ...[
                      _MealCard(
                        meal: meal,
                        onTap: meal.status == MealStatus.completed
                            ? () => showMealSheet(context, meal)
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _longDate(DateTime d) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

/// Today's steps — or, until it's connected, the way to connect it.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps, required this.status});

  final int steps;
  final StepsStatus status;

  @override
  Widget build(BuildContext context) {
    final connected = status == StepsStatus.connected;
    final (subtitle, action, onAction) = switch (status) {
      StepsStatus.connected => ('Steps today', null, null),
      StepsStatus.notConnected => (
        'See your steps next to your meals',
        'Connect',
        session.connectSteps,
      ),
      StepsStatus.denied => (
        'Allow physical activity in Settings',
        'Settings',
        openAppSettings,
      ),
      StepsStatus.unavailable => ("This device can't count steps", null, null),
    };

    return _Card(
      margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Ring(
            size: 58,
            stroke: 7,
            progress: connected ? steps / _stepGoal : 0,
            color: AppColors.brandBlue,
            child: const Icon(
              Icons.directions_walk,
              size: 24,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (connected)
                  Text.rich(
                    TextSpan(
                      text: formatThousands(steps),
                      children: [
                        TextSpan(
                          text: ' / ${formatThousands(_stepGoal)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  )
                else
                  const Text(
                    'Count your steps',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _thumb = 62.0;

// meal type is inferred from the clock, never asked
String mealType(DateTime d) => d.hour < 11
    ? 'Breakfast'
    : d.hour < 16
    ? 'Lunch'
    : d.hour < 21
    ? 'Dinner'
    : 'Snack';

String clockTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, this.onTap});

  final Meal meal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final analyzing = meal.status == MealStatus.analyzing;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MealImage(src: meal.image, width: _thumb, height: _thumb),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analyzing ? 'Analyzing…' : meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${clockTime(meal.loggedAt)} · ${mealType(meal.loggedAt)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textFaint,
                    ),
                  ),
                  if (!analyzing) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final macro in Macro.values) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: macro.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${meal.grams(macro)}g',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: analyzing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandGreen,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${meal.calories}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    required this.radius,
    required this.padding,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.macro,
    required this.target,
    required this.eaten,
  });

  final Macro macro;
  final int target;
  final int eaten;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${max(0, target - eaten)}g',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${macro.label} left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Center(
            child: Ring(
              size: 58,
              stroke: 7,
              progress: eaten / target,
              color: macro.color,
              child: Icon(macro.icon, size: 22, color: macro.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.future,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circleColor = future
        ? AppColors.border
        : selected
        ? AppColors.brandGreen
        : const Color(0xFFD3D3D8);

    return Pressable(
      onTap: future ? null : onTap,
      child: Center(
        child: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 7),
          // always bordered, transparent when unselected, so selecting doesn't shift it
          decoration: BoxDecoration(
            color: selected ? AppColors.card : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Text(
                _weekdays[date.weekday % 7],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: future
                      ? AppColors.disabled
                      : selected
                      ? AppColors.ink
                      : AppColors.textFaint,
                ),
              ),
              const SizedBox(height: 6),
              CustomPaint(
                painter: _CirclePainter(
                  color: circleColor,
                  dashed: !selected && !future,
                ),
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: future ? AppColors.disabled : AppColors.ink,
                      ),
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

/// Solid or dashed circle outline — the date strip's day markers.
class _CirclePainter extends CustomPainter {
  _CirclePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 1.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rect = (Offset.zero & size).deflate(width / 2);

    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    const dashes = 14;
    const sweep = 2 * pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.color != color || old.dashed != dashed;
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    size: 22,
                    color: Color(0xFFB4B4BC),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_bar(1), const SizedBox(height: 7), _bar(0.6)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isToday
                ? 'Snap your first meal of the day and the numbers land here.'
                : 'No meals logged on this day.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 20 / 15,
              color: AppColors.textMuted,
            ),
          ),
          if (isToday) ...[
            const SizedBox(height: 14),
            Pressable(
              onTap: () => context.go('/scan'),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Scan a meal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(double widthFactor) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}
