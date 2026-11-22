import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';

const _emblems = <IconData>[
  Icons.bolt_rounded,
  Icons.radar_rounded,
  Icons.science_rounded,
  Icons.memory_rounded,
  Icons.local_fire_department_rounded,
  Icons.diamond_rounded,
];

const _avatarColors = <Color>[
  Color(0xFFFFC43D),
  Color(0xFF3BE8D2),
  Color(0xFFFF5A5A),
  Color(0xFF7A8CFF),
  Color(0xFF62E58C),
  Color(0xFFFF8AD8),
];

IconData emblemIcon(int index) => _emblems[index % _emblems.length];

Color avatarColor(int index) => _avatarColors[index % _avatarColors.length];

String formatInt(int value, {bool tr = false}) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final sep = tr ? '.' : ',';
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(sep);
    b.write(digits[i]);
  }
  return negative ? '−$b' : b.toString();
}

String formatClock(double seconds) {
  final clamped = seconds.clamp(0, 9999);
  final m = clamped ~/ 60;
  final s = clamped % 60;
  return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
}

class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.panel,
    this.glow,
    this.borderColor,
    this.onTap,
    this.radius = AppRadius.m,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? glow;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, AppColors.bgDeep, 0.35)!],
        ),
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow!.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class HazardButton extends StatefulWidget {
  const HazardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent = AppColors.amber,
    this.primary = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool primary;
  final Widget? trailing;

  @override
  State<HazardButton> createState() => _HazardButtonState();
}

class _HazardButtonState extends State<HazardButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final accentDark = widget.accent == AppColors.amber
        ? AppColors.amberDeep
        : Color.lerp(widget.accent, Colors.black, 0.35)!;
    final bg = widget.primary
        ? LinearGradient(
            colors: [widget.accent, accentDark],
          )
        : LinearGradient(
            colors: [AppColors.panelHi, AppColors.panel],
          );
    final fg = widget.primary ? const Color(0xFF161000) : AppColors.text;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.title,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap?.call();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.975 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: bg,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: widget.primary
                      ? widget.accent.withValues(alpha: 0.7)
                      : AppColors.line,
                ),
                boxShadow: widget.primary
                    ? [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.22),
                          blurRadius: 26,
                          offset: const Offset(0, 8),
                          spreadRadius: -6,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.primary
                          ? const Color(0x33000000)
                          : widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.primary
                            ? const Color(0x33000000)
                            : widget.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.primary ? fg : widget.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: fg,
                            height: 1.1,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: widget.primary
                                  ? fg.withValues(alpha: 0.62)
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  widget.trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: fg.withValues(alpha: 0.65),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
                color: AppColors.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.emblem,
    required this.colorIndex,
    this.size = 48,
    this.ring = true,
  });

  final int emblem;
  final int colorIndex;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.28), AppColors.panelHi],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: ring ? color.withValues(alpha: 0.65) : AppColors.line,
          width: ring ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 18),
        ],
      ),
      child: Icon(emblemIcon(emblem), color: color, size: size * 0.46),
    );
  }
}

class ChipPill extends StatelessWidget {
  const ChipPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.cyan,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.text,
    this.caption,
  });

  final String label;
  final String value;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hudLabel,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class ScreenTopBar extends StatelessWidget {
  const ScreenTopBar({
    super.key,
    required this.title,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.t('common.back'),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
        ),
        ?action,
        const SizedBox(width: 6),
      ],
    );
  }
}

void showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  String? cancel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancel ?? context.t('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.redDeep : AppColors.amber,
            foregroundColor: destructive ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
