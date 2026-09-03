// 生成 App 图标：ICON=1 flutter test --update-goldens test/icon_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const ink = Color(0xFF492D22);
const cream = Color(0xFFF2E3C6);
const paper = Color(0xFFFCF8F0);

Future<void> _fonts() async {
  final l = FontLoader('EBGaramond');
  final b = await File('assets/fonts/EBGaramond.ttf').readAsBytes();
  l.addFont(Future.value(ByteData.view(b.buffer)));
  await l.load();
}

TextStyle garamond(double size, {Color color = ink, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: 'EBGaramond', fontSize: size, color: color, fontWeight: w, height: 1);

/// A 字母章：大 S + 双线
Widget iconA() => Container(
      color: cream,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 150, child: Text('S', style: garamond(720))),
          Positioned(bottom: 168, child: Column(children: [
            Container(width: 300, height: 14, color: ink),
            const SizedBox(height: 22),
            Container(width: 300, height: 6, color: ink),
          ])),
        ],
      ),
    );

/// B 火漆印：墨棕圆章 + 奶油 S + 细环
Widget iconB() => Container(
      color: cream,
      child: Center(
        child: Container(
          width: 700,
          height: 700,
          decoration: const BoxDecoration(color: ink, shape: BoxShape.circle),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 610,
                height: 610,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cream, width: 6)),
              ),
              Positioned(top: 88, child: Text('S', style: garamond(520, color: cream))),
            ],
          ),
        ),
      ),
    );

/// C 号码牌：细框 + 01
Widget iconC() => Container(
      color: cream,
      child: Center(
        child: Container(
          width: 720,
          height: 720,
          decoration: BoxDecoration(border: Border.all(color: ink, width: 14), borderRadius: BorderRadius.circular(60)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(top: 60, child: Text('№', style: garamond(120))),
              Positioned(top: 170, child: Text('01', style: garamond(430))),
            ],
          ),
        ),
      ),
    );

/// macOS：圆角 + 透明边距（macOS 图标惯例）
Widget macVariant(Widget inner) => Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: SizedBox(
        width: 832,
        height: 832,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(186),
          child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1024, height: 1024, child: inner)),
        ),
      ),
    );

void main() {
  final skip = Platform.environment['ICON'] != '1';

  Future<void> render(WidgetTester t, Widget w, String name) async {
    await t.binding.setSurfaceSize(const Size(1024, 1024));
    t.view.physicalSize = const Size(1024, 1024);
    t.view.devicePixelRatio = 1;
    await t.runAsync(_fonts);
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: RepaintBoundary(child: w)));
    await t.pumpAndSettle();
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('icon/$name.png'));
  }

  testWidgets('A', skip: skip, (t) => render(t, iconA(), 'icon_a'));
  testWidgets('B', skip: skip, (t) => render(t, iconB(), 'icon_b'));
  testWidgets('C', skip: skip, (t) => render(t, iconC(), 'icon_c'));
  testWidgets('A mac', skip: skip, (t) => render(t, macVariant(iconA()), 'icon_a_mac'));
  testWidgets('B mac', skip: skip, (t) => render(t, macVariant(iconB()), 'icon_b_mac'));
  testWidgets('C mac', skip: skip, (t) => render(t, macVariant(iconC()), 'icon_c_mac'));
}
