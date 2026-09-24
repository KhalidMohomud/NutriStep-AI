import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../state/backend.dart';
import '../state/session.dart';
import '../theme/app_colors.dart';
import '../theme/macros.dart';
import '../widgets/brand.dart';
import '../widgets/meal_image.dart';
import '../widgets/pressable.dart';

const scanBackground = Color(0xFF07122A);
const _tile = Color(0xFF14223F);
const _muted = Color(0xFF9AA3B5);

/// Set by the tab shell. The tabs are an indexed stack, so this screen stays
/// mounted on Home too — the camera only runs while its tab is showing.
final scanTabActive = ValueNotifier<bool>(false);

enum _Stage { viewfinder, captured, analyzing, result }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  _Stage _stage = _Stage.viewfinder;
  String? _photo; // file path, or the demo asset
  ScanResult? _result;

  CameraController? _camera;
  bool _noCamera = false; // simulator, or permission denied
  bool _cameraDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scanTabActive.addListener(_syncCamera);
    _syncCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanTabActive.removeListener(_syncCamera);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // the OS takes the camera back while the app is in the background
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _closeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _syncCamera();
    }
  }

  bool get _wantsCamera => scanTabActive.value && _stage == _Stage.viewfinder;

  Future<void> _syncCamera() async {
    if (!_wantsCamera) return _closeCamera();
    if (_camera != null || _noCamera) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _noCamera = true);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || !_wantsCamera) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on CameraException catch (e) {
      debugPrint('Camera unavailable: ${e.code}');
      if (mounted) {
        setState(() {
          _noCamera = true;
          _cameraDenied =
              e.code.contains('Denied') || e.code.contains('denied');
        });
      }
    } catch (e) {
      // e.g. the plugin isn't in this build yet — fall back to the gallery
      debugPrint('Camera failed to start: $e');
      if (mounted) setState(() => _noCamera = true);
    }
  }

  Future<void> _closeCamera() async {
    final controller = _camera;
    if (controller == null) return;
    if (mounted) setState(() => _camera = null);
    await controller.dispose();
  }

  Future<void> _capture() async {
    final camera = _camera;
    // no live camera (simulator, or denied): the shutter opens the gallery
    if (camera == null || !camera.value.isInitialized) {
      return _pickFromGallery();
    }
    try {
      final shot = await camera.takePicture();
      _show(shot.path);
    } on CameraException catch (e) {
      debugPrint('takePicture failed: ${e.code}');
    }
  }

  Future<void> _pickFromGallery() async {
    // demo mode on a simulator: nothing to pick from, so use the demo plate
    if (!backendEnabled && _noCamera) return _show(demoMeal);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) _show(picked.path);
    } catch (e) {
      debugPrint('Gallery failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't open your photos. Please try again."),
        ),
      );
    }
  }

  void _show(String photo) {
    setState(() {
      _photo = photo;
      _stage = _Stage.captured;
    });
    _closeCamera();
  }

  void _reset() {
    setState(() {
      _stage = _Stage.viewfinder;
      _photo = null;
      _result = null;
    });
    _syncCamera();
  }

  Future<void> _analyze() async {
    setState(() => _stage = _Stage.analyzing);
    final result = await session.scanMeal(_photo!);
    if (!mounted) return;
    setState(() {
      _result = result;
      _stage = _Stage.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scanBackground,
        body: switch (_stage) {
          _Stage.viewfinder => _Viewfinder(
            camera: _camera,
            denied: _cameraDenied,
            onCapture: _capture,
            onGallery: _pickFromGallery,
          ),
          _Stage.captured => _Captured(
            photo: _photo!,
            onRetake: _reset,
            onAnalyze: _analyze,
          ),
          _Stage.analyzing || _Stage.result => _Result(
            photo: _photo!,
            result: _result,
            onScanAnother: _reset,
            onDone: () {
              _reset();
              context.go('/home');
            },
          ),
        },
      ),
    );
  }
}

// ── viewfinder ──────────────────────────────────────────────────────────────

class _Viewfinder extends StatefulWidget {
  const _Viewfinder({
    required this.camera,
    required this.denied,
    required this.onCapture,
    required this.onGallery,
  });

