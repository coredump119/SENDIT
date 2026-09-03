import 'package:flutter_test/flutter_test.dart';
import 'package:sendit/core/core.dart';

RawMessage msg(String t, [int order = 0]) =>
    RawMessage(sender: 'A', time: null, order: order, text: t);

void main() {
  const p = NumberParser(80);

  group('基本写法', () {
    test('空格分隔', () => expect(p.parse(msg('1 3 5')).claims, [1, 3, 5]));
    test('中英逗号/顿号/斜杠', () {
      expect(p.parse(msg('1,3,5')).claims, [1, 3, 5]);
      expect(p.parse(msg('1，3，5')).claims, [1, 3, 5]);
      expect(p.parse(msg('1、3、5')).claims, [1, 3, 5]);
      expect(p.parse(msg('7/13/20/21')).claims, [7, 13, 20, 21]);
    });
    test('前导零', () => expect(p.parse(msg('05 09')).claims, [5, 9]));
    test('全角数字', () => expect(p.parse(msg('１３ ２２')).claims, [13, 22]));
    test('扣/要/号', () {
      expect(p.parse(msg('扣7')).claims, [7]);
      expect(p.parse(msg('7号')).claims, [7]);
      expect(p.parse(msg('要7')).claims, [7]);
      expect(p.parse(msg('我要5和7')).claims, [5, 7]);
    });
    test('去重', () => expect(p.parse(msg('3 3 3')).claims, [3]));
  });

  group('区间', () {
    test('各种横线', () {
      expect(p.parse(msg('1-5')).claims, [1, 2, 3, 4, 5]);
      expect(p.parse(msg('1~5')).claims, [1, 2, 3, 4, 5]);
      expect(p.parse(msg('1到5')).claims, [1, 2, 3, 4, 5]);
      expect(p.parse(msg('1—5')).claims, [1, 2, 3, 4, 5]);
    });
    test('混合', () => expect(p.parse(msg('1-3, 7, 9号')).claims, [1, 2, 3, 7, 9]));
    test('倒序区间当两个号', () => expect(p.parse(msg('5-1')).claims, [5, 1]));
  });

  group('取消 / 换号', () {
    test('换号', () {
      final r = p.parse(msg('5换7'));
      expect(r.cancels, [5]);
      expect(r.claims, [7]);
    });
    test('不要了', () => expect(p.parse(msg('5不要了')).cancels, [5]));
    test('退', () => expect(p.parse(msg('退5')).cancels, [5]));
    test('取消', () => expect(p.parse(msg('取消 5')).cancels, [5]));
    test('取消后剩余仍算认领', () {
      final r = p.parse(msg('退5 要8'));
      expect(r.cancels, [5]);
      expect(r.claims, [8]);
    });
  });

  group('噪音', () {
    test('时间单位', () => expect(p.parse(msg('我 10 分钟后来')).status, ParseStatus.noise));
    test('小时', () => expect(p.parse(msg('2小时前发的')).status, ParseStatus.noise));
    test('越界', () {
      final r = p.parse(msg('哈哈 666'));
      expect(r.status, ParseStatus.noise);
      expect(r.outOfRange, [666]);
    });
    test('纯文字', () => expect(p.parse(msg('太好看了')).status, ParseStatus.noise));
    test('表情', () => expect(p.parse(msg('[强][强]')).status, ParseStatus.noise));
    test('空', () => expect(p.parse(msg('')).status, ParseStatus.noise));
    test('序数', () => expect(p.parse(msg('第3个好看')).status, ParseStatus.noise));
  });

  group('需人工确认', () {
    test('长句夹数字', () =>
        expect(p.parse(msg('这个 3 真好看，我要 5')).status, ParseStatus.ambiguous));
    test('礼貌用语不算闲聊', () {
      expect(p.parse(msg('扣7 谢谢老师')).status, ParseStatus.ok);
      expect(p.parse(msg('1 3 5 麻烦老师了')).status, ParseStatus.ok);
      expect(p.parse(msg('5 我先扣了')).status, ParseStatus.ok);
    });
  });
}
