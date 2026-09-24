import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../state/backend.dart';
import '../state/reminders.dart';
import '../state/session.dart';
import '../state/steps.dart';
import '../theme/app_colors.dart';
import '../theme/macros.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import 'plan_reveal_screen.dart';

const _groupedBackground = Color(0xFFF3F5F4);
const _chevron = Color(0xFFC2C2C9);
const _destructive = Color(0xFFE5484D);

const _months = [
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

/// Placeholder rows open this, so a live row and a not-yet-built one look alike
/// but never pretend to work.
void _soon(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog.adaptive(
    title: const Text('Coming soon'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('OK'),
      ),
    ],
  ),
);

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _confirmDelete(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog.adaptive(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently removes your profile, your targets and every meal you have logged. It cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialog).pop();
            // Supabase: the delete-account Edge Function goes here, then sign out
            session.signOut().then((_) {
              if (context.mounted) context.go('/');
            });
          },
          child: const Text('Delete', style: TextStyle(color: _destructive)),
        ),
      ],
    ),
  );

  // stays mounted behind the other tabs, so it listens for a regenerated plan
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final profile = session.profile;
    final since = profile?.memberSince;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: _groupedBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // clear the floating tab bar (the Scaffold folds it into this padding)
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 20,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _UserCard(onTap: () => _editName(context)),
            const SizedBox(height: 12),
            _UpgradeCard(onTap: () => _soon(context)),

            const _SectionTitle('Goals & Tracking'),
            _Card(
              children: [
                _Row(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Daily targets',
                  value: profile != null
                      ? '${formatThousands(profile.plan.calories)} cal'
                      : null,
                  onTap: () => context.push('/profile/details'),
                ),
                _Row(
                  icon: Icons.flag_outlined,
                  label: 'Goals & current weight',
                  value: profile != null
                      ? '${profile.input.weightKg.toStringAsFixed(0)} kg, goal ${profile.input.targetWeightKg.toStringAsFixed(0)}'
                      : null,
                  onTap: () => context.push('/profile/details'),
                ),
                _Row(
                  icon: Icons.favorite_border,
                  label: isIOS ? 'Apple Health' : 'Step counting',
                  value: switch (session.stepsStatus) {
                    StepsStatus.connected => 'On',
                    StepsStatus.denied => 'Blocked',
                    StepsStatus.unavailable => 'Not available',
                    StepsStatus.notConnected => 'Connect',
                  },
                  onTap: switch (session.stepsStatus) {
                    StepsStatus.notConnected => session.connectSteps,
                    StepsStatus.denied => openAppSettings,
                    _ => null,
                  },
                ),
                _Row(
                  icon: Icons.notifications_none_rounded,
                  label: 'Step reminders',
                  value: session.remindersOn
                      ? '${StepReminders.summaryHour - 12} PM daily'
                      : 'Off',
                  onTap: () => session.setReminders(!session.remindersOn),
                ),
              ],
            ),

            const _SectionTitle('Account'),
            _Card(
              children: [
                _Row(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since',
                  value: since != null
                      ? '${_months[since.month - 1]} ${since.year}'
                      : '—',
                ),
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Personal Details',
                  onTap: () => context.push('/profile/details'),
                ),
                _Row(
                  icon: Icons.tune,
                  label: 'Preferences',
                  onTap: () => _soon(context),
                ),
                _Row(
                  icon: Icons.translate,
                  label: 'Language',
                  value: 'English',
                  onTap: () => _soon(context),
                ),
              ],
            ),

            const _SectionTitle('About'),
            _Card(
              children: [
                _Row(
                  icon: Icons.back_hand_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _soon(context),
                ),
                _Row(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _soon(context),
                ),
              ],
            ),

            const _SectionTitle('Support'),
            _Card(
              children: [
                _Row(
                  icon: Icons.chat_bubble_outline,
                  label: 'Send feedback',
                  onTap: () => _soon(context),
                ),
              ],
            ),

            const SizedBox(height: 26),
            _Card(
              children: [
                _Row(
                  icon: Icons.logout,
                  label: 'Sign out',
                  onTap: () async {
                    await session.signOut();
                    if (context.mounted) context.go('/');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Card(
              children: [
                _Row(
                  icon: Icons.delete_outline,
                  label: 'Delete your account',
                  tint: _destructive,
                  // real deletion needs the delete-account Edge Function (service role);
                  // until then, don't pretend
                  onTap: () =>
                      backendEnabled ? _soon(context) : _confirmDelete(context),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(26, 10, 26, 0),
              child: Text(
                'Deleting your account removes your profile and meal history for good.',
                style: TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  color: Color(0xFFA0A0A8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

/// Bottom sheet to set or change the name shown on the profile.
Future<void> _editName(BuildContext context) {
  final controller = TextEditingController(text: session.displayName ?? '');
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) {
      var saving = false;
      return StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          // lift above the keyboard
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewInsetsOf(sheet).bottom +
                MediaQuery.paddingOf(sheet).bottom +
                20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E2E7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your name',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is how NutriStep greets you.',
                style: TextStyle(fontSize: 15, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                maxLength: 40,
                cursorColor: AppColors.brandGreen,
                onChanged: (_) => setSheet(() {}),
                style: const TextStyle(fontSize: 17, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'e.g. Khalid Mohamud',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.card,
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.textFaint,
                  ),
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
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Save',
                loading: saving,
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () async {
                        setSheet(() => saving = true);
                        try {
                          await session.updateDisplayName(controller.text);
                          if (sheet.mounted) Navigator.of(sheet).pop();
                        } catch (e) {
                          setSheet(() => saving = false);
                          if (sheet.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Couldn't save your name. Try again.",
                                ),
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = session.displayName;
    final email = session.email;

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // gradient ring around the avatar, like the logo's sweep
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandGreenTint,
                ),
                child: name == null
                    ? const Icon(
                        Icons.person,
                        size: 30,
                        color: AppColors.brandGreen,
                      )
                    : Text(
                        _initials(name),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandGreenDark,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreenTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Free plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandGreenDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name ?? 'Your profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    email ?? 'Tap to edit your name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 20, color: _chevron),
          ],
        ),
      ),
    );
  }
}

/// NutriStep's Free → Pro pitch (PLAN.md: 2 vs 8 scans a day, AI Coach, no ads).
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.brandGreen,
              AppColors.brandAzure,
              AppColors.brandBlue,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '8 scans a day, AI Nutrition Coach and no ads.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 19 / 14,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textFaint,
      ),
    ),
  );
}

/// White grouped card; rows after the first get a hairline divider.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 54,
                color: Color(0xFFF1F1F3),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.tint = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          SizedBox(width: 24, child: Icon(icon, size: 22, color: tint)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, color: tint),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(fontSize: 16, color: AppColors.textFaint),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: _chevron),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      highlightColor: const Color(0xFFF7F7F9),
      child: body,
    );
  }
}