  final CameraController? camera;
  final bool denied;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final live = camera != null && camera.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (live)
          // fill the screen, cropping the preview's long edge rather than letterboxing
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: camera.value.previewSize?.height ?? 1080,
                height: camera.value.previewSize?.width ?? 1920,
                child: CameraPreview(camera),
              ),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.1,
                colors: [Color(0xFF16305C), scanBackground],
              ),
            ),
          ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const _ScanHeader(),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Transform.scale(
                      scale:
                          1 + 0.025 * Curves.easeInOut.transform(_pulse.value),
                      child: const SizedBox.square(
                        dimension: 270,
                        child: CustomPaint(painter: ScanCornersPainter()),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.denied
                      ? 'Allow camera access in Settings, or pick a photo from your gallery.'
                      : 'Fit the whole plate in frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                // full width, or the stack shrinks to the shutter and the
                // gallery button falls off its edge
                width: double.infinity,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PositionedDirectional(
                      start: 34,
                      child: _RoundButton(
                        icon: Icons.photo_library_outlined,
                        size: 52,
                        onTap: widget.onGallery,
                      ),
                    ),
                    _Shutter(onTap: widget.onCapture),
                  ],
                ),
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanHeader extends StatelessWidget {
  const _ScanHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoMark(size: 24),
          SizedBox(width: 8),
          Text(
            'Scan your meal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Four rounded corner brackets in the logo's green → blue.
class ScanCornersPainter extends CustomPainter {
  const ScanCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    const arm = 54.0;
    const r = 18.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.brandLeaf,
          AppColors.brandAzure,
          AppColors.brandBlue,
        ],
      ).createShader(rect);

    final path = Path();
    for (final (cx, cy, sx, sy) in [
      (rect.left, rect.top, 1.0, 1.0),
      (rect.right, rect.top, -1.0, 1.0),
      (rect.left, rect.bottom, 1.0, -1.0),
      (rect.right, rect.bottom, -1.0, -1.0),
    ]) {
      path
        ..moveTo(cx, cy + sy * arm)
        ..lineTo(cx, cy + sy * r)
        ..arcToPoint(
          Offset(cx + sx * r, cy),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(cx + sx * arm, cy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedOpacity: 0.7,
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              AppColors.brandLeaf,
              AppColors.brandAzure,
              AppColors.brandBlue,
              AppColors.brandLeaf,
            ],
            transform: GradientRotation(-pi / 2),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: scanBackground,
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.size = 56});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedOpacity: 0.7,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _tile),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

// ── captured: the photo, before it's sent ───────────────────────────────────

class _Captured extends StatelessWidget {
  const _Captured({
    required this.photo,
    required this.onRetake,
    required this.onAnalyze,
  });

  final String photo;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MealImage(src: photo),
        // lifts the buttons off the photo
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.55, 1],
              colors: [Colors.transparent, Color(0xCC07122A)],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: MediaQuery.paddingOf(context).bottom + 26,
          child: Row(
            children: [
              _RoundButton(icon: Icons.refresh, onTap: onRetake),
              const SizedBox(width: 12),
              Expanded(
                child: _PillButton(
                  label: 'Analyze the food',
                  icon: Icons.auto_awesome,
                  onTap: onAnalyze,
                  gradient: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: gradient ? null : _tile,
          gradient: gradient ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── result ──────────────────────────────────────────────────────────────────

class _Result extends StatelessWidget {
  const _Result({
    required this.photo,
    required this.result,
    required this.onScanAnother,
    required this.onDone,
  });

  final String photo;
  final ScanResult? result; // null while analyzing
  final VoidCallback onScanAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final result = this.result;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MealImage(src: photo, height: 250, width: double.infinity),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (result) {
                null => const _Analyzing(),
                ScanSuccess(:final meal) => _Breakdown(meal: meal),
                ScanNotFood() => const _Problem(
                  icon: Icons.no_food_outlined,
                  title: "That doesn't look like food",
                  body:
                      'Try again with the meal centred and well lit. This scan was not counted.',
                ),
                ScanQuotaReached(:final limit) => _Problem(
                  icon: Icons.workspace_premium,
                  title: "You've used today's $limit scans",
                  body: 'Your scans reset at midnight. Pro gives you 8 a day.',
                ),
                ScanFailed() => const _Problem(
                  icon: Icons.cloud_off_outlined,
                  title: "We couldn't read that one",
                  body:
                      'Check your connection and try again. This scan was not counted.',
                ),
              },
            ),
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
              child: Row(
                children: [
                  Expanded(
                    child: _PillButton(
                      label: result is ScanSuccess
                          ? 'Scan another'
                          : 'Try again',
                      onTap: onScanAnother,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PillButton(
                      label: 'Done',
                      onTap: onDone,
                      gradient: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 38, color: AppColors.brandLeaf),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 21 / 15,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.brandLeaf,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Analyzing your meal…',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This takes a few seconds.',
            style: TextStyle(fontSize: 15, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            meal.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: '${meal.calories}',
              children: const [
                TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final macro in Macro.values) ...[
                if (macro != Macro.protein) const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _tile,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(macro.icon, size: 20, color: macro.color),
                        const SizedBox(height: 8),
                        Text(
                          '${meal.grams(macro)}g',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          macro.label,
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
