import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../game/duel_engine.dart';
import '../../game/math_problem.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../widgets/answer_pad.dart';
import '../widgets/arena_background.dart';
import '../widgets/bomb_device.dart';
import '../widgets/ui_kit.dart';
import 'result_screen.dart';

class DuelConfig {
  const DuelConfig({
    required this.bot,
    required this.seed,
    required this.opponentId,
    required this.opponentName,
    required this.opponentTag,
    required this.opponentRating,
    this.difficulty = 'normal',
    this.matchId,
  });

  final bool bot;
  final int seed;
  final String opponentId;
  final String opponentName;
  final String opponentTag;
  final int opponentRating;
  final String difficulty;
  final String? matchId;

  static int seedNow() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  factory DuelConfig.bot({required String difficulty}) {
    const ratings = {'easy': 850, 'normal': 1050, 'hard': 1250, 'master': 1450};
    return DuelConfig(
      bot: true,
      seed: seedNow(),
      opponentId: 'cpu',
      opponentName: 'CPU ${difficulty.toUpperCase()}',
      opponentTag: 'CPU',
      opponentRating: ratings[difficulty] ?? 1050,
      difficulty: difficulty,
    );
  }

  factory DuelConfig.online(OnlineMatchStart start) => DuelConfig(
    bot: false,
    seed: start.seed,
    opponentId: start.opponentId,
    opponentName: start.opponentName,
    opponentTag: start.opponentTag,
    opponentRating: start.opponentRating,
    matchId: start.matchId,
  );

