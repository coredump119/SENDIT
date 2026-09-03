import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sendit/core/core.dart';
import 'package:sendit/platform/ops.dart' as ops;
import 'package:sendit/platform/picked.dart';

/// 最小合法 PNG（1x1），够 File.copy 用
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  test('按人复制到子文件夹', () async {
    final tmp = await Directory.systemTemp.createTemp('sendit_');
    final src = Directory(p.join(tmp.path, 'src'))..createSync();
    for (var i = 1; i <= 6; i++) {
      File(p.join(src.path, '${i.toString().padLeft(3, '0')}.png')).writeAsBytesSync(_png);
    }
    final ix = const ImageIndexer().index((await ops.listFolder(src.path)).map((e) => e.id).toList());
    expect(ix.maxNumber, 6);

    const parser = NumberParser(6);
    final ms = [
      parser.parse(const RawMessage(sender: '张三', time: null, order: 0, text: '1 2 3')),
      parser.parse(const RawMessage(sender: 'a/b', time: null, order: 1, text: '4')),
    ];
    final a = Allocator().allocate(ms, const Rules(maxNumber: 6));

    final out = p.join(tmp.path, 'out');
    final ExportSummary sum = await ops.exportFolders(allocation: a, images: ix, outputDir: out);

    expect(sum.filesCopied, 6);
    expect(sum.folders, ['张三 (3张) 1-3', 'a_b (1张) 4', '_未认领 (2张)']);
    expect(File(p.join(out, '张三 (3张) 1-3', '01.png')).existsSync(), isTrue);
    expect(File(p.join(out, 'a_b (1张) 4', '04.png')).existsSync(), isTrue);
    expect(File(p.join(out, '_未认领 (2张)', '06.png')).existsSync(), isTrue);
    expect(File(p.join(out, '_分配公告.txt')).readAsStringSync(), contains('张三：1-3'));
    // 源文件未动
    expect(src.listSync().length, 6);
    await tmp.delete(recursive: true);
  });
}
