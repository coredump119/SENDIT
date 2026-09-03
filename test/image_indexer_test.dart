import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

void main() {
  test('取第一段数字', () {
    const ix = ImageIndexer();
    expect(ix.numberOf('001.png'), 1);
    expect(ix.numberOf('12_cat.jpg'), 12);
    expect(ix.numberOf('图-7.png'), 7);
    expect(ix.numberOf('IMG_2024_05.png'), 2024);
    expect(ix.numberOf('cat.png'), isNull);
  });

  test('取最后一段数字', () {
    const ix = ImageIndexer(rule: NumberRule.lastNumber);
    expect(ix.numberOf('IMG_2024_05.png'), 5);
  });

  test('index：重复、缺号、非图片', () {
    const ix = ImageIndexer();
    final r = ix.index(['/d/1.png', '/d/2.png', '/d/2 copy.png', '/d/4.jpg', '/d/notes.txt', '/d/x.png']);
    expect(r.byNumber, {1: '/d/1.png', 4: '/d/4.jpg'});
    expect(r.duplicates.keys, [2]);
    expect(r.missing, [3]);
    expect(r.maxNumber, 4);
    expect(r.unnumbered.single.name, 'x.png');
    expect(r.ok, isFalse);
  });

  test('sequential：忽略文件名按顺序编号', () {
    const ix = ImageIndexer(rule: NumberRule.sequential);
    final r = ix.index(['/d/zeta.png', '/d/notes.txt', '/d/alpha.jpg', '/d/IMG_9.png']);
    expect(r.byNumber, {1: '/d/zeta.png', 2: '/d/alpha.jpg', 3: '/d/IMG_9.png'});
    expect(r.duplicates, isEmpty);
    expect(r.missing, isEmpty);
    expect(r.maxNumber, 3);
  });
}