  DuelConfig rematch() => DuelConfig(
    bot: bot,
    seed: seedNow(),
    opponentId: opponentId,
    opponentName: opponentName,
    opponentTag: opponentTag,
    opponentRating: opponentRating,
    difficulty: difficulty,
    matchId: null,
  );
}

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key, required this.config});

  final DuelConfig config;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen>
    with SingleTickerProviderStateMixin {
  late final String _myId;
  TurnDuelEngine? _engine;
  TurnBot? _bot;
  Timer? _ticker;
  Timer? _botTimer;
  StreamSubscription<Map<String, dynamic>>? _sub;
  late final AnimationController _shake;

  MathProblem? _problem;
  int _myScore = 0;
  int _oppScore = 0;
  bool _myTurn = false;
  String _input = '';
  bool? _feedback;
  bool _feedbackIsMine = true;
  bool _locked = false;
  bool _ended = false;
  bool _recorded = false;
  bool _intro = true;
  bool _waitingForTurn = true;
  double _timeLeft = TurnDuelEngine.turnSeconds.toDouble();
  DateTime? _deadline;
  DateTime? _turnStartedAt;
  double _elapsed = 0;
  int _myCorrect = 0;
  int _myWrong = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _fastestMs = 0;
  String? _emote;
  Timer? _emoteTimer;
  Map<String, dynamic>? _pendingTurn;
  int _secondsSinceSync = 0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _myId = state.profile?.id ?? 'me';
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    if (widget.config.bot) {
      _engine = TurnDuelEngine(
        seed: widget.config.seed,
        firstId: _myId,
        secondId: widget.config.opponentId,
      );
      _bot = TurnBot(
        difficulty: widget.config.difficulty,
        seed: widget.config.seed,
      );
      _problem = _engine!.problem;
    } else {
      final net = context.read<MultiplayerService>();
      _sub = net.events.listen(_onNetEvent);
      _pendingTurn = net.pendingTurn;
    }

    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _intro = false;
      });
      if (widget.config.bot) {
        _beginMyTurn();
      } else if (_pendingTurn != null) {
        _applyServerTurn(_pendingTurn!);
      }
    });
    AudioManager.instance.playSfx('tick', volume: 0.5);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _botTimer?.cancel();
    _emoteTimer?.cancel();
    _sub?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _tick(Timer timer) {
    if (!mounted || _ended || _intro) return;
    _elapsed += 0.1;
    final deadline = _deadline;
    if (deadline != null) {
      final next = deadline.difference(DateTime.now()).inMilliseconds / 1000;
      _timeLeft = next.clamp(0, TurnDuelEngine.turnSeconds.toDouble());
    }
    if (widget.config.bot && _myTurn && !_locked && _timeLeft <= 0) {
      _timeoutMyTurn();
    }
    if (!widget.config.bot) {
      _secondsSinceSync++;
      if (_secondsSinceSync > 60 &&
          !context.read<MultiplayerService>().isOnline) {
        _finishOnline(won: false, draw: false, reason: 'disconnected');
      }
    }
    setState(() {});
  }

  // ---------------------------------------------------------------- bot flow

  void _beginMyTurn() {
    final engine = _engine!;
    if (engine.finished) {
      _finishBot();
      return;
    }
    setState(() {
      _myTurn = true;
      _waitingForTurn = false;
      _problem = engine.problem;
      _input = '';
      _feedback = null;
      _locked = false;
      _timeLeft = TurnDuelEngine.turnSeconds.toDouble();
      _turnStartedAt = DateTime.now();
      _deadline = DateTime.now().add(
        const Duration(seconds: TurnDuelEngine.turnSeconds),
      );
    });
  }

  void _beginBotTurn() {
    final engine = _engine!;
    if (engine.finished) {
      _finishBot();
      return;
    }
    setState(() {
      _myTurn = false;
      _problem = engine.problem;
      _input = '';
      _feedback = null;
      _locked = false;
      _timeLeft = TurnDuelEngine.turnSeconds.toDouble();
      _turnStartedAt = DateTime.now();
      _deadline = DateTime.now().add(
        const Duration(seconds: TurnDuelEngine.turnSeconds),
      );
    });
    final think = _bot!.thinkMs(engine.turnIndex);
    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: think), _botAnswer);
  }

  void _botAnswer() {
    if (!mounted || _ended) return;
    final engine = _engine!;
    final correct = _bot!.answersCorrectly();
    final problem = engine.problem;
    final value = correct ? problem.answer : problem.answer + 1;
    engine.submit(widget.config.opponentId, value);
    _syncScores();
    setState(() {
      _feedback = correct;
      _feedbackIsMine = false;
      _input = '';
    });
    if (engine.finished) {
      _finishBot();
      return;
    }
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _beginMyTurn();
    });
  }

  void _timeoutMyTurn() {
    final engine = _engine!;
    engine.passTurn();
    _syncScores();
    setState(() {
      _feedback = false;
      _feedbackIsMine = true;
      _locked = true;
      _myWrong++;
      _combo = 0;
    });
    if (engine.finished) {
      _finishBot();
      return;
    }
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _beginBotTurn();
    });
  }

  void _syncScores() {
    final engine = _engine!;
    _myScore = engine.scoreOf(_myId);
    _oppScore = engine.scoreOf(widget.config.opponentId);
    _myCorrect = engine.correctOf(_myId);
    _myWrong = engine.wrongOf(_myId);
    _bestCombo = engine.bestComboOf(_myId);
    final fastest = engine.fastestOf(_myId);
    if (fastest > 0) _fastestMs = fastest;
  }

  // ------------------------------------------------------------- online flow

  void _onNetEvent(Map<String, dynamic> msg) {
    _secondsSinceSync = 0;
    switch (msg['t']) {
      case 'match.turn':
        if (_intro) {
          _pendingTurn = msg;
        } else {
          _applyServerTurn(msg);
        }
      case 'match.score':
        final scores = (msg['scores'] as Map?)?.cast<String, dynamic>();
        if (scores != null) {
          setState(() {
            _myScore = (scores[_myId] as num?)?.toInt() ?? _myScore;
            _oppScore =
                (scores[widget.config.opponentId] as num?)?.toInt() ??
                _oppScore;
          });
        }
      case 'match.answer':
        final playerId = (msg['playerId'] ?? '').toString();
        final correct = msg['correct'] == true;
        if (playerId != _myId) {
          setState(() {
            _feedback = correct;
            _feedbackIsMine = false;
          });
          Future.delayed(const Duration(milliseconds: 1100), () {
            if (mounted && !_ended) setState(() => _feedback = null);
          });
        }
      case 'match.timeout':
        final playerId = (msg['playerId'] ?? '').toString();
        if (mounted) {
          showSnack(
            context,
            playerId == _myId
                ? context.t('duel.timeUp')
                : context.t('duel.opponentTimeUp'),
          );
        }
      case 'match.emote':
        final kind = (msg['kind'] ?? '').toString();
        if (kind.isNotEmpty) _showEmote(kind);
      case 'match.end':
        final winnerId = (msg['winnerId'] ?? '').toString();
        final draw = winnerId == 'draw';
        _finishOnline(
          won: winnerId == _myId && !draw,
          draw: draw,
          reason: 'server',
        );
      case 'error':
        final message = (msg['message'] ?? '').toString();
        if (message.isNotEmpty && mounted) showSnack(context, message);
    }
  }

  void _applyServerTurn(Map<String, dynamic> msg) {
    if (_ended) return;
    final playerId = (msg['playerId'] ?? '').toString();
    final index = (msg['index'] as num?)?.toInt() ?? 0;
    final deadlineMs = (msg['deadline'] as num?)?.toInt();
    setState(() {
      _myTurn = playerId == _myId;
      _waitingForTurn = false;
      _problem = DuelSequence.problemFor(widget.config.seed, index);
      _input = '';
      _feedback = null;
      _locked = false;
      _timeLeft = TurnDuelEngine.turnSeconds.toDouble();
      _turnStartedAt = DateTime.now();
      _deadline = deadlineMs != null
          ? DateTime.fromMillisecondsSinceEpoch(deadlineMs)
          : DateTime.now().add(
              const Duration(seconds: TurnDuelEngine.turnSeconds),
            );
    });
  }

  // ---------------------------------------------------------------- actions

  bool get _canType =>
      !_ended &&
      !_intro &&
      _myTurn &&
      !_locked &&
      !_waitingForTurn &&
      _problem != null;

  bool get _canSubmit => _canType && _input.isNotEmpty;

  void _digit(String value) {
    if (!_canType) return;
    if (_input.length >= 5) return;
    Haptics.tap();
    setState(() => _input += value);
  }

  void _backspace() {
    if (!_canType || _input.isEmpty) return;
    Haptics.tap();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _clear() {
    if (!_canType || _input.isEmpty) return;
    Haptics.tap();
    setState(() => _input = '');
  }

  void _submit() {
    if (!_canSubmit) return;
    final value = int.tryParse(_input);
    if (value == null) return;
    final problem = _problem!;
    final correct = problem.isCorrect(value);
    final elapsedMs = _turnStartedAt == null
        ? 0
        : DateTime.now().difference(_turnStartedAt!).inMilliseconds;
    if (widget.config.bot) {
      _engine!.submit(_myId, value, elapsedMs: elapsedMs);
      _syncScores();
      if (correct) {
        _combo++;
        AudioManager.instance.playSfx('cut', volume: 0.85);
        Haptics.success();
      } else {
        _combo = 0;
        AudioManager.instance.playSfx('wrong', volume: 0.9);
        Haptics.error();
        _shake.forward(from: 0);
      }
      setState(() {
        _feedback = correct;
        _feedbackIsMine = true;
        _locked = true;
        _input = '';
      });
      if (_engine!.finished) {
        _finishBot();
      } else {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _beginBotTurn();
        });
      }
    } else {
      if (correct) {
        _combo++;
        _bestCombo = math.max(_bestCombo, _combo);
        _myCorrect++;
        _fastestMs = _fastestMs == 0
            ? elapsedMs
            : math.min(_fastestMs, elapsedMs);
        AudioManager.instance.playSfx('cut', volume: 0.85);
        Haptics.success();
      } else {
        _myWrong++;
        _combo = 0;
        AudioManager.instance.playSfx('wrong', volume: 0.9);
        Haptics.error();
        _shake.forward(from: 0);
      }
      setState(() {
        _feedback = correct;
        _feedbackIsMine = true;
        _locked = true;
        _input = '';
      });
      context.read<MultiplayerService>().reportAnswer(correct);
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

  void _showEmote(String kind) {
    final symbol = switch (kind) {
      'gg' => 'GG',
      'fire' => '🔥',
      'shock' => '😬',
      _ => kind,
    };
    _emoteTimer?.cancel();
    setState(() => _emote = symbol);
    _emoteTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _emote = null);
    });
  }

  void _sendEmote(String kind) {
    if (widget.config.bot) return;
    context.read<MultiplayerService>().sendEmote(kind);
    _showEmote(kind);
  }

  // ---------------------------------------------------------------- results

  void _finishBot() {
    final engine = _engine!;
    final won = engine.winnerId == _myId;
    final draw = engine.draw;
    _finish(won: won, draw: draw, reason: 'finished');
  }

  Future<void> _finishOnline({
    required bool won,
    required bool draw,
    required String reason,
  }) async {
    if (_recorded) return;
    _recorded = true;
    await _finish(won: won, draw: draw, reason: reason);
  }

  Future<void> _finish({
    required bool won,
    required bool draw,
    required String reason,
  }) async {
    if (_ended || !mounted) return;
    _ended = true;
    _ticker?.cancel();
    _botTimer?.cancel();
    setState(() {});
    final state = context.read<AppState>();
    final previousBest = state.stats.bestScore;
    final result = DuelRunResult(
      won: won,
      draw: draw,
      rated: !widget.config.bot,
      score: _myScore * 300 + _myCorrect * 50,
      modules: _myScore,
      correct: _myCorrect,
      wrong: _myWrong,
      bestCombo: _bestCombo,
      fastestMs: _fastestMs,
      durationMs: (_elapsed * 1000).round(),
      opponentName: widget.config.opponentName,
      opponentRating: widget.config.opponentRating,
    );
    final award = await state.recordDuel(result);
    if (!mounted) return;
    if (won) {
      AudioManager.instance.playSfx('win', volume: 0.9);
    } else if (!draw) {
      AudioManager.instance.playSfx('lose', volume: 0.8);
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final data = ResultData(
      duel: true,
      won: won,
      draw: draw,
      newBest: result.score > previousBest,
      score: result.score,
      modules: _myScore,
      correct: _myCorrect,
      wrong: _myWrong,
      bestCombo: _bestCombo,
      fastestMs: _fastestMs,
      durationMs: result.durationMs,
      bombs: 0,
      timeLeftMs: (_timeLeft * 1000).round(),
      medals: award.newMedals,
      endReason: reason,
      opponentName: widget.config.opponentName,
      ratingDelta: award.ratingDelta,
      newRating: award.newRating,
      rematchConfig: widget.config.bot ? widget.config.rematch() : null,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(data: data)),
    );
  }

  Future<void> _confirmLeave() async {
    if (_ended) return;
    final leave = await confirmAction(
      context,
      title: context.t('duel.leave'),
      body: context.t('game.quitBody'),
      confirm: context.t('duel.leave'),
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      _ticker?.cancel();
      _botTimer?.cancel();
      if (!widget.config.bot) {
        context.read<MultiplayerService>().forfeit();
        context.read<MultiplayerService>().leaveRoom();
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reduce = state.settings.reduceMotion;
    final danger = _timeLeft <= 4;
    final problem = _problem;
    final banner = _feedback == null
        ? (_myTurn
              ? context.t('duel.yourTurn')
              : context.t('duel.opponentTurn'))
        : _feedback!
        ? (_feedbackIsMine
              ? context.t('duel.youScored')
              : context.t('duel.opponentScored'))
        : (_feedbackIsMine
              ? context.t('duel.youMissed')
              : context.t('duel.opponentMissed'));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final amp = reduce ? 0.0 : 8 * (1 - t);
              return Transform.translate(
                offset: Offset(math.sin(t * 44) * amp, 0),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 14, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _confirmLeave,
                                icon: const Icon(Icons.close_rounded),
                              ),
                              Text(
                                'FACE-OFF',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.6,
                                ),
                              ),
                              const Spacer(),
                              ChipPill(
                                label: context.tf('duel.firstTo', {
                                  'n': TurnDuelEngine.pointsToWin,
                                }).toUpperCase(),
                                color: AppColors.amber,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ScoreCard(
                                  label: context.t('duel.you'),
                                  score: _myScore,
                                  active: _myTurn && !_ended,
                                  color: AppColors.amber,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ScoreCard(
                                  label: widget.config.opponentName
                                      .toUpperCase(),
                                  score: _oppScore,
                                  active: !_myTurn && !_ended,
                                  color: AppColors.cyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _myTurn
                                      ? AppColors.amber
                                      : AppColors.cyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_myTurn
                                                  ? AppColors.amber
                                                  : AppColors.cyan)
                                              .withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  banner.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                    color: _feedback == true
                                        ? AppColors.green
                                        : _feedback == false
                                        ? AppColors.red
                                        : AppColors.text,
                                  ),
                                ),
                              ),
                              Text(
                                '${_timeLeft.ceil()}s',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: danger
                                      ? AppColors.red
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (_timeLeft / TurnDuelEngine.turnSeconds)
                                  .clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: AppColors.line.withValues(
                                alpha: 0.5,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                danger ? AppColors.red : AppColors.amber,
                              ),
                            ),
                          ),
                        ),
                        if (_emote != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ChipPill(
                              label: '$_emote  ${widget.config.opponentName}',
                              color: AppColors.cyan,
                              filled: true,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final content = Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  BombDevice(
                                    prompt: problem?.prompt ?? '…',
                                    fuseFraction:
                                        (_timeLeft / TurnDuelEngine.turnSeconds)
                                            .clamp(0.0, 1.0),
                                    tier: problem?.tier ?? 1,
                                    modulesCut: _myScore,
                                    modulesTotal: TurnDuelEngine.pointsToWin,
                                    danger: danger,
                                    reduceMotion: reduce,
                                    dimmed: !_myTurn || _ended,
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnswerDisplay(
                                        value: _input,
                                        feedback: _feedback,
                                        dimmed: !_canType,
                                      ),
                                      const SizedBox(height: 8),
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
                                        ),
                                      ),
                                      if (!widget.config.bot) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _EmoteButton(
                                              symbol: 'GG',
                                              onTap: () => _sendEmote('gg'),
                                            ),
                                            const SizedBox(width: 10),
                                            _EmoteButton(
                                              symbol: '🔥',
                                              onTap: () => _sendEmote('fire'),
                                            ),
                                            const SizedBox(width: 10),
                                            _EmoteButton(
                                              symbol: '😬',
                                              onTap: () => _sendEmote('shock'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              );
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: box.maxWidth - 32,
                                    height: math.max(700, box.maxHeight - 10),
                                    child: content,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_intro)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.7, end: 1.05),
                              duration: const Duration(milliseconds: 500),
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.t('duel.ready'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    context.t('duel.go'),
                                    style: const TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_intro && _waitingForTurn && !_ended)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                      ),
                    if (_ended)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.75),
                          child: Center(
                            child: Text(
                              _myScore > _oppScore
                                  ? context.t('result.victory')
                                  : _myScore == _oppScore
                                  ? context.t('result.draw')
                                  : context.t('result.defeat'),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: AppColors.amber,
                              ),
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.active,
    required this.color,
  });

  final String label;
  final int score;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.8) : AppColors.line,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: active ? color : AppColors.muted,
              ),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
              color: active ? color : AppColors.text,
            ),
          ),
          Text(
            '/${TurnDuelEngine.pointsToWin}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmoteButton extends StatelessWidget {
  const _EmoteButton({required this.symbol, required this.onTap});

  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            symbol,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
