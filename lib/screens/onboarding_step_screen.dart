import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding.dart';

const _yearMs = 31557600000;

class OnboardingStepScreen extends StatefulWidget {
  const OnboardingStepScreen({super.key, required this.stepKey});

  final String stepKey;

  @override
  State<OnboardingStepScreen> createState() => _OnboardingStepScreenState();
}

class _OnboardingStepScreenState extends State<OnboardingStepScreen> {
  late final int index = stepIndex(widget.stepKey);
  late final OnboardingStep step = steps[index];
  late Object? value = answers[step.field];

  void _commit(Object v) {
    setState(() => value = v);
    answers[step.field] = v;
    // the goal-weight ruler opens on where you are now, not on a default
    if (step.field == 'weightKg') answers['targetWeightKg'] = v;
  }

  void _next() {
    final next = index + 1 < steps.length ? steps[index + 1] : null;
    context.push(
      next != null ? '/onboarding/${next.key}' : '/onboarding/building',
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = this.step;

    return OnboardingScaffold(
      progress: (index + 1) / steps.length,
      title: step.title,
      subtitle: step.subtitle,
      disabled: value == null,
      onNext: _next,
      child: switch (step) {
        CardsStep() => ListView(
          padding: const EdgeInsets.fromLTRB(26, 38, 26, 16),
          children: [
            for (final o in step.options) ...[
              OptionCard(
                title: o.title,
                subtitle: o.subtitle,
                icon: o.icon,
                glyph: o.glyph,
                tall: step.tall,
                selected: value == o.value,
                onTap: () => _commit(o.value),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        DateStep() => _DatePicker(value: value as String?, onChanged: _commit),
        RulerStep() => _Ruler(
          step: step,
          value: value as double?,
          onChanged: _commit,
        ),
      },
    );
  }
}

class _DatePicker extends StatelessWidget {
  const _DatePicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final latest = DateTime.fromMillisecondsSinceEpoch(now - 18 * _yearMs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: value != null ? DateTime.parse(value!) : latest,
            minimumDate: DateTime(1920),
            maximumDate: latest,
            onDateTimeChanged: (d) => onChanged(isoDate(d)),
          ),
        ),
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({
    required this.step,
    required this.value,
    required this.onChanged,
  });

  final RulerStep step;
  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value ?? step.min;
    final note = step.note?.call(current);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          RulerPicker(
            value: current,
            onChanged: onChanged,
            min: step.min,
            max: step.max,
            increment: step.increment,
            decimals: step.decimals,
            labelEvery: step.labelEvery,
            labelDecimals: step.labelDecimals,
            unit: step.unit,
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 0),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 19 / 14,
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
