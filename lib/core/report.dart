import 'models.dart';

/// 文本输出：群公告、文件夹名、号码压缩显示。
class Report {
  /// [1,2,3,5,7,8] -> "1-3, 5, 7-8"
  static String compress(Iterable<int> numbers, {String sep = ', '}) {
    final ns = numbers.toSet().toList()..sort();
    if (ns.isEmpty) return '';
    final parts = <String>[];
    var start = ns.first, prev = ns.first;
    for (var i = 1; i <= ns.length; i++) {
      final cur = i < ns.length ? ns[i] : null;
      if (cur != null && cur == prev + 1) {
        prev = cur;
        continue;
      }
      parts.add(start == prev
          ? '$start'
          : prev == start + 1
              ? '$start$sep$prev'
              : '$start-$prev');
      if (cur != null) {
        start = cur;
        prev = cur;
      }
    }
    return parts.join(sep);
  }

  /// [round] ≥ 2 时标题写"第 n 轮"，且只列本轮的人
  static String announcement(Allocation a, {String? title, int round = 1}) {
    final sb = StringBuffer();
    sb.writeln(title ?? (round <= 1 ? '本轮分配结果（共 ${a.maxNumber} 张）' : '第 $round 轮分配结果'));
    for (final p in a.people) {
      if (p.got.isEmpty) continue;
      sb.writeln('${p.name}：${compress(p.got)}');
    }
    final dropped = a.people.where((p) => p.droppedByLimit.isNotEmpty).toList();
    if (dropped.isNotEmpty) {
      sb.writeln('—');
      sb.writeln('超出限量、未分配：');
      for (final p in dropped) {
        sb.writeln('  ${p.name}：${compress(p.droppedByLimit)}');
      }
    }
    // "已被先扣走"不再写进公告：群里没人需要，反而要手动删
    final un = a.unclaimed;
    if (un.isNotEmpty) {
      sb.writeln('—');
      sb.writeln('${round <= 1 ? '未认领' : '仍未认领'}：${compress(un)}');
    }
    return sb.toString().trimRight();
  }

  /// 开下一轮时贴到群里的消息
  static String nextRoundMessage(int round, Iterable<int> unclaimed) =>
      '第 $round 轮可扣：${compress(unclaimed)}';

  /// "需人工确认"文本；没有则返回 null
  static String? reviewText(Allocation a) {
    if (a.needsReview.isEmpty) return null;
    final sb = StringBuffer('以下消息含数字但夹杂较多文字，未自动计入：\n\n');
    for (final m in a.needsReview) {
      sb.writeln('[${m.raw.sender}] ${m.raw.text}');
      sb.writeln('  识别到：${m.claims.join(', ')}');
      sb.writeln();
    }
    return sb.toString();
  }

  static final _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

  /// `张三 (5张) 1-5`
  static String folderName(PersonResult p) {
    var name = p.name.replaceAll(_illegal, '_').trim();
    name = name.replaceAll(RegExp(r'[. ]+$'), '');
    if (name.isEmpty) name = '未知';
    var nums = compress(p.got, sep: ',');
    if (nums.length > 40) nums = '${nums.substring(0, 37)}…';
    return '$name (${p.got.length}张) $nums';
  }

  static String fileNameForNumber(int n, String originalName, int maxNumber) {
    final width = maxNumber.toString().length.clamp(2, 4);
    final ext = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '';
    return '${n.toString().padLeft(width, '0')}$ext';
  }
}
