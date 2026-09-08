// COLLAGE=1 flutter test test/collage_render_test.dart → test/golden/collage_p1.jpg
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sendit/core/core.dart';
import 'package:sendit/ui/collage.dart';

Future<void> _fonts() async {
  for (final (fam, files) in [('EBGaramond', ['assets/fonts/EBGaramond.ttf']), ('NotoSansSC', ['assets/fonts/NotoSansSC-sub.ttf'])]) {
    final l = FontLoader(fam);
    for (final f in files) {
      l.addFont(Future.value(ByteData.view((await File(f).readAsBytes()).buffer)));
    }
    await l.load();
  }
}

void main() {
  testWidgets('render collage from mixed 9:16 / 16:9 samples', skip: Platform.environment['COLLAGE'] != '1', (t) async {
    await t.runAsync(() async {
      await _fonts();
      final dir = Directory('${Directory.systemTemp.path}/sendit_mixed')..createSync(recursive: true);
      final rnd = Random(7);
      final paths = <String>[];
      for (var n = 1; n <= 16; n++) {
        final landscape = n == 4 || n == 9 || n == 15;
        final w = landscape ? 640 : 360, h = landscape ? 360 : 640;
        final im = img.Image(width: w, height: h);
        final hue = (n * 37) % 360;
        img.fill(im, color: img.ColorRgb8(120 + rnd.nextInt(100), 140 + (hue % 90), 120 + (hue % 120)));
        img.fillCircle(im, x: w ~/ 2, y: h ~/ 2, radius: w ~/ 4, color: img.ColorRgb8(250, 244, 230));
        final p = '${dir.path}/${n.toString().padLeft(3, '0')}.png';
        File(p).writeAsBytesSync(img.encodePng(im));
        paths.add(p);
      }
      final ix = const ImageIndexer().index(paths);
      final pages = await const CollageBuilder().build(images: ix, numbers: ix.byNumber.keys.toList()..sort(), title: '第 2 轮可扣');
      expect(pages.length, 2);
      for (var i = 0; i < pages.length; i++) {
        File('test/golden/collage_p${i + 1}.jpg').writeAsBytesSync(pages[i]);
      }
    });
  });
}
