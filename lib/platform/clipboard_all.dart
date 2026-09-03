import 'package:flutter/services.dart';

/// 读取剪贴板里"所有"条目、所有文本类型，取最完整的那份。
/// 微信多选复制在 iOS 上可能是多个条目，或纯文本只含首条而富文本才完整。
class ClipboardAll {
  static const _ch = MethodChannel('sendit/clipboard');

  static Future<String> readAll() async {
    try {
      final s = await _ch.invokeMethod<String>('readAll');
      if (s != null && s.trim().isNotEmpty) return s;
    } on MissingPluginException {
      // web / 未实现的平台
    } catch (_) {}
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    return d?.text ?? '';
  }
}
