import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';

const _suggestions = [
  'What should I eat for dinner?',
  'Am I getting enough protein?',
  'How am I doing this week?',
  'A healthy snack under 200 kcal?',
];

/// A conversation with the AI coach, which knows the user's targets, today's
/// meals, this week's calories and today's steps (the ai-coach Edge Function).
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _status; // "2 of 3 free questions left today", or why it stopped
  bool _blocked = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || session.coachThinking) return;
    _input.clear();
    _toBottom();
    final reply = await session.askCoach(text);
    if (!mounted) return;
    setState(() {
      switch (reply) {
        case CoachAnswer(:final used, :final limit):
          _status = used != null && limit != null
              ? '${limit - used} of $limit questions left today'
              : null;
        case CoachQuotaReached(:final limit):
          _blocked = true;
          _status =
              "You've used today's $limit questions. They reset at midnight — Pro gives you 50 a day.";
        case CoachFailed():
          _input.text = text; // keep what they typed
          _status =
              "Couldn't reach the coach. Check your connection and try again.";
      }
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final turns = session.coachTurns;
        final thinking = session.coachThinking;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const _Header(),
                const Divider(height: 1, color: AppColors.divider),
                Expanded(
                  child: turns.isEmpty && !thinking
                      ? _Welcome(onPick: _send)
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          children: [
                            for (final t in turns) _Bubble(turn: t),
                            if (thinking) const _Typing(),
                          ],
                        ),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Text(
                      _status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _blocked ? AppColors.error : AppColors.textFaint,
                      ),
                    ),
                  ),
                _InputBar(
                  controller: _input,
                  enabled: !thinking && !_blocked,
                  onSend: () => _send(_input.text),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    'AI can make mistakes. Not medical advice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
          const _Avatar(size: 40),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Knows your meals, steps and targets',
                  style: TextStyle(fontSize: 13, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: LogoMark(size: size * 0.62),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final name = session.displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        const Center(child: _Avatar(size: 76)),
        const SizedBox(height: 18),
        Text(
          name == null ? 'Hi 👋' : 'Hi $name 👋',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Ask me anything about what you eat. I can see today's meals, your targets and your steps.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 21 / 15,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 26),
        for (final s in _suggestions) ...[
          Pressable(
            onTap: () => onPick(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppColors.brandGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.north_east,
                    size: 16,
                    color: AppColors.textFaint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final CoachTurn turn;

  @override
  Widget build(BuildContext context) {
    final mine = turn.fromUser;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.brandGradient : null,
        color: mine ? null : AppColors.card,
        border: mine ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: SelectableText(
        turn.text,
        style: TextStyle(
          fontSize: 15,
          height: 21 / 15,
          color: mine ? Colors.white : AppColors.ink,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[const _Avatar(size: 28), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Avatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _dots,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Opacity(
                        // each dot peaks a third of a beat after the last
                        opacity:
                            0.3 +
                            0.7 * (1 - ((_dots.value * 3 - i) % 3).clamp(0, 1)),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.brandGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              cursorColor: AppColors.brandGreen,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Ask your coach…',
                counterText: '',
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppColors.brandGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: enabled ? onSend : null,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.4,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
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
