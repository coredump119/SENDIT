import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

const parser = NumberParser(10);
final alloc = Allocator();

/// 快速构造：[['A','1-10'], ['B','2 4']]
List<ParsedMessage> msgs(List<List<String>> rows) => [
      for (var i = 0; i < rows.length; i++)
        parser.parse(RawMessage(
            sender: rows[i][0], time: null, order: i, text: rows[i][1])),
    ];

void main() {
  group('限量（max=10，全局限 5）', () {
    const rules = Rules(maxNumber: 10, defaultLimit: 5);

    test('A 扣 1-10 → 得前 5，其余舍弃并释放', () {
      final a = alloc.allocate(msgs([['A', '1-10']]), rules);
      expect(a.person('A')!.got, [1, 2, 3, 4, 5]);
      expect(a.person('A')!.droppedByLimit, [6, 7, 8, 9, 10]);
      expect(a.unclaimed, [6, 7, 8, 9, 10]);
    });

    test('B 先扣 2 4，A 后扣 1-10 → A 得实际能拿到的前 5', () {
      final a = alloc.allocate(msgs([['B', '2 4'], ['A', '1-10']]), rules);
      expect(a.person('B')!.got, [2, 4]);
      expect(a.person('A')!.got, [1, 3, 5, 6, 7]);
      expect(a.person('A')!.lostTo, [const LostTo(2, 'B'), const LostTo(4, 'B')]);
      expect(a.person('A')!.droppedByLimit, [8, 9, 10]);
    });

    test('分两次扣累计', () {
      final a = alloc.allocate(msgs([['A', '1 2 3'], ['A', '4 5 6 7']]), rules);
      expect(a.person('A')!.got, [1, 2, 3, 4, 5]);
      expect(a.person('A')!.droppedByLimit, [6, 7]);
    });

    test('舍弃的号后来者可拿', () {
      final a = alloc.allocate(msgs([['A', '1-10'], ['C', '8']]), rules);
      expect(a.person('C')!.got, [8]);
    });

    test('单人限量覆盖全局', () {
      final a = alloc.allocate(
        msgs([['A', '1-10']]),
        rules.copyWith(personLimits: {'A': 2}),
      );
      expect(a.person('A')!.got, [1, 2]);
    });

    test('改限量后重算：保留最早的，其余释放给后来者', () {
      final ms = msgs([['A', '1 2 3 4 5'], ['B', '3']]);
      final a1 = alloc.allocate(ms, rules);
      expect(a1.person('B')!.got, isEmpty);
      final a2 = alloc.allocate(ms, rules.copyWith(personLimits: {'A': 2}));
      expect(a2.person('A')!.got, [1, 2]);
      expect(a2.person('B')!.got, [3]);
    });
  });

  group('取消 / 保留 / 排除', () {
    const rules = Rules(maxNumber: 10);

    test('取消后释放给后来者', () {
      final a = alloc.allocate(msgs([['A', '1 2'], ['A', '1不要了'], ['B', '1']]), rules);
      expect(a.person('A')!.got, [2]);
      expect(a.person('B')!.got, [1]);
    });

    test('不能取消别人的号', () {
      final a = alloc.allocate(msgs([['A', '1'], ['B', '退1']]), rules);
      expect(a.owner[1], 'A');
    });

    test('换号', () {
      final a = alloc.allocate(msgs([['A', '5'], ['A', '5换7']]), rules);
      expect(a.person('A')!.got, [7]);
      expect(a.owner[5], isNull);
    });

    test('保留号', () {
      final a = alloc.allocate(msgs([['A', '1 2']]), rules.copyWith(reserved: {1}));
      expect(a.person('A')!.got, [2]);
      expect(a.person('A')!.lostTo, [const LostTo(1, Allocation.reservedOwner)]);
      expect(a.reservedNumbers, [1]);
    });

    test('重复扣同一号不重复计', () {
      final a = alloc.allocate(msgs([['A', '3'], ['A', '3']]), rules);
      expect(a.person('A')!.got, [3]);
      expect(a.person('A')!.lostTo, isEmpty);
    });

    test('排除某人 → 其号释放', () {
      final a = alloc.allocate(msgs([['A', '1'], ['B', '1']]), rules.copyWith(excluded: {'A'}));
      expect(a.person('A'), isNull);
      expect(a.person('B')!.got, [1]);
    });

    test('作者消息不参与', () {
      final a = alloc.allocate(msgs([['me', '1-10'], ['A', '1']]), rules.copyWith(authorName: 'me'));
      expect(a.person('A')!.got, [1]);
    });
  });

  group('起点 / 人工确认 / 手动覆盖', () {
    const rules = Rules(maxNumber: 10);

    test('起点之前忽略', () {
      final a = alloc.allocate(msgs([['A', '1'], ['B', '1']]), rules.copyWith(anchorOrder: 1));
      expect(a.owner[1], 'B');
    });

    test('ambiguous 默认不计入，进 needsReview', () {
      final a = alloc.allocate(msgs([['A', '这个 3 真好看，我要 5']]), rules);
      expect(a.owner[5], isNull);
      expect(a.needsReview.length, 1);
    });

    test('approve 后计入', () {
      final a = alloc.allocate(
          msgs([['A', '这个 3 真好看，我要 5']]), rules.copyWith(approvedOrders: {0}));
      expect(a.person('A')!.got, [3, 5]);
      expect(a.needsReview, isEmpty);
    });

    test('ignore 后消失', () {
      final a = alloc.allocate(
          msgs([['A', '这个 3 真好看，我要 5']]), rules.copyWith(ignoredOrders: {0}));
      expect(a.needsReview, isEmpty);
    });

    test('手动改归属绕过限量', () {
      final a = alloc.allocate(
        msgs([['A', '1 2'], ['B', '3']]),
        rules.copyWith(defaultLimit: 1, manualOverrides: {2: 'B', 3: null}),
      );
      expect(a.person('A')!.got, [1]);
      expect(a.person('B')!.got, [2]);
      expect(a.owner[3], isNull);
    });
  });

  group('开始时间', () {
    ParsedMessage at(String who, String text, int order, int hour, int minute) =>
        parser.parse(RawMessage(
            sender: who, time: DateTime(2026, 8, 30, hour, minute), order: order, text: text));
    final start = DateTime(2026, 8, 30, 22, 0);

    test('21:59 的提前扣号排到 22:00 之后的人后面', () {
      final ms = [
        at('早鸟', '1 2', 0, 21, 59),
        at('A', '1', 1, 22, 0),
        at('B', '2 3', 2, 22, 1),
      ];
      final a = alloc.allocate(ms, Rules(maxNumber: 10, startTime: start));
      expect(a.person('A')!.got, [1]);
      expect(a.person('B')!.got, [2, 3]);
      expect(a.person('早鸟')!.got, isEmpty);
      expect(a.person('早鸟')!.lostTo, [const LostTo(1, 'A'), const LostTo(2, 'B')]);
    });

    test('提前的人之间仍按原顺序', () {
      final ms = [
        at('早1', '5', 0, 21, 58),
        at('早2', '5 6', 1, 21, 59),
        at('A', '7', 2, 22, 0),
      ];
      final a = alloc.allocate(ms, Rules(maxNumber: 10, startTime: start));
      expect(a.person('早1')!.got, [5]);
      expect(a.person('早2')!.got, [6]);
    });

    test('没有时间的消息不算提前', () {
      final ms = msgs([['A', '1'], ['B', '1']]);
      final a = alloc.allocate(ms, Rules(maxNumber: 10, startTime: start));
      expect(a.owner[1], 'A');
    });
  });

  group('第二轮（preassigned）', () {
    test('第一轮已分的号第二轮扣不到，记为 lostTo', () {
      final r1 = alloc.allocate(msgs([['A', '1 2'], ['B', '3']]), const Rules(maxNumber: 6));
      final locked = {for (final e in r1.owner.entries) if (e.value != null) e.key: e.value!};
      final r2 = alloc.allocate(msgs([['C', '1 4'], ['A', '5']]), Rules(maxNumber: 6, preassigned: locked));
      expect(r2.person('C')!.got, [4]);
      expect(r2.person('C')!.lostTo, [const LostTo(1, 'A')]);
      expect(r2.person('A')!.got, [5]); // 第二轮只记本轮拿到的
      expect(r2.owner[1], 'A');
      expect(r2.owner[3], 'B');
      expect(r2.unclaimed, [6]);
      expect(r2.people.map((p) => p.name).toList(), ['C', 'A']); // B 本轮没说话，不在本轮名单
    });

    test('第二轮限量按轮重新计数', () {
      final locked = {1: 'A', 2: 'A'};
      final r2 = alloc.allocate(msgs([['A', '3 4 5']]), Rules(maxNumber: 6, defaultLimit: 2, preassigned: locked));
      expect(r2.person('A')!.got, [3, 4]);
    });

    test('自留号与锁定号都不算未认领', () {
      final r2 = alloc.allocate(msgs([['A', '2']]), Rules(maxNumber: 4, reserved: {1}, preassigned: {3: 'B'}));
      expect(r2.unclaimed, [4]);
    });
  });

  group('人的顺序', () {
    test('按首次出现', () {
      final a = alloc.allocate(msgs([['B', '1'], ['A', '2'], ['B', '3']]), const Rules(maxNumber: 10));
      expect(a.people.map((p) => p.name).toList(), ['B', 'A']);
    });
  });
}
