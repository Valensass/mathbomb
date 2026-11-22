import 'package:flutter/services.dart';

/// Haptic feedback gated by the user's settings.
abstract final class Haptics {
  static bool enabled = true;

  static void tap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  static void impact() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void success() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void error() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void boom() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
