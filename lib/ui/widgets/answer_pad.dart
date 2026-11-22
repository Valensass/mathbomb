import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';

/// Read-out for the value the player is typing.
class AnswerDisplay extends StatelessWidget {
  const AnswerDisplay({
    super.key,
    required this.value,
    this.feedback,
    this.dimmed = false,
  });

  final String value;

  /// null | true (correct) | false (wrong)
  final bool? feedback;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final accent = feedback == null
        ? AppColors.cyan
        : feedback!
        ? AppColors.green
        : AppColors.red;
    final text = value.isEmpty ? '?' : value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF04120D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: feedback == null ? 0.35 : 0.9),
          width: feedback == null ? 1.2 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: feedback == null ? 0.08 : 0.22),
            blurRadius: 22,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            '=',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: value.isEmpty
                      ? accent.withValues(alpha: 0.35)
                      : dimmed
                      ? accent.withValues(alpha: 0.5)
                      : accent,
                  shadows: value.isEmpty
                      ? null
                      : [
                          Shadow(
                            color: accent.withValues(alpha: 0.6),
                            blurRadius: 14,
                          ),
                        ],
                ),
              ),
            ),
          ),
          Container(
            width: 2,
            height: 34,
            margin: const EdgeInsets.only(right: 18),
            color: accent.withValues(alpha: value.isEmpty ? 0.15 : 0.6),
          ),
        ],
      ),
    );
  }
}

/// Numeric keypad used by both game modes.
class AnswerPad extends StatelessWidget {
  const AnswerPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
    this.enabled = true,
    this.canSubmit = true,
    this.submitLabel,
    this.reduceMotion = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final bool enabled;
  final bool canSubmit;
  final String? submitLabel;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      [
        _key(context, '1'),
        _key(context, '2'),
        _key(context, '3'),
      ],
      [
        _key(context, '4'),
        _key(context, '5'),
        _key(context, '6'),
      ],
      [
        _key(context, '7'),
        _key(context, '8'),
        _key(context, '9'),
      ],
      [
        _key(context, 'C', label: 'C', onTap: onClear),
        _key(context, '0'),
        _key(
          context,
          '⌫',
          icon: Icons.backspace_outlined,
          onTap: onBackspace,
        ),
      ],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  Expanded(child: row[i]),
                  if (i != row.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 4),
        _SubmitButton(
          enabled: enabled && canSubmit,
          label: submitLabel ?? context.t('game.submit'),
          reduceMotion: reduceMotion,
          onTap: onSubmit,
        ),
      ],
    );
  }

  Widget _key(
    BuildContext context,
    String value, {
    String? label,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final content = icon != null
        ? Icon(icon, size: 22, color: AppColors.text)
        : Text(
            label ?? value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: value == 'C' ? AppColors.muted : AppColors.text,
            ),
          );
    return _PadKey(
      enabled: enabled,
      onTap: enabled ? (onTap ?? () => onDigit(value)) : null,
      reduceMotion: reduceMotion,
      child: content,
    );
  }
}

class _PadKey extends StatefulWidget {
  const _PadKey({
    required this.child,
    required this.onTap,
    required this.enabled,
    required this.reduceMotion,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool reduceMotion;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _down = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _down = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() => _down = false);
                widget.onTap!.call();
              },
        child: AnimatedScale(
          scale: _down && !widget.reduceMotion ? 0.94 : 1,
          duration: const Duration(milliseconds: 70),
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.35,
            duration: const Duration(milliseconds: 130),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.label,
    required this.onTap,
    required this.reduceMotion,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.amber, AppColors.amberDeep],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.amber.withValues(alpha: 0.25),
                        blurRadius: 22,
                        spreadRadius: -6,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cut_rounded, size: 20, color: Color(0xFF1A1200)),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    color: Color(0xFF1A1200),
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

