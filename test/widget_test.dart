import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bomb_math/app.dart';
import 'package:bomb_math/services/app_state.dart';

Future<AppState> _quietState() async {
  SharedPreferences.setMockInitialValues({});
  final state = await AppState.load();
  await state.updateSettings(
    state.settings.copyWith(serverUrl: '', music: false, sfx: false),
  );
  return state;
}

void main() {
  testWidgets('onboarding screen renders the call-sign form', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await _quietState();
    await tester.pumpWidget(BombMathApp(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('START DEFUSING'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('BOMB MATH'), findsWidgets);
  });

  testWidgets('an onboarded player lands on the home screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await _quietState();
    await state.completeOnboarding('TESTER');

    await tester.pumpWidget(BombMathApp(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.onboarded, isTrue);
    expect(state.profile?.name, 'TESTER');
    expect(find.text('DEFUSE'), findsOneWidget);
    expect(find.text('FACE-OFF'), findsOneWidget);
    expect(find.text('TESTER'), findsOneWidget);
  });
}
