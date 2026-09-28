import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

/// 用户从微信手机端「多选 → 复制」得到的真实样本
const sampleA = '''麋鹿
2026/08/30 21:59
13 22

 青柠
2026/08/30 22:00
18，40

 月见草
2026/08/30 22:00
7，23

 松鼠先生
2026/08/30 22:00
3

 松鼠先生
2026/08/30 22:00
3

 山茶
2026/08/30 22:00
7/13/20/21

 白桦
2026/08/30 22:00
2，3，33，36，37，39

 用户1234567890
2026/08/30 22:00
05 09

 山茶
2026/08/30 22:00
7/13/20/21

 云..
2026/08/30 22:00
36/37/38/40/6/9''';

void main() {
  sampleBTests();
  final imp = ChatImporter();

  test('格式 A：手机端复制', () {
    final ms = imp.import(sampleA);
    expect(ms.length, 10);
    expect(ms[0].sender, '麋鹿');
    expect(ms[0].time, DateTime(2026, 8, 30, 21, 59));
    expect(ms[0].text, '13 22');
    expect(ms[1].sender, '青柠'); // 前导空格去掉
    expect(ms[7].sender, '用户1234567890');
    expect(ms[7].text, '05 09');
    expect(ms[9].sender, '云..');
    expect(ms[9].text, '36/37/38/40/6/9');
    expect(ms.map((m) => m.order).toList(), List.generate(10, (i) => i));
  });

  test('格式 A：12 小时制 AM/PM 与中文上午/下午', () {
    final ms = imp.import('''₍^·༝·^*₎ﾉ 
2026/09/23 9:59 PM
4 5 33

若鱼🍀Wendy 
2026/09/23 10:00 PM
39 18

晨
2026/9/23 上午9:05
1

R.
2026/09/23 12:10 AM
2''');
    expect(ms.length, 4);
    expect(ms[0].sender, '₍^·༝·^*₎ﾉ');
    expect(ms[0].time, DateTime(2026, 9, 23, 21, 59));
    expect(ms[1].time, DateTime(2026, 9, 23, 22, 0));
    expect(ms[2].time, DateTime(2026, 9, 23, 9, 5));
    expect(ms[3].time, DateTime(2026, 9, 23, 0, 10));
    expect(ms[0].text, '4 5 33');
  });

  test('格式 A：多行内容', () {
    final ms = imp.import('''张三
2026/09/01 10:00
1 2
还有 3

李四
2026/09/01 10:01
4''');
    expect(ms.length, 2);
    expect(ms[0].text, '1 2\n还有 3');
    expect(ms[1].text, '4');
  });

  test('格式 B：昵称 + 时:分 一行', () {
    final ms = imp.import('''张三  14:32
1 3 5
李四 14:33
扣7''');
    expect(ms.length, 2);
    expect(ms[0].sender, '张三');
    expect(ms[0].text, '1 3 5');
    expect(ms[1].text, '扣7');
  });

  test('格式 C：昵称: 内容', () {
    final ms = imp.import('张三: 1 3\n李四：5\n\n王五:7');
    expect(ms.length, 3);
    expect(ms[1].sender, '李四');
    expect(ms[2].text, '7');
  });

  test('整链路：样本 → 解析 → 分配', () {
    final ms = imp.import(sampleA);
    const parser = NumberParser(40);
    final parsed = ms.map(parser.parse).toList();
    final a = Allocator().allocate(parsed, const Rules(maxNumber: 40));

    expect(a.person('麋鹿')!.got, [13, 22]);
    expect(a.person('松鼠先生')!.got, [3]);
    // 山茶 的 7、13 已被先扣
    expect(a.person('山茶')!.got, [20, 21]);
    expect(a.person('山茶')!.lostTo,
        [const LostTo(7, '月见草'), const LostTo(13, '麋鹿')]);
    // 白桦 的 3 被松鼠先生先扣
    expect(a.person('白桦')!.got, [2, 33, 36, 37, 39]);
    expect(a.person('用户1234567890')!.got, [5, 9]);
    expect(a.person('云..')!.got, [6, 38]);
    expect(a.needsReview, isEmpty);
  });
}

/// 第二段真实格式样本（昵称已替换）：点号分隔、单字昵称、英文昵称
const sampleB = '''电磁炮
2026/08/28 21:59
3 7 9 11 15 28 25 6 35

 月见草
2026/08/28 22:00
29

 瓶子
2026/08/28 22:00
21.04.39.35

 Ansger
2026/08/28 22:00
13.14.25.28.40

 晨
2026/08/28 22:00
28/36/12/15/20

 F
2026/08/28 22:00
16/25/37/28''';

void sampleBTests() {
  test('格式 A 样本 B：点号分隔、单字 / 英文昵称', () {
    final ms = ChatImporter().import(sampleB);
    expect(ms.length, 6);
    expect(ms.map((m) => m.sender).toList(), ['电磁炮', '月见草', '瓶子', 'Ansger', '晨', 'F']);
    const parser = NumberParser(40);
    expect(parser.parse(ms[2]).claims, [21, 4, 39, 35]);
    expect(parser.parse(ms[3]).claims, [13, 14, 25, 28, 40]);
    expect(parser.parse(ms[0]).claims, [3, 7, 9, 11, 15, 28, 25, 6, 35]);
  });
}
