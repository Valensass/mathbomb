import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../services/app_state.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _icons = [
    Icons.dialpad_rounded,
    Icons.local_fire_department_rounded,
    Icons.bolt_rounded,
    Icons.sports_kabaddi_rounded,
  ];

  static const _colors = [
    AppColors.cyan,
    AppColors.red,
    AppColors.amber,
    AppColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const count = 4;
    final last = _page == count - 1;
    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(title: context.t('howto.title')),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    AudioManager.instance.playSfx('click', volume: 0.4);
                  },
                  itemBuilder: (context, i) {
                    final n = i + 1;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(26, 10, 26, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _colors[i].withValues(alpha: 0.10),
                              border: Border.all(
                                color: _colors[i].withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _colors[i].withValues(alpha: 0.16),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: Icon(_icons[i], size: 44, color: _colors[i]),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            '0$n',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: _colors[i],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.t('howto.p${n}Title'),
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.t('howto.p${n}Body'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.6,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(flex: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < count; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.amber
                                  : AppColors.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (_page > 0)
                          Expanded(
                            child: HazardButton(
                              title: context.t('howto.back'),
                              icon: Icons.arrow_back_rounded,
                              primary: false,
                              onTap: () => _controller.previousPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                        if (_page > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: HazardButton(
                            title: last
                                ? context.t('howto.done')
                                : context.t('howto.next'),
                            icon: last
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            onTap: () {
                              if (last) {
                                Navigator.of(context).maybePop();
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
