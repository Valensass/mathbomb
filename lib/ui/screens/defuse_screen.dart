import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../game/defuse_engine.dart';
import '../../game/math_problem.dart';
import '../../services/app_state.dart';
import '../widgets/answer_pad.dart';
import '../widgets/arena_background.dart';
import '../widgets/bomb_device.dart';
import '../widgets/fx.dart';
import '../widgets/ui_kit.dart';
import 'result_screen.dart';

class DefuseScreen extends StatefulWidget {
  const DefuseScreen({super.key, this.seed});

  final int? seed;

  @override
  State<DefuseScreen> createState() => _DefuseScreenState();
}

class _DefuseScreenState extends State<DefuseScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final DefuseEngine _engine;
  late final AnimationController _shake;
  late final AnimationController _burst;
  late final AnimationController _flash;
  late final AnimationController _correctFlash;
  Timer? _timer;

  String _input = '';
  bool? _feedback;
  MathProblem? _feedbackProblem;
  bool _inputLocked = false;
  bool _showCleared = false;
  bool _exploding = false;
  bool _navigating = false;
  bool _paused = false;
  double _elapsed = 0;
  int _lastTickSecond = 99;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final seed =
        widget.seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    _engine = DefuseEngine(seed: seed)..start();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _correctFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _shake.dispose();
    _burst.dispose();
    _flash.dispose();
    _correctFlash.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_engine.over && !_paused) {
      _engine.paused = true;
      if (mounted) setState(() => _paused = true);
    }
  }

  void _onTick(Timer timer) {
    if (!mounted || _exploding || _paused) return;
    _engine.tick(0.1);
    if (!_engine.over) _elapsed += 0.1;
    final second = _engine.timeLeft.ceil();
    if (second != _lastTickSecond) {
      _lastTickSecond = second;
      if (second <= 10 && second > 0 && !_engine.over) {
        AudioManager.instance.playSfx('tick', volume: 0.55);
      }
    }
    setState(() {});
    if (_engine.over) _detonate();
  }

  void _digit(String value) {
    if (!_canType) return;
    if (_input.length >= 5) return;
    Haptics.tap();
    setState(() => _input += value);
  }

  void _backspace() {
    if (!_canType || _input.isEmpty) return;
    Haptics.tap();
    setState(() {
      _input = _input.substring(0, _input.length - 1);
    });
  }

  void _clear() {
    if (!_canType || _input.isEmpty) return;
    Haptics.tap();
    setState(() => _input = '');
  }

  bool get _canType =>
      !_inputLocked &&
      !_showCleared &&
      !_exploding &&
      !_paused &&
      !_engine.over;

  bool get _canSubmit => _canType && _input.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    final value = int.tryParse(_input);
    if (value == null) return;
    final shown = _engine.problem;
    final outcome = _engine.submit(value);
    if (outcome == null) return;

    if (outcome.correct) {
      AudioManager.instance.playSfx('cut', volume: 0.9);
      Haptics.success();
      _correctFlash.forward(from: 0);
      setState(() {
        _feedback = true;
        _feedbackProblem = shown;
        _inputLocked = true;
      });
      if (outcome.bombDefused) {
        AudioManager.instance.playSfx('defuse', volume: 0.9);
        setState(() => _showCleared = true);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted || _engine.over) return;
          _engine.nextBomb();
          setState(() {
            _showCleared = false;
            _feedback = null;
            _feedbackProblem = null;
            _inputLocked = false;
            _input = '';
          });
        });
      } else {
        Future.delayed(const Duration(milliseconds: 340), () {
          if (!mounted) return;
          setState(() {
            _feedback = null;
            _feedbackProblem = null;
            _inputLocked = false;
            _input = '';
          });
        });
      }
    } else {
      AudioManager.instance.playSfx('wrong', volume: 0.95);
      Haptics.error();
      _shake.forward(from: 0);
      _flash.forward(from: 0);
      setState(() {
        _feedback = false;
        _input = '';
      });
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted && !_engine.over) setState(() => _feedback = null);
      });
      if (outcome.runOver) _detonate();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final digit = _digitForKey(key);
    if (digit != null) {
      _digit(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String? _digitForKey(LogicalKeyboardKey key) {
    final map = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return map[key];
  }

  void _detonate() {
    if (_exploding) return;
    _exploding = true;
    _timer?.cancel();
    _engine.paused = true;
    AudioManager.instance.playSfx('explosion', volume: 1.0);
    Haptics.boom();
    _burst.forward(from: 0);
    _shake.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1350), _finish);
  }

  Future<void> _finish() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    final state = context.read<AppState>();
    final previousBest = state.stats.bestScore;
    final result = SoloRunResult(
      score: _engine.score,
      modules: _engine.modulesCut,
      correct: _engine.correctAnswers,
      wrong: _engine.wrongAnswers,
      bombs: _engine.bombsDefused,
      bestCombo: _engine.bestCombo,
      fastestMs: _engine.fastestCutMs,
      cleanBombs: _engine.cleanBombs,
      timeLeftMs: (_engine.timeLeft * 1000).round(),
      durationMs: (_elapsed * 1000).round(),
    );
    final medals = await state.recordSolo(result);
    if (!mounted) return;
    final data = ResultData(
      duel: false,
      won: false,
      draw: false,
      newBest: _engine.score > previousBest,
      score: _engine.score,
      modules: _engine.modulesCut,
      correct: _engine.correctAnswers,
      wrong: _engine.wrongAnswers,
      bestCombo: _engine.bestCombo,
      fastestMs: _engine.fastestCutMs,
      durationMs: result.durationMs,
      bombs: _engine.bombsDefused,
      timeLeftMs: result.timeLeftMs,
      medals: medals,
      endReason: _engine.endReason ?? 'timeout',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(data: data)),
    );
  }

  void _togglePause() {
    if (_engine.over) return;
    if (_paused) {
      setState(() {
        _paused = false;
        _engine.paused = false;
      });
    } else {
      setState(() {
        _paused = true;
        _engine.paused = true;
      });
    }
  }

  Future<void> _confirmQuit() async {
    final wasPaused = _engine.paused;
    _engine.paused = true;
    final leave = await confirmAction(
      context,
      title: context.t('game.quit'),
      body: context.t('game.quitBody'),
      confirm: context.t('game.quit'),
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      _timer?.cancel();
      Navigator.of(context).pop();
    } else if (!wasPaused) {
      _engine.paused = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final reduce = settings.reduceMotion;
    final time = _engine.timeLeft;
    final danger = time <= 10;
    final fraction = (time / DefuseEngine.maxFuse).clamp(0.0, 1.0);
    final shown = _feedbackProblem ?? _engine.problem;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final amp = reduce ? 0.0 : 10 * (1 - t);
              return Transform.translate(
                offset: Offset(
                  math.sin(t * 48) * amp,
                  math.cos(t * 39) * amp * 0.6,
                ),
                child: child,
              );
            },
            child: ArenaBackground(
              danger: danger,
              reduceMotion: reduce,
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _TopBar(
                          bomb: _engine.bombNumber,
                          module: math.min(
                            _engine.modulesCutInBomb + 1,
                            _engine.modulesPerBomb,
                          ),
                          modules: _engine.modulesPerBomb,
                          score: _engine.score,
                          paused: _paused,
                          onPause: _togglePause,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                          child: _FuseBar(
                            time: time,
                            fraction: fraction,
                            danger: danger,
                            combo: _engine.combo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final content = Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BombDevice(
                                        prompt: shown.prompt,
                                        fuseFraction: fraction,
                                        tier: _engine.tier,
                                        modulesCut: _engine.modulesCutInBomb,
                                        modulesTotal: _engine.modulesPerBomb,
                                        danger: danger,
                                        reduceMotion: reduce,
                                        dimmed: _showCleared,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 14,
                                            color: danger
                                                ? AppColors.red
                                                : AppColors.amber,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _feedback == true
                                                ? context.t('game.correct')
                                                : _feedback == false
                                                ? context.t('game.wrong')
                                                : context.t('game.typeAnswer'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.8,
                                              color: _feedback == true
                                                  ? AppColors.green
                                                  : _feedback == false
                                                  ? AppColors.red
                                                  : AppColors.text,
                                            ),
                                          ),
                                          const Spacer(),
                                          for (
                                            var i = 0;
                                            i < DefuseEngine.maxStrikes;
                                            i++
                                          )
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 5,
                                              ),
                                              child: Icon(
                                                i < _engine.strikes
                                                    ? Icons.close_rounded
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 16,
                                                color: i < _engine.strikes
                                                    ? AppColors.red
                                                    : AppColors.line,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      AnswerDisplay(
                                        value: _input,
                                        feedback: _feedback,
                                        dimmed: !_canType,
                                      ),
                                      const SizedBox(height: 10),
                                      IgnorePointer(
                                        ignoring: !_canType,
                                        child: AnswerPad(
                                          onDigit: _digit,
                                          onBackspace: _backspace,
                                          onClear: _clear,
                                          onSubmit: _submit,
                                          enabled: _canType,
                                          canSubmit: _canSubmit,
                                          reduceMotion: reduce,
                                          submitLabel: context.t('game.submit'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    context.t('game.fuseHint'),
                                    style: TextStyle(
                                      fontSize: 8,
                                      letterSpacing: 1.8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  2,
                                  16,
                                  12,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: box.maxWidth - 32,
                                    height: math.max(680, box.maxHeight - 14),
                                    child: content,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    // Wrong-answer red flash.
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _flash,
                        builder: (context, _) => FlashOverlay(t: _flash.value),
                      ),
                    ),
                    // Correct-answer green pulse.
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _correctFlash,
                        builder: (context, _) => IgnorePointer(
                          child: ColoredBox(
                            color: AppColors.green.withValues(
                              alpha:
                                  math.sin(_correctFlash.value * math.pi) *
                                  0.10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bomb cleared banner.
                    if (_showCleared)
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE607120D),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.green.withValues(alpha: 0.7),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.green.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 40,
                                  spreadRadius: -6,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.green,
                                  size: 44,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.t('game.defused'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.4,
                                    color: AppColors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${300 * _engine.bombsDefused}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Explosion.
                    if (_exploding)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _burst,
                          builder: (context, _) => BombBurst(t: _burst.value),
                        ),
                      ),
                    // Pause overlay.
                    if (_paused && !_exploding)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.72),
                          child: Center(
                            child: _PausePanel(
                              onResume: _togglePause,
                              onQuit: _confirmQuit,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.bomb,
    required this.module,
    required this.modules,
    required this.score,
    required this.paused,
    required this.onPause,
  });

  final int bomb;
  final int module;
  final int modules;
  final int score;
  final bool paused;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onPause,
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            color: AppColors.text,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tf('game.bomb', {'n': bomb}),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.text,
                ),
              ),
              Text(
                context.tf('game.module', {'a': module, 'b': modules}),
                style: hudLabel,
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(context.t('game.score'), style: hudLabel),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  formatInt(score, tr: context.l10n.isTr),
                  key: ValueKey(score),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuseBar extends StatelessWidget {
  const _FuseBar({
    required this.time,
    required this.fraction,
    required this.danger,
    required this.combo,
  });

  final double time;
  final double fraction;
  final bool danger;
  final int combo;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.red
        : fraction < 0.45
        ? AppColors.amber
        : AppColors.green;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(context.t('game.fuse'), style: hudLabel),
            const SizedBox(width: 8),
            Text(
              formatClock(time),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: color,
                shadows: danger
                    ? [
                        Shadow(
                          color: AppColors.red.withValues(alpha: 0.7),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
            ),
            const Spacer(),
            if (combo >= 2)
              ChipPill(
                label:
                    '${context.t('game.combo')} ×${(1 + 0.1 * math.min(combo, 20)).toStringAsFixed(1)}',
                icon: Icons.bolt_rounded,
                color: AppColors.amber,
                filled: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: AppColors.line.withValues(alpha: 0.45)),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PausePanel extends StatelessWidget {
  const _PausePanel({required this.onResume, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.panelHi,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_outline_rounded, size: 52),
          const SizedBox(height: 10),
          Text(
            context.t('game.paused'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 22),
          HazardButton(
            title: context.t('game.resume'),
            icon: Icons.play_arrow_rounded,
            onTap: onResume,
          ),
          const SizedBox(height: 10),
          HazardButton(
            title: context.t('game.quit'),
            icon: Icons.logout_rounded,
            accent: AppColors.red,
            primary: false,
            onTap: onQuit,
          ),
        ],
      ),
    );
  }
}
