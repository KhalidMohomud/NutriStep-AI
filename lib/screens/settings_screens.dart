import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';

const _groupedBackground = Color(0xFFF3F5F4);

const languages = <(String, String)>[
  ('en', 'English'),
  ('so', 'Soomaali'),
  ('ar', 'العربية'),
];

String languageName(String code) =>
    languages.firstWhere((l) => l.$1 == code, orElse: () => languages.first).$2;

String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 20 → "8 PM", 9 → "9 AM".
String hourLabel(int h) =>
    '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';

// ── shared pieces ─────────────────────────────────────────────────────────────

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _groupedBackground,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.ink,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 14,
              height: 19 / 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    ),
  );
}

/// A wrap of selectable pills — the one control every preference here uses.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onPick,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, label) in options)
            Pressable(
              onTap: () => onPick(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: value == selected
                      ? AppColors.brandGreenTint
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: value == selected
                        ? AppColors.brandGreen
                        : AppColors.border,
                    width: value == selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: value == selected
                        ? AppColors.brandGreenDark
                        : AppColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── preferences ───────────────────────────────────────────────────────────────

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _Page(
        title: 'Preferences',
        children: [
          const _Label(
            'Daily step goal',
            hint: 'The ring on Home fills up as you get there.',
          ),
          _Choices<int>(
            options: [
              for (final g in [5000, 7500, 10000, 12500, 15000])
                (g, _thousands(g)),
            ],
            selected: session.stepGoal,
            onPick: (g) => session.updatePreferences(stepGoal: g),
          ),
          const _Label(
            'Evening step summary',
            hint: 'A notification with how far you walked today.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Step reminders',
                      style: TextStyle(fontSize: 16, color: AppColors.ink),
                    ),
                  ),
                  Switch.adaptive(
                    value: session.remindersOn,
                    activeTrackColor: AppColors.brandGreen,
                    onChanged: session.setReminders,
                  ),
                ],
              ),
            ),
          ),
          if (session.remindersOn) ...[
            const SizedBox(height: 12),
            _Choices<int>(
              options: [
                for (final h in [18, 19, 20, 21, 22]) (h, hourLabel(h)),
              ],
              selected: session.reminderHour,
              onPick: (h) => session.updatePreferences(reminderHour: h),
            ),
          ],
          const _Label(
            'Language',
            hint:
                'Meal names from your scans and the AI coach answer in this language.',
          ),
          _Choices<String>(
            options: languages,
            selected: session.language,
            onPick: (code) => session.updatePreferences(language: code),
          ),
        ],
      ),
    );
  }
}

