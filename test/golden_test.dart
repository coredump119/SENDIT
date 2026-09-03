// 视觉检查：把四个页面按桌面 / 手机尺寸渲染成 PNG
// GOLDEN=1 flutter test --update-goldens test/golden_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/ui/app_state.dart';
import 'package:sendit/ui/scope.dart';
import 'package:sendit/ui/shell.dart';
import 'package:sendit/ui/theme.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await File(f).readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  await load('EBGaramond', ['assets/fonts/EBGaramond.ttf']);
  await load('SpaceMono', ['assets/fonts/SpaceMono-Regular.ttf', 'assets/fonts/SpaceMono-Bold.ttf']);
  await load('NotoSansSC', ['assets/fonts/NotoSansSC-sub.ttf']);
}

ThemeData _themeWithCjk() => Tone.theme();

Future<AppState> _state() async {
  final state = AppState();
  await state.loadFolder('${Directory.current.path}/samples/demo_images');
  state.setChatText(File('samples/chat_sample.txt').readAsStringSync());
  state.parseChat();
  state.setDefaultLimit(5);
  state.setReservedText('1');
  state.setStartTimeText('22:00');
  return state;
}

void main() {
  final skip = Platform.environment['GOLDEN'] != '1';

  Future<void> render(WidgetTester tester, Size size, String prefix, bool desktop, {bool web = false}) async {
    AppState.desktopOverride = desktop;
    AppState.webOverride = web;
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    late AppState state;
    await tester.runAsync(() async {
      await _loadFonts();
      state = await _state();
    });
    Widget app() => AppScope(state: state, child: MaterialApp(debugShowCheckedModeBanner: false, theme: _themeWithCjk(), home: const Shell()));
    for (final (stage, name) in [(Stage.images, '01_images'), (Stage.chat, '02_chat'), (Stage.result, '03_result'), (Stage.export, '04_export')]) {
      state.goTo(stage);
      await tester.pumpWidget(app());
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
      await expectLater(find.byType(Shell), matchesGoldenFile('golden/${prefix}_$name.png'));
    }
    AppState.desktopOverride = null;
    AppState.webOverride = null;
  }

  testWidgets('desktop', skip: skip, (t) => render(t, const Size(1280, 820), 'desktop', true));
  testWidgets('mobile', skip: skip, (t) => render(t, const Size(390, 844), 'mobile', false));
  testWidgets('web', skip: skip, (t) => render(t, const Size(1280, 820), 'web', false, web: true));

  testWidgets('round2', skip: skip, (t) async {
    AppState.desktopOverride = true;
    await t.binding.setSurfaceSize(const Size(1280, 820));
    t.view.physicalSize = const Size(1280, 820);
    t.view.devicePixelRatio = 1;
    late AppState state;
    await t.runAsync(() async {
      await _loadFonts();
      state = await _state();
      state.startNextRound();
      state.setChatText('麋鹿\n2026/08/31 20:00\n4 8 10\n\n 蓝莓\n2026/08/31 20:00\n11 12 13 22');
      state.parseChat();
    });
    Widget app() => AppScope(state: state, child: MaterialApp(debugShowCheckedModeBanner: false, theme: _themeWithCjk(), home: const Shell()));
    for (final (stage, name) in [(Stage.chat, '02_chat'), (Stage.result, '03_result'), (Stage.export, '04_export')]) {
      state.goTo(stage);
      await t.pumpWidget(app());
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await t.pumpAndSettle();
      await expectLater(find.byType(Shell), matchesGoldenFile('golden/round2_$name.png'));
    }
    AppState.desktopOverride = null;
  });
}
