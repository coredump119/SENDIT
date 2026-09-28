import 'models.dart';

/// 从一条消息文本中提取认领号与取消号。
///
/// 规则见 DEV.md §4.2。纯函数，无状态。
class NumberParser {
  final int maxNumber;
  const NumberParser(this.maxNumber);

  // 数字后面跟这些单位 → 不是扣号
  static final _unitAfter = RegExp(
    r'(\d+)\s*(分钟|分|小时|点半|点钟|点|月|日|号楼|楼|元|块钱|块|张|个|次|秒|天|年|人|岁|米|公里|折|倍|万|千|百|k|K)',
  );
  // 前面跟这些 → 序数/时间，不是扣号
  static final _prefixBefore = RegExp(r'(第|周|星期|礼拜)\s*(\d+)');
  static final _swap = RegExp(r'(\d+)\s*换\s*(\d+)');
  static final _cancelPre = RegExp(r'(退掉|退|取消|不要|放弃|去掉|删掉|删)\s*(\d+)');
  static final _cancelPost = RegExp(r'(\d+)\s*(不要了|不要|退了|退|取消|放弃|去掉|删掉)');
  static final _range = RegExp(r'(\d+)\s*[-~～—–－至]\s*(\d+)|(\d+)\s*到\s*(\d+)');
  static final _bracketEmoji = RegExp(r'\[[^\]]{1,10}\]');
  static final _number = RegExp(r'\d+');

  // 扣号语境里常见的词组，先整体去掉
  static const _phrases = [
    '谢谢', '感谢', '老师', '大大', '太太', '作者', '麻烦', '辛苦', '请问', '可以',
    '一下', '这些', '所有', '全部', '剩下', '其他', '别的', '另外', '优先', '顺序',
    '依次', '分别', '已经', '如果', '还有', '没有', '有的话', '的话', '能不能',
    '好的', '好了', '好嘞', '好哒', '好滴', '收到', '拜托', '在吗', '有吗', '还在',
    'ok', 'OK', 'Ok', 'pls', 'plz', 'thx', 'thanks', 'please',
  ];
  // 扣号语境里的单字（去掉后剩余的才算"闲聊量"）
  static const _singles = [
    '扣', '要', '号', '我', '加', '和', '跟', '与', '及', '的', '了', '呀', '吧',
    '哈', '嘿', '哦', '啊', '呢', '吗', '嘛', '哇', '嗯', '想', '求', '再', '补',
    '来', '拿', '走', '抢', '给', '发', '私', '帮', '图', '张', '也', '都', '就',
    '先', '还', '有', '没', '被', '在', '换', '退', '不', '同', '样', '一', '两',
    '几', '多', '份', '排', '队', '让', '等', '选', '挑', '定', '个', '各',
  ];

  ParsedMessage parse(RawMessage raw) {
    var text = _normalize(raw.text);
    final claims = <int>[];
    final cancels = <int>[];
    final outOfRange = <int>[];

    void addClaim(int n) {
      if (n < 1 || n > maxNumber) {
        outOfRange.add(n);
      } else if (!claims.contains(n)) {
        claims.add(n);
      }
    }

    void addCancel(int n) {
      if (n >= 1 && n <= maxNumber && !cancels.contains(n)) cancels.add(n);
    }

    if (text.isEmpty) return _noise(raw);

    // 0. 表情 / 系统标记
    text = text.replaceAll(_bracketEmoji, ' ');

    // 1. 换号：a换b
    text = text.replaceAllMapped(_swap, (m) {
      addCancel(int.parse(m[1]!));
      addClaim(int.parse(m[2]!));
      return ' ';
    });

    // 2. 取消
    text = text.replaceAllMapped(_cancelPre, (m) {
      addCancel(int.parse(m[2]!));
      return ' ';
    });
    text = text.replaceAllMapped(_cancelPost, (m) {
      addCancel(int.parse(m[1]!));
      return ' ';
    });

    // 3. 单位/序数 → 剔除
    text = text.replaceAll(_prefixBefore, ' ');
    text = text.replaceAll(_unitAfter, ' ');

    // 4. 区间
    text = text.replaceAllMapped(_range, (m) {
      final a = int.parse(m[1] ?? m[3]!);
      final b = int.parse(m[2] ?? m[4]!);
      if (a <= b && b - a < 500) {
        for (var n = a; n <= b; n++) {
          addClaim(n);
        }
      } else {
        addClaim(a);
        addClaim(b);
      }
      return ' ';
    });

    // 5. 剩余孤立数字
    text = text.replaceAllMapped(_number, (m) {
      addClaim(int.parse(m[0]!));
      return ' ';
    });

    if (claims.isEmpty && cancels.isEmpty) {
      return ParsedMessage(
        raw: raw,
        claims: const [],
        cancels: const [],
        status: ParseStatus.noise,
        outOfRange: outOfRange,
      );
    }

    // 6. 闲聊量判断
    final residual = _residualText(text);
    // 只看去掉数字、标点、常见扣号用语后剩下的文字量；纯号码列表再长也不算待确认
    final ambiguous = residual.length >= 3;

    return ParsedMessage(
      raw: raw,
      claims: claims,
      cancels: cancels,
      status: ambiguous ? ParseStatus.ambiguous : ParseStatus.ok,
      outOfRange: outOfRange,
    );
  }

  ParsedMessage _noise(RawMessage raw) => ParsedMessage(
        raw: raw,
        claims: const [],
        cancels: const [],
        status: ParseStatus.noise,
      );

  /// 去掉关键词、标点、空白后剩下的字符
  static String _residualText(String text) {
    var t = text;
    for (final k in _phrases) {
      t = t.replaceAll(k, '');
    }
    for (final k in _singles) {
      t = t.replaceAll(k, '');
    }
    t = t.replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
    return t;
  }

  /// 全角数字/标点 → 半角；统一空白
  static String _normalize(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF10 && r <= 0xFF19) {
        sb.writeCharCode(r - 0xFF10 + 0x30); // ０-９
      } else if (r == 0xFF0C || r == 0x3001) {
        sb.write(','); // ，、
      } else if (r == 0xFF0F) {
        sb.write('/'); // ／
      } else if (r == 0x3000 || r == 0xA0) {
        sb.write(' ');
      } else {
        sb.writeCharCode(r);
      }
    }
    return sb.toString().trim();
  }
}
