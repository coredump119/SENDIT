import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

void main() {
  test('compress', () {
    expect(Report.compress([1, 2, 3, 5, 7, 8, 10]), '1-3, 5, 7, 8, 10');
    expect(Report.compress([3, 1, 2]), '1-3');
    expect(Report.compress([]), '');
  });

  test('folderName 去非法字符', () {
    final p = PersonResult(name: 'a/b:c..', firstOrder: 0, got: [1, 2, 3]);
    expect(Report.folderName(p), 'a_b_c (3张) 1-3');
  });

  test('fileNameForNumber 补零', () {
    expect(Report.fileNameForNumber(5, 'cat.PNG', 80), '05.PNG');
    expect(Report.fileNameForNumber(5, 'x.jpg', 120), '005.jpg');
  });

  test('announcement', () {
    const parser = NumberParser(6);
    final ms = [
      parser.parse(const RawMessage(sender: 'A', time: null, order: 0, text: '1-4')),
      parser.parse(const RawMessage(sender: 'B', time: null, order: 1, text: '2 5')),
    ];
    final a = Allocator().allocate(ms, const Rules(maxNumber: 6, defaultLimit: 3));
    expect(Report.announcement(a), '''本轮分配结果（共 6 张）
A：1-3
B：5
—
超出限量、未分配：
  A：4
—
已被先扣走：
  B：2
—
未认领：4, 6''');
  });

  test('第二轮公告与开轮消息', () {
    const parser = NumberParser(6);
    final ms = [parser.parse(const RawMessage(sender: 'C', time: null, order: 0, text: '4'))];
    final a = Allocator().allocate(ms, const Rules(maxNumber: 6, preassigned: {1: 'A', 2: 'A', 3: 'B'}));
    expect(Report.announcement(a, round: 2), '''第 2 轮分配结果
C：4
—
仍未认领：5, 6''');
    expect(Report.nextRoundMessage(2, [4, 5, 6]), '第 2 轮可扣：4-6');
  });
}
