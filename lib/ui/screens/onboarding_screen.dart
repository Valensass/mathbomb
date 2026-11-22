import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../services/app_state.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = TextEditingController();
  String _lang = 'system';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _lang = state.settings.language;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.t('onboard.error'));
      AudioManager.instance.playSfx('wrong', volume: 0.6);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    await state.updateSettings(state.settings.copyWith(language: _lang));
    await state.completeOnboarding(name);
    AudioManager.instance.playSfx('defuse', volume: 0.55);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.amber, AppColors.amberDeep],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.35),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF1A1200),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'BOMB MATH',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: ChipPill(
                          label: context.t('onboard.kicker'),
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  context.t('onboard.title'),
                  style: const TextStyle(
                    fontSize: 46,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 46, height: 4, color: AppColors.amber),
                const SizedBox(height: 18),
                Text(
                  context.t('onboard.body'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  context.t('onboard.name'),
                  style: hudLabel.copyWith(color: AppColors.text),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLength: 14,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _start(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: context.t('onboard.nameHint'),
                    counterText: '',
                    prefixIcon: const Icon(
                      Icons.badge_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  context.t('onboard.language'),
                  style: hudLabel.copyWith(color: AppColors.text),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _LangChip(
                      label: context.t('settings.system'),
                      selected: _lang == 'system',
                      onTap: () => setState(() => _lang = 'system'),
                    ),
                    const SizedBox(width: 8),
                    _LangChip(
                      label: 'ENGLISH',
                      selected: _lang == 'en',
                      onTap: () => setState(() => _lang = 'en'),
                    ),
                    const SizedBox(width: 8),
                    _LangChip(
                      label: 'TÜRKÇE',
                      selected: _lang == 'tr',
                      onTap: () => setState(() => _lang = 'tr'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                HazardButton(
                  key: const ValueKey('onboarding-start'),
                  title: context.t('onboard.start'),
                  subtitle: context.t('app.sub'),
                  icon: Icons.power_settings_new_rounded,
                  onTap: _busy ? null : _start,
                  trailing: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    context.t('app.tagline'),
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.amber.withValues(alpha: 0.12)
                : AppColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.amber : AppColors.line,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: selected ? AppColors.amber : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
