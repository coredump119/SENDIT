import 'models.dart';

/// 把粘贴进来的聊天文本切成 [RawMessage] 列表。
///
/// 支持三种格式（自动识别）：
///
/// A. 微信手机端「多选 → 复制」：
/// ```
/// 昵称
/// 2026/08/30 21:59
/// 内容
///
/// 昵称
/// ...
/// ```
/// B. 桌面端常见「昵称  14:32」一行 + 内容行
/// C. 手写「昵称: 内容」每行一条
class ChatImporter {
  /// 2026/08/30 21:59 · 2026/9/23 9:59 PM · 2026-09-23 上午9:59 · 2026年9月23日 下午10:00
  static final _fullTime = RegExp(
      r'^\s*(\d{4})[/\-.年](\d{1,2})[/\-.月](\d{1,2})日?\s+(上午|下午|凌晨|中午|晚上|AM|PM|am|pm)?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\s*$');
  static final _nameTimeLine =
      RegExp(r'^\s*(.+?)\s{1,}(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$');
  static final _colonLine = RegExp(r'^\s*([^:：]{1,40})[:：]\s*(.*)$');

  List<RawMessage> import(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.any((l) => _fullTime.hasMatch(l))) return _parseA(lines);
    if (lines.where((l) => _nameTimeLine.hasMatch(l)).length >= 2) {
      return _parseB(lines);
    }
    return _parseC(lines);
  }

  /// 格式 A：找所有时间行，其前一行是昵称，内容延续到下一个「昵称+时间」对之前。
  List<RawMessage> _parseA(List<String> lines) {
    final headerIdx = <int>[]; // 昵称行下标
    for (var i = 0; i + 1 < lines.length; i++) {
      if (_fullTime.hasMatch(lines[i + 1]) && lines[i].trim().isNotEmpty) {
        headerIdx.add(i);
      }
    }
    final out = <RawMessage>[];
    for (var k = 0; k < headerIdx.length; k++) {
      final h = headerIdx[k];
      final end = k + 1 < headerIdx.length ? headerIdx[k + 1] : lines.length;
      final body = lines.sublist(h + 2, end);
      final content = _trimBlank(body).join('\n');
      out.add(RawMessage(
        sender: lines[h].trim(),
        time: _parseFullTime(lines[h + 1]),
        order: out.length,
        text: content,
      ));
    }
    return out;
  }

  List<RawMessage> _parseB(List<String> lines) {
    final out = <RawMessage>[];
    String? sender;
    DateTime? time;
    final buf = <String>[];
    void flush() {
      if (sender != null) {
        out.add(RawMessage(
          sender: sender,
          time: time,
          order: out.length,
          text: _trimBlank(buf).join('\n'),
        ));
      }
      buf.clear();
    }

    for (final l in lines) {
      final m = _nameTimeLine.firstMatch(l);
      if (m != null) {
        flush();
        sender = m[1]!.trim();
        final now = DateTime.now();
        time = DateTime(now.year, now.month, now.day, int.parse(m[2]!),
            int.parse(m[3]!), int.parse(m[4] ?? '0'));
      } else {
        buf.add(l);
      }
    }
    flush();
    return out;
  }

  List<RawMessage> _parseC(List<String> lines) {
    final out = <RawMessage>[];
    for (final l in lines) {
      if (l.trim().isEmpty) continue;
      final m = _colonLine.firstMatch(l);
      if (m == null) continue;
      out.add(RawMessage(
        sender: m[1]!.trim(),
        time: null,
        order: out.length,
        text: m[2]!.trim(),
      ));
    }
    return out;
  }

  static DateTime? _parseFullTime(String s) {
    final m = _fullTime.firstMatch(s);
    if (m == null) return null;
    var hour = int.parse(m[5]!);
    final marker = (m[4] ?? m[8] ?? '').toUpperCase();
    final pm = marker == 'PM' || marker == '下午' || marker == '晚上';
    final am = marker == 'AM' || marker == '上午' || marker == '凌晨';
    if (pm && hour < 12) hour += 12;
    if (am && hour == 12) hour = 0;
    return DateTime(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      hour,
      int.parse(m[6]!),
      int.parse(m[7] ?? '0'),
    );
  }

  static List<String> _trimBlank(List<String> body) {
    var s = 0, e = body.length;
    while (s < e && body[s].trim().isEmpty) {
      s++;
    }
    while (e > s && body[e - 1].trim().isEmpty) {
      e--;
    }
    return body.sublist(s, e).map((l) => l.trimRight()).toList();
  }
}
