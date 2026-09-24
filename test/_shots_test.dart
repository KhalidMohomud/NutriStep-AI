// Temporary: renders the tab bar for a visual check. Deleted after use.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutristep_ai/main.dart';
import 'package:nutristep_ai/onboarding/steps.dart';
import 'package:nutristep_ai/plan/plan.dart';
import 'package:nutristep_ai/router.dart';
import 'package:nutristep_ai/screens/plan_includes_screen.dart';
import 'package:nutristep_ai/state/session.dart';

const out = '/private/tmp/claude-501/-Users-khaalid-dital-solutions-NutriStep-AI/481e8d68-ebbc-48fc-b7b3-372225269cac/scratchpad';
const fonts = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
  }
  await l.load();
}

void main() {
  final key = GlobalKey();
  Future<void> shot(WidgetTester t, String name) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/t-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('tab bar', (t) async {
    await _font('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
    await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    answers.addAll({'gender': 'male', 'goal': 'lose', 'activityLevel': 'moderate', 'dietPreference': 'classic'});
    draftPlan = formulaPlan(answersAsInput()!);
    session.signInDemo();
    await saveDraftProfile();
    await t.pumpWidget(RepaintBoundary(key: key, child: const NutriStepApp()));
    router.go('/home');
    await shot(t, '1-home');
    router.go('/scan');
    await shot(t, '2-scan');
    router.go('/profile');
    await shot(t, '3-profile');
  });
}