// ── personal details ────────────────────────────────────────────────────────

class PersonalDetailsScreen extends StatelessWidget {
  const PersonalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final plan = profile?.plan;

    return Scaffold(
      backgroundColor: _groupedBackground,
      body: SafeArea(
        child: ListView(
          // clear the floating tab bar (the Scaffold folds it into this padding)
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 20,
          ),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22, top: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Pressable(
                  onTap: () => context.pop(),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Text(
                'Personal details',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (plan != null) ...[
              const _SectionTitle('Daily targets'),
              _Card(
                children: [
                  _Row(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Calories',
                    value: '${formatThousands(plan.calories)} cal',
                  ),
                  for (final m in Macro.values)
                    _Row(
                      icon: m.icon,
                      label: m.label,
                      value: '${plan.grams(m)} g',
                      tint: AppColors.ink,
                    ),
                ],
              ),
            ],
            if (profile != null) ...[
              const _SectionTitle('Body & goal'),
              _Card(
                children: [
                  _Row(
                    icon: Icons.height,
                    label: 'Height',
                    value: '${profile.input.heightCm.toStringAsFixed(0)} cm',
                  ),
                  _Row(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: '${profile.input.weightKg.toStringAsFixed(1)} kg',
                  ),
                  _Row(
                    icon: Icons.flag_outlined,
                    label: 'Goal weight',
                    value:
                        '${profile.input.targetWeightKg.toStringAsFixed(1)} kg',
                  ),
                  _Row(
                    icon: Icons.trending_down,
                    label: 'Goal',
                    value: '${_capitalize(profile.input.goal)} weight',
                  ),
                  _Row(
                    icon: Icons.restaurant,
                    label: 'Diet',
                    value: _capitalize(profile.input.dietPreference),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Pressable(
                // redoing the questionnaire regenerates the targets; the account stays signed in
                onTap: () => context.go('/onboarding/gender'),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brandGreen, width: 1.5),
                  ),
                  child: const Text(
                    'Update my plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