/// The same language choice as Preferences, from the Profile row.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Language',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Meal names and the AI coach answer in this language.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            for (final (code, name) in languages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  name,
                  style: const TextStyle(fontSize: 17, color: AppColors.ink),
                ),
                trailing: session.language == code
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.brandGreen,
                      )
                    : const Icon(
                        Icons.circle_outlined,
                        color: AppColors.disabled,
                      ),
                onTap: () {
                  session.updatePreferences(language: code);
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

// ── feedback ──────────────────────────────────────────────────────────────────

Future<void> showFeedbackSheet(BuildContext context) {
  final text = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, set) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(sheet).bottom +
              MediaQuery.paddingOf(sheet).bottom +
              16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send feedback',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'A bug, an idea, a wrong calorie count — we read every message.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              onChanged: (_) => set(() {}),
              textCapitalization: TextCapitalization.sentences,
              cursorColor: AppColors.brandGreen,
              decoration: InputDecoration(
                hintText: 'What should we know?',
                counterText: '',
                filled: true,
                fillColor: AppColors.card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.brandGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Send',
              onPressed: text.text.trim().isEmpty
                  ? null
                  : () async {
                      Navigator.of(sheet).pop();
                      try {
                        await session.sendFeedback(text.text);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Thanks — feedback sent.'),
                          ),
                        );
                      } catch (e) {
                        debugPrint('Feedback failed: $e');
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't send it. Check your connection and try again.",
                            ),
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Pro ───────────────────────────────────────────────────────────────────────

/// What Pro will include. Purchases need the App Store / Play Console products
/// first, so the button says so instead of pretending.
Future<void> showProSheet(BuildContext context) {
  const rows = <(IconData, String, String, String)>[
    (Icons.photo_camera_outlined, 'Meal scans', '2 a day', '8 a day'),
    (Icons.auto_awesome, 'AI coach questions', '3 a day', '50 a day'),
    (Icons.directions_walk, 'Step tracking', '✓', '✓'),
    (Icons.block, 'No ads', '—', '✓'),
  ];
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'NutriStep Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: SizedBox()),
                        SizedBox(
                          width: 74,
                          child: Text(
                            'Free',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 74,
                          child: Text(
                            'Pro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final (icon, label, free, pro) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: AppColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 74,
                            child: Text(
                              free,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 74,
                            child: Text(
                              pro,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandGreenDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const PrimaryButton(label: 'Coming soon', onPressed: null),
            const SizedBox(height: 8),
            const Text(
              'Subscriptions open when NutriStep launches on the App Store and Google Play.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── legal ─────────────────────────────────────────────────────────────────────

class LegalScreen extends StatelessWidget {
  const LegalScreen.privacy({super.key}) : privacy = true;
  const LegalScreen.terms({super.key}) : privacy = false;

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final sections = privacy ? _privacy : _terms;
    return _Page(
      title: privacy ? 'Privacy Policy' : 'Terms of Service',
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 6, 22, 0),
          child: Text(
            'Last updated: October 2026',
            style: TextStyle(fontSize: 13, color: AppColors.textFaint),
          ),
        ),
        for (final (heading, body) in sections)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Plain-language drafts of what the app actually does with data. Have them
// reviewed before the store submission.
const _privacy = <(String, String)>[
  (
    'What we collect',
    'Your email address and password (stored securely by our login provider), the answers you give during setup '
        '(gender, date of birth, height, weight, goal, activity and diet), the meal photos you scan with the '
        'nutrition we estimate from them, your daily step count if you connect it, your preferences, and any '
        'feedback you send.',
  ),
  (
    'How we use it',
    'To build your daily targets, estimate the calories and macros in your meals, show your progress and steps, '
        'answer your questions in the AI coach, and send the reminders you switch on. We do not sell your data '
        'or use it for advertising.',
  ),
  (
    'AI processing',
    'Meal photos and coach questions are sent to Google\'s Gemini service to be analysed. Only what is needed for '
        'that request is sent, together with your targets and recent meals for the coach. Your name and email are '
        'not sent.',
  ),
  (
    'Where it is stored',
    'Your account, meals and photos are stored with Supabase. Each account can only read its own data. Photos are '
        'kept in private storage and are shown to you only through short-lived links.',
  ),
  (
    'Steps and health data',
    'Steps are read from Apple Health, Health Connect or your phone\'s step sensor only after you allow it, are '
        'used only to show your activity in the app, and are never shared for advertising.',
  ),
  (
    'Your choices',
    'You can change your details, turn reminders off, and disconnect step counting at any time. Delete your account '
        'from Profile to erase your account, meals, photos and steps for good.',
  ),
  (
    'Contact',
    'Questions about privacy? Use Send feedback in the app and we will reply.',
  ),
];

const _terms = <(String, String)>[
  (
    'Using NutriStep AI',
    'NutriStep AI helps you track food and activity. You need an account to use it, and you are responsible for '
        'keeping your login safe.',
  ),
  (
    'Not medical advice',
    'Calorie and nutrition estimates come from AI and can be wrong — always check them. The app and its AI coach '
        'give general information, not medical advice. Talk to a doctor or dietitian before changing your diet, '
        'especially if you are pregnant or have a medical condition.',
  ),
  (
    'Free and Pro',
    'The free plan includes a daily number of meal scans and coach questions. Pro, when available, adds more. '
        'Subscriptions are billed and renewed by the App Store or Google Play and can be cancelled there.',
  ),
  (
    'Fair use',
    'Do not misuse the service, try to access other people\'s data, or upload content you do not have the right to '
        'share.',
  ),
  (
    'Changes and ending',
    'We may update the app and these terms. You can stop using NutriStep AI and delete your account at any time.',
  ),
  ('Contact', 'Use Send feedback in the app.'),
];
