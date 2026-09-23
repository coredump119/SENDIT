import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

CollageItem p(int n) => CollageItem(number: n, width: 9, height: 16); // 竖图
CollageItem l(int n) => CollageItem(number: n, width: 16, height: 9); // 横图

void main() {
  const lay = CollageLayout();

  test('保持比例：每个位置的宽高比等于原图比例', () {
    final page = lay.layout([p(1), l(2), p(3), p(4)]);
    for (final pl in page.items) {
      final src = pl.number == 2 ? 16 / 9 : 9 / 16;
      expect(pl.w / pl.h, closeTo(src, 1e-6));
    }
  });

  List<List<Placement>> rowsOf(CollagePage page) {
    final byY = <double, List<Placement>>{};
    for (final it in page.items) {
      byY.putIfAbsent(it.y, () => []).add(it);
    }
    final keys = byY.keys.toList()..sort();
    return [for (final k in keys) byY[k]!];
  }

  test('8 张竖图 → 两行各 4 张，每行填满宽度、同行等高、顺序不变', () {
    final page = lay.layout([for (var i = 1; i <= 8; i++) p(i)]);
    expect(page.items.map((e) => e.number).toList(), [1, 2, 3, 4, 5, 6, 7, 8]);
    final rows = rowsOf(page);
    expect(rows.map((r) => r.length).toList(), [4, 4]);
    for (final r in rows) {
      expect(r.last.x + r.last.w, closeTo(lay.canvasWidth - lay.margin, 0.5));
      expect(r.map((e) => e.h).toSet().length, 1);
    }
  });

  test('竖图一行不超过 4 张', () {
    for (var n = 1; n <= 8; n++) {
      final page = lay.layout([for (var i = 1; i <= n; i++) p(i)]);
      for (final r in rowsOf(page)) {
        expect(r.length, lessThanOrEqualTo(4), reason: 'n=$n');
      }
    }
  });

  test('不会出现孤儿行：7 张竖图 → 4 + 3', () {
    final page = lay.layout([for (var i = 1; i <= 7; i++) p(i)]);
    expect(rowsOf(page).map((r) => r.length).toList(), [4, 3]);
  });

  test('混排：横图 + 一张竖图同行，不会横图独占一行撑满', () {
    final page = lay.layout([l(1), p(2), p(3), p(4), p(5)]);
    final rows = rowsOf(page);
    expect(rows.length, 2);
    expect(rows.first.map((e) => e.number).toList(), [1, 2]);
    expect(rows.first.first.h, lessThan(lay.targetRowHeight * 1.05));
  });

  test('连续横图：两两一行，不会每张独占一行', () {
    final page = lay.layout([l(1), l(2), l(3), l(4)]);
    final rows = rowsOf(page);
    for (final r in rows) {
      expect(r.length, greaterThanOrEqualTo(1));
      expect(r.first.h, lessThanOrEqualTo(lay.targetRowHeight * 1.05));
    }
    expect(rows.length, lessThanOrEqualTo(3));
  });

  test('竖竖方横：不会挤成一行小格子', () {
    final sq = CollageItem(number: 3, width: 1, height: 1);
    final page = lay.layout([p(1), p(2), sq, l(4), p(5), p(6)]);
    for (final r in rowsOf(page)) {
      expect(r.first.h, greaterThan(lay.targetRowHeight * 0.7), reason: 'row ${r.map((e) => e.number)}');
    }
  });

  test('单张不无限放大', () {
    final page = lay.layout([p(1)]);
    expect(page.items.single.h, lessThanOrEqualTo(lay.targetRowHeight * 1.3));
  });

  test('极端比例被夹住', () {
    final page = lay.layout([const CollageItem(number: 1, width: 1, height: 10)]);
    expect(page.items.single.w / page.items.single.h, closeTo(9 / 16, 1e-6));
  });

  test('分页：16 张 → 8 + 8，每页两行各 4；14 张 → 7 + 7', () {
    final a = lay.paginate([for (var i = 1; i <= 16; i++) p(i)]);
    expect(a.map((pg) => pg.items.length).toList(), [8, 8]);
    expect(rowsOf(a.first).map((r) => r.length).toList(), [4, 4]);
    final b = lay.paginate([for (var i = 1; i <= 14; i++) p(i)]);
    expect(b.map((pg) => pg.items.length).toList(), [7, 7]);
    expect(rowsOf(b.last).map((r) => r.length).toList(), [4, 3]);
  });
}
