import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';
import 'primary_button.dart';

const _segments = 4;

/// Back arrow + the four-segment progress bar.
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({super.key, required this.progress});

  final double progress; // 0..1

  @override
  Widget build(BuildContext context) {
    final filled = 1 + (progress * (_segments - 1)).floor();

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 26, end: 26, top: 4),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Pressable(
              onTap: () => context.canPop() ? context.pop() : context.go('/'),
              child: const Icon(
                Icons.arrow_back,
                size: 24,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 26),
            for (var i = 0; i < _segments; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 5,
                decoration: BoxDecoration(
                  color: i < filled
                      ? AppColors.brandGreen
                      : AppColors.segmentOff,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidth = 264,
  });

  final String title;
  final String? subtitle;
  final double subtitleWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 26, end: 26, top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                height: 38 / 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: subtitleWidth),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 17,
                  height: 23 / 17,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.progress,
    required this.onNext,
    required this.child,
    this.title,
    this.subtitle,
    this.cta = 'Next',
    this.disabled = false,
  });

  final double progress;
  final String? title;
  final String? subtitle;
  final String cta;
  final VoidCallback onNext;
  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingTopBar(progress: progress),
            if (title != null) ScreenTitle(title: title!, subtitle: subtitle),
            Expanded(child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 16),
              child: PrimaryButton(
                label: cta,
                onPressed: disabled ? null : onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.glyph,
    this.tall = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? glyph;
  final bool selected;
  final bool tall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedOpacity: 0.7,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minHeight: tall ? 96 : 70),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandGreenTint : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected ? AppColors.brandGreen : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: tall ? 48 : 32,
              child: Center(
                child: glyph != null
                    ? Text(
                        glyph!,
                        style: const TextStyle(fontSize: 44, height: 1.1),
                      )
                    : icon != null
                    ? Icon(
                        icon,
                        size: tall ? 36 : 28,
                        color: selected ? AppColors.brandGreen : AppColors.ink,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 21 / 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 19 / 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 15, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

const _item = 14.0;

/// Snaps to ticks like [FixedExtentScrollPhysics], but a flick only carries a
/// fraction as far — at 14pt a tick, a normal flick would otherwise fly to the
/// end of the ruler.
class _RulerPhysics extends FixedExtentScrollPhysics {
  const _RulerPhysics({super.parent});

  @override
  _RulerPhysics applyTo(ScrollPhysics? ancestor) =>
      _RulerPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(position, velocity * 0.25);
}

const _visible = 16;

/// Vertical tape-measure picker: big value on top, ruler below, high → low.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.increment,
    required this.unit,
    this.decimals = 0,
    this.labelEvery = 5,
    this.labelDecimals = 0,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double increment;
  final String unit;
  final int decimals;
  final int labelEvery;
  final int labelDecimals;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final FixedExtentScrollController _controller;
  late int _index;

  int get _count => ((widget.max - widget.min) / widget.increment).round() + 1;

  double _valueAt(int i) => double.parse(
    (widget.max - i * widget.increment).toStringAsFixed(widget.decimals + 1),
  );

  @override
  void initState() {
    super.initState();
    _index = ((widget.max - widget.value) / widget.increment).round().clamp(
      0,
      _count - 1,
    );
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v, int decimals) => v % 1 == 0 && decimals == 0
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    const height = _item * _visible;
    final value = _valueAt(_index);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(widget.decimals),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.unit,
              style: const TextStyle(fontSize: 17, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              final cx = box.maxWidth / 2;
              return Stack(
                children: [
                  // stepped fade so the ruler dissolves at both ends, like the design
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0, 0.22, 0.78, 1],
                    ).createShader(r),
                    child: ListWheelScrollView.useDelegate(
                      controller: _controller,
                      itemExtent: _item,
                      physics: const _RulerPhysics(),
                      // flat, not a 3D drum
                      diameterRatio: 100,
                      perspective: 0.0001,
                      onSelectedItemChanged: (i) {
                        setState(() => _index = i);
                        widget.onChanged(_valueAt(i));
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _count,
                        builder: (context, i) {
                          final major = i % widget.labelEvery == 0;
                          // a label within one row of the centre would collide with the selected one
                          final showLabel = major && (i - _index).abs() > 1;
                          return SizedBox(
                            width: box.maxWidth,
                            height: _item,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: cx - (major ? 13 : 9),
                                  top: _item / 2 - (major ? 1 : 0.75),
                                  child: Container(
                                    width: major ? 26 : 18,
                                    height: major ? 2 : 1.5,
                                    decoration: BoxDecoration(
                                      color: major
                                          ? const Color(0xFFC9C9CE)
                                          : const Color(0xFFDEDEE2),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                                if (showLabel)
                                  Positioned(
                                    left: cx + 94,
                                    top: -3,
                                    child: Text(
                                      _valueAt(
                                        i,
                                      ).toStringAsFixed(widget.labelDecimals),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 20 / 17,
                                        color: AppColors.iconInactive,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // the fixed selection marker: a line with a dot, value on the right
                  IgnorePointer(
                    child: Stack(
                      children: [
                        Positioned(
                          left: cx - 87,
                          top: height / 2 - 1,
                          child: Container(
                            width: 174,
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                            ),
                          ),
                        ),
                        Positioned(
                          left: cx - 13,
                          top: height / 2 - 13,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppColors.brandGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x4005A029),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: cx + 94,
                          top: height / 2 - 10,
                          child: Text(
                            _format(value, widget.decimals),
                            style: const TextStyle(
                              fontSize: 17,
                              height: 20 / 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
