import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models.dart';

class MedalContext {
  const MedalContext({
    required this.stats,
    required this.friends,
    required this.rating,
  });

  final GameStats stats;
  final int friends;
  final int rating;
}

class MedalDef {
  const MedalDef({
    required this.id,
    required this.titleEn,
    required this.descEn,
    required this.titleTr,
    required this.descTr,
    required this.icon,
    required this.color,
    required this.target,
    required this.progress,
  });

  final String id;
  final String titleEn;
  final String descEn;
  final String titleTr;
  final String descTr;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(MedalContext) progress;

  String title(bool tr) => tr ? titleTr : titleEn;
  String desc(bool tr) => tr ? descTr : descEn;

  int clampProgress(MedalContext ctx) {
    final p = progress(ctx);
    if (p < 0) return 0;
    return p > target ? target : p;
  }

  static const List<MedalDef> all = [
    MedalDef(
      id: 'first_cut',
      titleEn: 'First Solve',
      descEn: 'Solve your first module.',
      titleTr: 'İlk Çözüm',
      descTr: 'İlk modülü çöz.',
      icon: Icons.cut_rounded,
      color: AppColors.cyan,
      target: 1,
      progress: _modules,
    ),
    MedalDef(
      id: 'rookie',
      titleEn: 'Demolition Rookie',
      descEn: 'Defuse your first bomb.',
      titleTr: 'Çaylak',
      descTr: 'İlk bombayı etkisizleştir.',
      icon: Icons.shield_outlined,
      color: AppColors.green,
      target: 1,
      progress: _bombs,
    ),
    MedalDef(
      id: 'bomb_squad',
      titleEn: 'Bomb Squad',
      descEn: 'Defuse 10 bombs.',
      titleTr: 'Bomba Ekibi',
      descTr: '10 bomba etkisizleştir.',
      icon: Icons.workspaces_rounded,
      color: AppColors.amber,
      target: 10,
      progress: _bombs,
    ),
    MedalDef(
      id: 'chain',
      titleEn: 'Chain Reaction',
      descEn: 'Reach a 10× combo.',
      titleTr: 'Zincirleme',
      descTr: '10× komboya ulaş.',
      icon: Icons.bolt_rounded,
      color: AppColors.amber,
      target: 10,
      progress: _combo,
    ),
    MedalDef(
      id: 'neuro',
      titleEn: 'Neurosurgeon',
      descEn: 'Reach a 25× combo.',
      titleTr: 'Beyin Cerrahı',
      descTr: '25× komboya ulaş.',
      icon: Icons.psychology_rounded,
      color: AppColors.red,
      target: 25,
      progress: _combo,
    ),
    MedalDef(
      id: 'clean_sweep',
      titleEn: 'Clean Sweep',
      descEn: 'Clear a bomb without a wrong answer.',
      titleTr: 'Temiz Temizlik',
      descTr: 'Hiç yanlış cevap vermeden bir bombayı bitir.',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.cyan,
      target: 1,
      progress: _cleanBombs,
    ),
    MedalDef(
      id: 'flawless_five',
      titleEn: 'Flawless Five',
      descEn: 'Clear 5 bombs without a wrong answer.',
      titleTr: 'Kusursuz Beş',
      descTr: 'Yanlışsız 5 bomba bitir.',
      icon: Icons.verified_rounded,
      color: AppColors.green,
      target: 5,
      progress: _cleanBombs,
    ),
    MedalDef(
      id: 'speed_demon',
      titleEn: 'Speed Demon',
      descEn: 'Solve a module in under 2 seconds.',
      titleTr: 'Hız Şeytanı',
      descTr: 'Bir modülü 2 saniyeden kısa sürede çöz.',
      icon: Icons.speed_rounded,
      color: AppColors.amber,
      target: 1,
      progress: _fastCut,
    ),
    MedalDef(
      id: 'time_lord',
      titleEn: 'Time Lord',
      descEn: 'Finish a run with more than 30 s left.',
      titleTr: 'Zaman Efendisi',
      descTr: 'Koşuyu 30 sn’den fazla süreyle bitir.',
      icon: Icons.hourglass_bottom_rounded,
      color: AppColors.cyan,
      target: 1,
      progress: _timeLeft,
    ),
    MedalDef(
      id: 'century',
      titleEn: 'Century',
      descEn: 'Score 10,000 in one run.',
      titleTr: 'Yüzlük',
      descTr: 'Tek koşuda 10.000 puan yap.',
      icon: Icons.workspace_premium_rounded,
      color: AppColors.amber,
      target: 10000,
      progress: _bestScore,
    ),
    MedalDef(
      id: 'survivor',
      titleEn: 'Survivor',
      descEn: 'Defuse 5 bombs in a single run.',
      titleTr: 'Hayatta Kalan',
      descTr: 'Tek koşuda 5 bomba etkisizleştir.',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.red,
      target: 5,
      progress: _bestBombs,
    ),
    MedalDef(
      id: 'duelist',
      titleEn: 'Duelist',
      descEn: 'Win a Face-Off.',
      titleTr: 'Düellocu',
      descTr: 'Bir Face-Off kazan.',
      icon: Icons.sports_kabaddi_rounded,
      color: AppColors.cyan,
      target: 1,
      progress: _duelWins,
    ),
    MedalDef(
      id: 'rivalry',
      titleEn: 'Rivalry',
      descEn: 'Win 10 Face-Offs.',
      titleTr: 'Rekabet',
      descTr: '10 Face-Off kazan.',
      icon: Icons.military_tech_rounded,
      color: AppColors.amber,
      target: 10,
      progress: _duelWins,
    ),
    MedalDef(
      id: 'sharpshooter',
      titleEn: 'Sharpshooter',
      descEn: '95% accuracy over 100+ answers.',
      titleTr: 'Keskin Nişancı',
      descTr: '100+ cevapta %95 isabet.',
      icon: Icons.gps_fixed_rounded,
      color: AppColors.green,
      target: 95,
      progress: _accuracy,
    ),
    MedalDef(
      id: 'marathon',
      titleEn: 'Marathon',
      descEn: 'Play 50 solo runs.',
      titleTr: 'Maraton',
      descTr: '50 koşu oyna.',
      icon: Icons.timer_rounded,
      color: AppColors.steel,
      target: 50,
      progress: _runs,
    ),
    MedalDef(
      id: 'social',
      titleEn: 'Social',
      descEn: 'Add your first friend.',
      titleTr: 'Sosyal',
      descTr: 'İlk arkadaşını ekle.',
      icon: Icons.group_add_rounded,
      color: AppColors.cyan,
      target: 1,
      progress: _friends,
    ),
    MedalDef(
      id: 'contender',
      titleEn: 'Contender',
      descEn: 'Reach a rating of 1200.',
      titleTr: 'Meydan Okuyan',
      descTr: '1200 puana ulaş.',
      icon: Icons.trending_up_rounded,
      color: AppColors.green,
      target: 1200,
      progress: _rating,
    ),
    MedalDef(
      id: 'elite',
      titleEn: 'Elite',
      descEn: 'Reach a rating of 1400.',
      titleTr: 'Elit',
      descTr: '1400 puana ulaş.',
      icon: Icons.diamond_rounded,
      color: AppColors.amber,
      target: 1400,
      progress: _rating,
    ),
  ];

  static MedalDef? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}

int _modules(MedalContext c) => c.stats.modulesCut;
int _bombs(MedalContext c) => c.stats.bombsDefused;
int _combo(MedalContext c) => c.stats.bestCombo;
int _cleanBombs(MedalContext c) => c.stats.cleanBombs;
int _bestScore(MedalContext c) => c.stats.bestScore;
int _bestBombs(MedalContext c) => c.stats.bestBombs;
int _duelWins(MedalContext c) => c.stats.duelsWon;
int _runs(MedalContext c) => c.stats.runs;
int _friends(MedalContext c) => c.friends;
int _rating(MedalContext c) => c.rating;

int _fastCut(MedalContext c) =>
    c.stats.fastestMs > 0 && c.stats.fastestMs <= 2000 ? 1 : 0;

int _timeLeft(MedalContext c) => c.stats.bestTimeLeftMs >= 30000 ? 1 : 0;

int _accuracy(MedalContext c) {
  final pct = (c.stats.accuracy * 100).round();
  return c.stats.answers >= 100 ? pct : pct.clamp(0, 94);
}
